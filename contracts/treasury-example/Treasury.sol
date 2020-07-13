pragma solidity ^0.5.17;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/ERC20Token.sol";
import "../common-contracts/HashChain.sol";
import "../common-contracts/AccessController.sol";

contract GameController is AccessController {

    enum GameStatus { Empty, Enabled, Disabled }

    struct Game {
        address gameAddress;
        string gameName;
    }

    struct GameSettings {
        uint8 index;
        GameStatus status;
    }

    Game[] public treasuryGames;
    mapping(address => GameSettings) public settings;
    mapping(uint8 => mapping(uint8 => uint256)) gameTokens;
    mapping(uint8 => mapping(uint8 => uint128)) maximumBet;

    modifier onlyDeclaredGame(uint8 _gameIndex) {
        require(
            settings[
                treasuryGames[_gameIndex].gameAddress
            ].status != GameStatus.Empty,
            "Treasury: game is not declared!"
        );
        _;
    }

    modifier onlyEnabledGame(uint8 _gameIndex) {
        require(
            settings[
                treasuryGames[_gameIndex].gameAddress
            ].status == GameStatus.Enabled,
            "Treasury: game must be enabled!"
        );
        _;
    }

    modifier onlyDisabledGame(uint8 _gameIndex) {
        require(
            settings[
                treasuryGames[_gameIndex].gameAddress
            ].status == GameStatus.Disabled,
            "Treasury: game must be disabled!"
        );
        _;
    }

   function addGame(
        address _newGameAddress,
        string calldata _newGameName,
        bool _isActive
    ) external onlyCEO {
        require(
            settings[_newGameAddress].status == GameStatus.Empty,
            'Treasury: game already declared!'
        );
        treasuryGames.push(
            Game({
                gameAddress: _newGameAddress,
                gameName: _newGameName
            })
        );
        settings[_newGameAddress].index = uint8(treasuryGames.length - 1);
        settings[_newGameAddress].status = _isActive == true
            ? GameStatus.Enabled
            : GameStatus.Disabled;
    }

    function getGameIndex(
        address _gameAddress
    ) internal view returns (uint8) {
        require(
            settings[_gameAddress].status != GameStatus.Empty,
            'Treasury: game is not declared!'
        );
        return settings[_gameAddress].index;
    }

    function updateGameAddress(
        uint8 _gameIndex,
        address _newGameAddress
    ) external onlyCEO onlyDeclaredGame(_gameIndex) {

        require(
            settings[_newGameAddress].status == GameStatus.Empty,
            'Treasury: game with new address already declared!'
        );

        settings[_newGameAddress] = settings[treasuryGames[_gameIndex].gameAddress];
        delete settings[treasuryGames[_gameIndex].gameAddress];
        treasuryGames[_gameIndex].gameAddress = _newGameAddress;
    }

    function updateGameName(
        uint8 _gameIndex,
        string calldata _newGameName
    ) external onlyCEO {
        treasuryGames[_gameIndex].gameName = _newGameName;
    }

    function enableGame(
        uint8 _gameIndex
    ) external onlyCEO onlyDisabledGame(_gameIndex) {
        settings[
            treasuryGames[_gameIndex].gameAddress
        ].status = GameStatus.Enabled;
    }

    function disableGame(
        uint8 _gameIndex
    ) external onlyCEO onlyEnabledGame(_gameIndex) {
        settings[
            treasuryGames[_gameIndex].gameAddress
        ].status = GameStatus.Disabled;
    }
}

contract TokenController is AccessController {

    struct Token {
        address tokenAddress;
        string tokenName;
    }

    Token[] public treasuryTokens;

    function addToken(
        address _tokenAddress,
        string memory _tokenName
    ) public onlyCEO {
        treasuryTokens.push(Token({
            tokenAddress: _tokenAddress,
            tokenName: _tokenName
        }));
    }

    function getTokenInstance(
        uint8 _tokenIndex
    ) internal view returns (ERC20Token) {
        return ERC20Token(treasuryTokens[_tokenIndex].tokenAddress);
    }

    function getTokenAddress(
        uint8 _tokenIndex
    ) external view returns (address) {
        return treasuryTokens[_tokenIndex].tokenAddress;
    }

    function getTokenName(
        uint8 _tokenIndex
    ) external view returns (string memory) {
        return treasuryTokens[_tokenIndex].tokenName;
    }

    function updateTokenAddress(
        uint8 _tokenIndex,
        address _newTokenAddress
    ) external onlyCEO {
        treasuryTokens[_tokenIndex].tokenAddress = _newTokenAddress;
    }

    function updateTokenName(
        uint8 _tokenIndex,
        string calldata _newTokenName
    ) external onlyCEO {
        treasuryTokens[_tokenIndex].tokenName = _newTokenName;
    }

    function deleteToken(
        uint8 _tokenIndex
    ) external onlyCEO {
        ERC20Token token = getTokenInstance(_tokenIndex);
        require(
            token.balanceOf(address(this)) == 0,
            'TokenController: balance detected'
        );
        delete treasuryTokens[_tokenIndex];
    }
}

