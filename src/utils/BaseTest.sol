// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {DSTest} from "ds-test/test.sol";
import {CheatCodes} from "./CheatCodes.sol";

/// @author Philippe Dumonet
contract BaseTest is DSTest {
    CheatCodes private hevm = CheatCodes(HEVM_ADDRESS);
}
