// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title Ownership Interface for Access Control
/// @notice Interface for managing ownership of contracts with a two-step ownership transfer pattern
/// @dev Handles ownership management including transfers, renouncement and pending owner acceptance
interface IOwnership {
    /// @notice Emitted when ownership is transferred from one address to another
    /// @param previousOwner Address of the previous owner
    /// @param newOwner Address of the new owner
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when ownership transfer is initiated
    /// @param previousOwner Address of the previous owner
    /// @param newOwner Address of the new owner
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /// @notice Returns the address of the current owner
    /// @return owner_ Address of the current owner
    function owner() external view returns (address owner_);

    /// @notice Returns the address of the pending owner
    /// @return pendingOwner_ Address of the pending owner that can accept ownership
    function pendingOwner() external view returns (address pendingOwner_);

    /// @notice Allows the current owner to relinquish ownership of the contract
    /// @dev Leaves the contract without an owner. Only callable by current owner
    function renounceOwnership() external;

    /// @notice Initiates transfer of ownership to a new address
    /// @dev Only callable by current owner. Sets the pending owner
    /// @param newOwner Address that will become the pending owner
    function transferOwnership(address newOwner) external;

    /// @notice Allows pending owner to accept ownership of the contract
    /// @dev Completes the ownership transfer process. Only callable by pending owner
    function acceptOwnership() external;
}
