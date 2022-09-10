// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {BaseTest} from "../utils/BaseTest.sol";
import {IAssetVault} from "../IAssetVault.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IStorerBase {
    function target() external view returns (address);

    function show() external view returns (bool);

    function requireSuccess() external view returns (bool);

    function totalCalls() external view returns (uint256);

    function increase() external;
}

struct Call {
    address target;
    bytes data;
    uint256 value;
    bool requireSuccess;
    uint256 index;
}

contract CallStorer {
    IStorerBase private immutable storerBase;

    constructor(address _storerBase) {
        storerBase = IStorerBase(_storerBase);
    }

    Call[] private calls;

    fallback(bytes calldata _calldata) external payable returns (bytes memory) {
        if (storerBase.show()) {
            return abi.encode(calls);
        }
        calls.push(
            Call({
                target: storerBase.target(),
                data: _calldata,
                value: msg.value,
                requireSuccess: storerBase.requireSuccess(),
                index: storerBase.totalCalls()
            })
        );
        storerBase.increase();
        return "";
    }
}

struct VaultCall {
    bytes data;
    uint256 index;
}

contract VaultCallStorer {
    IStorerBase private immutable storerBase;

    constructor(address _storerBase) {
        storerBase = IStorerBase(_storerBase);
    }

    VaultCall[] private calls;

    fallback(bytes calldata _calldata) external payable returns (bytes memory) {
        if (storerBase.show()) {
            return abi.encode(calls);
        }
        calls.push(VaultCall({data: _calldata, index: storerBase.totalCalls()}));
        storerBase.increase();
        return "";
    }
}

/// @author Philippe Dumonet
contract LiveStuffBase is BaseTest, IStorerBase {
    address public target;
    bool public show;
    bool public requireSuccess;
    uint256 public totalCalls;

    address internal callStorer;
    IAssetVault internal vault;

    function setUp() public {
        cheats.deal(msg.sender, 1e9 ether);
    }

    function increase() external {
        totalCalls++;
    }

    function _resetCalls() internal {
        callStorer = address(new CallStorer(address(this)));
        vault = IAssetVault(address(new VaultCallStorer(address(this))));
        totalCalls = 0;
    }

    modifier showCalls() {
        _resetCalls();
        _;
        show = true;
        (, bytes memory returndataCalls) = callStorer.call("");
        (, bytes memory returndataVaultCalls) = address(vault).call("");
        show = false;
        Call[] memory calls = abi.decode(returndataCalls, (Call[]));
        VaultCall[] memory vaultCalls = abi.decode(returndataVaultCalls, (VaultCall[]));

        emit log("multicall");
        emit log("data:\n");
        uint256 totalCalls = calls.length + vaultCalls.length;
        uint256 callIndex = 0;
        uint256 vaultCallIndex = 0;
        for (uint256 i = 0; i < totalCalls; i++) {
            if (callIndex < calls.length && calls[callIndex].index == i) {
                Call memory call = calls[callIndex];
                emit log_bytes(
                    abi.encodeCall(
                        IAssetVault.doCustomCall,
                        (call.target, call.value, call.data, call.requireSuccess)
                    )
                );
                callIndex++;
            } else {
                emit log_bytes(vaultCalls[vaultCallIndex].data);
                vaultCallIndex++;
            }
            emit log(",\n");
        }
    }
}

interface IWeth {
    function deposit() external payable;

    function withdraw(address) external;
}

contract LiveStuff is LiveStuffBase {
    function testSolution() public showCalls {
        requireSuccess = true;
        target = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        IWeth weth = IWeth(callStorer);

        weth.deposit{value: 3 ether}();

        for (uint256 i = 0; i < 20; i++) {
            vault.transferNFT(
                IERC721(0xC4638af1e01720C4B5df3Bc8D833db6be85d2211),
                0x488F1889E5e219e5228e86e2E41f9a9c74A28397,
                0x33CC24dbf9c8FDDB574077eE0Fa1d2b93B566381,
                i + 4555
            );
        }
    }
}
