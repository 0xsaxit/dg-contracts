// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

import "./common-contracts/SafeMath.sol";
import "./common-contracts/AccessController.sol";
import "./common-contracts/ERC20Token.sol";

contract dgPointer is AccessController {

    using SafeMath for uint256;

    modifier onlyDeclaredContracts() {
        require(
            declaredContracts[msg.sender] == true,
            'dgPointer: unauthorized call!'
        );
        _;
    }

    ERC20Token public distributionToken;

    constructor(address _distributionToken) {
        distributionToken = ERC20Token(_distributionToken);
    }

    mapping(address => bool) declaredContracts;
    mapping(address => uint256) pointsBalancer;

    function addPoints(address _player, uint256 _points) external onlyDeclaredContracts returns (bool) {
        pointsBalancer[_player] = pointsBalancer[_player].add(_points);
        return true;
    }

    function getMyTokens() external returns(uint256 tokenAmount) {
        return distributeTokens(msg.sender);
    }

    function distributeTokens(address _player) public returns (uint256 tokenAmount) {
        tokenAmount = pointsBalancer[_player];
        pointsBalancer[_player] = 0;
        distributionToken.transfer(_player, tokenAmount);
    }

    function declareContract(address _contract) external onlyCEO returns(bool) {
        declaredContracts[_contract] = true;
    }

    function unDeclareContract(address _contract) external onlyCEO returns(bool) {
        declaredContracts[_contract] = false;
    }
}