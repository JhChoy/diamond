// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {IDiamond} from "../interfaces/IDiamond.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {ICreateX} from "../interfaces/ICreateX.sol";
import {CREATEX_ADDRESS, CREATEX_BYTECODE} from "./CreateX.sol";
import {CreateX} from "./CreateX.sol";

contract DiamondScript is Script {
    using stdJson for string;

    string internal root;
    string internal network;
    string internal diamondName;
    string internal diamondJson;

    bytes4[] internal addSelectors;
    bytes4[] internal replaceSelectors;

    IDiamond.FacetCut[] internal cuts;
    bytes4[] internal removeSelectors;

    struct Deployment {
        address diamond;
        address[] facets;
    }

    constructor(string memory diamondName_) {
        diamondName = diamondName_;
        diamondJson = vm.readFile(resolveCompiledOutputPath(diamondName_));
        root = vm.projectRoot();
        network = vm.toString(block.chainid);

        if (block.chainid == 31337) {
            vm.label(CREATEX_ADDRESS, "CreateX");
            vm.etch(CREATEX_ADDRESS, CREATEX_BYTECODE);
        }
    }

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function getFileName() internal view virtual returns (string memory) {
        return string.concat(diamondName, ".", network);
    }

    function getDeploymentPath() internal view virtual returns (string memory) {
        return string.concat(root, "/deployments/", getFileName(), ".json");
    }

    function getDeployer() internal returns (address) {
        (VmSafe.CallerMode mode, address msgSender,) = vm.readCallers();
        return uint256(mode) == 0 ? address(this) : msgSender;
    }

    function resolveCompiledOutputPath(string memory name) internal view returns (string memory) {
        bool hasColon = false;
        assembly {
            let ptr := add(name, 32)
            let len := mload(name)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                if eq(byte(0, mload(add(ptr, i))), 0x3a) {
                    mstore8(add(ptr, i), 0x2f)
                    hasColon := true
                    break
                }
            }
        }
        if (hasColon) {
            return string.concat(vm.projectRoot(), "/out/", name, ".json");
        } else {
            return string.concat(vm.projectRoot(), "/out/", name, ".sol/", name, ".json");
        }
    }

    function deployDiamond(bytes11 salt, bytes memory args) internal returns (address) {
        address deployer = getDeployer();
        bytes32 encodedSalt = bytes32(abi.encodePacked(deployer, hex"00", salt));
        console.log(string.concat("Deploying ", diamondName, "..."));

        address diamond =
            CreateX.create3(deployer, encodedSalt, abi.encodePacked(diamondJson.readBytes(".bytecode.object"), args));
        console.log(string.concat("  ", diamondName, ":"), diamond);
        console.log("Done\n");
        return diamond;
    }

    function _deployNewFacet(string memory facetName, bytes memory args)
        private
        returns (address, bytes4[] memory, string[] memory)
    {
        string memory json = vm.readFile(resolveCompiledOutputPath(facetName));
        bytes memory initCode = abi.encodePacked(json.readBytes(".bytecode.object"), args);
        address deployer = getDeployer();
        address facet = CreateX.computeCreate2Address(deployer, initCode);

        if (facet.codehash != bytes32(0)) {
            console.log("Facet already deployed:", facet);
        } else {
            address deployed = CreateX.create2(deployer, initCode);
            console.log(string.concat("Deployed ", facetName, ":"), deployed);
            require(facet == deployed, "Facet address does not match");
        }

        string[] memory selectorNames = vm.parseJsonKeys(json, ".methodIdentifiers");
        bytes4[] memory selectors = new bytes4[](selectorNames.length);
        console.log("  Selectors:");
        for (uint256 i = 0; i < selectorNames.length; ++i) {
            bytes4 selector = bytes4(keccak256(bytes(selectorNames[i])));
            selectors[i] = selector;
            console.log(string.concat("    ", selectorNames[i], ": ", toString(selector)));
        }
        return (facet, selectors, selectorNames);
    }

    function deployFacets(address diamond, string[] memory facetNames, bytes[] memory args)
        internal
        returns (address[] memory newFacets)
    {
        console.log("Deploying facets...");
        if (facetNames.length == 0) {
            console.log("No facets to deploy\n");
            return newFacets;
        }
        IDiamond.FacetCut[] memory facetCuts = new IDiamond.FacetCut[](facetNames.length);
        if (facetNames.length != args.length) {
            revert("Facet names and args length mismatch");
        }
        newFacets = new address[](facetNames.length);
        for (uint256 i = 0; i < facetNames.length; ++i) {
            (address facet, bytes4[] memory selectors,) = _deployNewFacet(facetNames[i], args[i]);
            facetCuts[i] = IDiamond.FacetCut({
                facetAddress: facet,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            });
            newFacets[i] = facet;
        }
        console.log("Cutting diamond...");
        IDiamondCut(diamond).diamondCut(facetCuts, address(0), "");
        console.log("Done\n");
    }

    function _upgradeFacet(
        address diamond,
        address oldFacet,
        address newFacet,
        bytes4[] memory newSelectors,
        string[] memory newSelectorNames
    ) private {
        console.log(string.concat("  Old facet: ", vm.toString(oldFacet)));
        console.log(string.concat("  New facet: ", vm.toString(newFacet)));

        addSelectors = new bytes4[](0);
        replaceSelectors = new bytes4[](0);

        for (uint256 i; i < newSelectors.length; ++i) {
            address remoteFacet = IDiamondLoupe(diamond).facetAddress(newSelectors[i]);
            if (remoteFacet == address(0)) {
                console.log("    Adding selector ", newSelectorNames[i]);
                addSelectors.push(newSelectors[i]);
            } else if (remoteFacet == oldFacet) {
                console.log("    Replacing selector ", newSelectorNames[i]);
                replaceSelectors.push(newSelectors[i]);
            } else {
                revert("Invalid selector");
            }
        }

        bytes4[] memory oldSelectors = IDiamondLoupe(diamond).facetFunctionSelectors(oldFacet);
        for (uint256 i = 0; i < oldSelectors.length; ++i) {
            bool found = false;
            for (uint256 j = 0; j < newSelectors.length; ++j) {
                if (oldSelectors[i] == newSelectors[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                console.log(string.concat("    Removing selector ", toString(oldSelectors[i])));
                removeSelectors.push(oldSelectors[i]);
            }
        }
        if (addSelectors.length > 0) {
            cuts.push(
                IDiamond.FacetCut({
                    facetAddress: newFacet,
                    action: IDiamond.FacetCutAction.Add,
                    functionSelectors: addSelectors
                })
            );
        }
        if (replaceSelectors.length > 0) {
            cuts.push(
                IDiamond.FacetCut({
                    facetAddress: newFacet,
                    action: IDiamond.FacetCutAction.Replace,
                    functionSelectors: replaceSelectors
                })
            );
        }
    }

    function loadDeployment() internal view returns (string memory deploymentJson) {
        return vm.readFile(getDeploymentPath());
    }

    function upgradeTo(string[] memory facetNames, bytes[] memory args)
        internal
        returns (Deployment memory deployment)
    {
        return upgradeTo(loadDeployment(), facetNames, args);
    }

    function upgradeTo(string memory deploymentJson, string[] memory facetNames, bytes[] memory args)
        internal
        returns (Deployment memory deployment)
    {
        deployment.diamond = deploymentJson.readAddress(string.concat(".", diamondName));
        if (facetNames.length != args.length) {
            revert("Facet names and args length mismatch");
        }
        deployment.facets = new address[](facetNames.length);
        string[] memory oldFacetNames = vm.parseJsonKeys(deploymentJson, "$");
        for (uint256 i = 0; i < oldFacetNames.length; ++i) {
            bool found = false;
            for (uint256 j = 0; j < facetNames.length; ++j) {
                if (keccak256(bytes(oldFacetNames[i])) == keccak256(bytes(facetNames[j]))) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                console.log("Removing facet:", oldFacetNames[i]);
                address oldFacet = deploymentJson.readAddress(string.concat(".", oldFacetNames[i]));
                bytes4[] memory oldSelectors = IDiamondLoupe(deployment.diamond).facetFunctionSelectors(oldFacet);
                for (uint256 j = 0; j < oldSelectors.length; ++j) {
                    console.log("    Removing selector:", toString(oldSelectors[j]));
                    removeSelectors.push(oldSelectors[j]);
                }
            }
        }

        for (uint256 i = 0; i < facetNames.length; ++i) {
            console.log("Upgrading facet:", facetNames[i]);

            (address newFacet, bytes4[] memory newSelectors, string[] memory newSelectorNames) =
                _deployNewFacet(facetNames[i], args[i]);
            deployment.facets[i] = newFacet;

            if (deploymentJson.keyExists(string.concat(".", facetNames[i]))) {
                address oldFacet = deploymentJson.readAddress(string.concat(".", facetNames[i]));

                if (oldFacet == newFacet) {
                    console.log(string.concat("  ", facetNames[i], " is up to date"));
                    continue;
                }

                _upgradeFacet(deployment.diamond, oldFacet, newFacet, newSelectors, newSelectorNames);
            } else {
                console.log("  Adding above all selectors");
                cuts.push(
                    IDiamond.FacetCut({
                        facetAddress: newFacet,
                        action: IDiamond.FacetCutAction.Add,
                        functionSelectors: newSelectors
                    })
                );
            }
        }

        if (removeSelectors.length > 0) {
            cuts.push(
                IDiamond.FacetCut({
                    facetAddress: address(0),
                    action: IDiamond.FacetCutAction.Remove,
                    functionSelectors: removeSelectors
                })
            );
            if (cuts.length > 1) {
                // @dev switch the first and last cuts to execute the remove cut first
                IDiamond.FacetCut memory tmp = cuts[0];
                cuts[0] = cuts[cuts.length - 1];
                cuts[cuts.length - 1] = tmp;
            }
        }

        if (cuts.length > 0) {
            console.log("Applying cuts...");
            IDiamondCut(deployment.diamond).diamondCut(cuts, address(0), "");
            console.log("Done\n");
        } else {
            console.log("No changes to apply");
        }
    }

    function upgradeToAndSave(string[] memory facetNames, bytes[] memory args)
        internal
        returns (Deployment memory deployment)
    {
        deployment = upgradeTo(facetNames, args);
        saveDeployment(deployment.diamond, facetNames, deployment.facets);
    }

    function upgradeToAndSave(string memory deploymentJson, string[] memory facetNames, bytes[] memory args)
        internal
        returns (Deployment memory deployment)
    {
        deployment = upgradeTo(deploymentJson, facetNames, args);
        saveDeployment(deployment.diamond, facetNames, deployment.facets);
    }

    function deploy(bytes memory args) internal returns (Deployment memory deployment) {
        return deploy(args, new string[](0), new bytes[](0));
    }

    function deploy(bytes memory args, bytes11 salt) internal returns (Deployment memory deployment) {
        return deploy(args, salt, new string[](0), new bytes[](0));
    }

    function deploy(bytes memory args, string[] memory facetNames, bytes[] memory facetArgs)
        internal
        returns (Deployment memory deployment)
    {
        return deploy(args, bytes11(uint88(block.timestamp)), facetNames, facetArgs);
    }

    function deploy(bytes memory args, bytes11 salt, string[] memory facetNames, bytes[] memory facetArgs)
        internal
        returns (Deployment memory deployment)
    {
        address diamond = deployDiamond(salt, args);
        address[] memory newFacets = deployFacets(diamond, facetNames, facetArgs);
        deployment = Deployment({diamond: diamond, facets: newFacets});
        return deployment;
    }

    function buildDeploymentJson(address diamond, string[] memory facetNames, address[] memory newFacets)
        internal
        returns (string memory)
    {
        string memory rootKey = "root key";
        for (uint256 i = 0; i < facetNames.length; ++i) {
            vm.serializeAddress(rootKey, facetNames[i], newFacets[i]);
        }
        return vm.serializeAddress(rootKey, diamondName, diamond);
    }

    function saveDeployment(address diamond, string[] memory facetNames, address[] memory newFacets) internal {
        string memory json = buildDeploymentJson(diamond, facetNames, newFacets);
        vm.writeJson(json, getDeploymentPath());
    }

    function deployAndSave(bytes memory args) internal returns (Deployment memory deployment) {
        return deployAndSave(args, new string[](0), new bytes[](0));
    }

    function deployAndSave(bytes memory args, bytes11 salt) internal returns (Deployment memory deployment) {
        return deployAndSave(args, salt, new string[](0), new bytes[](0));
    }

    function deployAndSave(bytes memory args, string[] memory facetNames, bytes[] memory facetArgs)
        internal
        returns (Deployment memory deployment)
    {
        return deployAndSave(args, bytes11(uint88(block.timestamp)), facetNames, facetArgs);
    }

    function deployAndSave(bytes memory args, bytes11 salt, string[] memory facetNames, bytes[] memory facetArgs)
        internal
        returns (Deployment memory deployment)
    {
        deployment = deploy(args, salt, facetNames, facetArgs);
        saveDeployment(deployment.diamond, facetNames, deployment.facets);
        return deployment;
    }

    function toString(bytes4 selector) internal pure returns (string memory result) {
        result = vm.toString(selector);
        assembly {
            mstore(result, 10)
        }
    }
}
