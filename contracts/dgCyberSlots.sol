// SPDX-License-Identifier: -- 🎰 --

pragma solidity ^0.8.0;

// Cyber Slot Machine Contract ///////////////////////////////////////////////////////////
// Author: Decentral Games (hello@decentral.games) ///////////////////////////////////////
// Single Play - Cyber Slots - TokenIndex

import "./common-contracts/MultiController.sol";
import "./common-contracts/MultiHashChain.sol";
import "./common-contracts/TreasuryInstance.sol";
import "./common-contracts/PointerInstance.sol";

contract dgCyberSlots is MultiController, MultiHashChain {

    TreasuryInstance public treasury;
    PointerInstance public pointerContract;

    bytes30[5] public reels;
    uint256 public blockGap = 10; // adjustable

    // keeps track of deposited amount and unlocks
    mapping(address => mapping(uint8 => uint256)) depositAmount;
    mapping(address => mapping(uint8 => uint256)) withdrawBlock;

    event PlayerDeposit(
        address indexed _playerAddress,
        uint256 _depositAmount,
        uint8 indexed _tokenIndex
    );

    event PlayerPayed(
        address indexed _playerAddress,
        uint256 _payoutAmount,
        uint8 indexed _tokenIndex
    );

    event SpinResult(
        address indexed _player,
        uint8 indexed _tokenIndex,
        uint128 _landID,
        uint128 indexed _machineID,
        uint256 _winAmount
    );

    constructor(
        // address _treasury,
        // address _pointerAddress
    )
    {
        treasury = TreasuryInstance(
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 // _treasury
        );

        pointerContract = PointerInstance(
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 // _pointerAddress
        );

        // can be adjustable
        reels[0] = 0x09010502010604030602030501040B080302040103070502010705020306;
        reels[1] = 0x09010502010604030602030501040B080302040103070502010705020306;
        reels[2] = 0x09010502010604030602030501040B080302040103070502010705020306;
        reels[3] = 0x09010502010604030602030501040B080302040103070502010705020306;
        reels[4] = 0x09010502010604030602030501040B080302040103070502010705020306;
    }

    function depositToPlay(
        address _playerAddress,
        uint256 _depositAmount,
        uint8 _tokenIndex
    )
        external
        onlyWorker
    {
        treasury.tokenInboundTransfer(
            _tokenIndex,
            _playerAddress,
            _depositAmount
        );

        depositAmount[_playerAddress][_tokenIndex] =
        depositAmount[_playerAddress][_tokenIndex] + _depositAmount;

        emit PlayerDeposit(
            _playerAddress,
            _depositAmount,
            _tokenIndex
        );
    }

    function finalizePlay(
        address _playerAddress,
        uint8 _tokenIndex
    )
        external
        onlyWorker
    {
        require(
            withdrawBlock[_playerAddress][_tokenIndex] == 0,
            'CyberSlots: withdrawal block already announced'
        );

        withdrawBlock[_playerAddress][_tokenIndex] = getBlock() + blockGap;
    }

    function payoutPlayer(
        address _playerAddress,
        uint8 _tokenIndex
    )
        external
        onlyWorker
    {
        require(
            withdrawBlock[_playerAddress][_tokenIndex] > 0 &&
            withdrawBlock[_playerAddress][_tokenIndex] < getBlock(),
            'CyberSlots: invalid withdrawal block'
        );

        _doPayout(
            _tokenIndex,
            _playerAddress,
            depositAmount[_playerAddress][_tokenIndex]
        );
    }

    function _doPayout(
        uint8 _tokenIndex,
        address _playerAddress,
        uint256 _payoutAmount
    )
        private
    {
        delete depositAmount[_playerAddress][_tokenIndex];
        delete withdrawBlock[_playerAddress][_tokenIndex];

        treasury.tokenOutboundTransfer(
            _tokenIndex,
            _playerAddress,
            _payoutAmount
        );

        emit PlayerPayed(
            _playerAddress,
            _payoutAmount,
            _tokenIndex
        );
    }

    function play(
        address _player,
        uint128 _landID,
        uint128 _machineID,
        uint128 _betAmount,
        uint128 _payoutAmount,
        bytes32 _localhash,
        bytes5 _result,
        uint8 _tokenIndex,
        uint256 _wearableBonus
    )
        external
        onlyWorker
    {
        require(
            treasury.checkApproval(_player, _tokenIndex) >= _betAmount,
            'CyberSlots: exceeded allowance amount'
        );

        require(
            treasury.getMaximumBet(_tokenIndex) >= _betAmount,
            'CyberSlots: exceeded maximum bet amount'
        );

        require(
            treasury.checkAllocatedTokens(_tokenIndex) >= _payoutAmount,
            'CyberSlots: not enough tokens for payout in treasury'
        );

        require(
            withdrawBlock[_player][_tokenIndex] == 0,
            'CyberSlots: withdrawal block detected'
        );

        _consumeMachineHash(
            _machineID,
            _localhash
        );

        _verifyResult(
            _localhash,
            _result
        );

        if (_payoutAmount > 0) {

            depositAmount[_player][_tokenIndex] =
            depositAmount[_player][_tokenIndex] + _payoutAmount;

        } else {

            depositAmount[_player][_tokenIndex] =
            depositAmount[_player][_tokenIndex] - _betAmount;

        }

        pointerContract.addPoints(
            _player,
            _betAmount,
            treasury.getTokenAddress(_tokenIndex),
            1,
            _wearableBonus
        );

        emit SpinResult(
            _player,
            _tokenIndex,
            _landID,
            _machineID,
            _payoutAmount
        );
    }

    function _verifyResult(
        bytes32 _localhash,
        bytes5 _result
    )
        private
        view
    {
        for (uint256 i = 0; i < reels.length; i++) {
            uint256 number = getRandomNumber(_localhash, i) % reels[i].length;
            require(
                _result[i] == getSymbol(i, number),
                'CyberSlots: invalid result'
            );
        }
    }

    function getRandomNumber(
        bytes32 _localhash,
        uint256 _reelnumber
    )
        private
        pure
        returns (uint256)
    {
        return uint256(
            keccak256(
                abi.encodePacked(
                    _localhash, _reelnumber
                )
            )
        );
    }

    function getSymbol(
        uint256 _reel,
        uint256 _index
    )
        public
        view
        returns (bytes1)
    {
        return reels[_reel][_index];
    }

    function getBlock()
        public
        view
        returns (uint256)
    {
        return block.number;
    }
}
