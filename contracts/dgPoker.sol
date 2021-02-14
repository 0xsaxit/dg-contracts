// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.4;

import "./common-contracts/TreasuryInstance.sol";
import "./common-contracts/AccessController.sol";
import "./common-contracts/PointerInstance.sol";
import "./common-contracts/SafeMath.sol";

contract dgPoker is AccessController {

    using SafeMath for uint256;

    enum GameState { NewGame, OnGoingGame, EndedGame }
    enum PlayerState { notInGame, inGame, hasFolded, hasLost, hasWon }

    struct Game {
        address[] players;
        uint256[] entryBets;
        uint256[] approvals;
        uint256 wageredTotal;
        uint8 tokenIndex;
        uint8 playersCount;
        PlayerState[] pState;
        GameState state;
    }

    mapping(bytes16 => Game) public Games;

    modifier onlyOnGoingGames(bytes16 _gameId) {
        require(
            Games[_gameId].state == GameState.OnGoingGame,
            "onlyOnGoingGames: not OnGoingGame"
        );
        _;
    }

    modifier onlyInGamePlayer(bytes16 _gameId, uint8 _playerIndex) {
        require(
            Games[_gameId].pState[_playerIndex] == PlayerState.inGame,
            "onlyInGamePlayer: player not inGame"
        );
        _;
    }

    modifier checkPlayerIndex(bytes16 _gameId, uint8 _playerIndex, address _playerAddress) {
        require(
            Games[_gameId].players[_playerIndex] == _playerAddress,
            "checkPlayerIndex: invalid _playerAddress"
        );
        _;
    }

    TreasuryInstance public treasury;

    struct Globals {
        uint256[] maxBet;
        uint256[] maxApproval;
        uint256 nonce;
        uint8 maxPlayers;
        uint8 houseFee;
    }

    Globals public globals;

    event ApprovedAmountTaken(
        uint8 indexed tokenIndex,
        address indexed player,
        uint256 approvedAmount
    );

    event EntryBetPlaced(
        uint8 indexed tokenIndex,
        address indexed player,
        uint256 betAmount
    );

    event GameInitializing(
        bytes16 indexed gameId
    );

    event GameInitialized(
        bytes16 indexed gameId,
        uint256[] entryBets,
        uint256[] approvals,
        uint8 tokenIndex,
        uint256 indexed landId,
        uint256 indexed tableId
    );

    event PlayerFolded(
        bytes16 indexed gameId,
        uint8 indexed playerIndex,
        address indexed playerAddress
    );

    event PlayerRefunded(
        bytes16 indexed gameId,
        address indexed player,
        uint256 indexed entryBet,
        uint256 refundAmount,
        uint256 wageredAmount,
        uint256 approvedAmount
    );

    event PlayerWon(
        bytes16 indexed gameId,
        address indexed player,
        uint256 indexed entryBet,
        uint256 winAmount,
        uint256 wageredAmount,
        uint256 approvedAmount
    );

    event FinishedGame(
        bytes16 indexed gameId
    );

    PointerInstance public pointerContract;

    constructor(
        address _treasuryAddress,
        uint8 _maxPlayers,
        uint8 _houseFee,
        address _pointerAddress

    ) {
        require(_maxPlayers < 10);
        require(_houseFee < 10);

        treasury = TreasuryInstance(_treasuryAddress);
        globals.maxPlayers = _maxPlayers;
        globals.houseFee = _houseFee;
        pointerContract = PointerInstance(_pointerAddress);
    }

    function changeHouseFee(
        uint8 _newHouseFee
    )
        external
        onlyCEO
    {
        require(_newHouseFee < 10);
        globals.houseFee = _newHouseFee;
    }

    function changeMaxPlayer(
        uint8 _newMaxPlayer
    )
        external
        onlyCEO
    {
        require(_newMaxPlayer < 10);
        globals.maxPlayers = _newMaxPlayer;
    }

    function changeMaxBet(
        uint8 _tokenIndex,
        uint8 _newMaxBet
    )
        external
        onlyCEO
    {
        require(
            _newMaxBet < globals.maxApproval[_tokenIndex]
        );
        globals.maxBet[_tokenIndex] = _newMaxBet;
    }

    function changeMaxApproval(
        uint8 _tokenIndex,
        uint8 _newMaxApproval
    )
        external
        onlyCEO
    {
        require(
            _newMaxApproval > globals.maxBet[_tokenIndex]
        );
        globals.maxApproval[_tokenIndex] = _newMaxApproval;
    }

    function _addPoints(
        address _player,
        uint256 _points,
        address _token,
        uint256 _numPlayers,
        uint256 _wearableBonus
    )
        private
    {
        pointerContract.addPoints(
            _player,
            _points,
            _token,
            _numPlayers,
            _wearableBonus
        );
    }

    function takeApprovedAmount(
        bytes16 _gameId,
        uint8 _playerIndex
    )
        private
    {
        uint8 tokenIndex = Games[_gameId].tokenIndex;
        address player = Games[_gameId].players[_playerIndex];
        uint256 approvalAmount = Games[_gameId].approvals[_playerIndex];

        require(
            treasury.getMaximumBet(tokenIndex) >= approvalAmount,
            "takeApprovedAmount: approvalAmount must be below treasury limit"
        );

        require(
            globals.maxApproval[tokenIndex] >= approvalAmount,
            "takeApprovedAmount: approvalAmount must be below game limit"
        );

        treasury.tokenInboundTransfer(
            tokenIndex, player, approvalAmount
        );

        emit ApprovedAmountTaken(
            tokenIndex, player, approvalAmount
        );
    }

    function placeEntryBet(
        bytes16 _gameId,
        uint8 _playerIndex
    )
        private
    {
        uint8 tokenIndex = Games[_gameId].tokenIndex;
        address player = Games[_gameId].players[_playerIndex];
        uint256 entryBet = Games[_gameId].entryBets[_playerIndex];

        require(
            globals.maxBet[tokenIndex] >= entryBet,
            "placeEntryBet: entryBet must be below game limit"
        );

        Games[_gameId].wageredTotal =
        Games[_gameId].wageredTotal.add(entryBet);

        emit EntryBetPlaced(
            tokenIndex, player, entryBet
        );
    }

    function initializePlayer(
        bytes16 _gameId,
        uint8 _playerIndex
    )
        private
    {
        require(
            Games[_gameId].pState[_playerIndex] == PlayerState.notInGame ||
            Games[_gameId].pState[_playerIndex] == PlayerState.hasFolded ||
            Games[_gameId].pState[_playerIndex] == PlayerState.hasLost ||
            Games[_gameId].pState[_playerIndex] == PlayerState.hasWon,
            "initializePlayer: invalid playerState detected"
        );

        Games[_gameId].pState[_playerIndex] = PlayerState.inGame;
    }

    function initializeGame(
        address[] calldata _players,
        uint256[] calldata _entryBets,
        uint256[] calldata _approvals,
        uint8 _tokenIndex,
        uint256 _serverId,
        uint256 _landId,
        uint256 _tableId
    )
        external
        whenNotPaused
        onlyWorker
        returns (bytes16 gameId)
    {
        require(
            _players.length <= globals.maxPlayers &&
            _entryBets.length == _players.length &&
            _players.length == _approvals.length,
            "initializeGame: invalid length in initializeGame"
        );

        gameId = getGameId(
            _serverId,
            _landId,
            _tableId,
            _players,
            globals.nonce
        );

        globals.nonce = globals.nonce + 1;

        require(
            Games[gameId].state == GameState.NewGame ||
            Games[gameId].state == GameState.EndedGame,
            "initializeGame: invalid GameState detected"
        );

        emit GameInitializing(
            gameId
        );

        Game memory _game = Game(
            _players,
            _entryBets,
            _approvals,
            0,
            _tokenIndex,
            uint8(_players.length),
            new PlayerState[](_players.length),
            GameState.OnGoingGame
        );

        Games[gameId] = _game;

        for (uint8 playerIndex = 0; playerIndex < _players.length; playerIndex++) {

            initializePlayer(
                gameId, playerIndex
            );

            takeApprovedAmount(
                gameId, playerIndex
            );

            placeEntryBet(
                gameId, playerIndex
            );
        }

        emit GameInitialized(
            gameId,
            _entryBets,
            _approvals,
            _tokenIndex,
            _landId,
            _tableId
        );
    }

    function playerFolds(
        bytes16 _gameId,
        address _foldPlayer,
        uint8 _playerIndex,
        uint256 _wageredAmount,
        uint256 _refundAmount
    )
        external
        onlyOnGoingGames(_gameId)
        onlyInGamePlayer(_gameId, _playerIndex)
        whenNotPaused
        onlyWorker
    {
        _refundPlayer(
            _gameId,
            Games[_gameId].tokenIndex,
            _playerIndex,
            _foldPlayer,
            _wageredAmount,
            _refundAmount
        );

        Games[_gameId].pState[_playerIndex] = PlayerState.hasFolded;

        emit PlayerFolded(
            _gameId,
            _playerIndex,
            _foldPlayer
        );
    }

    function manualPayout(
        bytes16 _gameId,
        address _winPlayerAddress,
        uint8 _winPlayerIndex,
        uint256 _winAmount,
        uint256[] calldata _wageredAmounts,
        uint256[] calldata _refundAmounts
        // uint256[] calldata _wearableBonus
    )
        external
        onlyOnGoingGames(_gameId)
        whenNotPaused
        onlyWorker
    {
        uint8 playersCount = Games[_gameId].playersCount;

        require(
            playersCount == _wageredAmounts.length &&
            playersCount == _refundAmounts.length,
            "manualPayout: invalid playersCount"
        );

        _payoutLoss(
            _gameId,
            _winPlayerAddress,
            _wageredAmounts,
            _refundAmounts
            // _wearableBonus
        );

        _payoutWin(
            _gameId,
            _winPlayerIndex,
            _winPlayerAddress,
            _winAmount,
            _wageredAmounts[_winPlayerIndex]
        );

        Games[_gameId].state = GameState.EndedGame;

        emit FinishedGame(
            _gameId
        );
    }

    function _payoutLoss(
        bytes16 _gameId,
        address _winPlayerAddress,
        uint256[] calldata _wageredAmounts,
        uint256[] calldata _refundAmounts
        // uint256[] calldata _wearableBonus
    )
        private
    {
        for (uint8 i = 0; i < _refundAmounts.length; i++) {

            address _playerAddress = Games[_gameId].players[i];

            if (
                _playerAddress != _winPlayerAddress &&
                Games[_gameId].pState[i] == PlayerState.inGame
            ) {
                _refundPlayer(
                    _gameId,
                    Games[_gameId].tokenIndex,
                    i,
                    _playerAddress,
                    _refundAmounts[i],
                    _wageredAmounts[i]
                );

                Games[_gameId].wageredTotal =
                Games[_gameId].wageredTotal.add(_wageredAmounts[i]);

                Games[_gameId].pState[i] = PlayerState.hasLost;
            }
        }
    }

    function _payoutWin(
        bytes16 _gameId,
        uint8 _playerIndex,
        address _playerAddress,
        uint256 _winAmount,
        uint256 _wageredAmount
    )
        private
        onlyOnGoingGames(_gameId)
        onlyInGamePlayer(_gameId, _playerIndex)
        checkPlayerIndex(_gameId, _playerIndex, _playerAddress)
    {
        uint256 wageredTotal = Games[_gameId].wageredTotal;

        uint256 returnApproval = Games[_gameId].approvals[_playerIndex];
        uint256 returnEntryBet = Games[_gameId].entryBets[_playerIndex];

        require(
            _winAmount == wageredTotal
                .add(returnApproval)
                .add(returnEntryBet),
            "_payoutWin: invalid _winAmount"
        );

        _proceedWithPayout(
            _gameId,
            _playerIndex,
            _winAmount
        );

        emit PlayerWon(
            _gameId,
            _playerAddress,
            returnEntryBet,
            _winAmount,
            _wageredAmount,
            returnApproval
        );
    }

    function _proceedWithPayout(
        bytes16 _gameId,
        uint8 _playerIndex,
        uint256 _winAmount
    )
        private
    {
        treasury.tokenOutboundTransfer(
           Games[_gameId].tokenIndex,
           Games[_gameId].players[_playerIndex],
           _winAmount
        );
    }

    function _refundPlayer(
        bytes16 _gameId,
        uint8 _tokenIndex,
        uint8 _playerIndex,
        address _playerAddress,
        uint256 _wageredAmount,
        uint256 _refundAmount
    )
        private
        onlyOnGoingGames(_gameId)
        onlyInGamePlayer(_gameId, _playerIndex)
        checkPlayerIndex(_gameId, _playerIndex, _playerAddress)
    {
        uint256 entryBet = Games[_gameId].entryBets[_playerIndex];
        uint256 approvedAmount = Games[_gameId].approvals[_playerIndex];

        require(
            _refundAmount == approvedAmount
                .sub(entryBet)
                .sub(_wageredAmount),
            "_refundPlayer: invalid _refundAmount"
        );

        treasury.tokenOutboundTransfer(
            _tokenIndex, _playerAddress, _refundAmount
        );

        emit PlayerRefunded(
            _gameId,
            _playerAddress,
            entryBet,
            _refundAmount,
            _wageredAmount,
            approvedAmount
        );
    }

    function _smartPoints(
        bytes16 _gameId,
        uint8 _playerIndex,
        uint256 _refundAmount,
        uint256 _wearableBonus
    )
        internal
    {
        require(
            Games[_gameId].approvals[_playerIndex] >= _refundAmount,
            "_smartPoints: invalid _refundAmount"
        );

        _addPoints(
            Games[_gameId].players[_playerIndex],
            Games[_gameId].entryBets[_playerIndex] - _refundAmount,
            treasury.getTokenAddress(Games[_gameId].tokenIndex),
            Games[_gameId].players.length,
            _wearableBonus
        );
    }

    function getGameId(
        uint256 _serverID,
        uint256 _landID,
        uint256 _tableID,
        address[] memory _players,
        uint256 _nonce
    )
        public
        pure
        returns (bytes16 gameId)
    {
        gameId = bytes16(
            keccak256(
                abi.encodePacked(_serverID, _landID, _tableID, _players, _nonce)
            )
        );
    }

    function updatePointer(
        address _newPointerAddress
    )
        external
        onlyCEO
    {
        pointerContract = PointerInstance(_newPointerAddress);
    }
}