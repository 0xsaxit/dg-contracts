pragma solidity ^0.5.14;

// Slot Machine Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";

contract SlotMachineLogic is AccessControl {
    using SafeMath for uint256;

    enum BetType { Single }

    uint256 public factor1;
    uint256 public factor2;
    uint256 public factor3;
    uint256 public factor4;

    struct Bet {
        BetType betType;
        address player;
        uint256 number;
        uint256 value;
    }

    Bet[] public bets;
    address public masterAddress;
    mapping (uint => mapping (uint => uint)) public betLimits;

    uint256[] winAmounts;

    event SpinResult(
        string _tokenName,
        uint256 indexed _landID,
        uint256 _number,
        uint256 indexed _machineID,
        uint256[] _winAmounts
    );

    constructor(address _masterAddress) public {
        masterAddress = _masterAddress;
        factor1 = 250;
        factor2 = 15;
        factor3 = 8;
        factor4 = 4;
    }

    modifier onlyMaster {
        require(
            msg.sender == masterAddress,
            'can only be called by master/parent contract'
        );
        _;
    }

    uint256[] symbols;

    function createBet(
        BetType _betType,
        address _player,
        uint256 _number,
        uint256 _value
    ) external onlyMaster {

        require(_player != address(0x0), "player undefined");
        require(_number == 0, "number must be 0");
        require(_value > 0, "bet value must be > 0");

        Bet memory newBet;
        newBet.betType = _betType;
        newBet.player = _player;
        newBet.number = _number;
        newBet.value = _value;
        bets.push(newBet);

        betLimits[uint(_betType)][_number] = betLimits[uint(_betType)][_number].add(_value);
    }

    function launch(
        bytes32 _localhash,
        uint256 _machineID,
        uint256 _landID,
        string calldata _tokenName
    ) external onlyMaster returns (uint256[] memory, uint256 numbers) {
        // randomly determine number from 0 - 999
        numbers = randomNumber(_localhash) % 1000;
        uint256 number = numbers;
        uint256 winAmount = 0;
        winAmounts.length = 0;

        // look-up table defining groups of winning number (symbol) combinations
        symbols = [4, 4, 4, 4, 3, 3, 3, 2, 2, 1];
        uint256 winner = symbols[number % 10]; // get symbol for rightmost number

        for (uint256 i = 0; i < 2; i++) {
            number = uint256(number) / 10; // shift numbers to get next symbol
            if (symbols[number % 10] != winner) {
                winner = 0;
                break; // if number not part of the winner group (same symbol) break
            }
        }

        for (uint256 i = 0; i < bets.length; i++) {
            if (winner == 1) {
                winAmount = factor1.mul(bets[i].value);
            } else if (winner == 2) {
                winAmount = factor2.mul(bets[i].value);
            } else if (winner == 3) {
                winAmount = factor3.mul(bets[i].value);
            } else if (winner == 4) {
                winAmount = factor4.mul(bets[i].value);
            } else {
                winAmount = 0;
            }
            winAmounts.push(winAmount);

            // reset combined bets value tracking
            betLimits[uint(bets[i].betType)][bets[i].number] = 0;
        }

        // notify of results
        emit SpinResult(_tokenName, _landID, numbers, _machineID, winAmounts);

        // reset bets array
        bets.length = 0;

        //return wins
        return (winAmounts, numbers);
    }

    function setJackpots(
        uint256 _factor1,
        uint256 _factor2,
        uint256 _factor3,
        uint256 _factor4
    ) external onlyCEO {
        factor1 = _factor1;
        factor2 = _factor2;
        factor3 = _factor3;
        factor4 = _factor4;
    }

    function getPayoutForType(BetType _betType) public view returns (uint256) {
        if (_betType == BetType.Single) return factor1;
        return 0;
    }

    function randomNumber(bytes32 _localhash) private pure returns (uint256 numbers) {
        return uint256(keccak256(abi.encodePacked(_localhash)));
    }

    function getNecessaryBalance() external view returns (uint256 _necessaryBalance) {

        uint256 _necessaryForBetType;
        uint256 _i;
        uint256[1] memory betTypeMax;

        // determine highest for each betType
        for (_i = 0; _i < bets.length; _i++) {

            Bet memory b = bets[_i];
            _necessaryForBetType = betLimits[uint(b.betType)][b.number].mul(
                getPayoutForType(b.betType)
            );

            if (_necessaryForBetType > betTypeMax[uint(b.betType)]) {
                betTypeMax[uint(b.betType)] = _necessaryForBetType;
            }
        }

        // calculate total for all betTypes
        for (_i = 0; _i < betTypeMax.length; _i++) {
            _necessaryBalance = _necessaryBalance.add(betTypeMax[_i]);
        }
    }

    function getAmountBets() external view returns (uint256) {
        return bets.length;
    }

    function masterChange(address _newMaster) external onlyCEO {
        masterAddress = _newMaster;
    }

}
