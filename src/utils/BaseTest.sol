// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {DSTest} from "ds-test/test.sol";
import {CheatCodes} from "./CheatCodes.sol";

/// @author Philippe Dumonet
contract BaseTest is DSTest {
    CheatCodes internal cheats = CheatCodes(HEVM_ADDRESS);

    function _advanceTime(uint256 _increase) internal returns (uint256 newTime) {
        newTime = block.timestamp + _increase;
        cheats.warp(newTime);
    }
}
