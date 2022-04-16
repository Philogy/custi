// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

/// @author Philippe Dumonet
library MerkleProofBuilder {
    function hashTwoNodes(bytes32 _a, bytes32 _b) internal pure returns (bytes32 parentNode) {
        (_a, _b) = _a < _b ? (_a, _b) : (_b, _a);
        assembly {
            mstore(0x00, _a)
            mstore(0x20, _b)
            parentNode := keccak256(0x00, 0x40)
        }
    }
}
