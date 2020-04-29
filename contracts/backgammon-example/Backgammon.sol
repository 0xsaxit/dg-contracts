pragma solidity ^0.5.16;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/MasterInterface.sol";

contract Backgammon is AccessControl {

    using SafeMath for uint256;
    enum GameState {NewGame, OnGoingGame, DoublingStage, GameEnded}

    event GameStarted(
        uint256 gameId,
        address indexed playerOne,
        address indexed playerTwo,
        string tokenName
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
        GameState state;
        address playerOne;
        address playerTwo;
        string tokenName;
        uint256 stake;
        uint256 total;
        address lastStaker;
    }

    //safe factor to check allowance
    uint256 constant safeFactor = 64;

    mapping(uint256 => Game) public currentGames;
    mapping(address => uint256) public wins;

    modifier onlyDoublingStage(uint256 gameId) {
        require(
            currentGames[gameId].state == GameState.DoublingStage,
            "must be proposed to double first by one of the players"
        );
        _;
    }

    modifier onlyOnGoingGame(uint256 gameId) {
        require(
            currentGames[gameId].state == GameState.OnGoingGame,
            "must be ongoing game"
        );
        _;
    }

    modifier isPlayerInGame(uint256 gameId, address player) {
        require(
            player == currentGames[gameId].playerOne ||
            player == currentGames[gameId].playerTwo,
            "must be one of the players"
        );
        _;
    }

    address masterAddress;
    MasterInstance master;

    constructor(address _masterAddress) public {
        masterAddress = _masterAddress;
        master =  MasterInstance(_masterAddress);
    }

    function initializeGame(
        uint256 _defaultStake,
        address _playerOneAddress,
        address _playerTwoAddress,
        string memory _tokenName
    ) public whenNotPaused onlyWorker returns (bool) {

        //_consume(_localhash); //if needed

        require(
            address(_playerOneAddress) != address(_playerTwoAddress),
            "must be two different players"
        );

        uint256 gameId = uint256(
            keccak256(abi.encodePacked(_playerOneAddress, _playerTwoAddress))
        );

        require(
            currentGames[gameId].state == GameState.NewGame ||
            currentGames[gameId].state == GameState.GameEnded,
            "cannot initialize running game"
        );

        require(
            master.tokenAddress(_tokenName) != address(0),
            "token is not delcared in master!"
        );

        require(
            master.selfMaximumBet(_tokenName) >= _defaultStake,
            "exceeding maximum bet defined in master/treasury"
        );

        // declare token (from treasury)
        ERC20Token _token = master.tokenInstance(_tokenName);

        require(
            _token.allowance(_playerOneAddress, masterAddress) >=
            _defaultStake.mul(safeFactor),
            "must approve/allow master contract as spender"
        );

        require(
            _token.allowance(_playerTwoAddress, masterAddress) >=
            _defaultStake.mul(safeFactor),
            "must approve/allow master contract as spender"
        );

        //get original stakes from each player to start the game
        master.tokenInboundTransfer(_tokenName, _playerOneAddress, _defaultStake);
        master.tokenInboundTransfer(_tokenName, _playerTwoAddress, _defaultStake);

        // set new status of the game
        Game memory _game = Game(
            GameState.OnGoingGame,
            _playerOneAddress,
            _playerTwoAddress,
            _tokenName,
            _defaultStake,
            _defaultStake.mul(2),
            address(0)
        );

        currentGames[gameId] = _game;

        emit GameStarted(
            gameId,
            _playerOneAddress,
            _playerTwoAddress,
            _tokenName
        );
    }

    function raiseDouble(uint256 _gameId, address _playerRaising)
        public
        whenNotPaused
        onlyWorker
        onlyOnGoingGame(_gameId)
        isPlayerInGame(_gameId, _playerRaising)
    {
        require(
            address(_playerRaising) !=
            address(currentGames[_gameId].lastStaker),
            "same player cannot raise double again"
        );

        require(
            master.tokenInboundTransfer(
                currentGames[_gameId].tokenName,
                _playerRaising,
                currentGames[_gameId].stake
            ),
            "raising double transfer failed"
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
        public
        whenNotPaused
        onlyWorker
        onlyDoublingStage(_gameId)
        isPlayerInGame(_gameId, _playerCalling)
    {
        require(
            address(_playerCalling) !=
            address(currentGames[_gameId].lastStaker),
            "call must come from opposite player who doubled"
        );

        require(
            master.tokenInboundTransfer(
                currentGames[_gameId].tokenName,
                _playerCalling,
                currentGames[_gameId].stake
            ),
            "calling double transfer failed"
        );

        currentGames[_gameId].total = currentGames[_gameId].total.add(
            currentGames[_gameId].stake
        );

        //multiply for next stake
        currentGames[_gameId].stake = currentGames[_gameId].stake.mul(2);

        //set status to continue game
        currentGames[_gameId].state = GameState.OnGoingGame;

        emit StakeDoubled(
            _gameId,
            _playerCalling,
            currentGames[_gameId].total
        );
    }

    function dropGame(uint256 _gameId, address _playerDropping)
        public
        whenNotPaused
        onlyWorker
        onlyDoublingStage(_gameId)
        isPlayerInGame(_gameId, _playerDropping)
    {
        require(
            _playerDropping != currentGames[_gameId].lastStaker,
            "drop must come from opposite player who doubled"
        );

        require(
            master.tokenOutboundTransfer(
                currentGames[_gameId].tokenName,
                currentGames[_gameId].lastStaker,
                currentGames[_gameId].total
            ),
            "win amount transfer failed (dropGame)"
        );

        wins[currentGames[_gameId].lastStaker] = wins[currentGames[_gameId].lastStaker].add(1);
        currentGames[_gameId].state = GameState.GameEnded;

        emit PlayerDropped(_gameId, _playerDropping);
    }

    function resolveGame(uint256 _gameId, address _winPlayer)
        public
        whenNotPaused
        onlyWorker
        onlyOnGoingGame(_gameId)
        isPlayerInGame(_gameId, _winPlayer)
    {

        require(
            master.tokenOutboundTransfer(
                currentGames[_gameId].tokenName,
                _winPlayer,
                currentGames[_gameId].total
            ),
            "win amount transfer failed (resolveGame)"
        );

        wins[_winPlayer] = wins[_winPlayer].add(1);
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

    function changeMaster(address _newMaster) external onlyCEO {
        masterAddress = _newMaster;
        master =  MasterInstance(_newMaster);
    }

}
