// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

/// @author Philippe Dumonet <philippe@dumo.net>
interface ICustiVaultV1 {
    error NotOwner();
    error UseWhileLocked();
    error InvalidLockTime();
    error CustomCallFailed(bytes errorData);

    event Locked(uint256 lockEnd);
    event Ping();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
