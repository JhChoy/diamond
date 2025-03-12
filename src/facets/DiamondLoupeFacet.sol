// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {Diamond} from "../storages/Diamond.sol";

contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
    function facets() external view returns (Facet[] memory facets_) {
        Diamond.Storage storage $ = Diamond.load();
        uint256 numFacets = $.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i = 0; i < numFacets; ++i) {
            address facetAddress_ = $.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = $.facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_) {
        Diamond.Storage storage $ = Diamond.load();
        facetFunctionSelectors_ = $.facetFunctionSelectors[_facet].functionSelectors;
    }

    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        Diamond.Storage storage $ = Diamond.load();
        facetAddresses_ = $.facetAddresses;
    }

    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {
        Diamond.Storage storage $ = Diamond.load();
        facetAddress_ = $.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        Diamond.Storage storage $ = Diamond.load();
        return $.supportedInterfaces[_interfaceId];
    }
}
