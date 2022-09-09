// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

/// @author Philippe Dumonet <philippe@dumo.net>
contract AssetAcceptor is ERC721Holder, ERC1155Holder {
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
