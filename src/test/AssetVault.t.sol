// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {BaseTest} from "../utils/BaseTest.sol";
import {AssetVault} from "../AssetVault.sol";
import {IAssetVault} from "../IAssetVault.sol";
import {MerkleProofBuilder} from "../utils/MerkleProofBuilder.sol";

/// @author Philippe Dumonet
contract AssetVaultTest is BaseTest {
    uint256 private constant START_TIME = 1000;

    address private constant USER1 = address(1);
    address private constant USER2 = address(2);

    address private constant GUARDIAN1 = address(3);
    uint256 private delay1 = 3 days;
    bytes32 private node1;

    address private constant GUARDIAN2 = address(4);
    uint256 private delay2 = 30 days;
    bytes32 private node2;

    bytes32 private root;

    address private constant ATTACKER1 = address(5);

    AssetVault private vault;

    function setUp() public {
        cheats.warp(START_TIME);

        vault = new AssetVault();

        node1 = vault.guardianLeaf(GUARDIAN1, delay1);
        node2 = vault.guardianLeaf(GUARDIAN2, delay2);
        root = MerkleProofBuilder.hashTwoNodes(node1, node2);

        vault.initialize(USER1, root);
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event GuardiansUpdate(bytes32 indexed newMerkleRoot);
    event Ping();
    event GuardianRecovered(address indexed guardian, address indexed newOwner, uint256 delay);

    function testInitializationEvents() public {
        AssetVault testVault = new AssetVault();
        bytes32 placeholderMerkleRoot = keccak256("Some random data");

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.expectEmit(true, false, false, false);
        emit GuardiansUpdate(placeholderMerkleRoot);

        cheats.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), USER2);

        testVault.initialize(USER2, placeholderMerkleRoot);
    }

    function testFailReinitialize() public {
        cheats.prank(USER1);
        vault.initialize(ATTACKER1, bytes32(uint256(1)));
    }

    function testCorrectInitialState() public {
        assertEq(vault.owner(), USER1, "Unexpected owner");
        assertEq(vault.lastPing(), START_TIME, "Unexpected last ping");
        assertEq(vault.guardiansMerkleRoot(), root, "Unexpected guardians merkle root");
    }

    function testGuardianLeaf() public {
        assertEq(
            vault.guardianLeaf(USER1, 31 days + 34 minutes),
            keccak256(abi.encode(USER1, 31 days + 34 minutes))
        );

        assertEq(
            vault.guardianLeaf(0x43357700930Dd1cdE05ff0E412059bc54CEFc0CE, 61 weeks),
            0xeebca5918a7d88835b821dbf207d64bae498d97c445f02407725393a289afe89
        );
    }

    function testGuardiansInMerkleTree() public {
        bytes32[] memory proof = new bytes32[](1);

        proof[0] = node2;
        assertTrue(vault.isGuardian(GUARDIAN1, delay1, proof));

        proof[0] = node1;
        assertTrue(vault.isGuardian(GUARDIAN2, delay2, proof));
    }

    function testOwnerPing() public {
        uint256 newTime = _advanceTime(2 days);

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.prank(USER1);
        vault.ping();

        assertEq(vault.lastPing(), newTime);
    }

    function testPreventNotOwnerPing() public {
        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));

        cheats.prank(ATTACKER1);
        vault.ping();
    }

    function testOwnerUpdateMerkle() public {
        uint256 newTime = _advanceTime(2 days);

        bytes32 newRoot = keccak256("some placeholder content testOwnerUpdateMerkle");

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.expectEmit(true, false, false, false);
        emit GuardiansUpdate(newRoot);

        cheats.prank(USER1);
        vault.updateGuardianMerkle(newRoot);

        assertEq(vault.lastPing(), newTime);
    }

    function testPreventNotOwnerUpdateMerkle() public {
        bytes32 attackLeaf = vault.guardianLeaf(ATTACKER1, 0);

        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));
        cheats.prank(ATTACKER1);
        vault.updateGuardianMerkle(attackLeaf);
    }
}
