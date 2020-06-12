pragma solidity ^0.5.17;

// Roulette Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessController.sol";
import "../common-contracts/TreasuryInstance.sol";

contract TreasuryRoulette is AccessController {

    using SafeMath for uint;

    uint256 maxNumberBets;
    uint256 nextRoundTimestamp;
    uint256 maxSquareBetDefault;

    enum BetType { Single, EvenOdd, RedBlack, HighLow, Column, Dozen }

    mapping (uint => uint) public maxSquareBets;
    mapping (uint => mapping (uint => mapping (uint => uint))) public currentBets;

    Bet[] public bets;
    uint256[] winAmounts;

    struct Bet {
        uint256 betType;
        address player;
        uint256 number;
        uint256 value;
        uint256 tokenIndex;
    }

    event GameResult(
        address[] _players,
        uint8[] _tokenIndex,
        uint256 indexed _landID,
        uint256 indexed _number,
        uint256 indexed _machineID,
        uint256[] _winAmounts
    );

    TreasuryInstance public treasury;

    constructor(
        address _treasuryAddress,
        uint256 _maxSquareBetDefault,
        uint256 _maxNumberBets
    ) public {
        treasury = TreasuryInstance(_treasuryAddress);
        maxSquareBetDefault = _maxSquareBetDefault;
        maxNumberBets = _maxNumberBets;
        nextRoundTimestamp = now;
    }

    function getNextRoundTimestamp() external view returns(uint) {
        return nextRoundTimestamp;
    }

    function createBet(
        uint256 _betType,
        address _player,
        uint256 _number,
        uint256 _value,
        uint256 _tokenIndex
    ) external whenNotPaused onlyCEO {
        bet(
            _betType,
            _player,
            _number,
            _value,
            _tokenIndex
        );
    }

    function bet(
        uint256 _betType,
        address _player,
        uint256 _number,
        uint256 _value,
        uint256 _tokenIndex
    ) internal {

        currentBets[_tokenIndex][_betType][_number] += _value;

        uint256 _maxSquareBet = maxSquareBets[_tokenIndex] == 0
            ? maxSquareBetDefault
            : maxSquareBets[_tokenIndex];

        require(
            currentBets[_tokenIndex][_betType][_number] <= _maxSquareBet,
            'exceeding maximum bet limit'
        );

        bets.push(Bet({
            betType: _betType,
            player: _player,
            number: _number,
            value: _value,
            tokenIndex: _tokenIndex
        }));
    }

    function launch(
        bytes32 _localhash
    ) external whenNotPaused onlyCEO returns(
        uint256[] memory,
        uint256 number
    ) {
        return _launch(_localhash);
    }

    function _launch(
        bytes32 _localhash
    ) private returns(uint256[] memory, uint256 number) {

        require(now > nextRoundTimestamp, 'expired round');
        require(bets.length > 0, 'must have bets');

        winAmounts.length = 0;
        nextRoundTimestamp = now;

        uint diff = block.difficulty;
        bytes32 hash = _localhash;
        Bet memory lb = bets[bets.length-1];

        number = uint(
            keccak256(
                abi.encodePacked(
                    now, diff, hash, lb.betType, lb.player, lb.number
                )
            )
        ) % 37;

        for (uint i = 0; i < bets.length; i++) {
            bool won = false;
            Bet memory b = bets[i];
            if (b.betType == uint(BetType.Single) && b.number == number) {
                won = true;
            } else if (b.betType == uint(BetType.EvenOdd)) {
                if (number > 0 && number % 2 == b.number) {
                    won = true;
                }
            } else if (b.betType == uint(BetType.RedBlack) && b.number == 0) {
                if ((number > 0 && number <= 10) || (number >= 19 && number <= 28)) {
                    won = (number % 2 == 1);
                } else {
                    won = (number % 2 == 0);
                }
            } else if (b.betType == uint(BetType.RedBlack) && b.number == 1) {
                if ((number > 0 && number <= 10) || (number >= 19 && number <= 28)) {
                    won = (number % 2 == 0);
                } else {
                    won = (number % 2 == 1);
                }
            } else if (b.betType == uint(BetType.HighLow)) {
                if (number >= 19 && b.number == 0) {
                    won = true;
                }
                if (number > 0 && number <= 18 && b.number == 1) {
                    won = true;
                }
            } else if (b.betType == uint(BetType.Column)) {
                if (b.number == 0) won = (number % 3 == 1);
                if (b.number == 1) won = (number % 3 == 2);
                if (b.number == 2) won = (number % 3 == 0);
            } else if (b.betType == uint(BetType.Dozen)) {
                if (b.number == 0) won = (number <= 12);
                if (b.number == 1) won = (number > 12 && number <= 24);
                if (b.number == 2) won = (number > 24);
            }

            if (won) {
                uint256 betWin = b.value.mul(
                    getPayoutForType(b.betType, b.number)
                );
                winAmounts.push(betWin);
            } else {
                winAmounts.push(0);
            }

            currentBets[b.tokenIndex][uint(b.betType)][b.number] = 0;
        }

        delete bets;
        return(winAmounts, number);
    }

    function play(
        address[] memory _players,
        uint256 _landID,
        uint256 _machineID,
        uint256[] memory _betIDs,
        uint256[] memory _betValues,
        uint256[] memory _betAmount,
        bytes32 _localhash,
        uint8[] memory _tokenIndex
    ) public whenNotPaused onlyWorker {

        require(
            _betIDs.length == _betValues.length,
            'Roulette: inconsistent amount of betsValues'
        );

        require(
            _tokenIndex.length == _betAmount.length,
            'Roulette: inconsistent amount of betAmount'
        );

        require(
            _betValues.length == _tokenIndex.length,
            'Roulette: inconsistent amount of tokenIndex'
        );

        require(
            _betIDs.length <= maxNumberBets,
            'Roulette: maximum amount of bets reached'
        );

        treasury.consumeHash(_localhash);

        for (uint256 i = 0; i < _betIDs.length; i++) {

            require(
                treasury.getMaximumBet(_tokenIndex[i]) >= _betAmount[i],
                'Roulette: bet amount is more than maximum'
            );

            treasury.tokenInboundTransfer(
                _tokenIndex[i],
                _players[i],
                _betAmount[i]
            );

            bet(
                _betIDs[i],
                _players[i],
                _betValues[i],
                _betAmount[i],
                _tokenIndex[i]
            );

            /* uint256 tokenFunds = treasury.checkAllocatedTokens(
                _tokenIndex[i]
            );

            require(
                getNecessaryBalance(_tokenIndex[i]) <= tokenFunds,
                'Roulette: not enough tokens for payout'
            );*/
        }

        uint256 _spinResult;
        (winAmounts, _spinResult) = _launch(_localhash);

        for (uint256 i = 0; i < winAmounts.length; i++) {
            if (winAmounts[i] > 0) {
                treasury.tokenOutboundTransfer(
                    _tokenIndex[i],
                    _players[i],
                    winAmounts[i]
                );
            }
        }

        emit GameResult(
            _players,
            _tokenIndex,
            _landID,
            _spinResult,
            _machineID,
            winAmounts
        );
    }

    function getPayoutForType(
        uint256 _betType,
        uint256 _betNumber
    ) public pure returns(uint256) {

        if (_betType == uint(BetType.Single))
            return _betNumber > 36 ? 0 : 36;
        if (_betType == uint(BetType.EvenOdd))
            return _betNumber > 1 ? 0 : 2;
        if (_betType == uint(BetType.RedBlack))
            return _betNumber > 1 ? 0 : 2;
        if (_betType == uint(BetType.HighLow))
            return _betNumber > 1 ? 0 : 2;
        if (_betType == uint(BetType.Column))
            return _betNumber > 2 ? 0 : 3;
        if (_betType == uint(BetType.Dozen))
            return _betNumber > 2 ? 0 : 3;

        return 0;
    }

    function getNecessaryBalance(
        uint256 _tokenIndex
    ) public view returns (uint256 _necessaryBalance) {

        uint256 _necessaryForBetType;
        uint256[] memory betTypesMax;

        for (uint8 _i = 0; _i < bets.length; _i++) {

            Bet memory b = bets[_i];

            if (b.tokenIndex != _tokenIndex) continue;

            uint256 _payout = getPayoutForType(b.betType, b.number);
            uint256 _square = currentBets[b.tokenIndex][uint(b.betType)][b.number];

            require(
                _payout > 0,
                'Roulette: incorrect bet type/value'
            );

            _necessaryForBetType = _square.mul(_payout);

            if (_necessaryForBetType > betTypesMax[uint(b.betType)]) {
                betTypesMax[uint(b.betType)] = _necessaryForBetType;
            }
        }

        for (uint8 _i = 0; _i < betTypesMax.length; _i++) {
            _necessaryBalance = _necessaryBalance.add(
                betTypesMax[_i]
            );
        }
    }

    function getBetsCountAndValue() external view returns(uint value, uint) {
        for (uint i = 0; i < bets.length; i++) {
            value += bets[i].value;
        }
        return (bets.length, value);
    }

    function getBetsCount() external view returns (uint256) {
        return bets.length;
    }

    function changeMaxSquareBet(
        uint256 _tokenIndex,
        uint256 _newMaxSquareBet
    ) external onlyCEO {
        maxSquareBets[_tokenIndex] = _newMaxSquareBet;
    }

    function changeMaximumBetAmount(
        uint256 _newMaximum
    ) external onlyCEO {
        maxNumberBets = _newMaximum;
    }

    function changeTreasury(
        address _newTreasuryAddress
    ) external onlyCEO {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }

    function migrateTreasury(
        address _newTreasuryAddress
    ) external {
        require(
            msg.sender == address(treasury),
            'Roulette: wrong treasury address'
        );
        treasury = TreasuryInstance(_newTreasuryAddress);
    }
}