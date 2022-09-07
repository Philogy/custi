// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {BaseTest} from "../utils/BaseTest.sol";
import {IAssetVault} from "../IAssetVault.sol";

interface IStorerBase {
    function target() external view returns (address);

    function show() external view returns (bool);

    function requireSuccess() external view returns (bool);
}

struct Call {
    address target;
    bytes data;
    uint256 value;
    bool requireSuccess;
}

contract CallStorer is BaseTest {
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
                requireSuccess: storerBase.requireSuccess()
            })
        );
        return "";
    }
}

/// @author Philippe Dumonet
contract LiveStuffBase is BaseTest, IStorerBase {
    address public override target;
    bool public override show;
    bool public override requireSuccess;

    address internal callStorer;

    function setUp() public {
        cheats.deal(msg.sender, 1e9 ether);
    }

    function _resetCalls() internal {
        callStorer = address(new CallStorer(address(this)));
    }

    modifier showCalls() {
        _resetCalls();
        _;
        show = true;
        (, bytes memory returndata) = callStorer.call("");
        show = false;
        Call[] memory calls = abi.decode(returndata, (Call[]));

        emit log("calls:\n");

        uint256 callLen = calls.length;
        if (callLen == 1) {
            emit log("doCustomCall");
            emit log_named_address("_target", calls[0].target);
            emit log_named_uint("_value", calls[0].value);
            emit log_named_bytes("_calldata", calls[0].data);
            emit log_named_string("_requireSuccess", calls[0].requireSuccess ? "true" : "false");
        } else {
            emit log("multicall");
            emit log("data:\n");
            for (uint256 i = 0; i < callLen; i++) {
                Call memory call = calls[i];
                emit log_bytes(
                    abi.encodeCall(
                        IAssetVault.doCustomCall,
                        (call.target, call.value, call.data, call.requireSuccess)
                    )
                );
                emit log(",\n");
            }
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
        target = 0xae7e201257f3F7918E9e8F2F3De998E3D75f7A1d;
        IWeth c = IWeth(callStorer);
        c.deposit{value: 2 ether}();

        c.withdraw(0xae7e201257f3F7918E9e8F2F3De998E3D75f7A1d);
    }
}
