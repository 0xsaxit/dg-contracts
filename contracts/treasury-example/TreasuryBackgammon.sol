pragma solidity ^0.5.17;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessController.sol";
import "../common-contracts/TreasuryInstance.sol";

contract TreasuryBackgammon is AccessController {

    using SafeMath for uint256;
    enum GameState {NewGame, OnGoingGame, DoublingStage, GameEnded}

    event GameStarted(
        uint256 gameId,
        address indexed playerOne,
        address indexed playerTwo,
        uint8 tokenIndex
    );

    event StakeRaised(
        uint256 gameId,
        address indexed player,
        uint256 stake
    );

    event StakeDoubled(
        uint256 gameId,
        address indexed player,
        uint256 totalStaked
    );

    event PlayerDropped(
        uint256 gameId,
        address indexed player
    );

    event GameResolved(
        uint256 gameId,
        address indexed winner
    );

    struct Game {
        uint256 stake;
        uint256 total;
        address playerOne;
        address playerTwo;
        address lastStaker;
        uint8 tokenIndex;
        GameState state;
    }

    uint256 private data;
    mapping(uint256 => Game) public currentGames;

    modifier onlyDoublingStage(uint256 gameId) {
        require(
            currentGames[gameId].state == GameState.DoublingStage,
            'must be proposed to double first by one of the players'
        );
        _;
    }

    modifier onlyOnGoingGame(uint256 gameId) {
        require(
            currentGames[gameId].state == GameState.OnGoingGame,
            'must be ongoing game'
        );
        _;
    }

    modifier isPlayerInGame(uint256 gameId, address player) {
        require(
            player == currentGames[gameId].playerOne ||
            player == currentGames[gameId].playerTwo,
            'must be one of the players'
        );
        _;
    }

    modifier onlyTreasury() {
        require(
            msg.sender == address(treasury),
            'must be current treasury'
        );
        _;
    }

    TreasuryInstance public treasury;

    constructor(address _treasuryAddress) public {
        treasury = TreasuryInstance(_treasuryAddress);
        data |= 64<<128;
        data |= 10<<192;
    }

    function initializeGame(
        uint256 _defaultStake,
        address _playerOneAddress,
        address _playerTwoAddress,
        uint8 _tokenIndex
    ) external whenNotPaused onlyWorker returns (bool) {

        require(
            address(_playerOneAddress) != address(_playerTwoAddress),
            'must be two different players'
        );

        uint256 gameId = uint256(
            keccak256(abi.encodePacked(_playerOneAddress, _playerTwoAddress))
        );

        require(
            currentGames[gameId].state == GameState.NewGame ||
            currentGames[gameId].state == GameState.GameEnded,
            'cannot initialize running game'
        );

        require(
            treasury.tokenAddress(_tokenIndex) != address(0x0),
            'token is not delcared in treasury!'
        );

        require(
            _defaultStake <= treasury.getMaximumBet(_tokenIndex),
            'exceeding maximum bet defined in treasury'
        );

        require(
            _defaultStake.mul(uint64(data>>128)) <= treasury.checkApproval(_playerOneAddress, _tokenIndex),
            'P1 must approve/allow treasury as spender'
        );

        require(
            _defaultStake.mul(uint64(data>>128)) <= treasury.checkApproval(_playerTwoAddress, _tokenIndex),
            'P2 must approve/allow treasury as spender'
        );

        treasury.tokenInboundTransfer(_tokenIndex, _playerOneAddress, _defaultStake);
        treasury.tokenInboundTransfer(_tokenIndex, _playerTwoAddress, _defaultStake);

        Game memory _game = Game(
            _defaultStake,
            _defaultStake.mul(2),
            _playerOneAddress,
            _playerTwoAddress,
            address(0),
            _tokenIndex,
            GameState.OnGoingGame
        );

        currentGames[gameId] = _game;

        emit GameStarted(
            gameId,
            _playerOneAddress,
            _playerTwoAddress,
            _tokenIndex
        );
    }

    function raiseDouble(uint256 _gameId, address _playerRaising)
        external
        whenNotPaused
        onlyWorker
        onlyOnGoingGame(_gameId)
        isPlayerInGame(_gameId, _playerRaising)
    {
        require(
            address(_playerRaising) !=
            address(currentGames[_gameId].lastStaker),
            'same player cannot raise double again'
        );

        require(
            treasury.tokenInboundTransfer(
                currentGames[_gameId].tokenIndex,
                _playerRaising,
                currentGames[_gameId].stake
            ),
            'raising double transfer failed'
        );

        currentGames[_gameId].state = GameState.DoublingStage;
        currentGames[_gameId].lastStaker = _playerRaising;
        currentGames[_gameId].total = currentGames[_gameId].total.add(
            currentGames[_gameId].stake
        );

        emit StakeRaised(
            _gameId,
            _playerRaising,
            currentGames[_gameId].total
        );
    }

    function callDouble(uint256 _gameId, address _playerCalling)
        external
        whenNotPaused
        onlyWorker
        onlyDoublingStage(_gameId)
        isPlayerInGame(_gameId, _playerCalling)
    {
        require(
            address(_playerCalling) !=
            address(currentGames[_gameId].lastStaker),
            'call must come from opposite player who doubled'
        );

        require(
            treasury.tokenInboundTransfer(
                currentGames[_gameId].tokenIndex,
                _playerCalling,
                currentGames[_gameId].stake
            ),
            'calling double transfer failed'
        );

        currentGames[_gameId].total = currentGames[_gameId].total.add(
            currentGames[_gameId].stake
        );

        currentGames[_gameId].stake = currentGames[_gameId].stake.mul(2);
        currentGames[_gameId].state = GameState.OnGoingGame;

        emit StakeDoubled(
            _gameId,
            _playerCalling,
            currentGames[_gameId].total
        );
    }

    function dropGame(uint256 _gameId, address _playerDropping)
        external
        whenNotPaused
        onlyWorker
        onlyDoublingStage(_gameId)
        isPlayerInGame(_gameId, _playerDropping)
    {
        require(
            _playerDropping != currentGames[_gameId].lastStaker,
            'drop must come from opposite player who doubled'
        );

        require(
            treasury.tokenOutboundTransfer(
                currentGames[_gameId].tokenIndex,
                currentGames[_gameId].lastStaker,
                applyPercent(currentGames[_gameId].total)

            ),
            'win amount transfer failed (dropGame)'
        );

        currentGames[_gameId].state = GameState.GameEnded;

        emit PlayerDropped(
            _gameId,
            _playerDropping
        );
    }

    function applyPercent(uint256 _value) public view returns (uint256) {
        uint256 _feePercent = uint256(1000).sub(uint256(uint64(data>>192)).mul(10));
        return _value.mul(_feePercent).div(1000);
    }

    function resolveGame(uint256 _gameId, address _winPlayer)
        external
        whenNotPaused
        onlyWorker
        onlyOnGoingGame(_gameId)
        isPlayerInGame(_gameId, _winPlayer)
    {

        require(
            treasury.tokenOutboundTransfer(
                currentGames[_gameId].tokenIndex,
                _winPlayer,
                applyPercent(currentGames[_gameId].total)
            ),
            'win amount transfer failed (resolveGame)'
        );

        currentGames[_gameId].state = GameState.GameEnded;

        emit GameResolved(
            _gameId,
            _winPlayer
        );
    }

    function getGameIdOfPlayers(address playerOne, address playerTwo)
        external
        pure
        returns (uint256 gameId)
    {
        gameId = uint256(keccak256(abi.encodePacked(playerOne, playerTwo)));
    }

    function checkPlayerInGame(uint256 gameId, address player)
        external
        view
        returns (bool)
    {
        if (
            player == currentGames[gameId].playerOne ||
            player == currentGames[gameId].playerTwo
        ) return true;
    }

    function changeFeePercent(uint64 _newFeePercent) external onlyCEO {
        require(_newFeePercent < 20, 'must be below 20');
        data |= _newFeePercent<<192;
    }

    function changeSafeFactor(uint64 _newFactor) external onlyCEO {
        require(_newFactor > 0, 'must be above zero');
        data |= _newFactor<<128;
    }

    function changeTreasury(address _newTreasuryAddress) external onlyCEO {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }

    function _changeTreasury(address _newTreasuryAddress) external onlyTreasury {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }
}