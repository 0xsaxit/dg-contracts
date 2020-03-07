pragma solidity ^0.5.14;

// Slot Machine Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////
import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";

contract SlotMachineLogic is AccessControl {
    using SafeMath for uint256;

    uint256[] public currentBets;
    uint256 public factor1;
    uint256 public factor2;
    uint256 public factor3;
    uint256 public factor4;

    uint256[] winAmounts;

    event SpinResult(
        string _tokenName,
        uint256 _landID,
        uint256 indexed _number,
        uint256 indexed _machineID,
        uint256[] indexed _winAmounts
    );

    constructor() public payable {
        //default factor multipliers
        factor1 = 250;
        factor2 = 15;
        factor3 = 8;
        factor4 = 4;
    }

    uint256[] symbols; // array to hold symbol integer groups

    function createBet(uint _betID, address _player, uint _number, uint _value) external {
        require(_player != address(0), 'please provide player parameter');
        require(_number >= 0, 'please provide _number parameter');
        require(_value > 0, 'bet value should be more than 0 ');
        if (_betID == 1101) {
            currentBets.push(_value);
        }
    }

    function launch(
        bytes32 _localhash,
        uint256 _machineID,
        uint256 _landID,
        string calldata _tokenName
    ) external returns (uint256[] memory, uint256 numbers) {
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

        for (uint i = 0; i < currentBets.length; i++) {
            if (winner == 1) {
                winAmount = factor1.mul(currentBets[i]);
            } else if (winner == 2) {
                winAmount = factor2.mul(currentBets[i]);
            } else if (winner == 3) {
                winAmount = factor3.mul(currentBets[i]);
            } else if (winner == 4) {
                winAmount = factor4.mul(currentBets[i]);
            } else {
                winAmount = 0;
            }
            winAmounts.push(winAmount);
        }

        currentBets.length = 0;
        emit SpinResult(_tokenName, _landID, numbers, _machineID, winAmounts);

        //return wins
        return(winAmounts, number);
    }

    function setJackpots(uint256 _factor1, uint256 _factor2, uint256 _factor3, uint256 _factor4) external onlyCEO {
        factor1 = _factor1;
        factor2 = _factor2;
        factor3 = _factor3;
        factor4 = _factor4;
    }

    function getPayoutForType(uint256 _betID) public view returns(uint256) {
        if (_betID == 1101) return factor1; //return highest possible win
    }

    function randomNumber(bytes32 _localhash) private pure returns (uint256 numbers) {
        return
            uint256(
                keccak256(abi.encodePacked(_localhash))
            );
    }
}
