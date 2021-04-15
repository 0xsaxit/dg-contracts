// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.4;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, 'SafeMath: addition overflow');
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, 'SafeMath: subtraction overflow');
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, 'SafeMath: multiplication overflow');
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, 'SafeMath: division by zero');
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, 'SafeMath: modulo by zero');
        return a % b;
    }
}

contract AccessController {

    address public ceoAddress;

    bool public paused = false;

    mapping (address => bool) public isWorker;

    event CEOSet(
        address newCEO
    );

    event WorkerAdded(
        address newWorker
    );

    event WorkerRemoved(
        address existingWorker
    );

    event Paused();
    event Unpaused();

    constructor() {

        address creator = msg.sender;

        ceoAddress = creator;

        isWorker[creator] = true;

        emit CEOSet(
            creator
        );

        emit WorkerAdded(
            creator
        );
    }

    modifier onlyCEO() {
        require(
            msg.sender == ceoAddress,
            'AccessControl: CEO access denied'
        );
        _;
    }

    modifier onlyWorker() {
        require(
            isWorker[msg.sender] == true,
            'AccessControl: worker access denied'
        );
        _;
    }

    modifier nonZeroAddress(address checkingAddress) {
        require(
            checkingAddress != address(0x0),
            'AccessControl: invalid address'
        );
        _;
    }

    modifier whenNotPaused() {
        require(
            !paused,
            'AccessControl: currently paused'
        );
        _;
    }

    modifier whenPaused {
        require(
            paused,
            'AccessControl: currenlty not paused'
        );
        _;
    }

    function setCEO(
        address _newCEO
    )
        external
        nonZeroAddress(_newCEO)
        onlyCEO
    {
        ceoAddress = _newCEO;

        emit CEOSet(
            ceoAddress
        );
    }

    function addWorker(
        address _newWorker
    )
        external
        onlyCEO
    {
        _addWorker(
            _newWorker
        );
    }

    function addWorkerBulk(
        address[] calldata _newWorkers
    )
        external
        onlyCEO
    {
        for (uint8 index = 0; index < _newWorkers.length; index++) {
            _addWorker(_newWorkers[index]);
        }
    }

    function _addWorker(
        address _newWorker
    )
        internal
        nonZeroAddress(_newWorker)
    {
        require(
            isWorker[_newWorker] == false,
            'AccessControl: worker already exist'
        );

        isWorker[_newWorker] = true;

        emit WorkerAdded(
            _newWorker
        );
    }

    function removeWorker(
        address _existingWorker
    )
        external
        onlyCEO
    {
        _removeWorker(
            _existingWorker
        );
    }

    function removeWorkerBulk(
        address[] calldata _workerArray
    )
        external
        onlyCEO
    {
        for (uint8 index = 0; index < _workerArray.length; index++) {
            _removeWorker(_workerArray[index]);
        }
    }

    function _removeWorker(
        address _existingWorker
    )
        internal
        nonZeroAddress(_existingWorker)
    {
        require(
            isWorker[_existingWorker] == true,
            "AccessControl: worker not detected"
        );

        isWorker[_existingWorker] = false;

        emit WorkerRemoved(
            _existingWorker
        );
    }

    function pause()
        external
        onlyWorker
        whenNotPaused
    {
        paused = true;
        emit Paused();
    }

    function unpause()
        external
        onlyCEO
        whenPaused
    {
        paused = false;
        emit Unpaused();
    }
}

interface ERC20Token {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract EIP712Base {

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));

    bytes32 internal domainSeperator;

    constructor(string memory name, string memory version) {
      domainSeperator = keccak256(abi.encode(
			EIP712_DOMAIN_TYPEHASH,
			keccak256(bytes(name)),
			keccak256(bytes(version)),
			getChainID(),
			address(this)
		));
    }

    function getChainID() internal pure returns (uint256 id) {
		assembly {
			id := 1 // set to Goerli for now, Mainnet later
		}
	}

    function getDomainSeperator() private view returns(bytes32) {
		return domainSeperator;
	}

    /**
    * Accept message hash and returns hash message in EIP712 compatible form
    * So that it can be used to recover signer from signature signed using EIP712 formatted data
    * https://eips.ethereum.org/EIPS/eip-712
    * "\\x19" makes the encoding deterministic
    * "\\x01" is the version byte to make it compatible to EIP-191
    */
    function toTypedMessageHash(bytes32 messageHash) internal view returns(bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", getDomainSeperator(), messageHash));
    }

}

