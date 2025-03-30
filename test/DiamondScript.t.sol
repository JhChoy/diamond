// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {CREATEX_ADDRESS, CREATEX_BYTECODE} from "../src/helpers/CreateX.sol";
import {DiamondScript} from "../src/helpers/DiamondScript.sol";
import {IDiamondApp} from "../src/interfaces/IDiamondApp.sol";
import {FacetToAdd} from "./mocks/FacetToAdd.sol";
import {FacetToReplace} from "./mocks/FacetToReplace.sol";
import {FacetToRemove} from "./mocks/FacetToRemove.sol";

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

        address diamond = deploy(abi.encode(msg.sender), facetNames, args).diamond;
        assertEq(IDiamondApp(diamond).owner(), msg.sender);
        vm.stopPrank();
    }

    function test_upgradeDiamond() public {
        vm.startPrank(msg.sender);

        string[] memory facetNames = new string[](2);
        facetNames[0] = "FacetToReplace";
        facetNames[1] = "FacetToRemove";
        bytes[] memory args = new bytes[](2);
        args[0] = abi.encode(100);
        args[1] = "";

        Deployment memory deployment = deploy(abi.encode(msg.sender), facetNames, args);

        assertEq(FacetToReplace(deployment.diamond).fooReplace(), 100);
        assertEq(FacetToReplace(deployment.diamond).barReplace(), 101);
        assertEq(FacetToRemove(deployment.diamond).fooRemove(), 51);
        assertEq(FacetToRemove(deployment.diamond).barRemove(), 52);

        string memory deploymentJson = buildDeploymentJson(deployment.diamond, facetNames, deployment.facets);

        facetNames = new string[](2);
        facetNames[0] = "FacetToReplace";
        facetNames[1] = "FacetToAdd";
        args = new bytes[](2);
        args[0] = abi.encode(200);
        args[1] = "";

        upgradeTo(deploymentJson, facetNames, args);

        assertEq(FacetToReplace(deployment.diamond).fooReplace(), 200);
        assertEq(FacetToReplace(deployment.diamond).barReplace(), 201);
        assertEq(FacetToAdd(deployment.diamond).fooAdd(), 42);
        assertEq(FacetToAdd(deployment.diamond).barAdd(), 43);
        vm.expectRevert("Diamond: Function does not exist");
        FacetToRemove(deployment.diamond).fooRemove();
        vm.expectRevert("Diamond: Function does not exist");
        FacetToRemove(deployment.diamond).barRemove();
    }
}
