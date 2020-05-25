pragma solidity ^0.5.14;

// Roulette Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/TreasuryInstance.sol";

contract TreasuryRoulette is AccessControl {

    using SafeMath for uint;

    uint256 public maxSquareBet;
    uint256 public maximumNumberBets = 36;
    uint256 public nextRoundTimestamp;

    enum BetType { Single, EvenOdd, RedBlack, HighLow, Column, Dozen }
    mapping (uint => mapping (uint => uint256)) public currentBets;

    modifier onlyTreasury() {
        require(
            msg.sender == address(treasury),
            'must be current treasury'
        );
        _;
    }

    TreasuryInstance public treasury;

    constructor(address _treasuryAddress, uint256 _maxSquareBet) public {
        treasury = TreasuryInstance(_treasuryAddress);
        maxSquareBet = _maxSquareBet;
        nextRoundTimestamp = now;
    }

    struct Bet {
        BetType betType;
        address player;
        uint256 number;
        uint256 value;
        // string tokenName;
    }

    /* event SpinResult(
        string _tokenName,
        uint256 _landID,
        uint256 indexed _number,
        uint256 indexed _machineID,
        uint256[] _amountWins
    ); */

    event GameResult(
        address[] _players,
        string indexed _tokenName,
        uint256 _landID,
        uint256 indexed _number,
        uint256 indexed _machineID,
        uint256[] _winAmounts
    );

    uint256[] winAmounts;
    Bet[] public bets;

    /* event Finished(uint number, uint nextRoundTimestamp);
    event NewSingleBet(uint bet, address player, uint number, uint value);
    event NewEvenOddBet(uint bet, address player, uint number, uint value);
    event NewRedBlackBet(uint bet, address player, uint number, uint value);
    event NewHighLowBet(uint bet, address player, uint number, uint value);
    event NewColumnBet(uint bet, address player, uint column, uint value);
    event NewDozenBet(uint bet, address player, uint dozen, uint value);
    */

    function getNextRoundTimestamp() external view returns(uint) {
        return nextRoundTimestamp;
    }

    function createBet(
        uint _betType,
        address _player,
        uint _number,
        uint _value
        // string calldata _tokenName
    ) external whenNotPaused onlyCEO {
        bet(
            _betType,
            _player,
            _number,
            _value
            // _tokenName
        );
    }

    function bet(
        uint _betType,
        address _player,
        uint _number,
        uint _value
        // string memory _token
    ) internal {

        currentBets[_betType][_number] += _value;

        require(
            currentBets[_betType][_number] <= maxSquareBet,
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
            // tokenName: _token
        }));
        // emit NewSingleBet(bets.length, _player, _number, _value);
    }

    function betEvenOdd(uint256 _number, address _player, uint _value) internal {
        require(_number <= 1, 'Even(0) - Odd(1)');
        bets.push(Bet({
            betType: BetType.EvenOdd,
            player: _player,
            number: _number,
            value: _value
            // tokenName: _token
        }));
        // emit NewEvenOddBet(bets.length, _player, _number, _value);
    }

    function betRedBlack(uint256 _number, address _player, uint _value) internal {
        require(_number <= 1, 'Red(0) - Black(1)');
        bets.push(Bet({
            betType: BetType.RedBlack,
            player: _player,
            number: _number,
            value: _value
            // tokenName: _token
        }));
        // emit NewRedBlackBet(bets.length, _player, _number, _value);
    }

    function betHighLow(uint256 _number, address _player, uint _value) internal {
        require(_number <= 1, 'High(0) - Low(1)');
        bets.push(Bet({
            betType: BetType.HighLow,
            player: _player,
            number: _number,
            value: _value
            // tokenName: _token
        }));
        // emit NewHighLowBet(bets.length, _player, _number, _value);
    }

    function betColumn(uint _column, address _player, uint _value) internal {
        require(_column <= 2, 'column must be in region between 0 and 2');
        bets.push(Bet({
            betType: BetType.Column,
            player: _player,
            number: _column,
            value: _value
            // tokenName: _token
        }));
        // emit NewColumnBet(bets.length, _player, _column, _value);
    }

    function betDozen(uint _dozen, address _player, uint _value) internal {
        require(_dozen <= 2, 'dozen must be in region between 0 and 2');
        bets.push(Bet({
            betType: BetType.Dozen,
            player: _player,
            number: _dozen,
            value: _value
            // tokenName: _token
        }));
        // emit NewDozenBet(bets.length, _player, _dozen, _value);
    }

    function launch(
        bytes32 _localhash
        // uint256 _machineID,
        // uint256 _landID,
        // string calldata _tokenName
    ) external whenNotPaused onlyCEO returns(uint256[] memory, uint256 number) {
        return _launch(
            _localhash
            // _machineID,
            // _landID,
            // _tokenName
        );
    }

    function _launch(
        bytes32 _localhash
        // uint256 _machineID,
        // uint256 _landID,
        // string memory _tokenName
    ) private returns(uint256[] memory, uint256 number) {

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
                if (b.number == 0) won = (number % 3 == 1);
                if (b.number == 1) won = (number % 3 == 2);
                if (b.number == 2) won = (number % 3 == 0);
            } else if (b.betType == BetType.Dozen) {
                if (b.number == 0) won = (number <= 12);
                if (b.number == 1) won = (number > 12 && number <= 24);
                if (b.number == 2) won = (number > 24);
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
        // emit SpinResult(_tokenName, _landID, number, _machineID, winAmounts);

        // return wins
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
        string memory _tokenName
    ) public whenNotPaused onlyWorker {

        require(
            _betIDs.length == _betValues.length,
            'inconsistent amount of bets'
        );
        require(
            _betIDs.length == _betAmount.length,
            'inconsistent amount of bets'
        );
        require(
            _betIDs.length <= maximumNumberBets,
            'maximum amount of bets reached'
        );

        treasury.consumeHash(_localhash);

        for (uint256 i = 0; i < _betIDs.length; i++) {

            require(
                treasury.checkApproval(_players[i], _tokenName) >= _betAmount[i],
                'approve treasury as spender'
            );

            require(
                treasury.getMaximumBet(_tokenName) >= _betAmount[i],
                'bet amount is more than maximum'
            );

            require(
                treasury.tokenInboundTransfer(_tokenName, _players[i], _betAmount[i]),
                'inbound transfer failed'
            );

            bet(
                _betIDs[i],
                _players[i],
                _betValues[i],
                _betAmount[i]
                // _tokenName
            );
        }

        require(
            getNecessaryBalance() <= treasury.checkAllocatedTokens(_tokenName),
            "not enough tokens for payout"
        );

        uint256 number;
        (winAmounts, number) = _launch(
            _localhash
            // _machineID,
            // _landID,
            // _tokenName
        );

        for (uint256 i = 0; i < winAmounts.length; i++) {
            if (winAmounts[i] > 0) {
                treasury.tokenOutboundTransfer(_tokenName, _players[i], winAmounts[i]);
            }
        }

        emit GameResult(
            _players,
            _tokenName,
            _landID,
            number,
            _machineID,
            winAmounts
        );
    }


    function getPayoutForType(BetType _betType) public pure returns(uint256) {
        if (_betType == BetType.Single) return 36;
        if (_betType == BetType.EvenOdd) return 2;
        if (_betType == BetType.RedBlack) return 2;
        if (_betType == BetType.HighLow) return 2;
        if (_betType == BetType.Column) return 3;
        if (_betType == BetType.Dozen) return 3;
    }

    function getNecessaryBalance() public view returns (uint256 _necessaryBalance) {

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

    function changeMaxSquareBet(uint256 _newMaxSquareBet) external onlyCEO {
        maxSquareBet = _newMaxSquareBet;
    }

    function changeTreasury(address _newTreasuryAddress) external onlyCEO {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }

    function _changeTreasury(address _newTreasuryAddress) external onlyTreasury {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }
}
