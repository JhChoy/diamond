// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract FacetToAdd {
    function fooAdd() external pure returns (uint256) {
        return 42;
    }

    function barAdd() external pure returns (uint256) {
        return 43;
    }
}
