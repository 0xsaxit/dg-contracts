// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

import "./common-contracts/SafeMath.sol";
import "./common-contracts/AccessController.sol";
import "./common-contracts/ERC20Token.sol";

contract dgPointer is AccessController {

    using SafeMath for uint256;

    ERC20Token public distributionToken;

    mapping(address => bool) declaredContracts;
    mapping(address => uint256) pointsBalancer;
    mapping(address => uint256) tokenToPointRatio;
    mapping(address => address) affiliateData;

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
        address _token,
        uint256 _multiplier
    )
        external
        returns (uint256 newPoints)
    {
        if (_isDeclaredContract(msg.sender)) {

            newPoints = _points
                .div(tokenToPointRatio[_token])
                .mul(_multiplier)
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
        if (isAffiliated(_player)) {
            pointsBalancer[affiliateData[_player]] = _points.mul(20).div(100);
        }
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