// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.4;

import "./common-contracts/AccessController.sol";
import "./common-contracts/ERC20Token.sol";
import "./common-contracts/SafeMath.sol";

contract dgKeeper is AccessController {

    using SafeMath for uint256;

    ERC20Token public distributionToken;

    mapping(address => uint256) public keeperRate;
    mapping(address => uint256) public keeperDate;
    mapping(address => uint256) public keeperBalance;
    mapping(address => uint256) public keeperPayouts;

    constructor(address _distributionToken) {
        distributionToken = ERC20Token(
            _distributionToken
        );
    }

    function allocateTokensBulk(
        address[] memory _recipients,
        uint256[] memory _tokensOpened,
        uint256[] memory _tokensLocked,
        uint256[] memory _timeFrame
    )
        external
        onlyWorker
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allocateTokens(
                _recipients[i],
                _tokensOpened[i],
                _tokensLocked[i],
                _timeFrame[i]
            );
        }
    }

    function allocateTokens(
        address _recipient,
        uint256 _tokensOpened,
        uint256 _tokensLocked,
        uint256 _timeFrame
    )
        public
        onlyWorker
    {
        require(
            _timeFrame > 0,
            'dgKeeper: undefined timeFrame'
        );

        keeperDate[_recipient] = getNow();
        keeperRate[_recipient] = _tokensLocked.div(_timeFrame);
        keeperBalance[_recipient] = _tokensOpened;
    }

    function scrapeTokens()
        public
    {
        uint256 _availableBalance =
        availableBalance(msg.sender);

        keeperPayouts[msg.sender] =
        keeperPayouts[msg.sender].add(_availableBalance);

        if (keeperBalance[msg.sender] > 0) {
            keeperBalance[msg.sender] = 0;
        }

        ERC20Token t = ERC20Token(distributionToken);
        t.transfer(msg.sender, _availableBalance);
    }

    function availableBalance(address _user)
        public
        view
        returns (uint256 rewardAvailable)
    {
        uint256 timePassed = getNow().sub(keeperDate[_user]);
        rewardAvailable = keeperRate[_user]
            .mul(timePassed)
            .add(keeperBalance[_user])
            .sub(keeperPayouts[_user]);
    }

    function getNow()
        public
        view
        returns (uint256)
    {
        return block.timestamp;
    }

    // for testing (consider removing)
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
}