// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {CREATEX_ADDRESS, CREATEX_BYTECODE} from "../src/helpers/CreateX.sol";
import {DiamondScript} from "../src/helpers/DiamondScript.sol";
import {IDiamondApp} from "../src/interfaces/IDiamondApp.sol";
import {FacetToAdd} from "./mocks/FacetToAdd.sol";

contract SetUpTest is Test, DiamondScript("DiamondApp") {
    string[] facetNames;
    bytes[] facetArgs;

    address app;

    function setUp() public {
        facetNames.push("FacetToAdd");
        facetArgs.push("");

        app = deploy(abi.encode(address(this)), bytes32(0), facetNames, facetArgs, address(0), "", false).diamond;

        assertEq(FacetToAdd(app).fooAdd(), 42);
    }

    function test_simple() public view {
        assertEq(FacetToAdd(app).barAdd(), 43);
    }
}
