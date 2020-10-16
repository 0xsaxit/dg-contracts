// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

import "./common-contracts/AccessController.sol";
import "./common-contracts/ERC20Token.sol";

contract dgAirdrop is AccessController {

    bool public distributionEnabled;
    ERC20Token public distributionToken;

    mapping(address => uint256) public airdropBalance;

    constructor(address _distributionToken) {
        distributionToken = ERC20Token(_distributionToken);
    }

    function allocateTokensBulk(
        address[] memory _recipients,
        uint256[] memory _tokens
    )
        external
        onlyWorker
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allocateTokens(_recipients[i], _tokens[i]);
        }
    }

    function allocateTokens(
        address _recipient,
        uint256 _tokens
    )
        public
        onlyWorker
    {
        airdropBalance[_recipient] = _tokens;
    }

    function getMyTokens() external returns(uint256 tokenAmount) {
        return distributeTokens(msg.sender);
    }

    function distributeTokensBulk(
        address[] memory _recipients
    )
        external
    {
        for(uint i = 0; i < _recipients.length; i++) {
            distributeTokens(_recipients[i]);
        }
    }

    function distributeTokens(
        address _recipient
    )
        public
        returns (uint256 tokenAmount)
    {
        require(
            distributionEnabled == true,
            'Airdrop: distribution disabled'
        );
        tokenAmount = airdropBalance[_recipient];
        airdropBalance[_recipient] = 0;
        distributionToken.transfer(_recipient, tokenAmount);
    }

    function changeDistributionToken(address _newDistributionToken) external onlyCEO {
        distributionToken = ERC20Token(_newDistributionToken);
    }

    function enableDistribtion(bool _state) external onlyCEO {
        distributionEnabled = _state;
    }

    function withdrawTokens(uint256 _amount) external onlyCEO {
        distributionToken.transfer(msg.sender, _amount);
    }
}