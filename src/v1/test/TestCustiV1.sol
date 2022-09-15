// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";

/// @author Philippe Dumonet <philippe@dumo.net>
contract TestCustiV1 is Test {
    function test1Eq1() external {
        assertEq(uint256(1), uint256(1));
    }
}
