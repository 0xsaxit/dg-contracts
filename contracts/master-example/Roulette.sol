pragma solidity ^0.5.14;

// Roulette Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";

contract RouletteLogic is AccessControl {
    using SafeMath for uint;

    uint256 public nextRoundTimestamp;
    uint256 public maxBet;

    address public masterAddress;
    enum BetType { Single, EvenOdd, RedBlack, HighLow, Column, Dozen }

    mapping (uint => mapping (uint => uint256)) public currentBets;

    constructor(address _masterAddress, uint256 _maxBet) public {
        masterAddress = _masterAddress;
        maxBet = _maxBet;
        nextRoundTimestamp = now;
    }

    modifier onlyMaster {
        require(
            msg.sender == masterAddress,
            'can only be called by master/parent contract'
        );
        _;
    }

    struct Bet {
        BetType betType;
        address player;
        uint256 number;
        uint256 value;
    }

    event SpinResult(
        string _tokenName,
        uint256 _landID,
        uint256 indexed _number,
        uint256 indexed _machineID,
        uint256[] _amountWins
    );

    uint256[] winAmounts;
    Bet[] public bets;

    event Finished(uint number, uint nextRoundTimestamp);
    event NewSingleBet(uint bet, address player, uint number, uint value);
    event NewEvenOddBet(uint bet, address player, uint number, uint value);
    event NewRedBlackBet(uint bet, address player, uint number, uint value);
    event NewHighLowBet(uint bet, address player, uint number, uint value);
    event NewColumnBet(uint bet, address player, uint column, uint value);
    event NewDozenBet(uint bet, address player, uint dozen, uint value);

    function getNextRoundTimestamp() external view returns(uint) {
        return nextRoundTimestamp;
    }

    function createBet(
        uint _betType,
        address _player,
        uint _number,
        uint _value
    ) external onlyMaster {

        currentBets[_betType][_number] += _value;

        require(
            currentBets[_betType][_number] <= maxBet,
            'exceeding maximum bet limit'
        );

        if (_betType == uint(BetType.Single)) return betSingle(_number, _player, _value);
        if (_betType == uint(BetType.EvenOdd)) return betEvenOdd(_number, _player, _value);
        if (_betType == uint(BetType.RedBlack)) return betRedBlack(_number ,_player, _value);
        if (_betType == uint(BetType.HighLow)) return betHighLow(_number, _player, _value);
        if (_betType == uint(BetType.Column)) return betColumn(_number, _player, _value);
        if (_betType == uint(BetType.Dozen)) return betDozen(_number, _player, _value);

    }

    function betSingle(uint _number, address _player, uint _value) internal {
        require(_number <= 36, 'must be between 0 and 36');
        bets.push(Bet({
            betType: BetType.Single,
            player: _player,
            number: _number,
            value: _value
        }));
        emit NewSingleBet(bets.length, _player, _number, _value);
    }

    function betEvenOdd(uint256 _number, address _player, uint _value) internal {
        require(_number <= 1, 'Even(0) - Odd(1)');
        bets.push(Bet({
            betType: BetType.EvenOdd,
            player: _player,
            number: _number,
            value: _value
        }));
        emit NewEvenOddBet(bets.length, _player, _number, _value);
    }

    function betRedBlack(uint256 _number, address _player, uint _value) internal {
        require(_number <= 1, 'Red(0) - Black(1)');
        bets.push(Bet({
            betType: BetType.RedBlack,
            player: _player,
            number: _number,
            value: _value
        }));
        emit NewRedBlackBet(bets.length, _player, _number, _value);
    }


    function betHighLow(uint256 _number, address _player, uint _value) internal {
        require(_number <= 1, 'High(0) - Low(1)');
        bets.push(Bet({
            betType: BetType.HighLow,
            player: _player,
            number: _number,
            value: _value
        }));
        emit NewHighLowBet(bets.length, _player, _number, _value);
    }


    function betColumn(uint _column, address _player, uint _value) internal {
        require(_column <= 2, 'column must be in region between 0 and 2');
        bets.push(Bet({
            betType: BetType.Column,
            player: _player,
            number: _column,
            value: _value
        }));
        emit NewColumnBet(bets.length, _player, _column, _value);
    }

    function betDozen(uint _dozen, address _player, uint _value) internal {
        require(_dozen <= 2, 'dozen must be in region between 0 and 2');
        bets.push(Bet({
            betType: BetType.Dozen,
            player: _player,
            number: _dozen,
            value: _value
        }));
        emit NewDozenBet(bets.length, _player, _dozen, _value);
    }

    function launch(
        bytes32 _localhash,
        uint256 _machineID,
        uint256 _landID,
        string calldata _tokenName
    ) external onlyMaster returns(uint256[] memory, uint256 number) {
        require(now > nextRoundTimestamp, 'expired round');
        require(bets.length > 0, 'must have bets');

        winAmounts.length = 0;
        nextRoundTimestamp = now;

        uint diff = block.difficulty;
        bytes32 hash = _localhash;
        Bet memory lb = bets[bets.length-1];
        number = uint(keccak256(abi.encodePacked(now, diff, hash, lb.betType, lb.player, lb.number))) % 37;

        for (uint i = 0; i < bets.length; i++) {
            bool won = false;
            Bet memory b = bets[i];
            if (b.betType == BetType.Single && b.number == number) {
                won = true;
            } else if (b.betType == BetType.EvenOdd) {
                if (number > 0 && number % 2 == b.number) {
                    won = true;
                }
            } else if (b.betType == BetType.RedBlack && b.number == 0) {
                if ((number > 0 && number <= 10) || (number >= 19 && number <= 28)) {
                    won = (number % 2 == 1);
                } else {
                    won = (number % 2 == 0);
                }
            } else if (b.betType == BetType.RedBlack && b.number == 1) {
                if ((number > 0 && number <= 10) || (number >= 19 && number <= 28)) {
                    won = (number % 2 == 0);
                } else {
                    won = (number % 2 == 1);
                }
            } else if (b.betType == BetType.HighLow) {
                if (number >= 19 && b.number == 0) {
                    won = true;
                }
                if (number > 0 && number <= 18 && b.number == 1) {
                    won = true;
                }
            } else if (b.betType == BetType.Column) {
                if (b.number == 1) won = (number % 3 == 1);
                if (b.number == 2) won = (number % 3 == 2);
                if (b.number == 3) won = (number % 3 == 0);
            } else if (b.betType == BetType.Dozen) {
                if (b.number == 1) won = (number <= 12);
                if (b.number == 2) won = (number > 12 && number <= 24);
                if (b.number == 3) won = (number > 24);
            }

            if (won) {
                uint256 betWin = b.value.mul(getPayoutForType(b.betType));
                winAmounts.push(betWin);
            } else {
                winAmounts.push(0);
            }

            currentBets[uint(b.betType)][b.number] = 0;
        }

        // reset bets
        bets.length = 0;
        emit SpinResult(_tokenName, _landID, number, _machineID, winAmounts);

        // return wins
        return(winAmounts, number);

    }

    function getPayoutForType(BetType _betType) public pure returns(uint256) {
        if (_betType == BetType.Single) return 36;
        if (_betType == BetType.EvenOdd) return 2;
        if (_betType == BetType.RedBlack) return 2;
        if (_betType == BetType.HighLow) return 2;
        if (_betType == BetType.Column) return 3;
        if (_betType == BetType.Dozen) return 3;
    }

    function getNecessaryBalance() external view returns (uint256 _necessaryBalance) {

        uint256 _necessaryForBetType;
        uint256 _i;
        uint256[6] memory betTypesMax;

        // determine highest for each betType
        for (_i = 0; _i < bets.length; _i++) {

            Bet memory b = bets[_i];

            _necessaryForBetType = currentBets[uint(b.betType)][b.number].mul(
                getPayoutForType(b.betType)
            );

            if (_necessaryForBetType > betTypesMax[uint(b.betType)]) {
                betTypesMax[uint(b.betType)] = _necessaryForBetType;
            }
        }

        // calculate total for all betTypes
        for (_i = 0; _i < betTypesMax.length; _i++) {
            _necessaryBalance = _necessaryBalance.add(
                betTypesMax[_i]
            );
        }
    }

    function getBetsCountAndValue() external view returns(uint, uint) {
        uint value = 0;
        for (uint i = 0; i < bets.length; i++) {
            value += bets[i].value;
        }
        return (bets.length, value);
    }


    function getBetsCount() external view returns (uint256) {
        return bets.length;
    }

    function changeMaxSquareBet(uint256 _newMaxBet) external onlyCEO {
        maxBet = _newMaxBet;
    }

    function changeMaster(address _newMaster) external onlyCEO {
        masterAddress = _newMaster;
    }

}