contract Treasury is GameController, TokenController, HashChain {

    using SafeMath for uint256;

    constructor(
        address _defaultTokenAddress,
        string memory _defaultTokenName,
        address _migrationAddress
    ) public {
        _migrationAddress == address(0x0)
            ? addToken(_defaultTokenAddress, _defaultTokenName)
            : setCEO(_migrationAddress);
    }

    function tokenInboundTransfer(
        uint8 _tokenIndex,
        address _from,
        uint256 _amount
    ) external returns (bool) {
        uint8 _gameIndex = getGameIndex(msg.sender);
        ERC20Token token = getTokenInstance(_tokenIndex);
        addGameTokens(_gameIndex, _tokenIndex, _amount);
        token.transferFrom(_from, address(this), _amount);
        return true;
    }

    function addGameTokens(uint8 _gameIndex, uint8 _tokenIndex, uint256 _amount) private {
        gameTokens[_gameIndex][_tokenIndex] = gameTokens[_gameIndex][_tokenIndex].add(_amount);
    }

    function tokenOutboundTransfer(
        uint8 _tokenIndex,
        address _to,
        uint256 _amount
    ) external returns (bool) {
        uint8 _gameIndex = getGameIndex(msg.sender);
        ERC20Token token = getTokenInstance(_tokenIndex);
        subGameTokens(_gameIndex, _tokenIndex, _amount);
        token.transfer(_to, _amount);
        return true;
    }

    function subGameTokens(uint8 _gameIndex, uint8 _tokenIndex, uint256 _amount) private {
        gameTokens[_gameIndex][_tokenIndex] = gameTokens[_gameIndex][_tokenIndex].sub(_amount);
    }

    function setMaximumBet(
        uint8 _gameIndex,
        uint8 _tokenIndex,
        uint128 _maximumBet
    ) external onlyCEO onlyDeclaredGame(_gameIndex) {
        maximumBet[_gameIndex][_tokenIndex] = _maximumBet;
    }

    function gameMaximumBet(
        uint8 _gameIndex,
        uint8 _tokenIndex
    ) external view onlyDeclaredGame(_gameIndex) returns (uint256) {
        return maximumBet[_gameIndex][_tokenIndex];
    }

    function getMaximumBet(
        uint8 _tokenIndex
    ) external view returns (uint128) {
        uint8 _gameIndex = getGameIndex(msg.sender);
        return maximumBet[_gameIndex][_tokenIndex];
    }

    function deleteGame(
        uint8 _gameIndex
    ) public onlyCEO {
        for (uint8 _tokenIndex = 0; _tokenIndex < treasuryTokens.length; _tokenIndex++) {
            _withdrawGameTokens(
                _gameIndex, _tokenIndex, gameTokens[_gameIndex][_tokenIndex]
            );
            gameTokens[_gameIndex][_tokenIndex] = 0;
            maximumBet[_gameIndex][_tokenIndex] = 0;
        }
        delete treasuryGames[_gameIndex];
    }

    function checkApproval(
        address _userAddress,
        uint8 _tokenIndex
    ) external view returns (uint256) {
        return getTokenInstance(_tokenIndex).allowance(
            _userAddress,
            address(this)
        );
    }

    function() external payable {
        revert();
    }

    function addFunds(
        uint8 _gameIndex,
        uint8 _tokenIndex,
        uint256 _tokenAmount
    ) external {

        require(
            _gameIndex < treasuryGames.length,
            'Treasury: unregistered gameIndex'
        );

        require(
            _tokenIndex < treasuryTokens.length,
            'Treasury: unregistered tokenIndex'
        );

        ERC20Token token = getTokenInstance(_tokenIndex);
        addGameTokens(_gameIndex, _tokenIndex, _tokenAmount);
        token.transferFrom(msg.sender, address(this), _tokenAmount);
    }

    function checkAllocatedTokens(
        uint8 _tokenIndex
    ) external view returns (uint256) {
        uint8 _gameIndex = getGameIndex(msg.sender);
        return _checkAllocatedTokens(_gameIndex, _tokenIndex);
    }

    function _checkAllocatedTokens(
        uint8 _gameIndex,
        uint8 _tokenIndex
    ) internal view returns (uint256) {
        return gameTokens[_gameIndex][_tokenIndex];
    }

    function checkGameTokens(
        uint8 _gameIndex,
        uint8 _tokenIndex
    ) external view returns (uint256) {
        return _checkAllocatedTokens(_gameIndex, _tokenIndex);
    }

    function _withdrawGameTokens(
        uint8 _gameIndex,
        uint8 _tokenIndex,
        uint256 _amount
    ) internal {
        ERC20Token token = getTokenInstance(_tokenIndex);
        subGameTokens(_gameIndex, _tokenIndex, _amount);
        token.transfer(ceoAddress, _amount);
    }

    function withdrawGameTokens(
        uint8 _gameIndex,
        uint8 _tokenIndex,
        uint256 _amount
    ) external onlyCEO {
        _withdrawGameTokens(_gameIndex, _tokenIndex, _amount);
    }

    function withdrawTreasuryTokens(
        uint8 _tokenIndex
    ) public onlyCEO {

        ERC20Token token = getTokenInstance(_tokenIndex);

        uint256 amount = token.balanceOf(
            address(this)
        );

        for (uint256 i = 0; i < treasuryGames.length; i++) {
            uint8 _gameIndex = settings[
                treasuryGames[i].gameAddress
            ].index;
            gameTokens[_gameIndex][_tokenIndex] = 0;
        }
        token.transfer(ceoAddress, amount);
    }

    function setTail(
        bytes32 _tail
    ) external onlyCEO {
        _setTail(_tail);
    }

    function consumeHash(
        bytes32 _localhash
    ) external returns (bool) {
        require(
            settings[msg.sender].status == GameStatus.Enabled,
            'Treasury: active-game not present'
        );
        _consume(_localhash);
        return true;
    }

    function migrateTreasury(
        address _newTreasury
    ) external onlyCEO returns (bool) {

        TreasuryMigration nt = TreasuryMigration(_newTreasury);

        for (uint8 g = 0; g < treasuryGames.length; g++) {
            bool gameStatus = settings[treasuryGames[g].gameAddress].status == GameStatus.Enabled ? true : false;
            nt.addGame(
                treasuryGames[g].gameAddress,
                treasuryGames[g].gameName,
                gameStatus
            );
            GameMigration gm = GameMigration(treasuryGames[g].gameAddress);
            gm.migrateTreasury(_newTreasury);
        }

        for (uint8 t = 0; t < treasuryTokens.length; t++) {
            nt.addToken(
                treasuryTokens[t].tokenAddress,
                treasuryTokens[t].tokenName
            );

            ERC20Token token = getTokenInstance(t);
            token.approve(
                _newTreasury,
                token.balanceOf(address(this))
            );

            for (uint8 j = 0; j < treasuryGames.length; j++) {
                uint256 amount = gameTokens[j][t];
                uint128 maxBet = maximumBet[j][t];
                nt.addFunds(j, t, amount);
                nt.setMaximumBet(j, t, maxBet);
                gameTokens[j][t] = 0;
            }
        }

        nt.setTail(tail);
        nt.setCEO(msg.sender);
    }
}

interface GameMigration {
    function migrateTreasury(
        address _newTreasuryAddress
    ) external;
}

interface TreasuryMigration {
    function addGame(
        address _newGameAddress,
        string calldata _newGameName,
        bool _isActive
    ) external;

    function addToken(
        address _tokenAddress,
        string calldata _tokenName
    ) external;

    function addFunds(
        uint8 _gameIndex,
        uint8 _tokenIndex,
        uint256 _tokenAmount
    ) external;

    function setCEO(
        address _newCEO
    ) external;

    function setMaximumBet(
        uint8 _gameIndex,
        uint8 _tokenIndex,
        uint128 _maximumBet
    ) external;

    function setTail(
        bytes32 _tail
    ) external;
}
