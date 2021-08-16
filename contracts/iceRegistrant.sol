// SPDX-License-Identifier: -- 💎 --

pragma solidity ^0.8.0;

import "./common-contracts-0.8/AccessController.sol";
import "./common-contracts-0.8/TransferHelper.sol";
import "./common-contracts-0.8/EIP712Base.sol";

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

abstract contract EIP712MetaTransaction is EIP712Base {

    bytes32 private constant META_TRANSACTION_TYPEHASH =
        keccak256(
            bytes(
                "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
            )
        );

    event MetaTransactionExecuted(
        address userAddress,
        address payable relayerAddress,
        bytes functionSignature
    );

    mapping(address => uint256) internal nonces;

    /*
     * Meta transaction structure.
     * No point of including value field here as if user is doing value transfer then he has the funds to pay for gas
     * He should call the desired function directly in that case.
     */
    struct MetaTransaction {
		uint256 nonce;
		address from;
        bytes functionSignature;
	}

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    )
        public
        payable
        returns(bytes memory)
    {
        MetaTransaction memory metaTx = MetaTransaction(
            {
                nonce: nonces[userAddress],
                from: userAddress,
                functionSignature: functionSignature
            }
        );

        require(
            verify(
                userAddress,
                metaTx,
                sigR,
                sigS,
                sigV
            ), "Signer and signature do not match"
        );

	    nonces[userAddress] =
	    nonces[userAddress] + 1;

        // Append userAddress at the end to extract it from calling context
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(
                functionSignature,
                userAddress
            )
        );

        require(
            success,
            'Function call not successful'
        );

        emit MetaTransactionExecuted(
            userAddress,
            payable(msg.sender),
            functionSignature
        );

        return returnData;
    }

    function hashMetaTransaction(
        MetaTransaction memory metaTx
    )
        internal
        pure
        returns (bytes32)
    {
		return keccak256(
		    abi.encode(
                META_TRANSACTION_TYPEHASH,
                metaTx.nonce,
                metaTx.from,
                keccak256(metaTx.functionSignature)
            )
        );
	}

    function verify(
        address user,
        MetaTransaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    )
        internal
        view
        returns (bool)
    {
        address signer = ecrecover(
            toTypedMessageHash(
                hashMetaTransaction(metaTx)
            ),
            sigV,
            sigR,
            sigS
        );

        require(
            signer != address(0x0),
            'Invalid signature'
        );
		return signer == user;
	}

    function msgSender() internal view returns(address sender) {
        if(msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            sender = msg.sender;
        }
        return sender;
    }
}

