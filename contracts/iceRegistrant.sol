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

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;
}

interface ERC20 {

    function burn(
        uint256 _amount
    )
        external
        returns (bool);
}

contract iceRegistrant is AccessController, TransferHelper {

    uint256 public maxUpgradeLevel;
    uint256 public upgradeRequestCount;

    address public dgTokenAddress;
    address public iceTokenAddress;

    struct Level {
        uint256 dgAmount;
        uint256 iceAmount;
        uint256 minBonus;
        uint256 maxBonus;
        bool isActive;
    }

    struct Upgrade {
        uint256 level;
        uint256 bonus;
    }

    struct Request {
        uint256 tokenId;
        address tokenAddress;
        address tokenOwner;
    }

    struct Delegate {
        uint256 delegateAmount;
        address delegateAddress;
    }

    mapping (uint256 => Level) public levels;
    mapping (uint256 => Request) public requests;

    mapping (address => mapping (bytes32 => Upgrade)) public registrer;
    mapping (address => mapping (bytes32 => Delegate)) public delegate;

    event TokenUpgrade(
        address indexed tokenOwner,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 upgradeLevel
    );

    event UpgradeRequest(
        address indexed tokenOwner,
        uint256 indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 upgradeIndex
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
        uint256 tokenAddress,
        uint256 delegatePercent,
        address delegateAddress,
        address tokenOwner
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
        address _iceTokenAddress,
        uint256 _maxUpgradeLevel
    ) {
        dgTokenAddress = _dgTokenAddress;
        iceTokenAddress = _iceTokenAddress;
        maxUpgradeLevel = _maxUpgradeLevel;
    }

    function changeMaxUpgradeLevel(
        uint256 _newMaxUpgradeLevel
    )
        external
        onlyCEO
    {
        maxUpgradeLevel = _newMaxUpgradeLevel;
    }

    function manageLevel(
        uint256 _level,
        uint256 _dgAmount,
        uint256 _iceAmount,
        uint256 _minBonus,
        uint256 _maxBonus,
        bool _isActive
    )
        external
        onlyCEO
    {
        require(
            _level < maxUpgradeLevel,
            'iceRegistrant: invalid level'
        );

        levels[_level].dgAmount = _dgAmount;
        levels[_level].iceAmount = _iceAmount;

        levels[_level].minBonus = _minBonus;
        levels[_level].maxBonus = _maxBonus;

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
        address tokenOwner = msg.sender;

        require(
            tokenNFT.ownerOf(_tokenId) == tokenOwner,
            'iceRegistrant: invalid owner'
        );

        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        uint256 currentLevel = registrer[tokenOwner][tokenHash].level;
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

        registrer[tokenOwner][tokenHash].level = nextLevel;
        registrer[tokenOwner][tokenHash].bonus = getNumber(
            levels[nextLevel].minBonus,
            levels[nextLevel].maxBonus,
            block.difficulty,
            gasleft()
        );

        emit TokenUpgrade(
            tokenOwner,
            _tokenAddress,
            _tokenId,
            nextLevel
        );
    }

    function requestMaxUpgrade(
        address _tokenAddress,
        uint256 _tokenId
    )
        external
        returns (uint256 requestIndex)
    {
        ERC721 tokenNFT = ERC721(_tokenAddress);
        address tokenOwner = msg.sender;

        require(
            tokenNFT.ownerOf(_tokenId) == tokenOwner,
            'iceRegistrant: invalid owner'
        );

        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        uint256 currentLevel = registrer[tokenOwner][tokenHash].level;
        uint256 nextLevel = currentLevel + 1;

        require(
            nextLevel == maxUpgradeLevel,
            'iceRegistrant: invalid level'
        );

        requestIndex = upgradeRequestCount;

        tokenNFT.transferFrom(
            tokenOwner,
            address(this),
            _tokenId
        );

        requests[requestIndex].tokenId = _tokenId;
        requests[requestIndex].tokenAddress = _tokenAddress;
        requests[requestIndex].tokenOwner = tokenOwner;

        upgradeRequestCount =
        upgradeRequestCount + 1;

        return requestIndex;
    }

    function cancelMaxUpgrade(
        uint256 _requestIndex
    )
        external
    {
        uint256 tokenId = requests[_requestIndex].tokenId;
        address tokenAddress = requests[_requestIndex].tokenAddress;
        address tokenOwner = requests[_requestIndex].tokenOwner;

        require(
            msg.sender == tokenOwner,
            'iceRegistrant: invalid owner'
        );

        // clear request data
        delete requests[_requestIndex];

        bytes32 tokenHash = getHash(
            tokenAddress,
            tokenId
        );

        // clear token registration
        delete registrer[tokenOwner][tokenHash];

        // return original token
        ERC721(tokenAddress).transferFrom(
            address(this),
            tokenOwner,
            tokenId
        );

        emit UpgradeCancel(
            tokenOwner,
            tokenAddress,
            tokenId,
            _requestIndex
        );
    }

    function resolveMaxUpgrade(
        uint256 _requestIndex,
        address _newTokenAddress,
        uint256 _newTokenId
    )
        external
        onlyWorker
    {
        uint256 tokenId = requests[_requestIndex].tokenId;
        address tokenAddress = requests[_requestIndex].tokenAddress;
        address tokenOwner = requests[_requestIndex].tokenOwner;

        delete requests[_requestIndex];

        bytes32 originalHash = getHash(
            tokenAddress,
            tokenId
        );

        delete registrer[tokenOwner][originalHash];

        // return original token
        ERC721(tokenAddress).transferFrom(
            address(this),
            tokenOwner,
            tokenId
        );

        bytes32 newHash = getHash(
            _newTokenAddress,
            _newTokenId
        );

        registrer[tokenOwner][newHash].level = maxUpgradeLevel;
        // registrer[tokenOwner][newHash].bonus = maxUpgradeLevel;

        // issue new tokens
        ERC721(_newTokenAddress).transferFrom(
            address(this),
            tokenOwner,
            _newTokenId
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

        registrer[_newOwner][tokenHash].level = registrer[_oldOwner][tokenHash].level;
        registrer[_newOwner][tokenHash].bonus = registrer[_oldOwner][tokenHash].bonus;

        delete registrer[_oldOwner][tokenHash];

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

        return registrer[_tokenOwner][tokenHash].level;
    }

    function getIceBonus(
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

        return registrer[_tokenOwner][tokenHash].bonus;
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

    function getNumber(
        uint256 _minValue,
        uint256 _maxValue,
        uint256 _sourceValue,
        uint256 _randomValue
    )
        public
        pure
        returns (uint256)
    {
        return _minValue + _maxValue + _randomValue + _sourceValue % _maxValue;
    }
}
