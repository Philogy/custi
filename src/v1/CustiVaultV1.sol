// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";
import {ICustiVaultV1} from "./ICustiVaultV1.sol";
import {AssetAcceptor} from "./utils/AssetAcceptor.sol";

/// @author Philippe Dumonet <philippe@dumo.net>
contract CustiVaultV1 is ICustiVaultV1, AssetAcceptor {
    using SafeTransferLib for address;

    // [  0..159] owner
    // [160..207] lastPing
    // [208..255] lockedTill
    uint256 internal slot0;
    uint256 internal constant PING_OFFSET = 160;
    uint256 internal constant LOCKED_TILL_OFFSET = 208;
    uint256 internal constant OWNER_MASK = uint256(type(uint160).max);
    uint256 internal constant OWNER_PING_MASK = uint256(type(uint208).max);
    uint256 internal constant NOT_PING_MASK = ~(uint256(type(uint48).max) << 160);

    bytes32 public guardiansTreeRoot;

    modifier onlyOwner() {
        uint256 slot0_ = slot0;
        _checkOwner(slot0);
        _checkLock(slot0);
        emit Ping();
        // solhint-disable-next-line not-rely-on-time
        slot0 = (slot0_ & NOT_PING_MASK) | (block.timestamp << PING_OFFSET);
        _;
    }

    function initialize(address _owner, bytes32 _guardiansTreeRoot) external {
        if (slot0 != 0) revert Initialized();
        _transferOwnership(0, _owner);
        _setGuardiansTreeRoot(_guardiansTreeRoot);
    }

    // solhint-disable-next-line no-empty-blocks
    function ping() external payable onlyOwner {}

    function lockTill(uint256 _timestamp) external {
        _lockTill(_timestamp);
    }

    function lockFor(uint256 _lockDuration) external {
        // solhint-disable-next-line not-rely-on-time
        _lockTill(block.timestamp + _lockDuration);
    }

    function transferOwnership(address _newOwner) external {
        if (_newOwner == address(0)) revert NewOwnerZeroAddress();
        uint256 slot0_ = slot0;
        _checkOwner(slot0_);
        _checkLock(slot0_);
        _transferOwnership(slot0_, _newOwner);
    }

    function setGuardiansTreeRoot(bytes32 _guardiansTreeRoot) external onlyOwner {
        _setGuardiansTreeRoot(_guardiansTreeRoot);
    }

    function buildGuardianLeaf(address _guardian, uint256 _delay)
        public
        pure
        returns (bytes32 guardianLeaf)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(0x00, _guardian)
            mstore(0x20, _delay)
            guardianLeaf := keccak256(0x00, 0x40)
        }
    }

    function isGuardian(
        bytes32[] calldata _proof,
        address _guardian,
        uint256 _delay
    ) public view returns (bool) {
        bytes32 guardianLeaf = buildGuardianLeaf(_guardian, _delay);
        return MerkleProofLib.verify(_proof, guardiansTreeRoot, guardianLeaf);
    }

    function recoverAsGuardianTo(
        address _newOwner,
        uint256 _delay,
        bytes32[] calldata _proof
    ) external {
        if (!isGuardian(_proof, msg.sender, _delay)) revert InvalidMerkleProof();
        uint256 slot0_ = slot0;
        uint256 lastPing_ = uint48(slot0_ >> PING_OFFSET);
        // solhint-disable-next-line not-rely-on-time
        if (lastPing_ + _delay > block.timestamp) revert DelayNotPassed();
        _transferOwnership(slot0_, _newOwner);
    }

    function doCustomCall(
        address _target,
        uint256 _value,
        bytes calldata _calldata,
        bool _requireSuccess
    ) external onlyOwner returns (bool success, bytes memory returndata) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, returndata) = _target.call{value: _value}(_calldata);
        if (_requireSuccess && !success) revert CustomCallFailed(returndata);
    }

    function transferNative(address _recipient, uint256 _value) external onlyOwner {
        if (_value == 0) {
            _value = address(this).balance;
            if (_value == 0) return;
        }
        _recipient.safeTransferETH(_value);
    }

    function transferToken(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        if (_amount == 0) {
            _amount = IERC20(_token).balanceOf(address(this));
            if (_amount == 0) return;
        }
        _token.safeTransfer(_to, _amount);
    }

    function transferTokenFrom(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        if (_amount == 0) {
            uint256 allowance = IERC20(_token).allowance(_from, address(this));
            uint256 bal = IERC20(_token).balanceOf(_from);
            _amount = bal < allowance ? bal : allowance;
            if (_amount == 0) return;
        }
        _token.safeTransferFrom(_from, _to, _amount);
    }

    function transferNFT(
        address _token,
        address _from,
        address _to,
        uint256 _tokenId
    ) external onlyOwner {
        IERC721(_token).safeTransferFrom(_from, _to, _tokenId);
    }

    function transferCollectible(
        address _collectible,
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount
    ) external onlyOwner {
        IERC1155(_collectible).safeTransferFrom(_from, _to, _tokenId, _amount, "");
    }

    function ownerPingLockedTill()
        public
        view
        returns (
            address owner_,
            uint256 lastPing_,
            uint256 lockedTill_
        )
    {
        uint256 slot0_ = slot0;
        owner_ = address(uint160(slot0_));
        lastPing_ = uint48(slot0_ >> PING_OFFSET);
        lockedTill_ = slot0_ >> LOCKED_TILL_OFFSET;
    }

    function owner() public view returns (address) {
        return address(uint160(slot0));
    }

    function lastPing() public view returns (uint256) {
        return uint48(slot0 >> PING_OFFSET);
    }

    function lockedTill() public view returns (uint256) {
        return slot0 >> LOCKED_TILL_OFFSET;
    }

    function _transferOwnership(uint256 _slot0, address _newOwner) internal {
        emit Ping();
        emit OwnershipTransferred(address(uint160(_slot0)), _newOwner);
        // solhint-disable-next-line not-rely-on-time
        slot0 = uint256(uint160(_newOwner)) | (block.timestamp << PING_OFFSET);
    }

    function _checkLock(uint256 _slot0) internal view {
        // solhint-disable-next-line not-rely-on-time
        if ((_slot0 >> LOCKED_TILL_OFFSET) > block.timestamp) revert UseWhileLocked();
    }

    function _checkOwner(uint256 _slot0) internal view {
        if (address(uint160(_slot0)) != msg.sender) revert NotOwner();
    }

    function _lockTill(uint256 _timestamp) internal {
        uint256 slot0_ = slot0;
        _checkOwner(slot0_);
        uint256 currentLock = slot0_ >> LOCKED_TILL_OFFSET;
        // solhint-disable-next-line not-rely-on-time
        if (_timestamp <= currentLock || _timestamp < block.timestamp) revert InvalidLockTime();
        emit Locked(_timestamp);
        // solhint-disable-next-line not-rely-on-time
        if (currentLock > block.timestamp) {
            // Vault still locked, no ping
            slot0 = (slot0_ & OWNER_PING_MASK) | (_timestamp << LOCKED_TILL_OFFSET);
        } else {
            // Vault was already unlocked, _ping not used here due to gas
            emit Ping();
            slot0 =
                (slot0_ & OWNER_MASK) |
                // solhint-disable-next-line not-rely-on-time
                (block.timestamp << PING_OFFSET) |
                (_timestamp << LOCKED_TILL_OFFSET);
        }
    }

    function _setGuardiansTreeRoot(bytes32 _guardiansTreeRoot) internal {
        guardiansTreeRoot = _guardiansTreeRoot;
        emit GuardiansUpdate(_guardiansTreeRoot);
    }
}