contract IceRegistrant is AccessController, TransferHelper, EIP712MetaTransaction {

    uint256 public upgradeCount;
    uint256 public reRollCount;

    uint256 public maxUpgradeLevel;
    uint256 public upgradeRequestCount;

    address public tokenAddressDG;
    address public tokenAddressICE;
    address public depositAddress;

    struct Level {
        uint256 costAmountDG;
        uint256 rollAmountDG;
        uint256 costAmountICE;
        uint256 rollAmountICE;
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
        address delegateAddress;
        uint256 delegatePercent;
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
        address tokenAddress,
        address delegateAddress,
        uint256 delegatePercent,
        address tokenOwner
    );

    event LevelEdit(
        uint256 indexed level,
        uint256 dgCostAmount,
        uint256 iceCostAmount,
        uint256 dgReRollAmount,
        uint256 iceReRollAmount,
        bool isActive
    );

    event IceLevelTransfer(
        address oldOwner,
        address indexed newOwner,
        address indexed tokenAddress,
        uint256 indexed tokenId
    );

    constructor(
        address _tokenAddressDG,
        address _tokenAddressICE,
        uint256 _maxUpgradeLevel
    )
        EIP712Base('IceRegistrant', 'v1.0')
    {
        tokenAddressDG = _tokenAddressDG;
        tokenAddressICE = _tokenAddressICE;
        maxUpgradeLevel = _maxUpgradeLevel;
    }

    function changeDepositAddress(
        address _newDepositAddress
    )
        external
        onlyCEO
    {
        depositAddress = _newDepositAddress;
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
        uint256 _costAmountDG,
        uint256 _rollAmountDG,
        uint256 _costAmountICE,
        uint256 _rollAmountICE,
        uint256 _minBonus,
        uint256 _maxBonus,
        bool _isActive
    )
        external
        onlyCEO
    {
        require(
            _level <= maxUpgradeLevel,
            'iceRegistrant: invalid level'
        );

        levels[_level].costAmountDG = _costAmountDG;
        levels[_level].rollAmountDG = _rollAmountDG;

        levels[_level].costAmountICE = _costAmountICE;
        levels[_level].rollAmountICE = _rollAmountICE;

        levels[_level].minBonus = _minBonus;
        levels[_level].maxBonus = _maxBonus;

        levels[_level].isActive = _isActive;

        emit LevelEdit(
            _level,
            _costAmountDG,
            _rollAmountDG,
            _costAmountICE,
            _rollAmountICE,
            _isActive
        );
    }

    function reRollBonus(
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

        require(
            currentLevel > 0,
            'iceRegistrant: invalid level'
        );

        require(
            currentLevel < maxUpgradeLevel,
            'iceRegistrant: invalid level'
        );

        _takePayment(
            tokenOwner,
            levels[currentLevel].rollAmountDG,
            levels[currentLevel].rollAmountICE
        );

        // consider using oracle instead of getNumber();
        registrer[tokenOwner][tokenHash].bonus = getNumber(
            levels[currentLevel].minBonus,
            levels[currentLevel].maxBonus,
            block.timestamp,
            reRollCount
        );

        reRollCount =
        reRollCount + 1;

        // emit event
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

        require(
            nextLevel < maxUpgradeLevel,
            'iceRegistrant: invalid level'
        );

        _takePayment(
            tokenOwner,
            levels[nextLevel].costAmountDG,
            levels[nextLevel].costAmountICE
        );

        registrer[tokenOwner][tokenHash].level = nextLevel;
        registrer[tokenOwner][tokenHash].bonus = getNumber(
            levels[nextLevel].minBonus,
            levels[nextLevel].maxBonus,
            upgradeCount,
            block.timestamp
        );

        upgradeCount =
        upgradeCount + 1;

        emit TokenUpgrade(
            tokenOwner,
            _tokenAddress,
            _tokenId,
            nextLevel
        );
    }

    function _takePayment(
        address _payer,
        uint256 _dgAmount,
        uint256 _iceAmount
    )
        internal
    {
        safeTransferFrom(
            tokenAddressDG,
            _payer,
            depositAddress,
            _dgAmount
        );

        safeTransferFrom(
            tokenAddressICE,
            _payer,
            address(this),
            _iceAmount
        );

        ERC20 iceToken = ERC20(tokenAddressICE);
        iceToken.burn(_iceAmount);

        // emit event
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

        //emit event

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

        _takePayment(
            tokenOwner,
            levels[maxUpgradeLevel].costAmountDG,
            levels[maxUpgradeLevel].costAmountICE
        );

        // return or not to return original token (DEBATE)
        ERC721(tokenAddress).transferFrom(
            address(this),
            depositAddress, // change where to send exactly (onlyCEO can decide)
            tokenId
        );

        bytes32 newHash = getHash(
            _newTokenAddress,
            _newTokenId
        );

        registrer[tokenOwner][newHash].level = maxUpgradeLevel;
        registrer[tokenOwner][newHash].bonus = getNumber(
            levels[maxUpgradeLevel].minBonus,
            levels[maxUpgradeLevel].maxBonus,
            upgradeCount,
            block.timestamp
        );

        upgradeCount =
        upgradeCount + 1;

        // issue new tokens upgraded to level5
        ERC721(_newTokenAddress).transferFrom(
            address(this),
            tokenOwner,
            _newTokenId
        );
        // event
    }

    function delegateToken(
        address _tokenAddress,
        uint256 _tokenId,
        address _delegateAddress,
        uint256 _delegatePercent
    )
        external
    {
        require(
            _delegatePercent <= 100,
            'iceRegistrant: invalid percent'
        );

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
