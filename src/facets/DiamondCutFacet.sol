// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {Ownable} from "../Ownable.sol";
import {Diamond} from "../storages/Diamond.sol";

contract DiamondCutFacet is IDiamondCut, Ownable {
    using LibDiamond for Diamond.Storage;

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external onlyOwner {
        Diamond.Storage storage $ = Diamond.load();
        $.diamondCut(_diamondCut, _init, _calldata);
    }
}
