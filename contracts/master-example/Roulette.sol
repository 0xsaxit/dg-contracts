pragma solidity ^0.5.14;

// Slot Machine Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////
import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";

contract RouletteLogic is AccessControl {

    using SafeMath for uint;
    uint public nextRoundTimestamp;
    enum BetType { Single, Odd, Even, Red, Black, High, Low, Column, Dozen }

    address public masterAddress;
    uint public maxSquareBet;

    mapping (uint => mapping (uint => uint256)) public squareBets;

    constructor(address _masterAddress, uint256 _maxSquareBet) public {
        masterAddress = _masterAddress;
        maxSquareBet = _maxSquareBet;
        nextRoundTimestamp = now;
    }

    modifier onlyMaster {
        require(msg.sender == masterAddress, 'can only be called by master/parent contract');
        _;
    }

    struct Bet {
        BetType betType;
        address player;
        uint256 number;
        uint256 value;
        uint256 betID;
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
    event NewEvenBet(uint bet, address player, uint value);
    event NewOddBet(uint bet, address player, uint value);
    event NewRedBet(uint bet, address player, uint value);
    event NewBlackBet(uint bet, address player, uint value);
    event NewHighBet(uint bet, address player, uint value);
    event NewLowBet(uint bet, address player, uint value);
    event NewColumnBet(uint bet, address player, uint column, uint value);
    event NewDozenBet(uint bet, address player, uint dozen, uint value);

    function getNextRoundTimestamp() external view returns(uint) {
        return nextRoundTimestamp;
    }

    function getBetsCountAndValue() external view returns(uint, uint) {
        uint value = 0;
        for (uint i = 0; i < bets.length; i++) {
            value += bets[i].value;
        }
        return (bets.length, value);
    }

    function createBet(
        uint _betID,
        address _player,
        uint _number,
        uint _value
    ) external onlyMaster {

        squareBets[_betID][_number] += _value;

        require(
            squareBets[_betID][_number] <= maxSquareBet,
            'exceeding maximum bet square limit'
        );

        if (_betID == 3301) {
            betSingle(_number, _player, _value);
        }
        else if (_betID == 3302) {
            betEven(_player, _value);
        }
        else if (_betID == 3303) {
            betOdd(_player, _value);
        }
        else if (_betID == 3304) {
            betRed(_player, _value);
        }
        else if (_betID == 3305) {
            betBlack(_player, _value);
        }
        else if (_betID == 3305) {
            betBlack(_player, _value);
        }
        else if (_betID == 3306) {
            betHigh(_player, _value);
        }
        else if (_betID == 3307) {
            betLow(_player, _value);
        }
        else if (_betID == 3308) {
            betColumn(_number, _player, _value);
        }
        else if (_betID == 3309) {
            betDozen(_number, _player, _value);
        }
    }

    //3301
    function betSingle(uint _number, address _player, uint _value) internal {
        require(_number <= 36, 'single bet must be in region between 0 and 36');
        bets.push(Bet({
            betType: BetType.Single,
            player: _player,
            number: _number,
            value: _value,
            betID: 3301
        }));
        emit NewSingleBet(bets.length, _player, _number, _value);
    }

    //3302
    function betEven(address _player, uint _value) internal {
        bets.push(Bet({
            betType: BetType.Even,
            player: _player,
            number: 0,
            value: _value,
            betID: 3302
        }));
        emit NewEvenBet(bets.length, _player, _value);
    }

    //3303
    function betOdd(address _player, uint _value) internal {
        bets.push(Bet({
            betType: BetType.Odd,
            player: _player,
            number: 0,
            value: _value,
            betID: 3303
        }));
        emit NewOddBet(bets.length, _player, _value);
    }

    //3304
    function betRed(address _player, uint _value) internal {
        bets.push(Bet({
            betType: BetType.Red,
            player: _player,
            number: 0,
            value: _value,
            betID: 3304
        }));
        emit NewRedBet(bets.length, _player, _value);
    }

    //3305
    function betBlack(address _player, uint _value) internal {
        bets.push(Bet({
            betType: BetType.Black,
            player: _player,
            number: 0,
            value: _value,
            betID: 3305
        }));
        emit NewBlackBet(bets.length, _player, _value);
    }

    //3306
    function betHigh(address _player, uint _value) internal {
        bets.push(Bet({
            betType: BetType.High,
            player: _player,
            number: 0,
            value: _value,
            betID: 3306
        }));
        emit NewHighBet(bets.length, _player, _value);
    }

    //3307
    function betLow(address _player, uint _value) internal {
        bets.push(Bet({
            betType: BetType.Low,
            player: _player,
            number: 0,
            value: _value,
            betID: 3307
        }));
        emit NewLowBet(bets.length, _player, _value);
    }

    //3308
    function betColumn(uint _column, address _player, uint _value) internal {
        require(_column >= 1 && _column <= 3, 'column bet must be in region between 1 and 3');
        bets.push(Bet({
            betType: BetType.Column,
            player: _player,
            number: _column,
            value: _value,
            betID: 3308
        }));
        emit NewColumnBet(bets.length, _player, _column, _value);
    }

    //3309
    function betDozen(uint _dozen, address _player, uint _value) internal {
        require(_dozen >= 1 && _dozen <= 3, 'dozen bet must be in region between 1 and 3');
        bets.push(Bet({
            betType: BetType.Dozen,
            player: _player,
            number: _dozen,
            value: _value,
            betID: 3309
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

        /* reset */
        winAmounts.length = 0;
        nextRoundTimestamp = now;

        /* calculate 'random' number */
        uint diff = block.difficulty;
        bytes32 hash = _localhash;
        //bytes32 hash = blockhash(block.number-1);
        Bet memory lb = bets[bets.length-1];
        number = uint(keccak256(abi.encodePacked(now, diff, hash, lb.betType, lb.player, lb.number))) % 37;

        for (uint i = 0; i < bets.length; i++) {
            bool won = false;
            Bet memory b = bets[i];
            if (b.betType == BetType.Single) {
                if (b.number == number) {
                    won = true;
                }
            } else if (b.betType == BetType.Even) {
                if (number > 0 && number % 2 == 0) {
                    won = true;
                }
            } else if (b.betType == BetType.Odd) {
                if (number > 0 && number % 2 == 1) {
                    won = true;
                }
            } else if (b.betType == BetType.Red) {
                if (number <= 10 || (number >= 19 && number <= 28)) {
                    won = (number % 2 == 1);
                } else {
                    won = (number % 2 == 0);
                }
            } else if (b.betType == BetType.Black) {
                if ((number > 0 && number <= 10) || (number >= 19 && number <= 28)) {
                    won = (number % 2 == 0);
                } else {
                    won = (number % 2 == 1);
                }
            } else if (b.betType == BetType.High) {
                if (number >= 19) {
                    won = true;
                }
            } else if (b.betType == BetType.Low) {
                if (number > 0 && number <= 18) {
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
                uint256 betWin = b.value.mul(getPayoutForType(b.betID));
                winAmounts.push(betWin);
            } else {
                winAmounts.push(0);
            }

            squareBets[b.betID][b.number] = 0;
        }

        bets.length = 0;
        emit SpinResult(_tokenName, _landID, number, _machineID, winAmounts);

        //return wins
        return(winAmounts, number);

    }

    function getPayoutForType(uint256 _betID) public pure returns(uint256) {
        if (_betID == 3301) return 36; //single
        if (_betID == 3302 || _betID == 3303) return 2; //odd-even
        if (_betID == 3304 || _betID == 3305) return 2; //black-red
        if (_betID == 3306 || _betID == 3307) return 2; //low-high
        if (_betID == 3308 || _betID == 3309) return 3; //column-dozen
        return 0;
    }

    function getAmountBets() external view returns (uint256) {
        return bets.length;
    }

    function changeMaxSquareBet(uint256 _newMaxBet) external onlyCEO {
        maxSquareBet = _newMaxBet;
    }

    function changeMaster(address _newMaster) external onlyCEO {
        masterAddress = _newMaster;
    }

}
