// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.4;

import "./common-contracts/SafeMath.sol";

contract dgKeeper {

    using SafeMath for uint256;

    address public gateKeeper;
    address public distributionToken;

    mapping(address => uint256) public keeperRate;
    mapping(address => uint256) public keeperFrom;
    mapping(address => uint256) public keeperTill;
    mapping(address => uint256) public keeperBalance;
    mapping(address => uint256) public keeperPayouts;

    mapping(address => bool) public isImmutable;

    modifier onlyGateKeeper() {
        require(
            msg.sender == gateKeeper,
            'dgKeeper: access denied!'
        );
        _;
    }

    event tokensScraped (
        address indexed scraper,
        uint256 scrapedAmount,
        uint256 timestamp
    );

    constructor(address _distributionToken) {
        distributionToken = _distributionToken;
        gateKeeper = msg.sender;
    }

    function allocateTokensBulk(
        address[] memory _recipients,
        uint256[] memory _tokensOpened,
        uint256[] memory _tokensLocked,
        uint256[] memory _timeFrame,
        bool[] memory _immutable
    )
        external
        onlyGateKeeper
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allocateTokens(
                _recipients[i],
                _tokensOpened[i],
                _tokensLocked[i],
                _timeFrame[i],
                _immutable[i]
            );
        }
    }

    function allocateTokens(
        address _recipient,
        uint256 _tokensOpened,
        uint256 _tokensLocked,
        uint256 _timeFrame,
        bool _immutable
    )
        public
        onlyGateKeeper
    {
        require(
            _timeFrame > 0,
            'dgKeeper: undefined timeFrame'
        );

        require(
            isImmutable[_recipient] == false,
            'dgKeeper: immutable recepient'
        );

        keeperFrom[_recipient] = getNow();
        keeperTill[_recipient] = getNow().add(_timeFrame);
        keeperRate[_recipient] = _tokensLocked.div(_timeFrame);
        keeperBalance[_recipient] = _tokensOpened;
        isImmutable[_recipient] = _immutable;
    }

    function scrapeTokens()
        external
    {
        uint256 scrapeAmount =
        availableBalance(msg.sender);

        keeperPayouts[msg.sender] =
        keeperPayouts[msg.sender].add(scrapeAmount);

        /*
        safeTransfer(
            distributionToken,
            msg.sender,
            scrapeAmount
        );
        */

        emit tokensScraped (
            msg.sender,
            scrapeAmount,
            block.timestamp
        );
    }

    function availableBalance(address _recipients)
        public
        view
        returns (uint256)
    {
        uint256 timePassed =
            getNow() < keeperTill[_recipients]
                ? getNow()
                    .sub(keeperFrom[_recipients])
                : keeperTill[_recipients]
                    .sub(keeperFrom[_recipients]);

        return keeperRate[_recipients]
            .mul(timePassed)
            .add(keeperBalance[_recipients])
            .sub(keeperPayouts[_recipients]);
    }

    function lockedBalance(address _recipients)
        external
        view
        returns (uint256)
    {
        uint256 timeRemaining =
            keeperTill[_recipients] > getNow() ?
            keeperTill[_recipients] - getNow() : 0;

        return keeperRate[_recipients]
            .mul(timeRemaining);
    }

    function getNow()
        public
        view
        returns (uint256)
    {
        return block.timestamp;
    }

    function changeDistributionToken(
        address _newDistributionToken
    )
        external
        onlyGateKeeper
    {
        distributionToken = _newDistributionToken;
    }

    function renounceOwnership()
        external
        onlyGateKeeper
    {
        gateKeeper = address(0x0);
    }

    bytes4 private constant TRANSFER = bytes4(
        keccak256(
            bytes(
                'transfer(address,uint256)'
            )
        )
    );

    function safeTransfer(
        address _token,
        address _to,
        uint256 _value
    )
        private
    {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(
                TRANSFER,
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
            'dgKeeper: TRANSFER_FAILED'
        );
    }
}