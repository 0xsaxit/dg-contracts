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

    bytes32 private constant META_TRANSACTION_TYPEHASH = keccak256(
        bytes(
            "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
        )
    );

    mapping(address => uint256) private nonces;
    
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

    constructor(string memory name, string memory version) public EIP712Base(name, version) {}

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
            "Signer and signature do not match"
        );

        // Append userAddress and relayer address at the end to extract it from calling context
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(functionSignature, userAddress, msg.sender)
        );

        require(success, "dgPointer: Function call not successfull");
        nonces[userAddress] = nonces[userAddress] + 1;

        emit MetaTransactionExecuted(
            userAddress,
            msg.sender,
            functionSignature
        );

        return returnData;
    }

    function getNonce(address user) public view returns(uint256 nonce) {
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

contract dgPointer is AccessController, ExecuteMetaTransaction {

    using SafeMath for uint256;

    uint256 constant MAX_BONUS = 140;
    uint256 constant MIN_BONUS = 100;

    bool public collectingEnabled;
    bool public distributionEnabled;

    ERC20Token public distributionToken;

    mapping(address => bool) public declaredContracts;
    mapping(address => uint256) public pointsBalancer;
    mapping(address => uint256) public tokenToPointRatio;
    mapping(address => address) public affiliateData;

    constructor(address _distributionToken) {
        distributionToken = ERC20Token(_distributionToken);
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
        returns (uint256 newPoints, uint256 multiplier)
    {
        return addPoints(
            _player,
            _points,
            _token,
            1
        );
    }

    function addPoints(
        address _player,
        uint256 _points,
        address _token,
        uint256 _numPlayers
    )
        public
        returns (uint256 newPoints, uint256 multiplier)
    {
      if (_isDeclaredContract(msg.sender) && collectingEnabled) {

            multiplier = getBonusMultiplier(_numPlayers);

            newPoints = _points
                .div(tokenToPointRatio[_token])
                .mul(multiplier)
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
            pointsBalancer[affiliateData[_player]] = _points.mul(20).div(100);
        }
    }

    function getBonusMultiplier(
        uint256 numPlayers
    )
        internal
        pure
        returns (uint256)
    {
        if (numPlayers == 1) return MIN_BONUS;
        return numPlayers > 4
            ? MAX_BONUS
            : MIN_BONUS.add(numPlayers.mul(10));
    }

    function _isAffiliated(address _player) internal view returns (bool) {
        return affiliateData[_player] != address(0x0);
    }

    function getMyTokens() external returns(uint256 tokenAmount) {
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
            'Pointer: distribution paused'
        );
        tokenAmount = pointsBalancer[_player];
        pointsBalancer[_player] = 0;
        distributionToken.transfer(_player, tokenAmount);
    }

    // can be removed on mainnet - for easier testing
    function changeDistributionToken(address _newDistributionToken) external onlyCEO {
        distributionToken = ERC20Token(_newDistributionToken);
    }

    function setPointToTokenRatio(address _token, uint256 _ratio) external onlyCEO {
        tokenToPointRatio[_token] = _ratio;
    }

    function enableCollecting(bool _state) external onlyCEO {
        collectingEnabled = _state;
    }

    function enableDistribtion(bool _state) external onlyCEO {
        distributionEnabled = _state;
    }

    function declareContract(address _contract) external onlyCEO returns(bool) {
        declaredContracts[_contract] = true;
    }

    function unDeclareContract(address _contract) external onlyCEO returns(bool) {
        declaredContracts[_contract] = false;
    }

    function _isDeclaredContract(address _contract) internal view returns (bool) {
        return declaredContracts[_contract];
    }
}