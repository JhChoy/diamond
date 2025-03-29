// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {CREATEX_ADDRESS, CREATEX_BYTECODE} from "../src/helpers/CreateX.sol";
import {DiamondScript} from "../src/helpers/DiamondScript.sol";
import {IDiamondApp} from "../src/interfaces/IDiamondApp.sol";
import {FacetToAdd} from "./mocks/FacetToAdd.sol";

contract DiamondScriptTest is Test, DiamondScript("DiamondApp") {
    function setUp() public {}

    function test_resolveCompiledOutputPath() public view {
        string memory path = resolveCompiledOutputPath("DiamondApp");
        assertEq(path, string.concat(vm.projectRoot(), "/out/DiamondApp.sol/DiamondApp.json"));
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

    // TODO: Enhance the tests
    function test_deploy() public {
        vm.startPrank(msg.sender);
        string[] memory facetNames = new string[](1);
        facetNames[0] = "FacetToAdd";
        bytes[] memory args = new bytes[](1);
        args[0] = "";

        (address diamond,) = deploy(abi.encode(msg.sender), facetNames, args);
        assertEq(IDiamondApp(diamond).owner(), msg.sender);
        vm.stopPrank();
    }

    function test_upgradeDiamond() public {
        vm.startPrank(msg.sender);

        (address diamond,) = deploy(abi.encode(msg.sender));
        string memory deploymentJson = buildDeploymentJson(diamond, new string[](0), new address[](0));
        string[] memory facetNames = new string[](1);
        facetNames[0] = "FacetToAdd";
        bytes[] memory args = new bytes[](1);
        args[0] = "";

        upgradeTo(deploymentJson, facetNames, args);
        assertEq(FacetToAdd(diamond).foo(), 42);
        assertEq(FacetToAdd(diamond).bar(), 43);
    }
}
