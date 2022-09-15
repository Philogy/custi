// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

/// @author Philippe Dumonet <philippe@dumo.net>
interface ICustiVaultV1 {
    error Initialized();
    error NotOwner();
    error NewOwnerZeroAddress();
    error UseWhileLocked();
    error InvalidLockTime();
    error InvalidMerkleProof();
    error DelayNotPassed();
    error CustomCallFailed(bytes errorData);

    event Locked(uint256 lockEnd);
    event Ping();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event GuardiansUpdate(bytes32 indexed guardiansTreeRoot);

    function ownerPingLockedTill()
        external
        view
        returns (
            address owner_,
            uint256 lastPing_,
            uint256 lockedTill_
        );

    function owner() external view returns (address);

    function lastPing() external view returns (uint256);

    function lockedTill() external view returns (uint256);

    function guardiansTreeRoot() external view returns (bytes32);

    function buildGuardianLeaf(address _guardian, uint256 _delay)
        external
        pure
        returns (bytes32 guardianLeaf);

    function isGuardian(
        bytes32[] calldata _proof,
        address _guardian,
        uint256 _delay
    ) external view returns (bool);

    function initialize(address _owner, bytes32 _guardiansTreeRoot) external;

    // solhint-disable-next-line no-empty-blocks
    function ping() external payable;

    function lockTill(uint256 _timestamp) external;

    function lockFor(uint256 _lockDuration) external;

    function transferOwnership(address _newOwner) external;

    function setGuardiansTreeRoot(bytes32 _guardiansTreeRoot) external;

    function recoverAsGuardianTo(
        address _newOwner,
        uint256 _delay,
        bytes32[] calldata _proof
    ) external;

    function doCustomCall(
        address _target,
        uint256 _value,
        bytes calldata _calldata,
        bool _requireSuccess
    ) external returns (bool success, bytes memory returndata);

    function transferNative(address _recipient, uint256 _value) external;

    function transferToken(
        address _token,
        address _to,
        uint256 _amount
    ) external;

    function transferTokenFrom(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external;

    function transferNFT(
        address _token,
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    function transferCollectible(
        address _collectible,
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount
    ) external;
}
