// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract FacetToRemove {
    function fooRemove() external pure returns (uint256) {
        return 51;
    }

    function barRemove() external pure returns (uint256) {
        return 52;
    }
}
