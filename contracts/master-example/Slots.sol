pragma solidity ^0.5.14;

// Slot Machine Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";

contract SlotMachineLogic is AccessControl {
    using SafeMath for uint;

    uint256 store;
    uint256 maxBet;
    uint256[] winAmounts;

    enum BetType { Single }

    struct Bet {
        BetType betType;
        address player;
        uint256 number;
        uint256 value;
    }

    Bet[] public bets;
    uint256 betLimit;

    event SpinResult(
        string _tokenName,
        uint256 indexed _landID,
        uint256 _number,
        uint256 indexed _machineID,
        uint256[] _winAmounts
    );

    constructor(
        address _masterAddress,
        uint256 factor1, // 250
        uint256 factor2, // 15
        uint256 factor3, // 8
        uint256 factor4, // 4
        uint256 _maxBet  // ?
    ) public {
        store = uint256(_masterAddress);
        store |= factor1<<192;
        store |= factor2<<208;
        store |= factor3<<224;
        store |= factor4<<240;
        maxBet = _maxBet;
    }

    modifier onlyMaster {
        require(
            msg.sender == address(store),
            'can only be called by master/parent contract'
        );
        _;
    }

    function createBet(
        BetType _betType,
        address _player,
        uint256 _number,
        uint256 _value
    ) external onlyMaster {

        require(_player != address(0x0), "player undefined");
        require(_number == 0, "number must be 0");
        require(_value > 0, "bet value must be > 0");

        betLimit = betLimit.add(_value);

        require(
            betLimit <= maxBet,
            'exceeding maximum bet limit'
        );

        Bet memory newBet;
        newBet.betType = _betType;
        newBet.player = _player;
        newBet.number = _number;
        newBet.value = _value;
        bets.push(newBet);
    }

    function launch(
        bytes32 _localhash,
        uint256 _machineID,
        uint256 _landID,
        string calldata _tokenName
    ) external onlyMaster returns (uint256[] memory, uint256 numbers) {

        numbers = randomNumber(_localhash) % 1000;

        uint256 winAmount;
        uint256 number = numbers;
        delete winAmounts;

        uint8[10] memory symbols = [4, 4, 4, 4, 3, 3, 3, 2, 2, 1];
        uint256 winner = symbols[number % 10];

        for (uint256 i = 0; i < 2; i++) {
            number = uint256(number) / 10; // shift
            if (symbols[number % 10] != winner) {
                winner = 0;
                break;
            }
        }

        uint8[5] memory positions = [255, 192, 208, 224, 240];
        for (uint256 i = 0; i < bets.length; i++) {
            winAmount = bets[i].value.mul(
                uint16(store>>positions[winner])
            );
            winAmounts.push(winAmount);
        }

        delete bets;
        delete betLimit;

        emit SpinResult(_tokenName, _landID, numbers, _machineID, winAmounts);
        return (winAmounts, numbers);
    }

    function updateSettings(
        address _newMaster,
        uint256 _factor1,
        uint256 _factor2,
        uint256 _factor3,
        uint256 _factor4
    ) external onlyCEO {
        store = uint256(_newMaster);
        store |= _factor1<<192;
        store |= _factor2<<208;
        store |= _factor3<<224;
        store |= _factor4<<240;
    }

    function updateMaxBet(uint256 _newMaxBet) external onlyCEO {
        maxBet = _newMaxBet;
    }

    function getPayoutFactor(uint256 _position) external view returns (uint16) {
       return uint16(store>>_position);
    }

    function getMasterAddress() external view returns (address) {
        return address(store);
    }

    function randomNumber(bytes32 _localhash) private pure returns (uint256 numbers) {
        return uint256(keccak256(abi.encodePacked(_localhash)));
    }

    function getNecessaryBalance() external view returns (uint256) {
        return betLimit.mul(
            uint16(store>>192)
        );
    }

    function getAmountBets() external view returns (uint256) {
        return bets.length;
    }

}
