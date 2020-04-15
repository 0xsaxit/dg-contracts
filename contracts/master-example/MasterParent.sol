pragma solidity ^0.5.14;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/ERC20Token.sol";
import "../common-contracts/HashChain.sol";

import "./GameInterface.sol";

contract MasterParent is HashChain, AccessControl {
    using SafeMath for uint256;
    event NewBalance(uint256 _gameID, uint256 _balance);

    uint8 public maximumNumberBets = 36; // contract's maximum amount of bets
    uint256[] public winAmounts; // last winning amounts
    uint256 public number = 0; // last reels numbers1
    string public defaultTokenName;
    uint256 necessaryBalance = 0;

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
            'inconsistent amount of bets/values'
        );
        require(
            _betIDs.length == _betAmount.length,
            'inconsistent amount of bets/amount'
        );
        require(
            _betIDs.length <= maximumNumberBets,
            'maximum amount of bets per game is 36'
        );

        GameInstance _game = GameInstance(games[_gameID].gameAddress);
        ERC20Token _token = ERC20Token(tokens[_tokenName]);

        // check necessary funds for payout based on betID
        necessaryBalance = 0;
        for (uint256 i = 0; i < _betIDs.length; i++) {
            uint256 fundsPerBet = _game.getPayoutForType(_betIDs[i]);
            if (_betIDs[i] > 0) {
                necessaryBalance = necessaryBalance.add(
                    fundsPerBet.mul(_betAmount[i])
                );
            } else {
                necessaryBalance = necessaryBalance.add(fundsPerBet);
            }
        }
        // consider adding the bet to payout amount before calculating
        require(
            necessaryBalance <= games[_gameID].gameTokens[_tokenName],
            'must have enough funds for payouts'
        );

        // set bets for the game
        for (uint256 i = 0; i < _betIDs.length; i++) {

            //check approval
            require(
                _token.allowance(_players[i], address(this)) >= _betAmount[i],
                'must approve/allow this contract as spender'
            );

            // get user tokens if approved
            _token.transferFrom(_players[i], address(this), _betAmount[i]);

            games[_gameID].gameTokens[_tokenName] = games[_gameID]
                .gameTokens[_tokenName]
                .add(_betAmount[i]);

            if (_betIDs[i] > 0) {
                bet(
                    _gameID,
                    _betIDs[i],
                    _players[i],
                    _betValues[i],
                    _betAmount[i],
                    _tokenName
                );
            }
        }

        // play move
        /* if (games[_gameID].isDelegated) {

            (bool success, bytes memory result) = games[_gameID].gameAddress.call(
                abi.encodeWithSignature('_actionName')
            );

            emit MoveResult(success, result);

        } else { */

        // play game
        (winAmounts, number) = _game.launch(
            _localhash,
            _machineID,
            _landID,
            _tokenName
        );

        for (uint256 i = 0; i < winAmounts.length; i++) {
            if (winAmounts[i] > 0) {
                games[_gameID].gameTokens[_tokenName] = games[_gameID]
                    .gameTokens[_tokenName]
                    .sub(winAmounts[i]); // keep balance of tokens per game

                //issue tokens to each winner
                _token.transfer(_players[i], winAmounts[i]); // transfer winning amount to player
            }
        }

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

    function() external payable {} // can send tokens directly

    function manualAllocation(
        uint256 _gameID,
        uint256 _tokenAmount,
        string calldata _tokenName
    ) external onlyCEO {
        games[_gameID].gameTokens[_tokenName] = games[_gameID]
            .gameTokens[_tokenName]
            .add(_tokenAmount);
    }

    function manualAdjustment(
        uint256 _gameID,
        uint256 _tokenAmount,
        string calldata _tokenName
    ) external onlyCEO {
        games[_gameID].gameTokens[_tokenName] = _tokenAmount; // overwrite allocated tokens per game value
    }

    function addFunds(
        uint256 _gameID,
        uint256 _tokenAmount,
        string calldata _tokenName
    ) external onlyCEO {

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
            'Amount more than game allocated balance'
        );

        ERC20Token token = ERC20Token(tokens[_tokenName]);

        games[_gameID].gameTokens[_tokenName] = games[_gameID]
            .gameTokens[_tokenName]
            .sub(_amount);
        token.transfer(ceoAddress, _amount); // transfer contract funds to contract owner

        emit NewBalance(_gameID, games[_gameID].gameTokens[_tokenName]); // notify server of new contract balance
    }

    function withdrawMaxTokenBalance(string calldata _tokenName)
        external
        onlyCEO
    {
        ERC20Token token = ERC20Token(tokens[_tokenName]);
        uint256 amount = token.balanceOf(address(this));

        for (uint256 i = 0; i < games.length; i++) {
            games[i].gameTokens[_tokenName] = 0; // reset game-specific token that is being withdrawn to 0
        }

        token.transfer(ceoAddress, amount); // withdraw max token amount
    }

}
