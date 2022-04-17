// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

/// @author Philippe Dumonet
contract MockContract {
    uint256 public value;
    address public lastSender;

    function reset() external {
        lastSender = address(0);
    }

    function setValue(uint256 _value) external {
        lastSender = msg.sender;
        value = _value;
    }

    function payIn() external payable returns (bytes32) {
        lastSender = msg.sender;
        require(msg.value == value, "MockContract: Incorrect Value");
        return keccak256(abi.encode(address(this)));
    }
}
