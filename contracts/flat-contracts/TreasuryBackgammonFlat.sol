
// File: contracts/common-contracts/SafeMath.sol

pragma solidity ^0.5.11;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: contracts/common-contracts/AccessControl.sol

pragma solidity ^0.5.11;

contract AccessControl {
    address public ceoAddress; // contract's owner and manager address
    address public workerAddress; // contract's owner and manager address

    bool public paused = false; // keeps track of whether or not contract is paused

    /**
    @notice fired when a new address is set as CEO
    */
    event CEOSet(address newCEO);
    event WorkerSet(address newWorker);

    /**
    @notice fired when the contract is paused
     */
    event Paused();

    /**
    @notice fired when the contract is unpaused
     */
    event Unpaused();

    // AccessControl constructor - sets default executive roles of contract to the sender account
    constructor() public {
        ceoAddress = msg.sender;
        workerAddress = msg.sender;
        emit CEOSet(ceoAddress);
    }

    // access modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress);
        _;
    }

    // access modifier for Worker-only functionality
    modifier onlyWorker() {
        require(msg.sender == workerAddress);
        _;
    }

    // assigns new CEO address - only available to the current CEO
    function setCEO(address _newCEO) public onlyCEO {
        require(_newCEO != address(0));
        ceoAddress = _newCEO;
        emit CEOSet(ceoAddress);
    }

    // assigns new Worker address - only available to the current CEO
    function setWorker(address _newWorker) public onlyCEO {
        require(_newWorker != address(0));
        workerAddress = _newWorker;
        emit WorkerSet(workerAddress);
    }

    // modifier to allow actions only when the contract IS NOT paused
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    // modifier to allow actions only when the contract IS paused
    modifier whenPaused {
        require(paused);
        _;
    }

    // pauses the smart contract - can only be called by the CEO
    function pause() public onlyCEO whenNotPaused {
        paused = true;
        emit Paused();
    }

    // unpauses the smart contract - can only be called by the CEO
    function unpause() public onlyCEO whenPaused {
        paused = false;
        emit Unpaused();
    }
}

// File: contracts/common-contracts/TreasuryInstance.sol

pragma solidity ^0.5.14;

interface TreasuryInstance {

    function tokenAddress(
        string calldata _tokenName
    ) external view returns (address);

    function tokenInboundTransfer(
        string calldata _tokenName,
        address _from,
        uint256 _amount
    )  external returns (bool);

    function tokenOutboundTransfer(
        string calldata _tokenName,
        address _to,
        uint256 _amount
    ) external returns (bool);

    function checkAllocatedTokens(
        string calldata _tokenName
    ) external view returns (uint256);

    function checkApproval(
        address _userAddress,
        string calldata _tokenName
    ) external view returns (uint256 approved);

    function getMaximumBet(
        string calldata _tokenName
    ) external view returns (uint256);

    function consumeHash(
        bytes32 _localhash
    ) external returns (bool);
}

// File: contracts/treasury-example/TreasuryBackgammon.sol

pragma solidity ^0.5.16;

contract TreasuryBackgammon is AccessControl {

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
    uint256 public safeFactor = 64;
    uint256 public feePercent = 10;

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
    }

    function initializeGame(
        uint256 _defaultStake,
        address _playerOneAddress,
        address _playerTwoAddress,
        string calldata _tokenName
    ) external whenNotPaused onlyWorker returns (bool) {

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
            treasury.tokenAddress(_tokenName) != address(0x0),
            "token is not delcared in treasury!"
        );

        require(
            _defaultStake <= treasury.getMaximumBet(_tokenName),
            "exceeding maximum bet defined in treasury"
        );

        require(
            _defaultStake.mul(safeFactor) <= treasury.checkApproval(_playerOneAddress, _tokenName),
            "P1 must approve/allow treasury contract as spender"
        );

        require(
            _defaultStake.mul(safeFactor) <= treasury.checkApproval(_playerTwoAddress, _tokenName),
            "P2 must approve/allow treasury contract as spender"
        );

        //get original stakes from each player to start the game
        treasury.tokenInboundTransfer(_tokenName, _playerOneAddress, _defaultStake);
        treasury.tokenInboundTransfer(_tokenName, _playerTwoAddress, _defaultStake);

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
        external
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
            treasury.tokenInboundTransfer(
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
        external
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
            treasury.tokenInboundTransfer(
                currentGames[_gameId].tokenName,
                _playerCalling,
                currentGames[_gameId].stake
            ),
            "calling double transfer failed"
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
            "drop must come from opposite player who doubled"
        );

        require(
            treasury.tokenOutboundTransfer(
                currentGames[_gameId].tokenName,
                currentGames[_gameId].lastStaker,
                applyPercent(currentGames[_gameId].total)

            ),
            "win amount transfer failed (dropGame)"
        );

        wins[currentGames[_gameId].lastStaker] = wins[currentGames[_gameId].lastStaker].add(1);
        currentGames[_gameId].state = GameState.GameEnded;

        emit PlayerDropped(
            _gameId,
            _playerDropping
        );
    }

    function applyPercent(uint256 _value) public view returns (uint256) {
        uint256 _feePercent = uint256(1000).sub(feePercent.mul(10));
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
                currentGames[_gameId].tokenName,
                _winPlayer,
                applyPercent(currentGames[_gameId].total)
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

    function changeFeePercent(uint256 _newFeePercent) external onlyCEO {
        require(_newFeePercent < 100, 'must be below 100');
        feePercent = _newFeePercent;
    }

    function changeSafeFactor(uint256 _newFactor) external onlyCEO {
        require(_newFactor > 0, 'must be above zero');
        safeFactor = _newFactor;
    }

    function changeTreasury(address _newTreasuryAddress) external onlyCEO {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }

    function _changeTreasury(address _newTreasuryAddress) external onlyTreasury {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }
}
