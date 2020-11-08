// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.4;

import "./common-contracts/SafeMath.sol";
import "./common-contracts/ERC20Token.sol";

contract dgKeeper {

    using SafeMath for uint256;

    address public gateKeeper;
    address public gateOverseer;
    address public distributionToken;

    uint256 public totalAvailable;

    mapping(address => uint256) public keeperRate;
    mapping(address => uint256) public keeperFrom;
    mapping(address => uint256) public keeperTill;
    mapping(address => uint256) public keeperBalance;
    mapping(address => uint256) public keeperPayouts;

    mapping(address => bool) public isImmutable;

    modifier onlyGateKeeper() {
        require(
            msg.sender == gateKeeper,
            'dgKeeper: keeper denied!'
        );
        _;
    }

    modifier onlyGateOverseer() {
        require(
            msg.sender == gateOverseer,
            'dgKeeper: overseer denied!'
        );
        _;
    }

    event tokensScraped (
        address indexed scraper,
        uint256 scrapedAmount,
        uint256 timestamp
    );

    event recipientCreated (
        address indexed recipient,
        uint256 timeLock,
        uint256 timeReward,
        uint256 instantReward,
        uint256 timestamp,
        bool isImmutable
    );

    event recipientAdjusted (
        address indexed recipient,
        uint256 timeLock,
        uint256 timeReward,
        uint256 instantReward,
        uint256 timestamp
    );

    constructor(
        address _distributionToken,
        address _gateOverseer,
        address _gateKeeper
    ) {
        distributionToken = _distributionToken;
        gateOverseer = _gateOverseer;
        gateKeeper = _gateKeeper;
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
        bool _isImmutable
    )
        public
        onlyGateKeeper
    {
        require(
            _timeFrame > 0,
            'dgKeeper: undefined timeFrame'
        );

        require(
            keeperRate[_recipient] == 0,
            'dgKeeper: _recipient is active'
        );

        totalAvailable =
        totalAvailable
            .add(_tokensOpened)
            .add(_tokensLocked);

        ERC20Token t = ERC20Token(
            distributionToken
        );

        require(
            t.balanceOf(address(this)) >= totalAvailable,
            'dgKeeper: not enough tokens inside contract'
        );

        keeperFrom[_recipient] = getNow();
        keeperTill[_recipient] = getNow().add(_timeFrame);
        keeperRate[_recipient] = _tokensLocked.div(_timeFrame);
        keeperBalance[_recipient] = _tokensOpened;
        isImmutable[_recipient] = _isImmutable;

        emit recipientCreated (
            _recipient,
            _timeFrame,
            _tokensLocked,
            _tokensOpened,
            block.timestamp,
            _isImmutable
        );
    }

    function scrapeMyTokens()
        external
    {
        _scrapeTokens(msg.sender);
    }

    function _scrapeTokens(
        address _recipient
    )
        internal
    {
       uint256 scrapeAmount =
        availableBalance(_recipient);

        keeperPayouts[_recipient] =
        keeperPayouts[_recipient].add(scrapeAmount);

        safeTransfer(
            distributionToken,
            _recipient,
            scrapeAmount
        );

        totalAvailable =
        totalAvailable.sub(scrapeAmount);

        emit tokensScraped (
            _recipient,
            scrapeAmount,
            block.timestamp
        );
    }

    function adjustRecipient(
        address _recipient,
        uint256 _tokensOpened,
        uint256 _tokensLocked,
        uint256 _timeFrame
    )
        external
        onlyGateOverseer
    {
        require(
            keeperRate[_recipient] > 0,
            'dgKeeper: _recipient is not active'
        );

        require(
            isImmutable[_recipient] == false,
            'dgKeeper: _recipient is immutable'
        );

        _scrapeTokens(_recipient);

        totalAvailable =
        totalAvailable
            .add(_tokensOpened)
            .add(_tokensLocked)
            .sub(lockedBalance(_recipient));

        ERC20Token t = ERC20Token(
            distributionToken
        );

        require(
            t.balanceOf(address(this)) >= totalAvailable,
            'dgKeeper: not enough tokens inside contract'
        );

        keeperFrom[_recipient] = getNow();
        keeperTill[_recipient] = getNow().add(_timeFrame);
        keeperRate[_recipient] = _timeFrame > 0
            ? _tokensLocked.div(_timeFrame) : 0;
        keeperBalance[_recipient] = _tokensOpened;
        keeperPayouts[_recipient] = 0;

        emit recipientAdjusted (
            _recipient,
            _timeFrame,
            _tokensLocked,
            _tokensOpened,
            block.timestamp
        );
    }

    function availableBalance(
        address _recipients
    )
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
        public
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