contract TransferHelper {

    bytes4 private constant TRANSFER = bytes4(
        keccak256(
            bytes(
                'transfer(address,uint256)' // 0xa9059cbb
            )
        )
    );

    bytes4 private constant TRANSFER_FROM = bytes4(
        keccak256(
            bytes(
                'transferFrom(address,address,uint256)' // 0x23b872dd
            )
        )
    );

    function safeTransfer(
        address _token,
        address _to,
        uint256 _value
    )
        internal
    {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(
                TRANSFER, // 0xa9059cbb
                _to,
                _value
            )
        );

        require(
            success && (
                data.length == 0 || abi.decode(
                    data, (bool)
                )
            ),
            'TransferHelper: TRANSFER_FAILED'
        );
    }

    function safeTransferFrom(
        address _token,
        address _from,
        address _to,
        uint _value
    )
        internal
    {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(
                TRANSFER_FROM,
                _from,
                _to,
                _value
            )
        );

        require(
            success && (
                data.length == 0 || abi.decode(
                    data, (bool)
                )
            ),
            'TransferHelper: TRANSFER_FROM_FAILED'
        );
    }

}

abstract contract EIP712MetaTransactionForPointer is EIP712Base {

    using SafeMath for uint256;

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
	    nonces[userAddress].add(1);

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
            msg.sender,
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

    function getNonce(
        address user
    )
        external
        view
        returns(uint256 nonce)
    {
        nonce = nonces[user];
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

interface OldPointer {
    function affiliateData(
        address player
    )
        external
        view
        returns (address);
}

contract dgPointer is AccessController, TransferHelper, EIP712MetaTransactionForPointer {

    using SafeMath for uint256;

    address constant ZERO_ADDRESS = address(0x0);

    uint256 public defaultPlayerBonus = 30;
    uint256 public defaultWearableBonus = 40;

    bool public collectingEnabled;
    bool public distributionEnabled;

    // should be DG token address
    address public immutable distributionToken;

    // stores addresses that allowed to addPoints
    mapping(address => bool) public declaredContracts;

    // stores amount that address can withdraw for specific token (player > payoutToken > amount )
    mapping(address => mapping(address => uint256)) public pointsBalancer;

    // stores ratio between input token to output token for each game (game > inputToken > outputToken)
    mapping(address => mapping(address => mapping(address => uint256))) public tokenToPointRatio;

    mapping(uint256 => uint256) public playerBonuses;
    mapping(uint256 => uint256) public wearableBonuses;

    mapping(address => address) public affiliateData;
    mapping(address => uint256) public affiliateCounts;

    mapping(address => mapping(uint256 => address)) public affiliatePlayer;
    mapping(address => mapping(address => uint256)) public affiliateProfit;
    mapping(address => mapping(address => uint256)) public affiliateHistoryProfit;

    OldPointer public immutable oldPointer;

    uint256 public affiliateBonus;
    uint256 public wearableBonusPerObject;

    event UpdatedPlayerBonus(
        uint256 indexed playersCount,
        uint256 indexed newBonus
    );

    event UpdatedAffiliateBonus(
        uint256 indexed newBonus
    );

    event UpdatedMaxPlayerBonus(
        uint256 indexed newBonus
    );

    event AffiliateAssigned(
        address indexed affiliate,
        address indexed player,
        uint256 indexed count
    );

    event ProfitAdded(
        address indexed affiliate,
        address indexed player,
        uint256 indexed points,
        uint256 total
    );

    event PointsAdded(
        address indexed affiliate,
        address indexed player,
        uint256 indexed points,
        uint256 total
    );

    constructor(
        address _distributionToken,
        address _oldPointerAddress,
        string memory name,
        string memory version
    ) EIP712Base(name, version) {

        distributionToken = (
            _distributionToken
        );

        affiliateBonus = 100;

        playerBonuses[2] = 10;
        playerBonuses[3] = 20;
        playerBonuses[4] = 30;

        wearableBonuses[1] = 10;
        wearableBonuses[2] = 20;
        wearableBonuses[3] = 30;
        wearableBonuses[4] = 40;

        oldPointer = OldPointer(
            _oldPointerAddress
        );
    }

    function assignAffiliate(
        address _affiliate,
        address _player
    )
        external
        onlyWorker
    {
        require(
            _affiliate != _player,
            'Pointer: self-referral'
        );

        _checkAffiliatesInOldPointer(
            _player
        );

        require(
            affiliateData[_player] == ZERO_ADDRESS,
            'Pointer: player already affiliated'
        );

        affiliateData[_player] = _affiliate;

        affiliateCounts[_affiliate] =
        affiliateCounts[_affiliate] + 1;

        uint256 affiliateNonce =
        affiliateCounts[_affiliate];
        affiliatePlayer[_affiliate][affiliateNonce] = _player;

        emit AffiliateAssigned(
            _affiliate,
            _player,
            affiliateNonce
        );
    }

    function addPoints(
        address _player,
        uint256 _points,
        address _token
    )
        external
        returns (
            uint256 newPoints,
            uint256 multiplierA,
            uint256 multiplierB
        )
    {
        return addPoints(
            _player,
            _points,
            _token,
            1,
            0
        );
    }

    function addPoints(
        address _player,
        uint256 _points,
        address _token,
        uint256 _playersCount
    )
        public
        returns (
            uint256 newPoints,
            uint256 multiplier,
            uint256 multiplierB
        )
    {
        return addPoints(
            _player,
            _points,
            _token,
            _playersCount,
            0
        );
    }

    function decimalDiff(
        address _tokenFrom,
        address _tokenTo
    )
        public
        returns (uint256, bool)
    {
        uint8 tokenFromDecimals = ERC20Token(_tokenFrom).decimals();
        uint8 tokenToDecimals = ERC20Token(_tokenTo).decimals();

        bool reverseOrder = tokenFromDecimals > tokenToDecimals;

        uint256 differenceCount = reverseOrder
            ? ERC20Token(_tokenFrom).decimals() - ERC20Token(_tokenTo).decimals()
            : ERC20Token(_tokenTo).decimals() - ERC20Token(_tokenFrom).decimals();

        return (differenceCount, reverseOrder);
    }

    function addPoints(
        address _player,
        uint256 _points,
        address _token,
        uint256 _playersCount,
        uint256 _wearablesCount
    )
        public
        returns (
            uint256 playerPoints,
            uint256 multiplierA,
            uint256 multiplierB
        )
    {
        require(
            _playersCount > 0,
            'dgPointer: _playersCount error'
        );

        if (_isDeclaredContract(msg.sender) && collectingEnabled) {

            multiplierA = getPlayerMultiplier(
                _playersCount,
                playerBonuses[_playersCount],
                defaultPlayerBonus
            );

            multiplierB = getWearableMultiplier(
                _wearablesCount,
                wearableBonuses[_wearablesCount],
                defaultWearableBonus
            );

            (uint256 diff, bool reverse) = decimalDiff(
                _token,
                distributionToken
            );

            playerPoints = _calculatePoints(
                _points,
                tokenToPointRatio[msg.sender][_token][distributionToken],
                diff,
                reverse,
                multiplierA,
                multiplierB
            );

            pointsBalancer[_player][distributionToken] =
            pointsBalancer[_player][distributionToken].add(playerPoints);

            _applyAffiliatePoints(
                _player,
                _token,
                _points,
                multiplierA,
                multiplierB
            );
        }
    }

    function _applyAffiliatePoints(
        address _player,
        address _token,
        uint256 _points,
        uint256 _multiplierA,
        uint256 _multiplierB
    )
        internal
    {
        _checkAffiliatesInOldPointer(
            _player
        );

        if (_isAffiliated(_player)) {

            address affiliate = affiliateData[_player];
            uint256 points = _calculatePoints(
                _points,
                tokenToPointRatio[msg.sender][_token][_token],
                0,
                false,
                _multiplierA,
                _multiplierB
            );

            uint256 pointsToAdd = points
                .mul(affiliateBonus)
                .div(100);

            affiliateProfit[_player][_token] =
            affiliateProfit[_player][_token].add(pointsToAdd);

            emit ProfitAdded(
                affiliate,
                _player,
                pointsToAdd,
                affiliateProfit[_player][_token]
            );

            pointsBalancer[affiliate][_token] =
            pointsBalancer[affiliate][_token].add(pointsToAdd);

            affiliateHistoryProfit[affiliate][_token] =
            affiliateHistoryProfit[affiliate][_token].add(pointsToAdd);

            emit PointsAdded(
                affiliate,
                _player,
                pointsToAdd,
                pointsBalancer[affiliate][_token]
            );
        }
    }

    function profitPagination(
        address _affiliate,
        address _token,
        uint256 _offset,
        uint256 _length
    )
        external
        view
        returns (
            uint256[] memory _profits,
            address[] memory _players
        )
    {
        uint256 start = _offset > 0 &&
            affiliateCounts[_affiliate] > _offset ?
            affiliateCounts[_affiliate] - _offset : affiliateCounts[_affiliate];

        uint256 finish = _length > 0 &&
            start > _length ?
            start - _length : 0;

        uint256 i;

        _players = new address[](start - finish);
        _profits = new uint256[](start - finish);

        for (uint256 _playerIndex = start; _playerIndex > finish; _playerIndex--) {
            address player = affiliatePlayer[_affiliate][_playerIndex];
            if (player != address(0x0)) {
                _players[i] = player;
                _profits[i] = affiliateProfit[player][_token];
                i++;
            }
        }
    }

    function _calculatePoints(
        uint256 _points,
        uint256 _ratio,
        uint256 _diff,
        bool _reverse,
        uint256 _multiplierA,
        uint256 _multiplierB
    )
        public
        pure
        returns (uint256)
    {
        uint256 pointsBase = _reverse
            ? _points.div(10 ** _diff)
            : _points.mul(10 ** _diff);

        return pointsBase
            .div(_ratio)
            .mul(uint256(100)
                .add(_multiplierA)
                .add(_multiplierB)
            )
            .div(100);
    }

    function getPlayerMultiplier(
        uint256 _playerCount,
        uint256 _playerBonus,
        uint256 _defaultPlayerBonus

    )
        internal
        pure
        returns (uint256)
    {
        if (_playerCount == 1) return 0;
        return _playerCount > 0 && _playerBonus == 0
            ? _defaultPlayerBonus
            : _playerBonus;
    }

    function getWearableMultiplier(
        uint256 _wearableCount,
        uint256 _wearableBonus,
        uint256 _defaultWearableBonus
    )
        internal
        pure
        returns (uint256)
    {
        return _wearableCount > 0 && _wearableBonus == 0
            ? _defaultWearableBonus
            : _wearableBonus;
    }

    function _checkAffiliatesInOldPointer(
        address _player
    )
        internal
    {
        if (address(oldPointer) != ZERO_ADDRESS) {

            address affiliate = oldPointer.affiliateData(
                _player
            );

            if (
                affiliate != ZERO_ADDRESS &&
                affiliateData[_player] == ZERO_ADDRESS
            ) {
                affiliateData[_player] = affiliate;
            }
        }
    }

    function _isAffiliated(
        address _player
    )
        internal
        view
        returns (bool)
    {
        return affiliateData[_player] != ZERO_ADDRESS;
    }

    function distributeAllTokens(
        address _player,
        address[] calldata _token
    )
        external
    {
        for (uint8 _tokenIndex = 0; _tokenIndex < _token.length; _tokenIndex++) {
            _distributePayout(
                _player,
                _token[_tokenIndex]
            );
        }
    }

    function distributeTokensForAffiliate(
        address _affiliate,
        address _token
    )
        external
    {
        _distributePayout(
            _affiliate,
            _token
        );
    }

    function _distributePayout(
        address _payoutAddress,
        address _payoutToken
    )
        internal
        returns (uint256 tokenAmount)
    {
        require(
            distributionEnabled == true,
            'Pointer: distribution disabled'
        );

        tokenAmount = pointsBalancer[_payoutAddress][_payoutToken];
        pointsBalancer[_payoutAddress][_payoutToken] = 0;

        safeTransfer(
            _payoutToken,
            _payoutAddress,
            tokenAmount
        );
    }

    function distributeTokensForPlayer(
        address _player
    )
        external
        returns (uint256)
    {
        return _distributePayout(
            _player,
            distributionToken
        );
    }

    function changeAffiliateBonus(
        uint256 _newAffiliateBonus
    )
        external
        onlyCEO
    {
        affiliateBonus = _newAffiliateBonus;

        emit UpdatedAffiliateBonus(
            _newAffiliateBonus
        );
    }

    function changePlayerBonus(
        uint256 _bonusIndex,
        uint256 _newBonus
    )
        external
        onlyCEO
    {
        playerBonuses[_bonusIndex] = _newBonus;

        emit UpdatedPlayerBonus(
            _bonusIndex,
            playerBonuses[_bonusIndex]
        );
    }

    function changeDefaultPlayerBonus(
        uint256 _newDefaultPlayerBonus
    )
        external
        onlyCEO
    {
        defaultPlayerBonus = _newDefaultPlayerBonus;

        emit UpdatedMaxPlayerBonus(
            defaultPlayerBonus
        );
    }

    function changeMaxWearableBonus(
        uint256 _newMaxWearableBonus
    )
        external
        onlyCEO
    {
        defaultWearableBonus = _newMaxWearableBonus;
    }

    function setTokenToPointRatio(
        address _game,
        address _tokenIn,
        address _tokenOut,
        uint256 _ratio
    )
        external
        onlyCEO
    {
        tokenToPointRatio[_game][_tokenIn][_tokenOut] = _ratio;
    }

    function enableCollecting(
        bool _state
    )
        external
        onlyCEO
    {
        collectingEnabled = _state;
    }

    function enableDistribtion(
        bool _state
    )
        external
        onlyCEO
    {
        distributionEnabled = _state;
    }

    function declareContract(
        address _contract
    )
        external
        onlyCEO
    {
        declaredContracts[_contract] = true;
    }

    function unDeclareContract(
        address _contract
    )
        external
        onlyCEO
    {
        declaredContracts[_contract] = false;
    }

    function _isDeclaredContract(
        address _contract
    )
        internal
        view
        returns (bool)
    {
        return declaredContracts[_contract];
    }
}