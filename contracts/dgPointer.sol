// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

import "./common-contracts/SafeMath.sol";
import "./common-contracts/AccessController.sol";
import "./common-contracts/ERC20Token.sol";
import "./common-contracts/EIP712Base.sol";

abstract contract ExecuteMetaTransaction is EIP712Base {

    using SafeMath for uint256;

    event MetaTransactionExecuted(
        address userAddress,
        address payable relayerAddress,
        bytes functionSignature
    );

    bytes32 internal constant META_TRANSACTION_TYPEHASH = keccak256(
        bytes(
            "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
        )
    );

    mapping(address => uint256) internal nonces;

    struct MetaTransaction {
		uint256 nonce;
		address from;
        bytes functionSignature;
	}

    function getNonce(
        address user
    )
        public
        view
        returns(uint256 nonce)
    {
        nonce = nonces[user];
    }

    function verify(
        address signer,
        MetaTransaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        return
            signer ==
            ecrecover(
                toTypedMessageHash(hashMetaTransaction(metaTx)),
                sigV,
                sigR,
                sigS
            );
    }

    function hashMetaTransaction(MetaTransaction memory metaTx)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    metaTx.nonce,
                    metaTx.from,
                    keccak256(metaTx.functionSignature)
                )
            );
    }

    function msgSender()
        internal
        view
        returns(address sender)
    {
        if (msg.sender == address(this)) {

            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }

        } else {

            sender = msg.sender;

        }
        return sender;
    }

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) public returns (bytes memory) {

        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[userAddress],
            from: userAddress,
            functionSignature: functionSignature
        });

        require(
            verify(userAddress, metaTx, sigR, sigS, sigV),
            'Signer and signature do not match'
        );

        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(
                functionSignature,
                userAddress,
                msg.sender
            )
        );

        require(
            success,
            'dgPointer: Function call not successfull'
        );

        nonces[userAddress] =
        nonces[userAddress] + 1;

        emit MetaTransactionExecuted(
            userAddress,
            msg.sender,
            functionSignature
        );

        return returnData;
    }
}

