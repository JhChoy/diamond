// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {DiamondScript} from "../src/helpers/DiamondScript.sol";

contract DiamondScriptTest is Test, DiamondScript("ExampleDiamond") {
    function setUp() public {}

    function test_resolveCompiledOutputPath() public view {
        string memory path = resolveCompiledOutputPath("ExampleDiamond");
        assertEq(path, string.concat(vm.projectRoot(), "/out/ExampleDiamond.sol/ExampleDiamond.json"));
        path = resolveCompiledOutputPath("FileName.sol:ContractName");
        assertEq(path, string.concat(vm.projectRoot(), "/out/FileName.sol/ContractName.json"));

        path = resolveCompiledOutputPath("LongContractName___________________");
        assertEq(
            path,
            string.concat(
                vm.projectRoot(),
                "/out/LongContractName___________________.sol/LongContractName___________________.json"
            )
        );
        path = resolveCompiledOutputPath("LongFileName___________________.sol:LongContractName___________________");
        assertEq(
            path,
            string.concat(
                vm.projectRoot(), "/out/LongFileName___________________.sol/LongContractName___________________.json"
            )
        );
    }
}
