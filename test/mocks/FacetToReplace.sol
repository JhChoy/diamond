// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract FacetToReplace {
    uint256 internal immutable base;

    constructor(uint256 base_) {
        base = base_;
    }

    function fooReplace() external view returns (uint256) {
        return base;
    }

    function barReplace() external view returns (uint256) {
        return base + 1;
    }
}
