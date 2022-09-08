// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {ICustiVaultV1} from "./ICustiVaultV1.sol";

/// @author Philippe Dumonet <philippe@dumo.net>
contract CustiVaultV1 is ICustiVaultV1 {
    // [  0..159] owner
    // [160..207] lastPing
    // [208..255] lockedTill
    uint256 internal slot0;
    uint256 internal constant PING_OFFSET = 160;
    uint256 internal constant LOCKED_TILL_OFFSET = 208;
    uint256 internal constant OWNER_MASK = uint256(type(uint160).max);
    uint256 internal constant OWNER_PING_MASK = uint256(type(uint208).max);
    uint256 internal constant NOT_PING_MASK = ~(uint256(type(uint48).max) << 160);

    modifier onlyOwner() {
        uint256 curSlot0 = slot0;
        _ownerLockCheck(curSlot0);
        slot0 = _ping(curSlot0);
        _;
    }

    function lockTill(uint256 _timestamp) external {
        uint256 curSlot0 = slot0;
        _checkOwner(curSlot0);
        slot0 = _setLockTill(curSlot0, _timestamp);
    }

    function lockFor(uint256 _lockDuration) external {
        uint256 curSlot0 = slot0;
        _checkOwner(curSlot0);
        slot0 = _setLockTill(curSlot0, block.timestamp + _lockDuration);
    }

    // solhint-disable-next-line no-empty-blocks
    function ping() external onlyOwner {}

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

    function _ownerLockCheck(uint256 _slot0) internal view {
        _checkOwner(_slot0);
        if ((_slot0 >> LOCKED_TILL_OFFSET) > block.timestamp) revert UseWhileLocked();
    }

    function _checkOwner(uint256 _slot0) internal view {
        if (address(uint160(_slot0)) != msg.sender) revert NotOwner();
    }

    function _setLockTill(uint256 _slot0, uint256 _timestamp)
        internal
        returns (uint256 updatedSlot0)
    {
        uint256 currentLock = _slot0 >> LOCKED_TILL_OFFSET;
        if (_timestamp <= currentLock) revert InvalidLockTime();
        emit Locked(_timestamp);
        if (currentLock > block.timestamp) {
            // Vault still locked, no ping
            return (_slot0 & OWNER_PING_MASK) | (_timestamp << LOCKED_TILL_OFFSET);
        } else {
            // Vault was already unlocked, _ping not used here due to gas
            emit Ping();
            return
                (_slot0 & OWNER_MASK) |
                (block.timestamp << PING_OFFSET) |
                (_timestamp << LOCKED_TILL_OFFSET);
        }
    }

    function _ping(uint256 _slot0) internal returns (uint256 updatedSlot0) {
        emit Ping();
        return (_slot0 & NOT_PING_MASK) | (block.timestamp << PING_OFFSET);
    }
}
