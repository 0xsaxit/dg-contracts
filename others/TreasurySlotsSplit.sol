// SPDX-License-Identifier: -- 🎲--

pragma solidity ^0.7.0;

// Slot Machine Logic Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////
// Single Play - Simple Slots - TokenIndex

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessController.sol";
import "../common-contracts/TreasuryInstance.sol";

contract TreasurySlots is AccessController {

    using SafeMath for uint128;

    uint256 private factors;
    TreasuryInstance public treasury;

    mapping (address => mapping(uint8 => uint128)) insertedTokens;
    mapping (address => mapping(uint8 => uint256)) redeemLock;

    struct NextPlay {
        address player;
        uint8 tokenIndex;
        uint128 betAmount;
        bool readyToPlay;
    }

    NextPlay public nextPlay;

    event GameResult(
        address player,
        uint8 tokenIndex,
        uint128 landID,
        uint256 indexed number,
        uint128 indexed machineID,
        uint256 winAmount
    );

    event tokenInserted (
        address player,
        uint8 tokenIndex,
        uint128 betAmount
    );

    constructor(
        address _treasury,
        uint16 factor1,
        uint16 factor2,
        uint16 factor3,
        uint16 factor4
    ) public {
        treasury = TreasuryInstance(_treasury);

        require(
            factor1 > factor2 + factor3 + factor4,
            'Slots: incorrect ratio'
        );

        factors |= uint256(factor1)<<0;
        factors |= uint256(factor2)<<16;
        factors |= uint256(factor3)<<32;
        factors |= uint256(factor4)<<48;
    }

    function insertToken(
        address _player,
        uint128 _betAmount,
        uint8 _tokenIndex
    ) external {

        require(
            treasury.checkApproval(_player, _tokenIndex) >= _betAmount,
            'Slots: exceeded allowance amount'
        );

        require(
            _betAmount > 0 &&
            treasury.getMaximumBet(_tokenIndex) >= _betAmount,
            'Slots: bet is not in available range'
        );

        require(
            nextPlay.readyToPlay == false,
            'Slots: player already inserted a token'
        );

        nextPlay.player = _player;
        nextPlay.tokenIndex = _tokenIndex;
        nextPlay.betAmount = _betAmount;
        nextPlay.readyToPlay = true;

        treasury.tokenInboundTransfer(
            _tokenIndex,
            _player,
            _betAmount
        );

        // insertedTokens[_player][_tokenIndex] = _betAmount;
        // redeemLock[_player][_tokenIndex] = block.timestamp + 12 hours;

        emit tokenInserted(
            _player,
            _tokenIndex,
            _betAmount
        );
    }

    /*
    function redeemToken(uint8 _tokenIndex) external onlyWorker {

        uint128 insertedAmount = insertedTokens[msg.sender][_tokenIndex];

        require(
            insertedAmount > 0,
            'Slots: no tokens inserted'
        );

        require(
            redeemLock[msg.sender][_tokenIndex] > 0 &&
            redeemLock[msg.sender][_tokenIndex] > block.timestamp,
            'Slots: redeem lock is not lifted yet'
        );

        insertedTokens[msg.sender][_tokenIndex] = 0;
        redeemLock[msg.sender][_tokenIndex] = 0;

        treasury.tokenOutboundTransfer(
            _tokenIndex,
            msg.sender,
            insertedAmount
        );
    }*/

    function play(
        uint128 _landID,
        uint128 _machineID,
        bytes32 _localhash
    ) public whenNotPaused onlyWorker {

        require(
            nextPlay.readyToPlay == true,
            'Slots: insert token first'
        );

        address _player = nextPlay.player;
        uint8 _tokenIndex = nextPlay.tokenIndex;
        uint128 _betAmount = nextPlay.betAmount;

        require(
            treasury.checkAllocatedTokens(_tokenIndex) >= getMaxPayout(_betAmount),
            'Slots: not enough tokens for payout'
        );

        nextPlay.readyToPlay = false;

        treasury.consumeHash(
           _localhash
        );

        (uint256 _number, uint256 _winAmount) = _launch(
            _localhash,
            _betAmount
        );

        // insertedTokens[_player][_tokenIndex] = 0;
        // redeemLock[_player][_tokenIndex] = 0;

        if (_winAmount > 0) {
            treasury.tokenOutboundTransfer(
                _tokenIndex,
                _player,
                _winAmount
            );
        }

        emit GameResult(
            _player,
            _tokenIndex,
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

        uint8[5] memory _positions = [255, 0, 16, 32, 48];
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

    function getRandomNumber(
        bytes32 _localhash
    ) private pure returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    _localhash
                )
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
                factors>>0
            )
        );
    }

    function updateFactors(
        uint16 factor1,
        uint16 factor2,
        uint16 factor3,
        uint16 factor4
    ) external onlyCEO {

        require(
            factor1 > factor2 + factor3 + factor4,
            'Slots: incorrect ratio'
        );

        factors = uint256(0);

        factors |= uint256(factor1)<<0;
        factors |= uint256(factor2)<<16;
        factors |= uint256(factor3)<<32;
        factors |= uint256(factor4)<<48;
    }

    function updateTreasury(
        address _newTreasuryAddress
    ) external onlyCEO {
        treasury = TreasuryInstance(
            _newTreasuryAddress
        );
    }

    function migrateTreasury(
        address _newTreasuryAddress
    ) external {
        require(
            msg.sender == address(treasury),
            'Slots: wrong treasury address'
        );
        treasury = TreasuryInstance(_newTreasuryAddress);
    }
}