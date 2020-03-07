pragma solidity ^0.5.16;

//import "./GameLogic.sol";
import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/ERC20Token.sol";
import "../common-contracts/HashChain.sol";

contract Backgammon is HashChain, AccessControl {
    using SafeMath for uint256;

    enum GameState {NewGame, OnGoingGame, DoublingStage, GameEnded}

    event GameStarted(
        uint256 gameId,
        address indexed playerOne,
        address indexed playerTwo,
        string tokenName
    );

    event StakeRaised(uint256 gameId, address indexed player, uint256 stake);

    event StakeDoubled(
        uint256 gameId,
        address indexed player,
        uint256 totalStaked
    );

    event PlayerDropped(uint256 gameId, address indexed player);

    event GameResolved(uint256 gameId, address indexed winner);

    struct Game {
        GameState state;
        address playerOne;
        address playerTwo;
        ERC20Token token;
        uint256 stake;
        uint256 total;
        address lastStaker;
    }

    //safe factor to check allowance
    uint256 constant safeFactor = 64;

    mapping(string => address) tokens;

    mapping(uint256 => Game) public currentGames;

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

    constructor(address defaultToken, string memory tokenName) public {
        tokens[tokenName] = defaultToken;
    }

    function initializeGame(
        //uint256 _landID,
        //uint256 _machineID,
        uint256 _defaultStake,
        address _playerOneAddress,
        address _playerTwoAddress,
        //bytes32 _localhash,
        string memory _tokenName
    ) public whenNotPaused onlyWorker returns (bool) {
        //_consume(_localhash);

        uint256 gameId = uint256(
            keccak256(abi.encodePacked(_playerOneAddress, _playerTwoAddress))
        );

        //check that is a new game or a finished game
        require(
            currentGames[gameId].state == GameState.NewGame ||
                currentGames[gameId].state == GameState.GameEnded,
            "cannot initialize running game"
        );

        //check that players are different addresses
        require(
            address(_playerOneAddress) != address(_playerTwoAddress),
            "must be two different players"
        );

        //check that token exists
        require(tokens[_tokenName] != address(0), "token does not exist");

        //declare token
        ERC20Token _token = ERC20Token(tokens[_tokenName]);

        //check that both players allowed contract as spender
        require(
            _token.allowance(_playerOneAddress, address(this)) >=
                _defaultStake.mul(safeFactor),
            "must approve/allow this contract as spender"
        );
        require(
            _token.allowance(_playerTwoAddress, address(this)) >=
                _defaultStake.mul(safeFactor),
            "must approve/allow this contract as spender"
        );

        //get original stakes from each player to start the game
        _token.transferFrom(_playerOneAddress, address(this), _defaultStake);
        _token.transferFrom(_playerTwoAddress, address(this), _defaultStake);

        // set new status of the game
        Game memory _game = Game(
            GameState.OnGoingGame,
            _playerOneAddress,
            _playerTwoAddress,
            _token,
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

    function raiseDouble(uint256 _gameId, address _playerStaking)
        public
        whenNotPaused
        onlyWorker
        onlyDoublingStage(_gameId)
        isPlayerInGame(_gameId, _playerStaking)
    {
        require(
            address(_playerStaking) !=
                address(currentGames[_gameId].lastStaker),
            "same player cannot double again"
        );

        //tranfer stake from player staking
        require(
            currentGames[_gameId].token.transferFrom(
                _playerStaking,
                address(this),
                currentGames[_gameId].stake
            ),
            "token transfer failed"
        );

        currentGames[_gameId].state = GameState.DoublingStage;
        currentGames[_gameId].lastStaker = _playerStaking;
        currentGames[_gameId].total = currentGames[_gameId].total.add(
            currentGames[_gameId].stake
        );

        emit StakeRaised(_gameId, _playerStaking, currentGames[_gameId].total);

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

        //tranfer from second players
        currentGames[_gameId].token.transferFrom(
            _playerCalling,
            address(this),
            currentGames[_gameId].stake
        );
        currentGames[_gameId].total = currentGames[_gameId].total.add(
            currentGames[_gameId].stake
        );

        //multiply for next stake
        currentGames[_gameId].stake = currentGames[_gameId].stake.mul(2);

        //set status to continue game
        currentGames[_gameId].state = GameState.OnGoingGame;

        emit StakeDoubled(_gameId, _playerCalling, currentGames[_gameId].total);
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

        //payout total tokens collected during the game to the winner;
        currentGames[_gameId].token.transfer(
            currentGames[_gameId].lastStaker,
            currentGames[_gameId].total
        );
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
        //payout total tokens collected during the game to the winner;
        currentGames[_gameId].token.transfer(
            _winPlayer,
            currentGames[_gameId].total
        );
        currentGames[_gameId].state = GameState.GameEnded;

        emit GameResolved(_gameId, _winPlayer);
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

    function setToken(address _tokenAddress, string calldata _tokenName)
        external
        onlyCEO
    {
        tokens[_tokenName] = _tokenAddress;
    }

    function setTail(bytes32 _tail) private onlyCEO {
        _setTail(_tail);
    }

    function testTail(bytes32 _localhash) private onlyCEO returns (bool) {
        _consume(_localhash);
        return true;
    }

}
