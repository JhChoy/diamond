// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IDiamond} from "./interfaces/IDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "./interfaces/IDiamondLoupe.sol";
import {IERC165} from "./interfaces/IERC165.sol";
import {IOwnership} from "./interfaces/IOwnership.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";
import {Diamond} from "./storages/Diamond.sol";
import {DiamondCutFacet} from "./facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "./facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "./facets/OwnershipFacet.sol";
import {Ownership} from "./storages/Ownership.sol";

contract DiamondApp {
    using LibDiamond for Diamond.Storage;

    constructor(address _owner) payable {
        Ownership.load().owner = _owner;
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();

        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](3);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        functionSelectors = new bytes4[](5);
        functionSelectors[0] = IDiamondLoupe.facets.selector;
        functionSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        functionSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        functionSelectors[3] = IDiamondLoupe.facetAddress.selector;
        functionSelectors[4] = IERC165.supportsInterface.selector;
        cut[1] = IDiamond.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        functionSelectors = new bytes4[](5);
        functionSelectors[0] = IOwnership.owner.selector;
        functionSelectors[1] = IOwnership.pendingOwner.selector;
        functionSelectors[2] = IOwnership.renounceOwnership.selector;
        functionSelectors[3] = IOwnership.transferOwnership.selector;
        functionSelectors[4] = IOwnership.acceptOwnership.selector;
        cut[2] = IDiamond.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        Diamond.Storage storage $ = Diamond.load();
        $.diamondCut(cut, address(0), "");
        $.supportedInterfaces[type(IERC165).interfaceId] = true;
        $.supportedInterfaces[type(IDiamond).interfaceId] = true;
        $.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        $.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        $.supportedInterfaces[type(IOwnership).interfaceId] = true;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        // get diamond storage
        Diamond.Storage storage $ = Diamond.load();
        // get facet from function selector
        address facet = $.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
