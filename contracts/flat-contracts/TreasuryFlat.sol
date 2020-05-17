
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

// File: contracts/common-contracts/ERC20Token.sol

pragma solidity ^0.5.11;

//contract ERC20Token {
interface ERC20Token {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// File: contracts/common-contracts/HashChain.sol

pragma solidity ^0.5.11;

contract HashChain {
    bytes32 public tail;

    function _setTail(bytes32 _tail) internal {
        tail = _tail;
    }

    function _consume(bytes32 _parent) internal {
        require(keccak256(abi.encodePacked(_parent)) == tail, "hash-chain: wrong parent");
        tail = _parent;
    }

}

// File: contracts/treasury-example/Treasury.sol

pragma solidity ^0.5.14;

contract TreasuryFlat is HashChain, AccessControl {

    using SafeMath for uint256;

    event NewBalance(uint256 _gameID, uint256 _balance);
    string public defaultTokenName;

    struct Game {
        address gameAddress;
        string gameName;
        bool isActive;
        mapping(string => uint256) gameTokens;
        mapping(string => uint256) maximumBets;
    }

    mapping(string => address) public tokens;
    Game[] public games;
    string[] public tokenNames;

    constructor() public {
        defaultTokenName = "MANA";
        tokens[defaultTokenName] = 0x2A3df21E612d30Ac0CD63C3F80E1eB583A4744cC;
        tokenNames.push(defaultTokenName);
    }

    function setDefaultToken(address _defaultToken, string memory _tokenName) internal {
        addToken(_defaultToken, _tokenName);
        defaultTokenName = _tokenName;
    }

    function updateDefaultToken(string memory _tokenName) public onlyCEO {
        defaultTokenName = _tokenName;
    }

    function tokenAddress(string calldata _tokenName) external view returns (address) {
        return tokens[_tokenName];
    }

    function tokenInboundTransfer(string calldata _tokenName, address _from, uint256 _amount)
        external
        returns (bool)
    {
        uint256 _gameID = getGameID(msg.sender);
        ERC20Token _token = ERC20Token(tokens[_tokenName]);
        games[_gameID].gameTokens[_tokenName] = games[_gameID].gameTokens[_tokenName].add(_amount);
        _token.transferFrom(_from, address(this), _amount);
        return true;
    }

    function tokenOutboundTransfer(string calldata _tokenName, address _to, uint256 _amount)
        external
        returns (bool)
    {
        uint256 gameID = getGameID(msg.sender);
        ERC20Token _token = ERC20Token(tokens[_tokenName]);
        games[gameID].gameTokens[_tokenName] = games[gameID].gameTokens[_tokenName].sub(_amount);
        _token.transfer(_to, _amount);
        return true;
    }

    function getGameID(address _gameAddress) private view returns (uint) {
        (bool result, uint gameID) = findGameID(_gameAddress);
        require(
            result && games[gameID].isActive,
            'active-game not present'
        );
        return gameID;
    }

    function findGameID(address _gameAddress) private view returns (bool, uint) {
        for (uint i = 0; i < games.length; i++) {
            if (games[i].gameAddress == _gameAddress) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function addGame(
        address _newGameAddress,
        string calldata _newGameName,
        uint256 _maximumBet,
        bool _isActive
    ) external onlyCEO {
        Game memory newGame;
        newGame.gameAddress = _newGameAddress;
        newGame.gameName = _newGameName;
        newGame.isActive = _isActive;
        uint256 _gameID = games.push(newGame);
        games[_gameID - 1].gameTokens[defaultTokenName] = 0;
        games[_gameID - 1].maximumBets[defaultTokenName] = _maximumBet;
    }

    function updateGame(
        uint256 _gameID,
        address _newGame,
        bool _isActive,
        string calldata _newGameName
    ) external onlyCEO {
        games[_gameID].gameAddress = _newGame;
        games[_gameID].gameName = _newGameName;
        games[_gameID].isActive = _isActive;
    }

    function updateGameAddress(
        uint256 _gameID,
        address _newGameAddress
    ) external onlyCEO {
        games[_gameID].gameAddress = _newGameAddress;
    }

    function removeGame(uint256 _gameID) external onlyCEO {
        delete games[_gameID];
    }

    function updateMaximumBet(
        uint256 _gameID,
        uint256 _maximumBet,
        string calldata _tokenName
    ) external onlyCEO {
        games[_gameID].maximumBets[_tokenName] = _maximumBet;
    }

    function gameMaximumBet(uint256 _gameID, string calldata _tokenName)
        external
        view
        returns (uint256)
    {
        return games[_gameID].maximumBets[_tokenName];
    }

    function getMaximumBet(string calldata _tokenName)
        external
        view
        returns (uint256)
    {
        uint256 _gameID = getGameID(msg.sender);
        return games[_gameID].maximumBets[_tokenName];
    }

    function addToken(address _tokenAddress, string memory _tokenName)
        public
        onlyCEO
    {
        tokens[_tokenName] = _tokenAddress;
        tokenNames.push(_tokenName);
    }

    function checkApproval(address _userAddress, string calldata _tokenName)
        external
        view
        returns (uint256 approved)
    {
        approved = ERC20Token(tokens[_tokenName]).allowance(
            _userAddress,
            address(this)
        );
    }

    function getBalanceByTokenName(string calldata _tokenName)
        external
        view
        returns (uint256)
    {
        ERC20Token _token = ERC20Token(tokens[_tokenName]);
        return _token.balanceOf(address(this));
    }

    function getBalanceByTokenAddress(address _tokenAddress)
        external
        view
        returns (uint256)
    {
        ERC20Token _token = ERC20Token(_tokenAddress);
        return _token.balanceOf(address(this));
    }

    function() external payable {
        revert();
    }

    function addFunds(
        uint256 _gameID,
        uint256 _tokenAmount,
        string calldata _tokenName
    ) external {

        require(
            tokens[_tokenName] != address(0x0),
            'unauthorized token address'
        );

        ERC20Token _token = ERC20Token(tokens[_tokenName]);

        require(
            _token.allowance(msg.sender, address(this)) >= _tokenAmount,
            'must allow to transfer'
        );

        _token.transferFrom(msg.sender, address(this), _tokenAmount);
        games[_gameID].gameTokens[_tokenName] = games[_gameID]
            .gameTokens[_tokenName]
            .add(_tokenAmount);

        emit NewBalance(_gameID, games[_gameID].gameTokens[_tokenName]);
    }

    function checkAllocatedTokens(
        string calldata _tokenName
    ) external view returns (uint256) {
        uint256 _gameID = getGameID(msg.sender);
        return _checkAllocatedTokens(_gameID, _tokenName);
    }

    function _checkAllocatedTokens(
        uint256 _gameID,
        string memory _tokenName
    ) internal view returns (uint256) {
        return games[_gameID].gameTokens[_tokenName];
    }

    function checkAllocatedTokensPerGame(
        uint256 _gameID,
        string calldata _tokenName
    ) external view returns (uint256) {
        return _checkAllocatedTokens(_gameID, _tokenName);
    }

    function withdrawTokens(
        uint256 _gameID,
        uint256 _amount,
        string calldata _tokenName
    ) external onlyCEO {
        require(
            _amount <= games[_gameID].gameTokens[_tokenName],
            'not enough tokens'
        );

        ERC20Token token = ERC20Token(tokens[_tokenName]);

        games[_gameID].gameTokens[_tokenName] = games[_gameID]
            .gameTokens[_tokenName]
            .sub(_amount);
        token.transfer(ceoAddress, _amount);

        emit NewBalance(_gameID, games[_gameID].gameTokens[_tokenName]);
    }

    function withdrawMaxTokens(string calldata _tokenName)
        external
        onlyCEO
    {
        ERC20Token token = ERC20Token(tokens[_tokenName]);
        uint256 amount = token.balanceOf(address(this));

        for (uint256 i = 0; i < games.length; i++) {
            games[i].gameTokens[_tokenName] = 0;
        }

        token.transfer(ceoAddress, amount);
    }

    function setTail(bytes32 _tail) external onlyCEO {
        _setTail(_tail);
    }

    function consumeHash(bytes32 _localhash) external returns (bool) {
        (bool result, uint gameID) = findGameID(msg.sender);
        require(
            result && games[gameID].isActive,
            'active-game not present'
        );
        _consume(_localhash);
        return true;
    }

    function migrateTreasury(
        address _newTreasury
    ) external onlyCEO returns (bool) {

        TreasuryMigration nt = TreasuryMigration(_newTreasury);
        nt.updateDefaultToken(defaultTokenName);

        for (uint i = 0; i < games.length; i++) {
            nt.addGame(
                games[i].gameAddress,
                games[i].gameName,
                games[i].maximumBets[defaultTokenName],
                games[i].isActive
            );
            GameMigration gm = GameMigration(games[i].gameAddress);
            gm._changeTreasury(_newTreasury);
        }

        for (uint i = 0; i < tokenNames.length; i++) {
            nt.addToken(
                tokens[tokenNames[i]],
                tokenNames[i]
            );
        }

        for (uint t = 0; t < tokenNames.length; t++) {

            ERC20Token token = ERC20Token(tokens[tokenNames[t]]);
            uint256 totalAmount = token.balanceOf(address(this));

            token.approve(_newTreasury, totalAmount);

            for (uint256 j = 0; j < games.length; j++) {
                uint256 amount = games[j].gameTokens[tokenNames[t]];
                uint256 maxBet = games[j].maximumBets[tokenNames[t]];
                nt.addFunds(j, amount, tokenNames[t]);
                nt.updateMaximumBet(j, maxBet, tokenNames[t]);
                games[j].gameTokens[tokenNames[t]] = 0;
            }
        }

        nt.setTail(tail);
        nt.setCEO(msg.sender);
    }
}

interface GameMigration {
    function _changeTreasury(
        address _newTreasuryAddress
    ) external;
}

interface TreasuryMigration {

    function addGame(
        address _newGameAddress,
        string calldata _newGameName,
        uint256 _maximumBet,
        bool _isActive
    ) external;

    function addToken(
        address _tokenAddress,
        string calldata _tokenName
    ) external;

    function addFunds(
        uint256 _gameID,
        uint256 _tokenAmount,
        string calldata _tokenName
    ) external;

    function setCEO(
        address _newCEO
    ) external;

    function setTail(
        bytes32 _tail
    ) external;

    function updateDefaultToken(
        string calldata _tokenName
    ) external;

    function updateMaximumBet(
        uint256 _gameID,
        uint256 _maximumBet,
        string calldata _tokenName
    ) external;
}
