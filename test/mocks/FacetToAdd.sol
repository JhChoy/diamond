// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract FacetToAdd {
    function foo() external pure returns (uint256) {
        return 42;
    }

    function bar() external pure returns (uint256) {
        return 43;
    }
}
