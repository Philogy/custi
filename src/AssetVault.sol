// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

error NotOwner();

/// @author Philippe Dumonet
contract AssetVault is Context, Multicall, Initializable {
    // slot n+0
    address internal owner;
    uint64 internal lastPing;
    uint32 internal guardianCount;

    // guardians stored in manually managed dynamic array for efficiency
    // keccak256("philogy.Social-Recovery-Asset-Vault.guardian-array")
    bytes32 internal constant GUARDIANS_START_SLOT =
        0x1948fdddb92e5a760b9e1d3ffc98707129333bbdc4313bac31e63d1502cc3f9e;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct CustomCall {
        bool requireSuccess;
        address target;
        uint256 value;
        bytes callData;
    }

    receive() external payable {}

    function initialize(address _firstOwner, uint256[] memory _packedGuardians)
        external
        initializer
    {
        owner = _firstOwner;
        lastPing = uint64(block.timestamp);
        guardianCount = uint32(_packedGuardians.length);
    }

    function ping() external {
        _checkOnlyOwner();
        lastPing = uint64(block.timestamp);
    }

    function transferOwnership(address _newOwner) external {
        (address previousOwner, ) = _checkOnlyOwner();
        owner = _newOwner;
        lastPing = uint64(block.timestamp);
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function doCalls(CustomCall[] calldata _calls) external {
        _checkOnlyOwner();
        uint256 callLen = _calls.length;
        for (uint256 i = 0; i < callLen; ) {
            (bool success, bytes memory returndata) = _calls[i].target.call{value: _calls[i].value}(
                _calls[i].callData
            );
            Address.verifyCallResult(
                success || !_calls[i].requireSuccess,
                returndata,
                "AssetVault: Required call revert"
            );
            unchecked {
                i++;
            }
        }
    }

    function _checkOnlyOwner() internal view returns (address, uint256) {
        address currentOwner = owner;
        uint256 currentGuardianCount = guardianCount;
        if (_msgSender() != currentOwner) revert NotOwner();
        return (currentOwner, currentGuardianCount);
    }
}
