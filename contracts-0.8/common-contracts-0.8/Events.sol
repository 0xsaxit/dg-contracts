// SPDX-License-Identifier: -- 💎 --

pragma solidity ^0.8.7;

contract Events {

    event UpgradeRequest(
        uint256 indexed itemId,
        uint256 issuedId,
        address tokenOwner,
        address tokenAddress,
        uint256 indexed tokenId,
        uint256 indexed requestIndex
    );

    event UpgradeCancel(
        address indexed tokenOwner,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 upgradeIndex
    );

    event UpgradeResolved(
        address indexed tokenOwner,
        uint256 indexed upgradeIndex
    );

    event Delegated (
        uint256 tokenId,
        address indexed tokenAddress,
        address indexed delegateAddress,
        uint256 delegatePercent,
        address indexed tokenOwner
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
