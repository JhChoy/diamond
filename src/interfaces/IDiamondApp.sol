// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IDiamondCut} from "./IDiamondCut.sol";
import {IDiamondLoupe} from "./IDiamondLoupe.sol";
import {IERC165} from "./IERC165.sol";
import {IOwnership} from "./IOwnership.sol";

interface IDiamondApp is IDiamondCut, IDiamondLoupe, IERC165, IOwnership {}
