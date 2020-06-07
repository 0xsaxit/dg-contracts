pragma solidity ^0.5.14;

// Slot Machine Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////
// Single Play - Simple Slots

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/TreasuryInstance.sol";

contract TreasurySlotsV2 is AccessControl {

    using SafeMath for uint128;

    struct Play {
        address player;
        uint128 value;
        uint128 token;
    }

    uint256 factors;

    event GameResult(
        address _player,
        string indexed _token,
        uint128 _landID,
        uint256 indexed _number,
        uint128 indexed _machineID,
        uint256 _winAmount
    );

    modifier onlyTreasury() {
        require(
            msg.sender == address(treasury),
            'Slots: un-authorized call detected'
        );
        _;
    }

    TreasuryInstance public treasury;

    constructor(
        address _treasury,
        uint16 factor1,
        uint16 factor2,
        uint16 factor3,
        uint16 factor4
    ) public {
        treasury = TreasuryInstance(_treasury);
        factors |= factor1<<192;
        factors |= factor2<<208;
        factors |= factor3<<224;
        factors |= factor4<<240;
    }

    function play(
        address _player,
        uint128 _landID,
        uint128 _machineID,
        uint128 _betAmount,
        bytes32 _localhash,
        uint128 _tokenIndex
    ) public whenNotPaused onlyWorker {

        string memory _tokenName = treasury.tokenNames(_tokenIndex);

        require(
            treasury.checkApproval(_player, _tokenName) >= _betAmount,
            'Slots: exceeded allowance amount'
        );

        require(
            treasury.getMaximumBet(_tokenName) >= _betAmount,
            'Slots: exceeded maximum bet amount'
        );

        require(
            treasury.checkAllocatedTokens(_tokenName) >= getMaxPayout(_betAmount),
            "Slots: not enough tokens for payout"
        );

        treasury.tokenInboundTransfer(
            _tokenName,
            _player,
            _betAmount
        );

        treasury.consumeHash(
           _localhash
        );

        (uint256 _number, uint256 _winAmount) = _launch(
            _localhash,
            _betAmount
        );

        if (_winAmount > 0) {
            treasury.tokenOutboundTransfer(
                _tokenName,
                _player,
                _winAmount
            );
        }

        emit GameResult(
            _player,
            _tokenName,
            _landID,
            _number,
            _machineID,
            _winAmount
        );
    }

    function _launch(
        bytes32 _localhash,
        uint128 _betAmount
    ) internal view returns (
        uint256 number,
        uint256 winAmount
    ) {
        number = getRandomNumber(_localhash) % 1000;
        uint256 _numbers = number;

        uint8[5] memory _positions = [255, 192, 208, 224, 240];
        uint8[10] memory _symbols = [4, 4, 4, 4, 3, 3, 3, 2, 2, 1];
        uint256 _winner = _symbols[_numbers % 10];

        for (uint256 i = 0; i < 2; i++) {
            _numbers = uint256(_numbers) / 10;
            if (_symbols[_numbers % 10] != _winner) {
                _winner = 0;
                break;
            }
        }

        delete _symbols;
        delete _numbers;

        winAmount = _betAmount.mul(
            uint16(
                factors>>_positions[_winner]
            )
        );
    }

    function updateFactors(
        uint16 _factor1,
        uint16 _factor2,
        uint16 _factor3,
        uint16 _factor4
    ) external onlyCEO {
        factors |= _factor1<<192;
        factors |= _factor2<<208;
        factors |= _factor3<<224;
        factors |= _factor4<<240;
    }

    function getRandomNumber(
        bytes32 _localhash
    ) private pure returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(_localhash)
            )
        );
    }

    function getPayoutFactor(
        uint8 _position
    ) external view returns (uint16) {
       return uint16(
           factors>>_position
        );
    }

    function getMaxPayout(
        uint128 _betSize
    ) public view returns (uint256) {
        return _betSize.mul(
            uint16(
                factors>>192
            )
        );
    }

    function updateTreasury(
        address _newTreasuryAddress
    ) external onlyCEO {
        treasury = TreasuryInstance(
            _newTreasuryAddress
        );
    }
}
