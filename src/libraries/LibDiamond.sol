// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IDiamond} from "../interfaces/IDiamond.sol";
import {Diamond} from "../storages/Diamond.sol";

/// @title LibDiamond
/// @author Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/// @author Modified by: JChoy
/// @notice EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
library LibDiamond {
    using LibDiamond for Diamond.Storage;

    error IncorrectFacetCutAction();
    error NoSelectorsInFacet();
    error FunctionAlreadyExists();
    error FacetAddressIsZero();
    error FacetAddressIsNotZero();
    error FacetContainsNoCode();
    error FunctionDoesNotExist();
    error FunctionIsImmutable();
    error InitZeroButCalldataNotEmpty();
    error CalldataEmptyButInitNotZero();
    error InitReverted();

    // Internal function version of diamondCut
    function diamondCut(
        Diamond.Storage storage $,
        IDiamond.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; ++facetIndex) {
            IDiamond.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamond.FacetCutAction.Add) {
                $.addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamond.FacetCutAction.Replace) {
                $.replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamond.FacetCutAction.Remove) {
                $.removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert IncorrectFacetCutAction();
            }
        }
        emit IDiamond.DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(Diamond.Storage storage $, address _facetAddress, bytes4[] memory _functionSelectors)
        internal
    {
        if (_functionSelectors.length == 0) {
            revert NoSelectorsInFacet();
        }
        if (_facetAddress == address(0)) {
            revert FacetAddressIsZero();
        }
        uint96 selectorPosition = uint96($.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            $.addFacet(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = $.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert FunctionAlreadyExists();
            }
            $.addFunction(selector, selectorPosition, _facetAddress);
            unchecked {
                ++selectorPosition;
            }
        }
    }

    function replaceFunctions(Diamond.Storage storage $, address _facetAddress, bytes4[] memory _functionSelectors)
        internal
    {
        if (_functionSelectors.length == 0) {
            revert NoSelectorsInFacet();
        }
        if (_facetAddress == address(0)) {
            revert FacetAddressIsZero();
        }
        uint96 selectorPosition = uint96($.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            $.addFacet(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = $.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == _facetAddress) {
                revert FunctionAlreadyExists();
            }
            $.removeFunction(oldFacetAddress, selector);
            $.addFunction(selector, selectorPosition, _facetAddress);
            unchecked {
                ++selectorPosition;
            }
        }
    }

    function removeFunctions(Diamond.Storage storage $, address _facetAddress, bytes4[] memory _functionSelectors)
        internal
    {
        if (_functionSelectors.length == 0) {
            revert NoSelectorsInFacet();
        }
        // if function does not exist then do nothing and return
        if (_facetAddress != address(0)) {
            revert FacetAddressIsNotZero();
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = $.selectorToFacetAndPosition[selector].facetAddress;
            $.removeFunction(oldFacetAddress, selector);
        }
    }

    function addFacet(Diamond.Storage storage $, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress);
        $.facetFunctionSelectors[_facetAddress].facetAddressPosition = $.facetAddresses.length;
        $.facetAddresses.push(_facetAddress);
    }

    function addFunction(Diamond.Storage storage $, bytes4 _selector, uint96 _selectorPosition, address _facetAddress)
        internal
    {
        $.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        $.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        $.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(Diamond.Storage storage $, address _facetAddress, bytes4 _selector) internal {
        if (_facetAddress == address(0)) {
            revert FunctionDoesNotExist();
        }
        // an immutable function is a function defined directly in a diamond
        if (_facetAddress == address(this)) {
            revert FunctionIsImmutable();
        }
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = $.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = $.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = $.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            $.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            $.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        $.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete $.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = $.facetAddresses.length - 1;
            uint256 facetAddressPosition = $.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = $.facetAddresses[lastFacetAddressPosition];
                $.facetAddresses[facetAddressPosition] = lastFacetAddress;
                $.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            $.facetAddresses.pop();
            delete $.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            if (_calldata.length != 0) {
                revert InitZeroButCalldataNotEmpty();
            }
            return;
        } else {
            if (_calldata.length == 0) {
                revert CalldataEmptyButInitNotZero();
            }
            if (_init != address(this)) {
                enforceHasContractCode(_init);
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    // bubble up error
                    /// @solidity memory-safe-assembly
                    assembly {
                        let returndata_size := mload(error)
                        revert(add(32, error), returndata_size)
                    }
                } else {
                    revert InitReverted();
                }
            }
        }
    }

    function enforceHasContractCode(address _contract) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if (contractSize == 0) {
            revert FacetContainsNoCode();
        }
    }
}
