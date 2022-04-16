// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IAssetVault} from "./IAssetVault.sol";

/// @author Philippe Dumonet
contract AssetVault is Context, Multicall, Initializable, IAssetVault {
    using SafeERC20 for IERC20;

    // slot n+0
    address public owner;
    uint64 public lastPing;

    bytes32 public guardiansMerkleRoot;

    modifier onlyOwner() {
        _checkOwnerCalling();
        _;
    }

    receive() external payable {
        if (_msgSender() == owner) _ping();
    }

    function initialize(address _firstOwner, bytes32 _guardiansMerkleRoot) external initializer {
        _ping();
        _setGuardiansMerkleRoot(_guardiansMerkleRoot);
        _transferOwner(address(0), _firstOwner);
    }

    // solhint-disable-next-line no-empty-blocks
    function ping() external onlyOwner {}

    function recoverAsGuardianTo(
        address _newOwner,
        uint256 _delay,
        bytes32[] memory _proof
    ) external {
        // read slot together
        address previousOwner = owner;
        uint256 lastStoredPing = lastPing;
        if (lastStoredPing + _delay > block.timestamp) revert DelayNotPassed();
        address guardian = _msgSender();
        if (!isGuardian(guardian, _delay, _proof)) revert InvalidMerkleProof();
        _ping();
        _transferOwner(previousOwner, _newOwner);
        emit GuardianRecovered(guardian, _newOwner, _delay);
    }

    function transferOwnership(address _newOwner) external {
        address previousOwner = _checkOwnerCalling();
        _transferOwner(previousOwner, _newOwner);
    }

    function updateGuardianMerkle(bytes32 _newGuardiansMerkleRoot) external onlyOwner {
        _setGuardiansMerkleRoot(_newGuardiansMerkleRoot);
    }

    function transferNative(address payable _recipient, uint256 _value) external onlyOwner {
        Address.sendValue(_recipient, _value);
    }

    function transferToken(
        IERC20 _token,
        address _from,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        _token.safeTransferFrom(_from, _to, _amount);
    }

    function transferNFT(
        IERC721 _token,
        address _from,
        address _to,
        uint256 _tokenId
    ) external onlyOwner {
        _token.safeTransferFrom(_from, _to, _tokenId);
    }

    function transferCollectible(
        IERC1155 _collectible,
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount
    ) external onlyOwner {
        _collectible.safeTransferFrom(_from, _to, _tokenId, _amount, "");
    }

    function doCustomCalls(CustomCall[] calldata _calls) external onlyOwner {
        uint256 callLen = _calls.length;
        for (uint256 i = 0; i < callLen; ) {
            (bool success, bytes memory returndata) = _calls[i].target.call{value: _calls[i].value}(
                _calls[i].data
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

    function guardianLeaf(address _guardian, uint256 _delay) public pure returns (bytes32 leaf) {
        // equivalent to leaf = keccak256(abi.encode(_guardian, _delay));
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(0x00, _guardian)
            mstore(0x20, _delay)
            leaf := keccak256(0x00, 0x40)
        }
    }

    function isGuardian(
        address _guardian,
        uint256 _delay,
        bytes32[] memory _proof
    ) public view returns (bool) {
        return MerkleProof.verify(_proof, guardiansMerkleRoot, guardianLeaf(_guardian, _delay));
    }

    function _checkOwnerCalling() internal returns (address) {
        _ping();
        address currentOwner = owner;
        if (_msgSender() != currentOwner) revert NotOwner();
        return currentOwner;
    }

    function _ping() internal {
        lastPing = uint64(block.timestamp);
        emit Ping();
    }

    function _transferOwner(address _previousOwner, address _newOwner) internal {
        if (_newOwner == address(0)) revert NewOwnerZeroAddress();
        owner = _newOwner;
        emit OwnershipTransferred(_previousOwner, _newOwner);
    }

    function _setGuardiansMerkleRoot(bytes32 _newGuardiansMerkleRoot) internal {
        guardiansMerkleRoot = _newGuardiansMerkleRoot;
        emit GuardiansUpdate(_newGuardiansMerkleRoot);
    }
}
