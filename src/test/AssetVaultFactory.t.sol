// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {BaseTest} from "../utils/BaseTest.sol";
import {AssetVaultFactory} from "../AssetVaultFactory.sol";
import {IAssetVault} from "../IAssetVault.sol";

/// @author Philippe Dumonet
contract AssetVaultFactoryTest is BaseTest {
    uint256 private constant START_TIME = 1000;

    address private constant USER1 = address(1);
    address private constant USER2 = address(2);
    address private constant USER3 = address(3);

    AssetVaultFactory private factory;

    function setUp() public {
        cheats.label(USER1, "user 1");
        cheats.label(USER2, "user 2");
        cheats.label(USER3, "user 3");

        cheats.warp(START_TIME);

        factory = new AssetVaultFactory();
        cheats.label(address(factory), "factory");
    }

    function testFactoryImplementationIsVault() public {
        uint256 newTime = _advanceTime(3000 days);
        IAssetVault vaultImplementation = IAssetVault(factory.vaultImplementation());
        bytes32 placeholderRoot = keccak256("placeholder test root (1)");
        vaultImplementation.initialize(USER1, placeholderRoot);
        assertEq(vaultImplementation.owner(), USER1);
        assertEq(vaultImplementation.lastPing(), newTime);
        assertEq(vaultImplementation.guardiansMerkleRoot(), placeholderRoot);
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event GuardiansUpdate(bytes32 indexed newMerkleRoot);
    event Ping();

    event NewVaultCreated(
        address indexed newVault,
        address indexed _initialOwner,
        bytes32 indexed guardiansMerkleRoot
    );

    function testCanCreateForSender() public {
        uint256 newTime = _advanceTime(24 hours);
        bytes32 placeholderRoot = keccak256("placeholder test root (2)");

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.expectEmit(true, false, false, false);
        emit GuardiansUpdate(placeholderRoot);

        cheats.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), USER1);

        cheats.expectEmit(false, true, true, false);
        emit NewVaultCreated(address(0), USER1, placeholderRoot);

        cheats.prank(USER1);
        IAssetVault newVault = IAssetVault(factory.createNewVault(placeholderRoot));

        assertEq(newVault.owner(), USER1);
        assertEq(newVault.lastPing(), newTime);
        assertEq(newVault.guardiansMerkleRoot(), placeholderRoot);
    }

    function testCanCreateForOther() public {
        uint256 newTime = _advanceTime(31 days);
        bytes32 placeholderRoot = keccak256("placeholder test root (3)");

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.expectEmit(true, false, false, false);
        emit GuardiansUpdate(placeholderRoot);

        cheats.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), USER3);

        cheats.expectEmit(false, true, true, false);
        emit NewVaultCreated(address(0), USER3, placeholderRoot);

        cheats.prank(USER2);
        IAssetVault newVault = IAssetVault(factory.createNewVaultFor(USER3, placeholderRoot));

        assertEq(newVault.owner(), USER3);
        assertTrue(newVault.owner() != USER2);
        assertEq(newVault.lastPing(), newTime);
        assertEq(newVault.guardiansMerkleRoot(), placeholderRoot);
    }
}
