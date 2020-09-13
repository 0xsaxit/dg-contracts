// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

import "./common-contracts/SafeMath.sol";
import "./common-contracts/AccessController.sol";
import "./common-contracts/ERC20Token.sol";

contract dgPointer is AccessController {

    using SafeMath for uint256;

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
      if (_isDeclaredContract(msg.sender)) {

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

    uint256 constant MAX_BONUS = 140;
    uint256 constant MIN_BONUS = 100;

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
        tokenAmount = pointsBalancer[_player];
        pointsBalancer[_player] = 0;
        distributionToken.transfer(_player, tokenAmount);
    }

    function setPointToTokenRatio(address _token, uint256 _ratio) external onlyCEO {
        tokenToPointRatio[_token] = _ratio;
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