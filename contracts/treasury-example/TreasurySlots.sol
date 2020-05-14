pragma solidity ^0.5.14;

// Slot Machine Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/TreasuryInstance.sol";

contract TreasurySlots is AccessControl {
    using SafeMath for uint;

    uint256 store;
    uint256 public maxBet;
    uint256 public betSize;
    uint256[] winAmounts;

    enum BetType { Single }

    struct Bet {
        BetType betType;
        address player;
        uint256 number;
        uint256 value;
        string tokenName;
    }

    Bet[] public bets;

    event SpinResult(
        string _tokenName,
        uint256 indexed _landID,
        uint256 _number,
        uint256 indexed _machineID,
        uint256[] _winAmounts
    );

    event GameResult(
        address[] _players,
        string indexed _tokenName,
        uint256 _landID,
        uint256 indexed _number,
        uint256 indexed _machineID,
        uint256[] _winAmounts
    );

    modifier onlyTreasury() {
        require(
            msg.sender == address(treasury),
            'must be current treasury'
        );
        _;
    }

    TreasuryInstance treasury;

    constructor(
        address _treasury,
        uint256 factor1, // 250
        uint256 factor2, // 15
        uint256 factor3, // 8
        uint256 factor4, // 4
        uint256 _maxBet  // ?
    ) public {
        treasury = TreasuryInstance(_treasury);
        store |= factor1<<192;
        store |= factor2<<208;
        store |= factor3<<224;
        store |= factor4<<240;
        maxBet = _maxBet;
    }

    function bet(
        uint256 _betType,
        address _player,
        uint256 _number,
        uint256 _value,
        string memory _tokenName
    ) internal {

        require(_player != address(0x0), "player undefined");
        require(_betType == uint(BetType.Single), 'bet undefined');

        betSize = betSize.add(_value);

        require (
            betSize <= maxBet,
            "total bet exceeding limit"
        );

        Bet memory newBet;
        newBet.betType = BetType.Single;
        newBet.player = _player;
        newBet.number = _number;
        newBet.value = _value;
        newBet.tokenName = _tokenName;
        bets.push(newBet);
    }

    function createBet(
        uint _betType,
        address _player,
        uint _number,
        uint _value,
        string calldata _tokenName
    ) external whenNotPaused onlyCEO {
        bet(
            _betType,
            _player,
            _number,
            _value,
            _tokenName
        );
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

        treasury.consumeHash(_localhash);

        // set bets for the game
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
                _betAmount[i],
                _tokenName
            );

        }

        require(
            getNecessaryBalance() <= treasury.checkAllocatedTokens(_tokenName),
            "not enough tokens for payout"
        );

        delete betSize;

        uint256 number;
        (winAmounts, number) = _launch(
            _localhash,
            _machineID,
            _landID,
            _tokenName
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

    function launch(
        bytes32 _localhash,
        uint256 _machineID,
        uint256 _landID,
        string calldata _tokenName
    ) external whenNotPaused onlyCEO returns(uint256[] memory, uint256 number) {
        return _launch(
            _localhash,
            _machineID,
            _landID,
            _tokenName
        );
    }

    function _launch(
        bytes32 _localhash,
        uint256 _machineID,
        uint256 _landID,
        string memory _tokenName
    ) internal returns (uint256[] memory, uint256 numbers) {

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

        emit SpinResult(_tokenName, _landID, numbers, _machineID, winAmounts);
        return (winAmounts, numbers);
    }

    function updateFactors(
        uint256 _factor1,
        uint256 _factor2,
        uint256 _factor3,
        uint256 _factor4
    ) external onlyCEO {
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

    function getTreasuryAddress() external view returns (address) {
        return address(treasury);
    }

    function randomNumber(bytes32 _localhash) private pure returns (uint256 numbers) {
        return uint256(keccak256(abi.encodePacked(_localhash)));
    }

    function getNecessaryBalance() public view returns (uint256) {
        return betSize.mul(
            uint16(store>>192)
        );
    }

    function getAmountBets() external view returns (uint256) {
        return bets.length;
    }

    function changeTreasury(address _newTreasuryAddress) external onlyCEO {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }

    function _changeTreasury(address _newTreasuryAddress) external onlyTreasury {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }
}
