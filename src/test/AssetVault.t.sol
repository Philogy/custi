// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {BaseTest} from "../utils/BaseTest.sol";
import {AssetVault} from "../AssetVault.sol";

/// @author Philippe Dumonet
contract AssetVaultTest is BaseTest {
    AssetVault private vault;

    address private constant USER1 = address(1);
    address private constant USER2 = address(2);

    function setUp() public {
        vault = new AssetVault();
        vault.initialize(USER1, bytes32(0));
    }
}
