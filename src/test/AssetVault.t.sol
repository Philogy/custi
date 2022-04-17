// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {BaseTest} from "../utils/BaseTest.sol";
import {AssetVault} from "../AssetVault.sol";
import {IAssetVault} from "../IAssetVault.sol";
import {MerkleProofBuilder} from "../utils/MerkleProofBuilder.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockERC721} from "../mock/MockERC721.sol";
import {MockERC1155} from "../mock/MockERC1155.sol";
import {MockContract} from "../mock/MockContract.sol";

/// @author Philippe Dumonet
contract AssetVaultTest is BaseTest {
    uint256 private constant START_TIME = 1000;

    address private constant USER1 = address(1);
    address private constant USER2 = address(2);
    address private constant USER3 = address(3);

    address private constant GUARDIAN1 = address(4);
    uint256 private delay1 = 3 days;
    bytes32 private node1;

    address private constant GUARDIAN2 = address(5);
    uint256 private delay2 = 30 days;
    bytes32 private node2;

    bytes32 private node12;

    address private constant GUARDIAN3 = address(6);
    uint256 private delay3 = 365 days;
    bytes32 private node3;

    bytes32 private root;

    address private constant ATTACKER1 = address(7);

    AssetVault private vault;

    function setUp() public {
        cheats.label(USER1, "user 1");
        cheats.label(USER2, "user 2");
        cheats.label(USER3, "user 3");
        cheats.label(GUARDIAN1, "user 1");
        cheats.label(GUARDIAN2, "user 2");
        cheats.label(GUARDIAN3, "user 3");
        cheats.label(ATTACKER1, "attacker");

        cheats.warp(START_TIME);

        vault = new AssetVault();
        cheats.label(address(vault), "vault");

        node1 = vault.guardianLeaf(GUARDIAN1, delay1);
        node2 = vault.guardianLeaf(GUARDIAN2, delay2);
        node3 = vault.guardianLeaf(GUARDIAN3, delay3);
        node12 = MerkleProofBuilder.hashTwoNodes(node1, node2);
        root = MerkleProofBuilder.hashTwoNodes(node12, node3);

        vault.initialize(USER1, root);
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event GuardiansUpdate(bytes32 indexed newMerkleRoot);
    event Ping();
    event GuardianRecovered(
        address indexed guardian,
        address indexed newOwner,
        uint256 delay,
        bytes32[] proof
    );

    // -- Test Initializer --

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

    // -- Test Base Methods And Initial State --

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
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[1] = node3;

        proof1[0] = node2;
        assertTrue(vault.isGuardian(GUARDIAN1, delay1, proof1));

        proof1[0] = node1;
        assertTrue(vault.isGuardian(GUARDIAN2, delay2, proof1));

        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = node12;
        assertTrue(vault.isGuardian(GUARDIAN3, delay3, proof2));
    }

    // -- Test General Admin Methods --
    function testOwnerMulticall() public {
        uint256 newTime = _advanceTime(365 days);

        MockERC20 token = new MockERC20();
        token.mint(address(vault), 1000 * 1e18);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(vault.transferToken, (token, USER1, 700 * 1e18));
        calls[1] = abi.encodeCall(vault.transferToken, (token, USER2, 200 * 1e18));
        calls[2] = abi.encodeCall(vault.transferToken, (token, USER3, 100 * 1e18));

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.prank(USER1);
        vault.multicall(calls);

        assertEq(token.balanceOf(USER1), 700 * 1e18);
        assertEq(token.balanceOf(USER2), 200 * 1e18);
        assertEq(token.balanceOf(USER3), 100 * 1e18);

        assertEq(vault.lastPing(), newTime);
    }

    // sanity check
    function testPreventCircumventOwnerMulticall() public {
        MockERC20 token = new MockERC20();
        token.mint(address(vault), 1000 * 1e18);

        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(vault.transferToken, (token, ATTACKER1, 1000 * 1e18));
        cheats.prank(ATTACKER1);
        vault.multicall(calls);
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

    function testOwnerCanTransferOwnership() public {
        uint256 newTime = _advanceTime(2 days);

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.expectEmit(true, true, false, false);
        emit OwnershipTransferred(USER1, USER2);

        cheats.prank(USER1);
        vault.transferOwnership(USER2);

        assertEq(vault.owner(), USER2);
        assertEq(vault.lastPing(), newTime);
    }

    function testPreventNotOwnerTransferOwnership() public {
        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));
        cheats.prank(ATTACKER1);
        vault.transferOwnership(ATTACKER1);
    }

    // -- Test Asset Acceptance --

    function testAcceptsETH() public {
        uint256 newTime = _advanceTime(2 days);
        cheats.deal(USER2, 8 ether);
        cheats.prank(USER2);
        bool success = payable(address(vault)).send(8 ether);
        assertTrue(success);
        assertEq(address(vault).balance, 8 ether);
        // ensure that ping not triggered
        assertTrue(vault.lastPing() != newTime);
    }

    function testETHTransferFromOwnerTriggersPing() public {
        uint256 newTime = _advanceTime(10 days);
        cheats.deal(USER1, 4 ether);
        cheats.expectEmit(false, false, false, false);
        emit Ping();
        (bool success, ) = _transferNative(USER1, address(vault), 4 ether);
        assertTrue(success);
        assertEq(address(vault).balance, 4 ether);
        assertEq(vault.lastPing(), newTime);
    }

    function testAcceptsERC721() public {
        MockERC721 token = new MockERC721();
        token.mint(USER2, 1);

        cheats.prank(USER2);
        token.safeTransferFrom(USER2, address(vault), 1);

        assertEq(token.ownerOf(1), address(vault));
    }

    function testAcceptsERC1155() public {
        MockERC1155 token = new MockERC1155();
        token.mint(USER2, 1, 12);
        token.mint(USER2, 2, 8);

        cheats.startPrank(USER2);

        token.safeTransferFrom(USER2, address(vault), 1, 5, "");
        assertEq(token.balanceOf(address(vault), 1), 5);
        assertEq(token.balanceOf(address(vault), 2), 0);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 3;
        amounts[1] = 4;
        token.safeBatchTransferFrom(USER2, address(vault), ids, amounts, "");
        assertEq(token.balanceOf(address(vault), 1), 8);
        assertEq(token.balanceOf(address(vault), 2), 4);

        cheats.stopPrank();
    }

    // -- Test Asset Managing Methods --

    function testOwnerTransferETH() public {
        // pretest setup
        uint256 bal = 10 ether;
        cheats.deal(address(vault), bal);
        uint256 transfer = 3 ether;
        uint256 newTime = _advanceTime(3.5 days);

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.prank(USER1);
        vault.transferNative(payable(USER2), transfer);

        assertEq(vault.lastPing(), newTime);
        assertEq(USER2.balance, transfer);
        assertEq(address(vault).balance, bal - transfer);
    }

    function testPreventNotOwnerTransferETH() public {
        cheats.deal(address(vault), 10 ether);

        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));
        cheats.prank(ATTACKER1);
        vault.transferNative(payable(ATTACKER1), 1 wei);
    }

    function testOwnerTransferDirectERC20() public {
        uint256 newTime = _advanceTime(4 days);

        MockERC20 token = new MockERC20();

        token.mint(address(vault), 10 * 1e18);
        assertEq(token.balanceOf(address(vault)), 10 * 1e18);

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.prank(USER1);
        vault.transferToken(token, USER2, 3 * 1e18);

        assertEq(token.balanceOf(address(vault)), 7 * 1e18);
        assertEq(token.balanceOf(USER2), 3 * 1e18);

        assertEq(vault.lastPing(), newTime);
    }

    function testPreventNotOwnerTransferDirectERC20() public {
        MockERC20 token = new MockERC20();
        token.mint(address(vault), 10 * 1e18);

        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));

        cheats.prank(ATTACKER1);
        vault.transferToken(token, ATTACKER1, 10 * 1e18);
    }

    function testOwnerTransferFromERC20() public {
        uint256 newTime = _advanceTime(4 days);

        MockERC20 token = new MockERC20();

        token.mint(USER2, 10 * 1e18);
        cheats.prank(USER2);
        token.approve(address(vault), type(uint256).max);

        cheats.expectEmit(false, false, false, false);
        emit Ping();

        cheats.prank(USER1);
        vault.transferTokenFrom(token, USER2, USER3, 3 * 1e18);

        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(USER1), 0);
        assertEq(token.balanceOf(USER2), 7 * 1e18);
        assertEq(token.balanceOf(USER3), 3 * 1e18);

        assertEq(vault.lastPing(), newTime);
    }

    function testPreventNotOwnerTransferFromERC20() public {
        MockERC20 token = new MockERC20();

        token.mint(USER2, 10 * 1e18);
        cheats.prank(USER2);
        token.approve(address(vault), type(uint256).max);

        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));
        cheats.prank(ATTACKER1);
        vault.transferTokenFrom(token, USER2, ATTACKER1, 10 * 1e18);
    }

    // ping no longer tested beyond here as `onlyOwner` is always used and
    // implicitly tested via the `testPrevent<X>` tests

    function testOwnerTransferERC721() public {
        MockERC721 token = new MockERC721();
        token.mint(address(vault), 21);
        assertEq(token.ownerOf(21), address(vault));
        cheats.prank(USER1);
        vault.transferNFT(token, address(vault), USER2, 21);
        assertEq(token.ownerOf(21), USER2);
    }

    function testPreventNotOwnerTransferERC721() public {
        MockERC721 token = new MockERC721();
        token.mint(address(vault), 21);

        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));
        cheats.prank(ATTACKER1);
        vault.transferNFT(token, address(vault), ATTACKER1, 21);
    }

    function testOwnerTransferERC1155() public {
        MockERC1155 token = new MockERC1155();
        token.mint(address(vault), 420, 69);
        assertEq(token.balanceOf(address(vault), 420), 69);
        cheats.prank(USER1);
        vault.transferCollectible(token, address(vault), USER2, 420, 21);
        assertEq(token.balanceOf(address(vault), 420), 69 - 21);
        assertEq(token.balanceOf(USER2, 420), 21);
    }

    function testPreventNotOwnerTransferERC1155() public {
        MockERC1155 token = new MockERC1155();
        token.mint(address(vault), 420, 69);

        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));
        cheats.prank(ATTACKER1);
        vault.transferCollectible(token, address(vault), ATTACKER1, 420, 69);
    }

    // -- Test Custom Calls --

    function testPreventNotOwnerCustomCall() public {
        MockContract c = new MockContract();

        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.NotOwner.selector));
        cheats.prank(ATTACKER1);
        vault.doCustomCall(address(c), 0, abi.encodeCall(c.setValue, 1 ether), true);
    }

    function testOwnerCustomCall() public {
        MockContract c = new MockContract();
        cheats.label(address(c), "mock contract");
        cheats.deal(address(vault), 10 ether);
        assertEq(c.value(), 0);
        assertEq(c.lastSender(), address(0));

        // basic call
        uint256 value = 1 ether;
        cheats.prank(USER1);
        (bool success, bytes memory returndata) = vault.doCustomCall(
            address(c),
            0,
            abi.encodeCall(c.setValue, value),
            true
        );
        assertTrue(success);
        assertEq(keccak256(returndata), keccak256(""));
        assertEq(address(vault).balance, 10 ether);
        assertEq(address(c).balance, 0);
        assertEq(c.value(), value);
        assertEq(c.lastSender(), address(vault));

        c.reset();

        // call with ETH / EVM native coin
        cheats.prank(USER1);
        (success, returndata) = vault.doCustomCall(
            address(c),
            value,
            abi.encodeCall(c.payIn, ()),
            true
        );
        assertTrue(success);
        assertEq(keccak256(returndata), keccak256(abi.encode(keccak256(abi.encode(address(c))))));
        assertEq(address(vault).balance, 10 ether - value);
        assertEq(address(c).balance, value);
        assertEq(c.lastSender(), address(vault));

        // call bubbles revert
        cheats.expectRevert("MockContract: Incorrect Value");
        cheats.prank(USER1);
        (success, returndata) = vault.doCustomCall(
            address(c),
            value - 1,
            abi.encodeCall(c.payIn, ()),
            true
        );

        // call does not bubble revert if success not required
        cheats.prank(USER1);
        (success, returndata) = vault.doCustomCall(
            address(c),
            value - 1,
            abi.encodeCall(c.payIn, ()),
            false
        );
        assertTrue(!success);
        assertEq(
            keccak256(returndata),
            keccak256(abi.encodeWithSignature("Error(string)", "MockContract: Incorrect Value"))
        );
    }

    // -- Test Recovery --

    function testGuardianCannotRecoverBeforeDelay() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = node1;
        proof[1] = node3;
        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.DelayNotPassed.selector));
        cheats.prank(GUARDIAN2);
        vault.recoverAsGuardianTo(USER2, delay2, proof);
        assertTrue(vault.isGuardian(GUARDIAN2, delay2, proof));
    }

    function testPreventRecoverWithInvalidProof() public {
        uint256 delay = 30 days;
        _advanceTime(30 days);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256("placeholder proof part 1");
        proof[1] = keccak256("placeholder proof part 2");
        cheats.expectRevert(abi.encodeWithSelector(IAssetVault.InvalidMerkleProof.selector));
        cheats.prank(ATTACKER1);
        vault.recoverAsGuardianTo(ATTACKER1, delay, proof);
    }

    function testValidGuardianCanRecover() public {
        uint256 newTime = _advanceTime(delay2 + 3 days);

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = node1;
        proof[1] = node3;

        cheats.expectEmit(false, false, false, false);
        emit Ping();
        cheats.expectEmit(true, true, false, false);
        emit OwnershipTransferred(USER1, USER2);
        cheats.expectEmit(true, true, false, true);
        emit GuardianRecovered(GUARDIAN2, USER2, delay2, proof);

        cheats.prank(GUARDIAN2);
        vault.recoverAsGuardianTo(USER2, delay2, proof);

        assertEq(vault.owner(), USER2);
        assertEq(vault.lastPing(), newTime);
    }
}
