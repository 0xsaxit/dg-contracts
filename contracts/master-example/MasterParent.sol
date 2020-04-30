pragma solidity ^0.5.14;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/ERC20Token.sol";
import "../common-contracts/HashChain.sol";

import "./GameInterface.sol";

contract MasterParent is HashChain, AccessControl {
    using SafeMath for uint256;
    event NewBalance(uint256 _gameID, uint256 _balance);

    uint256[] public winAmounts; // last winning amounts
    uint256 public number = 0;
    uint256 public maximumNumberBets = 36; // contract's maximum amount of bets
    string public defaultTokenName;

    struct Game {
        address gameAddress;
        string gameName;
        bool isDelegated;
        mapping(string => uint256) gameTokens;
        mapping(string => uint256) maximumBets;
    }

    event MoveResult(
        bool success,
        bytes result
    );

    event GameResult(
        address[] _players,
        string indexed _tokenName,
        uint256 _landID,
        uint256 indexed _number,
        uint256 indexed _machineID,
        uint256[] _winAmounts
    );

    mapping(string => address) public tokens;
    Game[] public games;

    constructor(address defaultToken, string memory tokenName) public {
        tokens[tokenName] = defaultToken;
        defaultTokenName = tokenName;
    }

    function tokenAddress(string calldata _tokenName) external view returns (address) {
        return tokens[_tokenName];
    }

    function tokenInstance(string calldata _tokenName) external view returns (ERC20Token) {
        return ERC20Token(tokens[_tokenName]);
    }

    function tokenInboundTransfer(string calldata _tokenName, address _from, uint256 _amount)
        external
        returns (bool)
    {
        (bool result, uint gameID) = findGameID(msg.sender);
        require(result && games[gameID].isDelegated, 'delegated-game is not present');

        ERC20Token _token = ERC20Token(tokens[_tokenName]);
        games[gameID].gameTokens[_tokenName] = games[gameID].gameTokens[_tokenName].add(_amount);
        _token.transferFrom(_from, address(this), _amount);
        return true;
    }

    function tokenOutboundTransfer(string calldata _tokenName, address _to, uint256 _amount)
        external
        returns (bool)
    {

        (bool result, uint gameID) = findGameID(msg.sender);
        require(result && games[gameID].isDelegated, 'delegated-game is not present');

        ERC20Token _token = ERC20Token(tokens[_tokenName]);
        games[gameID].gameTokens[_tokenName] = games[gameID].gameTokens[_tokenName].sub(_amount);
        _token.transfer(_to, _amount);
        return true;
    }

    function findGameID(address _gameAddress) public view returns (bool, uint) {
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
        bool _isDelegated
    ) external onlyCEO {
        Game memory newGame;
        newGame.gameAddress = _newGameAddress;
        newGame.gameName = _newGameName;
        newGame.isDelegated = _isDelegated;
        uint256 gameID = games.push(newGame);
        games[gameID - 1].gameTokens[defaultTokenName] = 0;
        games[gameID - 1].maximumBets[defaultTokenName] = _maximumBet;
    }

    function updateGame(
        uint256 _gameID,
        address _newGame,
        bool _isDelegated,
        string calldata _newGameName
    ) external onlyCEO {
        games[_gameID].gameAddress = _newGame;
        games[_gameID].gameName = _newGameName;
        games[_gameID].isDelegated = _isDelegated;
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

    function selfMaximumBet(string calldata _tokenName)
        external
        view
        returns (uint256)
    {
        (bool result, uint _gameID) = findGameID(msg.sender);
        require(result && games[_gameID].isDelegated, 'delegated-game is not present');
        return games[_gameID].maximumBets[_tokenName];
    }

    function getMaximumBet(uint256 _gameID, string calldata _tokenName)
        external
        view
        returns (uint256)
    {
        return games[_gameID].maximumBets[_tokenName];
    }

    function addToken(address _tokenAddress, string calldata _tokenName)
        external
        onlyCEO
    {
        tokens[_tokenName] = _tokenAddress;
    }

    function updateToken(address _newTokenAddress, string calldata _tokenName)
        external
        onlyCEO
    {
        tokens[_tokenName] = _newTokenAddress;
    }

    function checkApproval(address _userAddress, string memory _tokenName)
        public
        view
        returns (uint256 approved)
    {
        approved = ERC20Token(tokens[_tokenName]).allowance(
            _userAddress,
            address(this)
        );
    }

    function bet(
        uint256 _gameID,
        uint256 _betID,
        address _userAddress,
        uint256 _number,
        uint256 _value,
        string memory _tokenName
    ) internal whenNotPaused {
        require(
            _value <= games[_gameID].maximumBets[_tokenName],
            'bet amount is more than maximum'
        );

        GameInstance _game = GameInstance(games[_gameID].gameAddress);
        _game.createBet(_betID, _userAddress, _number, _value);
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

    function setTail(bytes32 _tail) external onlyCEO {
        _setTail(_tail);
    }

    function skipHash(bytes32 _localhash) external onlyCEO returns (bool) {
        _consume(_localhash);
        return true;
    }

    function play(
        uint256 _gameID,
        address[] memory _players,
        uint256 _landID,
        uint256 _machineID,
        uint256[] memory _betIDs,
        uint256[] memory _betValues,
        uint256[] memory _betAmount,
        bytes32 _localhash,
        string memory _tokenName
        // string memory _actionName
    ) public whenNotPaused onlyWorker {

        _consume(_localhash); // hash-chain check

        require(
            _betIDs.length == _betValues.length,
            'inconsistent amount of bets'
        );
        require(
            _betIDs.length == _betAmount.length,
            'inconsistent amount of bets'
        );
        require(
            _betIDs.length <= maximumNumberBets,
            'maximum amount of bets reached'
        );

        GameInstance _game = GameInstance(games[_gameID].gameAddress);
        ERC20Token _token = ERC20Token(tokens[_tokenName]);

        uint256 _trackingBalance = 0;

        // set bets for the game
        for (uint256 i = 0; i < _betIDs.length; i++) {

            //check approval
            require(
                _token.allowance(_players[i], address(this)) >= _betAmount[i],
                'approve contract as spender'
            );

            // get user tokens if approved
            _token.transferFrom(_players[i], address(this), _betAmount[i]);
            _trackingBalance = _trackingBalance.add(_betAmount[i]);

            bet(
                _gameID,
                _betIDs[i],
                _players[i],
                _betValues[i],
                _betAmount[i],
                _tokenName
            );
        }

        // keep track of funds
        games[_gameID].gameTokens[_tokenName] = games[_gameID]
            .gameTokens[_tokenName]
            .add(_trackingBalance);

        // check payouts balnace
        require(
            _game.getNecessaryBalance() <= games[_gameID].gameTokens[_tokenName],
            "not enough tokens"
        );

        // play game
        (winAmounts, number) = _game.launch(
            _localhash,
            _machineID,
            _landID,
            _tokenName
        );

        _trackingBalance = 0;

        for (uint256 i = 0; i < winAmounts.length; i++) {
            if (winAmounts[i] > 0) {
                _trackingBalance = _trackingBalance.add(winAmounts[i]);
                //issue tokens to each winner
                _token.transfer(_players[i], winAmounts[i]); // transfer winning amount to player
            }
        }

        // keep track of funds
        games[_gameID].gameTokens[_tokenName] = games[_gameID]
            .gameTokens[_tokenName]
            .sub(_trackingBalance);

        // free-up refund on gas
        delete _trackingBalance;

        // notify server of result numbers and winning amount if any
        emit GameResult(
            _players,
            _tokenName,
            _landID,
            number,
            _machineID,
            winAmounts
        );
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
            'unauthorized token detected'
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

        // notify server of new contract balance
        emit NewBalance(_gameID, games[_gameID].gameTokens[_tokenName]);
    }

    function checkAllocatedTokensPerGame(
        uint256 _gameID,
        string calldata _tokenName
    ) external view returns (uint256 tokensInGame) {
        tokensInGame = games[_gameID].gameTokens[_tokenName];
    }

    function withdrawCollateral(
        uint256 _gameID,
        uint256 _amount,
        string calldata _tokenName
    ) external onlyCEO {
        require(
            _amount <= games[_gameID].gameTokens[_tokenName],
            'game balance is lower'
        );

        ERC20Token token = ERC20Token(tokens[_tokenName]);

        games[_gameID].gameTokens[_tokenName] = games[_gameID]
            .gameTokens[_tokenName]
            .sub(_amount);
        token.transfer(ceoAddress, _amount);

        emit NewBalance(_gameID, games[_gameID].gameTokens[_tokenName]);
    }

    function withdrawMaxTokenBalance(string calldata _tokenName)
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

}
