// SPDX-License-Identifier: -- 💎 --

pragma solidity ^0.8.0;

import "./common-contracts-0.8/AccessController.sol";
import "./common-contracts-0.8/TransferHelper.sol";

interface ERC721 {

    function ownerOf(
        uint256 _tokenId
    )
        external
        view
        returns (address);
}

interface ERC20 {

    function burn(
        uint256 _amount
    )
        external
        returns (bool);
}

contract iceRegistrant is AccessController, TransferHelper {

    address public dgTokenAddress;
    address public iceTokenAddress;

    struct Level {
        uint256 dgAmount;
        uint256 iceAmount;
        bool isActive;
    }

    mapping (uint256 => Level) public levels;
    mapping (address => mapping (bytes32 => uint256)) public registrer;

    event TokenUpgrade(
        address indexed tokenOwner,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 upgradeLevel
    );

    event LevelEdit(
        uint256 indexed level,
        uint256 dgAmount,
        uint256 iceAmount,
        bool isActive
    );

    event IceLevelTransfer(
        address oldOwner,
        address indexed newOwner,
        address indexed tokenAddress,
        uint256 indexed tokenId
    );

    constructor(
        address _dgTokenAddress,
        address _iceTokenAddress
    ) {
        dgTokenAddress = _dgTokenAddress;
        iceTokenAddress = _iceTokenAddress;
    }

    function editLevel(
        uint256 _level,
        uint256 _dgAmount,
        uint256 _iceAmount,
        bool _isActive
    )
        external
        onlyCEO
    {
        levels[_level].dgAmount = _dgAmount;
        levels[_level].iceAmount = _iceAmount;
        levels[_level].isActive = _isActive;

        emit LevelEdit(
            _level,
            _dgAmount,
            _iceAmount,
            _isActive
        );
    }

    function upgradeNFT(
        address _tokenAddress,
        uint256 _tokenId
    )
        external
    {
        ERC721 tokenNFT = ERC721(_tokenAddress);

        require(
            tokenNFT.ownerOf(_tokenId) == msg.sender,
            'iceRegistrant: invalid owner'
        );

        address tokenOwner = msg.sender;
        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        uint256 currentLevel = registrer[tokenOwner][tokenHash];
        uint256 nextLevel = currentLevel + 1;

        require(
            levels[nextLevel].isActive,
            'iceRegistrant: inactive level'
        );

        safeTransferFrom(
            dgTokenAddress,
            tokenOwner,
            ceoAddress,
            levels[nextLevel].dgAmount
        );

        safeTransferFrom(
            iceTokenAddress,
            tokenOwner,
            address(this),
            levels[nextLevel].iceAmount
        );

        ERC20 iceToken = ERC20(iceTokenAddress);
        iceToken.burn(levels[nextLevel].iceAmount);

        registrer[tokenOwner][tokenHash] = nextLevel;

        emit TokenUpgrade(
            tokenOwner,
            _tokenAddress,
            _tokenId,
            nextLevel
        );
    }

    function transferIceLevel(
        address _oldOwner,
        address _tokenAddress,
        uint256 _tokenId,
        address _newOwner
    )
        external
        onlyWorker
    {
        ERC721 token = ERC721(_tokenAddress);

        require(
            token.ownerOf(_tokenId) == _newOwner,
            'iceRegistrant: invalid owner'
        );

        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        registrer[_newOwner][tokenHash] = registrer[_oldOwner][tokenHash];
        registrer[_oldOwner][tokenHash] = 0;

        emit IceLevelTransfer(
            _oldOwner,
            _newOwner,
            _tokenAddress,
            _tokenId
        );
    }

    function getIceLevel(
        address _tokenOwner,
        address _tokenAddress,
        uint256 _tokenId
    )
        public
        view
        returns (uint256)
    {
        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        return registrer[_tokenOwner][tokenHash];
    }

    function isIceEnabled(
        address _tokenOwner,
        address _tokenAddress,
        uint256 _tokenId
    )
        public
        view
        returns (bool)
    {
        uint256 iceLevel = getIceLevel(
            _tokenOwner,
            _tokenAddress,
            _tokenId
        );

        return iceLevel > 0;
    }

    function getHash(
        address _tokenAddress,
        uint256 _tokenId
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(
            _tokenAddress,
            _tokenId
        ));
    }
}
