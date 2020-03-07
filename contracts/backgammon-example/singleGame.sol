pragma solidity ^0.5.16;

//import "./GameLogic.sol";
import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/ERC20Token.sol";
import "../common-contracts/HashChain.sol";

contract Backgammon is HashChain, AccessControl {
    using SafeMath for uint256;

    enum GameState {
        ReadyToStart,
        OnGoingGame,
        DoublingStage
    }

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
    uint256 safeFactor = 64;

    mapping (string => address) tokens;
    Game public currentGame;

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

        //check that players are different addresses and game in default state
        require(currentGame.state == GameState.ReadyToStart, "game must be in default state");
        require(address(_playerOneAddress) != address(_playerTwoAddress), "must be two different players");

        //declare token
        ERC20Token _token = ERC20Token(tokens[_tokenName]);

        //check that both players allowed contract as spender
        require(_token.allowance(_playerOneAddress, address(this)) >= _defaultStake.mul(safeFactor), "must approve/allow this contract as spender");
        require(_token.allowance(_playerTwoAddress, address(this)) >= _defaultStake.mul(safeFactor), "must approve/allow this contract as spender");

        //get original stakes from each player to start the game
        _token.transferFrom(_playerOneAddress, address(this), _defaultStake);
        _token.transferFrom(_playerTwoAddress, address(this), _defaultStake);

        //set new status of the game
        currentGame.playerOne = _playerOneAddress;
        currentGame.playerTwo = _playerTwoAddress;
        currentGame.token = _token;
        currentGame.stake = _defaultStake;
        currentGame.total = _defaultStake.mul(2);
        currentGame.state = GameState.OnGoingGame;
        currentGame.lastStaker = address(0);

    }

    function raiseDouble(address _playerStaking) public whenNotPaused onlyWorker {
        require(currentGame.state == GameState.OnGoingGame, "Game not Initialized yet");
        require(_playerStaking == currentGame.playerOne || _playerStaking == currentGame.playerTwo, "must be one of the players");
        require(address(_playerStaking) != address(currentGame.lastStaker), "same player cannot double again");

        currentGame.state = GameState.DoublingStage;
        currentGame.lastStaker = _playerStaking;
        currentGame.total = currentGame.total.add(currentGame.stake);

        //tranfer from first players
        currentGame.token.transferFrom(_playerStaking, address(this), currentGame.stake);
    }

    function callDouble(address _playerCalling) public whenNotPaused onlyWorker {
        require(currentGame.state == GameState.DoublingStage, "must be proposed to double first by one of the players");
        require(_playerCalling == currentGame.playerOne || _playerCalling == currentGame.playerTwo, "must be one of the players");
        require(address(_playerCalling) != address(currentGame.lastStaker), "call must come from opposite player who doubled");

        //tranfer from second players
        currentGame.token.transferFrom(_playerCalling, address(this), currentGame.stake);
        currentGame.total = currentGame.total.add(currentGame.stake);

        //multiply for next stake
        currentGame.stake = currentGame.stake.mul(2);

        //set status to continue game
        currentGame.state = GameState.OnGoingGame;
    }

    function dropGame(address _playerDropping) public whenNotPaused onlyWorker {
        require(currentGame.state == GameState.DoublingStage, "must be proposed to double first by one of the players");
        require(_playerDropping == currentGame.playerOne || _playerDropping == currentGame.playerTwo, "must be one of the players");
        require(address(_playerDropping) != address(currentGame.lastStaker), "drop must come from opposite player who doubled");

        //payout total tokens collected during the game to the winner;
        currentGame.token.transfer(currentGame.lastStaker, currentGame.total);
        currentGame.state = GameState.ReadyToStart;
    }

    function resolveGame(address _winPlayer) public whenNotPaused onlyWorker {
        require(currentGame.state == GameState.OnGoingGame, "must be ongoing game");
        require(_winPlayer == currentGame.playerOne || _winPlayer == currentGame.playerTwo, "must be one of the players");

        //payout total tokens collected during the game to the winner;
        currentGame.token.transfer(_winPlayer, currentGame.total);
        currentGame.state = GameState.ReadyToStart;
    }

    constructor(address defaultToken, string memory tokenName) public {
        tokens[tokenName] = defaultToken;
    }

    function setToken(address _tokenAddress, string calldata _tokenName) external onlyCEO {
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
