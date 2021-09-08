// SPDX-License-Identifier: -- 🧊 --

pragma solidity ^0.8.6;

import "./common-contracts-0.8/EIP712MetaTransaction.sol";
import "./common-contracts-0.8/AccessController.sol";
import "./common-contracts-0.8/TransferHelper.sol";
import "./common-contracts-0.8/Interfaces.sol";
import "./common-contracts-0.8/Events.sol";

contract IceRegistrant is AccessController, TransferHelper, EIP712MetaTransaction, Events {

    uint256 public upgradeCount;
    uint256 public upgradeRequestCount;

    address public tokenAddressDG;
    address public tokenAddressICE;

    address public depositAddressDG;
    address public depositAddressNFT;

    address public paymentToken;
    uint256 public mintingPrice;

    uint256 public saleCount;

    uint256 public immutable saleLimit;
    uint256 public immutable saleFrame;

    address public acessoriesContract;

    struct Level {
        bool isActive;
        uint256 costAmountDG;
        uint256 moveAmountDG;
        uint256 costAmountICE;
        uint256 moveAmountICE;
        uint256 minBonus;
        uint256 maxBonus;
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
        address delegateAddress;
        uint256 delegatePercent;
    }

    mapping (address => bool) public targets;

    mapping (address => uint256) public frames;
    mapping (uint256 => uint256) public limits;

    mapping (uint256 => Level) public levels;
    mapping (uint256 => Request) public requests;

    mapping (address => mapping (bytes32 => Upgrade)) public registrer;
    mapping (address => mapping (bytes32 => Delegate)) public delegate;

    constructor(
        uint256 _mintingPrice,
        address _paymentToken,
        address _tokenAddressDG,
        address _tokenAddressICE,
        address _acessoriesContract
    )
        EIP712Base('IceRegistrant', 'v1.0')
    {
        saleLimit = 500;
        saleFrame = 24 hours;

        paymentToken = _paymentToken;
        mintingPrice = _mintingPrice;

        tokenAddressDG = _tokenAddressDG;
        tokenAddressICE = _tokenAddressICE;

        targets[_acessoriesContract] = true;

        acessoriesContract = _acessoriesContract;
    }

    function changeDepositAddressDG(
        address _newDepositAddressDG
    )
        external
        onlyCEO
    {
        depositAddressDG = _newDepositAddressDG;
    }

    function changeDepositAddressNFT(
        address _newDepositAddressNFT
    )
        external
        onlyCEO
    {
        depositAddressNFT = _newDepositAddressNFT;
    }

    function changeAcessoriesDG(
        address _newAcessoriesContract
    )
        external
        onlyCEO
    {
        acessoriesContract = _newAcessoriesContract;
    }

    function changeMintingPrice(
        uint256 _newMintingPrice
    )
        external
        onlyCEO
    {
        mintingPrice = _newMintingPrice;
    }

    function changeMintLimits(
        uint256 _itemId,
        uint256 _newLimit
    )
        external
        onlyCEO
    {
        limits[_itemId] = _newLimit;
    }

    function changePaymentToken(
        address _newPaymentToken
    )
        external
        onlyCEO
    {
        paymentToken = _newPaymentToken;
    }

    function changeTarget(
        address _tokenAddress,
        bool _isActive
    )
        external
        onlyCEO
    {
        targets[_tokenAddress] = _isActive;
    }

    function manageLevel(
        uint256 _level,
        uint256 _costAmountDG,
        uint256 _moveAmountDG,
        uint256 _costAmountICE,
        uint256 _moveAmountICE,
        uint256 _minBonus,
        uint256 _maxBonus,
        bool _isActive
    )
        external
        onlyCEO
    {
        levels[_level].costAmountDG = _costAmountDG;
        levels[_level].moveAmountDG = _moveAmountDG;

        levels[_level].costAmountICE = _costAmountICE;
        levels[_level].moveAmountICE = _moveAmountICE;

        levels[_level].minBonus = _minBonus;
        levels[_level].maxBonus = _maxBonus;

        levels[_level].isActive = _isActive;

        emit LevelEdit(
            _level,
            _costAmountDG,
            _moveAmountDG,
            _costAmountICE,
            _moveAmountICE,
            _isActive
        );
    }

    function mintToken(
        uint256 _itemId,
        address _minterAddress
    )
        external
        onlyWorker
    {
        require(
            saleLimit > saleCount,
            'iceRegistrant: sold-out'
        );

        unchecked {
            saleCount =
            saleCount + 1;
        }

        require(
            limits[_itemId] > 0,
            'iceRegistrant: limited'
        );

        unchecked {
            limits[_itemId] =
            limits[_itemId] - 1;
        }

        require(
            block.timestamp - frames[_minterAddress] > saleFrame,
            'iceRegistrant: cool-down detected'
        );

        frames[_minterAddress] = block.timestamp;

        safeTransferFrom(
            paymentToken,
            _minterAddress,
            ceoAddress,
            mintingPrice
        );

        DGAccessories target = DGAccessories(
            acessoriesContract
        );

        uint256 newTokenId = target.encodeTokenId(
            _itemId,
            getSupply(_itemId) + 1
        );

        bytes32 newHash = getHash(
            acessoriesContract,
            newTokenId
        );

        registrer[_minterAddress][newHash].level = 1;
        registrer[_minterAddress][newHash].bonus = getNumber(
            levels[0].minBonus,
            levels[0].maxBonus,
            saleCount,
            block.timestamp
        );

        address[] memory beneficiaries;
        beneficiaries[0] = _minterAddress;

        uint256[] memory itemIds;
        itemIds[0] = _itemId;

        target.issueTokens(
            beneficiaries,
            itemIds
        );

        emit InitialMinting(
            newTokenId,
            saleCount,
            _minterAddress
        );
    }

    function requestUpgrade(
        address _tokenAddress,
        uint256 _tokenId
    )
        external
        returns (uint256 requestIndex)
    {
        require(
            targets[_tokenAddress] == true,
            'iceRegistrant: invalid token'
        );

        ERC721 tokenNFT = ERC721(_tokenAddress);
        address tokenOwner = msgSender();

        require(
            tokenNFT.ownerOf(_tokenId) == tokenOwner,
            'iceRegistrant: invalid owner'
        );

        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        uint256 nextLevel = getLevel(
            tokenOwner,
            tokenHash
        ) + 1;

        require(
            levels[nextLevel].isActive,
            'iceRegistrant: inactive level'
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

        unchecked {
            upgradeRequestCount =
            upgradeRequestCount + 1;
        }

        emit UpgradeRequest(
            tokenOwner,
            _tokenAddress,
            _tokenId,
            requestIndex
        );
    }

    function cancelUpgrade(
        uint256 _requestIndex
    )
        external
    {
        uint256 tokenId = requests[_requestIndex].tokenId;
        address tokenAddress = requests[_requestIndex].tokenAddress;
        address tokenOwner = requests[_requestIndex].tokenOwner;

        require(
            msgSender() == tokenOwner,
            'iceRegistrant: invalid owner'
        );

        delete requests[_requestIndex];

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

    function resolveUpgradeMint(
        uint256 _requestIndex,
        uint256 _itemId
    )
        external
        onlyWorker
    {
        uint256 tokenId = requests[_requestIndex].tokenId;
        address tokenAddress = requests[_requestIndex].tokenAddress;
        address tokenOwner = requests[_requestIndex].tokenOwner;

        delete requests[_requestIndex];

        bytes32 tokenHash = getHash(
            tokenAddress,
            tokenId
        );

        uint256 nextLevel = getLevel(
            tokenOwner,
            tokenHash
        ) + 1;

        delete registrer[tokenOwner][tokenHash];

        _takePayment(
            tokenOwner,
            levels[nextLevel].costAmountDG,
            levels[nextLevel].costAmountICE
        );

        ERC721(tokenAddress).transferFrom(
            address(this),
            depositAddressNFT,
            tokenId
        );

        DGAccessories target = DGAccessories(
            acessoriesContract
        );

        uint256 newTokenId = target.encodeTokenId(
            _itemId,
            getSupply(_itemId) + 1
        );

        bytes32 newHash = getHash(
            acessoriesContract,
            newTokenId
        );

        registrer[tokenOwner][newHash].level = nextLevel;
        registrer[tokenOwner][newHash].bonus = getNumber(
            levels[nextLevel].minBonus,
            levels[nextLevel].maxBonus,
            upgradeCount,
            block.timestamp
        );

        unchecked {
            upgradeCount =
            upgradeCount + 1;
        }

        address[] memory beneficiaries;
        beneficiaries[0] = tokenOwner;

        uint256[] memory itemIds;
        itemIds[0] = _itemId;

        target.issueTokens(
            beneficiaries,
            itemIds
        );

        emit UpgradeResolved(
            tokenOwner,
            _requestIndex
        );
    }

    function resolveUpgradeSend(
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

        bytes32 tokenHash = getHash(
            tokenAddress,
            tokenId
        );

        uint256 nextLevel = getLevel(
            tokenOwner,
            tokenHash
        ) + 1;

        delete registrer[tokenOwner][tokenHash];

        _takePayment(
            tokenOwner,
            levels[nextLevel].costAmountDG,
            levels[nextLevel].costAmountICE
        );

        ERC721(tokenAddress).transferFrom(
            address(this),
            depositAddressNFT,
            tokenId
        );

        bytes32 newHash = getHash(
            _newTokenAddress,
            _newTokenId
        );

        registrer[tokenOwner][newHash].level = nextLevel;
        registrer[tokenOwner][newHash].bonus = getNumber(
            levels[nextLevel].minBonus,
            levels[nextLevel].maxBonus,
            upgradeCount,
            block.timestamp
        );

        unchecked {
            upgradeCount =
            upgradeCount + 1;
        }

        ERC721(_newTokenAddress).transferFrom(
            address(this),
            tokenOwner,
            _newTokenId
        );

        emit UpgradeResolved(
            tokenOwner,
            _requestIndex
        );
    }

    function delegateToken(
        address _tokenAddress,
        uint256 _tokenId,
        address _delegateAddress,
        uint256 _delegatePercent
    )
        external
    {
        ERC721 tokenNFT = ERC721(_tokenAddress);
        address tokenOwner = msgSender();

        require(
            tokenNFT.ownerOf(_tokenId) == tokenOwner,
            'iceRegistrant: invalid owner'
        );

        require(
            _delegatePercent <= 100,
            'iceRegistrant: invalid percent'
        );

        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        delegate[tokenOwner][tokenHash].delegateAddress = _delegateAddress;
        delegate[tokenOwner][tokenHash].delegatePercent = _delegatePercent;

        emit Delegated(
            _tokenId,
            _tokenAddress,
            _delegateAddress,
            _delegatePercent,
            tokenOwner
        );
    }

    function reIceNFT(
        address _oldOwner,
        address _tokenAddress,
        uint256 _tokenId
    )
        external
    {
        require(
            targets[_tokenAddress] == true,
            'iceRegistrant: invalid token'
        );

        ERC721 token = ERC721(_tokenAddress);
        address newOwner = msgSender();

        require(
            token.ownerOf(_tokenId) == newOwner,
            'iceRegistrant: invalid owner'
        );

        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        uint256 currentLevel = getLevelById(
            _oldOwner,
            _tokenAddress,
            _tokenId
        );

        _takePayment(
            newOwner,
            levels[currentLevel].moveAmountDG,
            levels[currentLevel].moveAmountICE
        );

        uint256 oldLevel = registrer[_oldOwner][tokenHash].level;
        uint256 oldBonus = registrer[_oldOwner][tokenHash].bonus;

        require(
            oldLevel > registrer[newOwner][tokenHash].level,
            'iceRegistrant: preventing level downgrade'
        );

        require(
            oldBonus > registrer[newOwner][tokenHash].bonus,
            'iceRegistrant: preventing bonus downgrade'
        );

        delete registrer[_oldOwner][tokenHash];

        registrer[newOwner][tokenHash].level = oldLevel;
        registrer[newOwner][tokenHash].bonus = oldBonus;

        emit IceLevelTransfer(
            _oldOwner,
            newOwner,
            _tokenAddress,
            _tokenId
        );
    }

    function adjustDelegateEntry(
        address _tokenOwner,
        address _tokenAddress,
        uint256 _tokenId,
        address _delegateAddress,
        uint256 _delegatePercent
    )
        external
        onlyWorker
    {
        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        require(
            _delegatePercent <= 100,
            'iceRegistrant: invalid percent'
        );

        delegate[_tokenOwner][tokenHash].delegateAddress = _delegateAddress;
        delegate[_tokenOwner][tokenHash].delegatePercent = _delegatePercent;
    }

    function adjustRegistrantEntry(
        address _tokenOwner,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _bonusValue,
        uint256 _levelValue
    )
        external
        onlyWorker
    {
        bytes32 tokenHash = getHash(
            _tokenAddress,
            _tokenId
        );

        registrer[_tokenOwner][tokenHash].level = _levelValue;
        registrer[_tokenOwner][tokenHash].bonus = _bonusValue;
    }

    function getSupply(
        uint256 _itemId
    )
        public
        returns (uint256)
    {
        (   string memory rarity,
            uint256 maxSupply,
            uint256 totalSupply,
            uint256 price,
            address beneficiary,
            string memory metadata,
            string memory contentHash

        ) = DGAccessories(acessoriesContract).items(_itemId);

        emit SupplyCheck(
            rarity,
            maxSupply,
            price,
            beneficiary,
            metadata,
            contentHash
        );

        return totalSupply;
    }

    function _takePayment(
        address _payer,
        uint256 _dgAmount,
        uint256 _iceAmount
    )
        internal
    {
        if (_dgAmount > 0) {
            safeTransferFrom(
                tokenAddressDG,
                _payer,
                depositAddressDG,
                _dgAmount
            );
        }

        if (_iceAmount > 0) {
            safeTransferFrom(
                tokenAddressICE,
                _payer,
                address(this),
                _iceAmount
            );

            ERC20 iceToken = ERC20(tokenAddressICE);
            iceToken.burn(_iceAmount);
        }
    }

    function getLevel(
        address _tokenOwner,
        bytes32 _tokenHash
    )
        public
        view
        returns (uint256)
    {
        return registrer[_tokenOwner][_tokenHash].level;
    }

    function getLevelById(
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
        uint256 iceBonus = getIceBonus(
            _tokenOwner,
            _tokenAddress,
            _tokenId
        );

        return iceBonus > 0;
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
        uint256 _nonceValue,
        uint256 _randomValue
    )
        public
        pure
        returns (uint256)
    {
        return _minValue + uint256(keccak256(abi.encodePacked(_nonceValue, _randomValue))) % (_maxValue + 1);
    }
}