contract dgPointer is AccessController, ExecuteMetaTransaction {

    using SafeMath for uint256;

    uint256 public MAX_PLAYER_BONUS = 130;
    uint256 constant MIN_PLAYER_BONUS = 100;
    uint256 public MAX_WEARABLE_BONUS = 40;

    bool public collectingEnabled;
    bool public distributionEnabled;

    ERC20Token public distributionToken;

    mapping(address => bool) public declaredContracts;
    mapping(address => uint256) public pointsBalancer;
    mapping(address => mapping(address => uint256)) public tokenToPointRatio;
    mapping(uint256 => uint256) public playerBonuses;
    mapping(uint256 => uint256) public wearableBonuses;
    mapping(address => address) public affiliateData;

    uint256 public affiliateBonus;
    uint256 public wearableBonusPerObject;

    event updatedPlayerBonus(
        uint256 numPlayers,
        uint256 newBonus
    );

    event updatedAffiliateBonus(
        uint256 newBonus
    );

    event updatedMaxPlayerBonus(
        uint256 newBonus
    );

    constructor(
        address _distributionToken,
        string memory name,
        string memory version
    ) EIP712Base(name, version) {

        distributionToken = ERC20Token(
            _distributionToken
        );

        affiliateBonus = 10;

        playerBonuses[2] = 10;
        playerBonuses[3] = 20;
        playerBonuses[4] = 30;

        wearableBonuses[1] = 10;
        wearableBonuses[2] = 20;
        wearableBonuses[3] = 30;
        wearableBonuses[4] = 40;
    }

    function assignAffiliate(
        address _affiliate,
        address _player
    )
        external
        onlyWorker
        returns (bool)
    {
        require(
            affiliateData[_player] == address(0x0),
            'Pointer: player already affiliated'
        );
        affiliateData[_player] = _affiliate;
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
        uint256 _numPlayers
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
            _numPlayers,
            0
        );
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
            uint256 newPoints,
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
                MAX_PLAYER_BONUS
            );

            multiplierB = getWearableMultiplier(
                _wearablesCount,
                wearableBonuses[_wearablesCount],
                MAX_WEARABLE_BONUS
            );

            newPoints = _points
                .div(tokenToPointRatio[msg.sender][_token])
                .mul(multiplierA.add(multiplierB))
                .div(100);

            pointsBalancer[_player] =
            pointsBalancer[_player].add(newPoints);

            _applyAffiliatePoints(
                _player,
                newPoints
            );
        }
    }

    function _applyAffiliatePoints(
        address _player,
        uint256 _points
    )
        internal
    {
        if (_isAffiliated(_player)) {
            pointsBalancer[affiliateData[_player]] =
            pointsBalancer[affiliateData[_player]] + _points
                .mul(affiliateBonus)
                .div(100);
        }
    }

    function getPlayerMultiplier(
        uint256 _playerCount,
        uint256 _playerBonus,
        uint256 _maxPlayerBonus

    )
        internal
        pure
        returns (uint256)
    {
        if (_playerCount == 1) return MIN_PLAYER_BONUS;
        return _playerCount > 0 && _playerBonus == 0
            ? _maxPlayerBonus
            : MIN_PLAYER_BONUS.add(_playerBonus);
    }

    function getWearableMultiplier(
        uint256 _wearableCount,
        uint256 _wearableBonus,
        uint256 _maxWearableBonus
    )
        internal
        pure
        returns (uint256)
    {
        return _wearableCount > 0 && _wearableBonus == 0
            ? _maxWearableBonus
            : _wearableBonus;
    }

    function _isAffiliated(
        address _player
    )
        internal
        view
        returns (bool)
    {
        return affiliateData[_player] != address(0x0);
    }

    function getMyTokens()
        external
        returns(uint256 tokenAmount)
    {
        return distributeTokens(msg.sender);
    }

    function distributeTokensBulk(
        address[] memory _player
    )
        external
    {
        for(uint i = 0; i < _player.length; i++) {
            distributeTokens(_player[i]);
        }
    }

    function distributeTokens(
        address _player
    )
        public
        returns (uint256 tokenAmount)
    {
        require(
            distributionEnabled == true,
            'Pointer: distribution disabled'
        );
        tokenAmount = pointsBalancer[_player];
        pointsBalancer[_player] = 0;
        distributionToken.transfer(_player, tokenAmount);
    }

    function changePlayerBonus(uint256 _bonusIndex, uint256 _newBonus)
        external
        onlyCEO
    {
        playerBonuses[_bonusIndex] = _newBonus;

        emit updatedPlayerBonus(
          _bonusIndex,
          playerBonuses[_bonusIndex]
        );
    }

    function changeAffiliateBonus(uint256 _newAffiliateBonus)
        external
        onlyCEO
    {
        affiliateBonus = _newAffiliateBonus;

        emit updatedAffiliateBonus(
            _newAffiliateBonus
        );
    }

    function changeMaxPlayerBonus(
        uint256 _newMaxPlayerBonus
    )
        external
        onlyCEO
    {
        MAX_PLAYER_BONUS =
        MIN_PLAYER_BONUS + _newMaxPlayerBonus;

        emit updatedMaxPlayerBonus(
            MAX_PLAYER_BONUS
        );
    }

    function changeMaxWearableBonus(
        uint256 _newMaxWearableBonus
    )
        external
        onlyCEO
    {
        MAX_WEARABLE_BONUS = _newMaxWearableBonus;
    }

    function changeDistributionToken(
        address _newDistributionToken
    )
        external
        onlyCEO
    {
        distributionToken = ERC20Token(
            _newDistributionToken
        );
    }

    function setPointToTokenRatio(
        address _token,
        address _gameAddress,
        uint256 _ratio
    )
        external
        onlyCEO
    {
        tokenToPointRatio[_gameAddress][_token] = _ratio;
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
        returns(bool)
    {
        declaredContracts[_contract] = true;
    }

    function unDeclareContract(
        address _contract
    )
        external
        onlyCEO
        returns(bool)
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