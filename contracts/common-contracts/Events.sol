// SPDX-License-Identifier: ---DG----

pragma solidity ^0.8.12;

contract Events {

    event UpgradeItem(
        uint256 indexed itemId,
        uint256 issuedId,
        address indexed tokenOwner,
        uint256 indexed tokenId,
        address tokenAddress,
        uint256 requestIndex
    );

    event UpgradeResolved(
        uint256 indexed newItemId,
        address indexed tokenOwner,
        uint256 indexed newTokenId,
        address tokenAddress
    );

    event LevelEdit(
        uint256 indexed level,
        uint256 dgCostAmount,
        uint256 dgMoveAmount,
        uint256 iceCostAmount,
        uint256 iceMoveAmount,
        bool isActive
    );

    event IceLevelTransfer(
        address oldOwner,
        address indexed newOwner,
        address indexed tokenAddress,
        uint256 indexed tokenId
    );

    event InitialMinting(
        uint256 indexed tokenId,
        uint256 indexed mintCount,
        address indexed tokenOwner
    );

    event SupplyCheck(
        string rarity,
        uint256 maxSupply,
        uint256 price,
        address indexed beneficiary,
        string indexed metadata,
        string indexed contentHash
    );
}
