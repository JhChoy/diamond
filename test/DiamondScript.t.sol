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

        assertEq(deployment.diamond, address(0x49404D9D86D42022eD12dbFeE58C182f9D203444));
        assertEq(deployment.facets.length, 2);
        assertEq(deployment.facets[0], address(0x14Ce377027337A1A61dE65f1F033D28776284BA4));
        assertEq(deployment.facets[1], address(0x0A47b3207fD3E64d706133D890b880C57403b0Df));

        string memory deploymentJson = buildDeploymentJson(deployment.diamond, facetNames, deployment.facets);
        console.log("deploymentJson: %s", deploymentJson);

        facetNames = new string[](2);
        facetNames[0] = "FacetToReplace";
        facetNames[1] = "FacetToAdd";
        args = new bytes[](2);
        args[0] = abi.encode(200);
        args[1] = "";

        Deployment memory newDeployment = upgradeTo(deploymentJson, facetNames, args);
        string memory newDeploymentJson = buildDeploymentJson(newDeployment.diamond, facetNames, newDeployment.facets);
        console.log("newDeployment: %s", newDeploymentJson);

        assertEq(FacetToReplace(deployment.diamond).fooReplace(), 200);
        assertEq(FacetToReplace(deployment.diamond).barReplace(), 201);
        assertEq(FacetToAdd(deployment.diamond).fooAdd(), 42);
        assertEq(FacetToAdd(deployment.diamond).barAdd(), 43);
        vm.expectRevert("Diamond: Function does not exist");
        FacetToRemove(deployment.diamond).fooRemove();
        vm.expectRevert("Diamond: Function does not exist");
        FacetToRemove(deployment.diamond).barRemove();

        assertEq(newDeployment.diamond, address(0x49404D9D86D42022eD12dbFeE58C182f9D203444));
        assertEq(newDeployment.facets.length, 2);
        assertEq(newDeployment.facets[0], address(0xbFB6c7993394f9D35CdcC112Dd41533cf79d3c52));
        assertEq(newDeployment.facets[1], address(0x11aa9484d521FE90523D223dcD99521198E81dE4));
    }
}
