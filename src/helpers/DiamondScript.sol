// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IDiamond} from "../interfaces/IDiamond.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {ICreateX} from "../interfaces/ICreateX.sol";
import {CreateX} from "./CreateX.sol";

contract DiamondScript is Script {
    using stdJson for string;

    string internal root;
    string internal network;
    string internal deploymentsPath;
    string internal diamondName;
    string internal diamondJson;

    bytes4[] internal addSelectors;
    bytes4[] internal replaceSelectors;

    IDiamond.FacetCut[] internal cuts;
    bytes4[] internal removeSelectors;

    constructor(string memory diamondName_) {
        diamondName = diamondName_;
        diamondJson = vm.readFile(resolveCompiledOutputPath(diamondName_));
        root = vm.projectRoot();
        network = vm.toString(block.chainid);
        deploymentsPath = string.concat(root, "/deployments/", network, ".json");
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

    function deployDiamond(address owner) internal returns (address) {
        return deployDiamond(bytes11(uint88(block.timestamp)), owner);
    }

    function deployDiamond(bytes11 salt, address owner) internal returns (address) {
        address deployer = msg.sender;
        bytes32 encodedSalt = bytes32(abi.encodePacked(deployer, hex"00", salt));
        console.log("Deploying diamond...");
        address diamond = CreateX.create3(
            deployer, encodedSalt, abi.encodePacked(diamondJson.readBytes(".bytecode.object"), abi.encode(owner))
        );
        console.log(string.concat("  ", diamondName, ":"), diamond);
        vm.writeJson(vm.toString(diamond), deploymentsPath, string.concat(".", diamondName));
        return diamond;
    }

    function _deployNewFacet(string memory facetName, bytes memory args)
        private
        returns (address, bytes4[] memory, string[] memory)
    {
        string memory json = vm.readFile(resolveCompiledOutputPath(facetName));
        bytes memory initCode = abi.encodePacked(json.readBytes(".bytecode.object"), args);
        address facet = CreateX.computeCreate2Address(msg.sender, initCode);

        if (facet.codehash != bytes32(0)) {
            console.log("Facet already deployed:", facet);
        } else {
            address deployed = CreateX.create2(msg.sender, initCode);
            console.log(string.concat("Deployed ", facetName, ":"), deployed);
            require(facet == deployed, "Facet address does not match");
        }

        string[] memory selectorNames = vm.parseJsonKeys(json, ".methodIdentifiers");
        bytes4[] memory selectors = new bytes4[](selectorNames.length);
        console.log("Selectors:");
        for (uint256 i = 0; i < selectorNames.length; ++i) {
            bytes4 selector = bytes4(keccak256(bytes(selectorNames[i])));
            selectors[i] = selector;
            console.log(string.concat("  ", selectorNames[i], ": ", vm.toString(selector)));
        }
        return (facet, selectors, selectorNames);
    }

    function deployFacets(address diamond, string[] memory facetNames, bytes[] memory args) internal {
        IDiamond.FacetCut[] memory facetCuts = new IDiamond.FacetCut[](facetNames.length);
        if (facetNames.length != args.length) {
            revert("Facet names and args length mismatch");
        }
        for (uint256 i = 0; i < facetNames.length; ++i) {
            (address facet, bytes4[] memory selectors,) = _deployNewFacet(facetNames[i], args[i]);
            facetCuts[i] = IDiamond.FacetCut({
                facetAddress: facet,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            });
            vm.writeJson(vm.toString(facet), deploymentsPath, string.concat(".", facetNames[i]));
        }
        console.log("Cutting diamond...");
        IDiamondCut(diamond).diamondCut(facetCuts, address(0), "");
    }

    function _buildCut(
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
        removeSelectors = new bytes4[](0);

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
                console.log(string.concat("Removing selector ", vm.toString(oldSelectors[i])));
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

    function upgrade(address diamond, string[] memory facetNames, bytes[] memory args) internal {
        if (facetNames.length != args.length) {
            revert("Facet names and args length mismatch");
        }

        for (uint256 i = 0; i < facetNames.length; ++i) {
            console.log("Upgrading facet:", facetNames[i]);
            string memory deploymentsJson = vm.readFile(deploymentsPath);
            address oldFacet = deploymentsJson.readAddress(string.concat(".", facetNames[i]));

            (address newFacet, bytes4[] memory newSelectors, string[] memory newSelectorNames) =
                _deployNewFacet(facetNames[i], args[i]);

            if (oldFacet == newFacet) {
                console.log(string.concat("  ", facetNames[i], " is up to date"));
                continue;
            }

            _buildCut(diamond, oldFacet, newFacet, newSelectors, newSelectorNames);
        }

        if (removeSelectors.length > 0) {
            cuts.push(
                IDiamond.FacetCut({
                    facetAddress: address(0),
                    action: IDiamond.FacetCutAction.Remove,
                    functionSelectors: removeSelectors
                })
            );
        }

        if (cuts.length > 0) {
            console.log("Applying cuts...");
            IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        } else {
            console.log("No changes to apply");
        }
    }

    function deploy(address owner, string[] memory facetNames, bytes[] memory facetArgs) internal returns (address) {
        address diamond = deployDiamond(owner);
        deployFacets(diamond, facetNames, facetArgs);
        return diamond;
    }

    function deploy(address owner, bytes11 salt, string[] memory facetNames, bytes[] memory facetArgs)
        internal
        returns (address)
    {
        address diamond = deployDiamond(salt, owner);
        deployFacets(diamond, facetNames, facetArgs);
        return diamond;
    }
}
