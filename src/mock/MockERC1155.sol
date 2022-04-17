// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @author Philippe Dumonet
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(
        address _recipient,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _mint(_recipient, _tokenId, _amount, "");
    }
}
