// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library Ownership {
    // bytes32(uint256(keccak256('app.ownership.storage')) - 1)
    bytes32 internal constant POSITION = 0x370d237e9dffbc274f5df43cb66b66c353eec1c223d8506a9e5e5630243e7174;

    struct Storage {
        address owner;
        address pendingOwner;
    }

    function load() internal pure returns (Storage storage $) {
        assembly {
            $.slot := POSITION
        }
    }
}
