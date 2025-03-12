// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownership} from "./storages/Ownership.sol";

abstract contract Ownable {
    error OwnableUnauthorizedAccount(address account);

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier onlyPendingOwner() {
        _checkPendingOwner();
        _;
    }

    function _checkOwner() private view {
        Ownership.Storage storage $ = Ownership.load();
        if ($.owner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function _checkPendingOwner() private view {
        Ownership.Storage storage $ = Ownership.load();
        if ($.pendingOwner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }
}
