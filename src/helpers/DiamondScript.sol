// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IDiamond} from "../interfaces/IDiamond.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {ICreateX} from "../interfaces/ICreateX.sol";
import {CreateX} from "./CreateX.sol";

contract DiamondScript is Script {
    using stdJson for string;

    string internal diamondName;
    string internal diamondJson;

    constructor(string memory diamondName_) {
        diamondName = diamondName_;
        diamondJson = vm.readFile(resolveCompiledOutputPath(diamondName_));
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

    function deployDiamond(bytes memory args) internal returns (address) {
        return deployDiamond(bytes11(uint88(block.timestamp)), args);
    }

    function deployDiamond(bytes11 salt, bytes memory args) internal returns (address) {
        address deployer = msg.sender;
        bytes32 encodedSalt = bytes32(abi.encodePacked(deployer, hex"00", salt));
        address diamond =
            CreateX.create3(deployer, encodedSalt, abi.encodePacked(diamondJson.readBytes(".bytecode.object"), args));
        console.log(string.concat(diamondName, ":"), diamond);
        return diamond;
    }

    function _deployNewFacet(string memory facetName, bytes memory args) private returns (IDiamond.FacetCut memory) {
        string memory json = vm.readFile(resolveCompiledOutputPath(facetName));
        address facet = CreateX.create2(msg.sender, abi.encodePacked(json.readBytes(".bytecode.object"), args));
        console.log(string.concat(facetName, ":"), facet);

        string[] memory selectorNames = vm.parseJsonKeys(json, ".methodIdentifiers");
        bytes4[] memory selectors = new bytes4[](selectorNames.length);
        console.log("Selectors:");
        for (uint256 i = 0; i < selectorNames.length; ++i) {
            bytes4 selector = bytes4(keccak256(bytes(selectorNames[i])));
            selectors[i] = selector;
            console.logBytes4(selector);
        }

        return
            IDiamond.FacetCut({facetAddress: facet, action: IDiamond.FacetCutAction.Add, functionSelectors: selectors});
    }

    function deployFacets(address diamond, string[] memory facetNames, bytes[] memory args) internal {
        IDiamond.FacetCut[] memory facetCuts = new IDiamond.FacetCut[](facetNames.length);
        if (facetNames.length != args.length) {
            revert("Facet names and args length mismatch");
        }
        for (uint256 i = 0; i < facetNames.length; ++i) {
            facetCuts[i] = _deployNewFacet(facetNames[i], args[i]);
        }
        IDiamondCut(diamond).diamondCut(facetCuts, address(0), "");
    }

    function deploy(bytes memory diamondArgs, string[] memory facetNames, bytes[] memory facetArgs)
        internal
        returns (address)
    {
        address diamond = deployDiamond(diamondArgs);
        deployFacets(diamond, facetNames, facetArgs);
        return diamond;
    }

    function deploy(bytes memory diamondArgs, bytes11 salt, string[] memory facetNames, bytes[] memory facetArgs)
        internal
        returns (address)
    {
        address diamond = deployDiamond(salt, diamondArgs);
        deployFacets(diamond, facetNames, facetArgs);
        // todo: store as files?
        return diamond;
    }
}
