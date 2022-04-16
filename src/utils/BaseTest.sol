// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {DSTest} from "ds-test/test.sol";
import {CheatCodes} from "./CheatCodes.sol";

/// @author Philippe Dumonet
contract BaseTest is DSTest {
    CheatCodes internal cheats = CheatCodes(HEVM_ADDRESS);

    function _advanceTime(uint256 _increase) internal returns (uint256 newTime) {
        // solhint-disable-next-line not-rely-on-time
        newTime = block.timestamp + _increase;
        cheats.warp(newTime);
    }

    function _transferNative(
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (bool success, bytes memory returndata) {
        cheats.prank(_from);
        // solhint-disable-next-line avoid-low-level-calls
        (success, returndata) = _to.call{value: _amount}("");
    }
}
