pragma solidity ^0.5.17;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/ERC20Token.sol";
import "../common-contracts/HashChain.sol";
import "../common-contracts/AccessController.sol";

contract GameController is AccessController {

    struct Game {
        address gameAddress;
        string gameName;
        mapping(uint8 => uint256) gameTokens;
        mapping(uint8 => uint128) maximumBet;
        bool isActive;
    }

    Game[] public treasuryGames;

   function addGame(
        address _newGameAddress,
        string calldata _newGameName,
        bool _isActive
    ) external onlyCEO {
        treasuryGames.push(
            Game({
                gameAddress: _newGameAddress,
                gameName: _newGameName,
                isActive: _isActive
            })
        );
    }

    function getGameIndex(
        address _gameAddress
    ) internal view returns (bool, uint8) {
        for (uint8 i = 0; i < treasuryGames.length; i++) {
            if (treasuryGames[i].gameAddress == _gameAddress) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function getGameInstance(
        address _gameAddress
    ) internal view returns (Game storage) {
        (bool result, uint gameIndex) = getGameIndex(_gameAddress);
        require(
            result && treasuryGames[gameIndex].isActive,
            'Treasury: active-game not present'
        );
        return treasuryGames[gameIndex];
    }

    function deleteGame(
        uint8 _gameIndex
    ) public onlyCEO {
        delete treasuryGames[_gameIndex];
    }

    function moveGame(
        uint8 _gameIndex,
        uint8 _newGameIndex
    ) external onlyCEO {
        treasuryGames[_newGameIndex] = treasuryGames[_gameIndex];
        deleteGame(_gameIndex);
    }

    function updateGameAddress(
        uint8 _gameIndex,
        address _newGameAddress
    ) external onlyCEO {
        treasuryGames[_gameIndex].gameAddress = _newGameAddress;
    }

    function updateGameName(
        uint8 _gameIndex,
        string calldata _newGameName
    ) external onlyCEO {
        treasuryGames[_gameIndex].gameName = _newGameName;
    }

    function updateGameStatus(
        uint8 _gameIndex,
        bool _newGameStatus
    ) external onlyCEO {
        treasuryGames[_gameIndex].isActive = _newGameStatus;
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
        uint256 _tokenIndex
    ) external view returns (address) {
        return treasuryTokens[_tokenIndex].tokenAddress;
    }

    function getTokenName(
        uint256 _tokenIndex
    ) external view returns (string memory) {
        return treasuryTokens[_tokenIndex].tokenName;
    }

    function updateTokenAddress(
        uint8 _tokenIndex,
        address _newTokenAddress
    ) public onlyCEO {
        treasuryTokens[_tokenIndex].tokenAddress = _newTokenAddress;
    }

    function updateTokenName(
        uint8 _tokenIndex,
        address _newTokenAddress
    ) public onlyCEO {
        treasuryTokens[_tokenIndex].tokenAddress = _newTokenAddress;
    }

    function deleteToken(
        uint8 _tokenIndex
    ) public onlyCEO {
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
        Game storage game = getGameInstance(msg.sender);
        ERC20Token token = getTokenInstance(_tokenIndex);
        addGameTokens(game, _tokenIndex, _amount);
        token.transferFrom(_from, address(this), _amount);
        return true;
    }

    function addGameTokens(Game storage _game, uint8 _tokenIndex, uint256 _amount) private {
        _game.gameTokens[_tokenIndex] = _game.gameTokens[_tokenIndex].add(_amount);
    }

    function tokenOutboundTransfer(
        uint8 _tokenIndex,
        address _to,
        uint256 _amount
    ) external returns (bool) {
        Game storage game = getGameInstance(msg.sender);
        ERC20Token token = getTokenInstance(_tokenIndex);
        subGameTokens(game, _tokenIndex, _amount);
        token.transfer(_to, _amount);
        return true;
    }

    function subGameTokens(Game storage _game, uint8 _tokenIndex, uint256 _amount) private {
        _game.gameTokens[_tokenIndex] = _game.gameTokens[_tokenIndex].sub(_amount);
    }

    function setMaximumBet(
        uint8 _gameIndex,
        uint8 _tokenIndex,
        uint128 _maximumBet
    ) external onlyCEO {
        treasuryGames[_gameIndex].maximumBet[_tokenIndex] = _maximumBet;
    }

    function gameMaximumBet(
        uint8 _gameIndex,
        uint8 _tokenIndex
    ) external view returns (uint256) {
        return treasuryGames[_gameIndex].maximumBet[_tokenIndex];
    }

    function getMaximumBet(
        uint8 _tokenIndex
    ) external view returns (uint128) {
        Game storage _game = getGameInstance(msg.sender);
        return _game.maximumBet[_tokenIndex];
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
        addGameTokens(treasuryGames[_gameIndex], _tokenIndex, _tokenAmount);
        token.transferFrom(msg.sender, address(this), _tokenAmount);
    }

    function checkAllocatedTokens(
        uint8 _tokenIndex
    ) external view returns (uint256) {
        Game storage _game = getGameInstance(msg.sender);
        return _checkAllocatedTokens(_game, _tokenIndex);
    }

    function _checkAllocatedTokens(
        Game storage _game,
        uint8 _tokenIndex
    ) internal view returns (uint256) {
        return _game.gameTokens[_tokenIndex];
    }

    function checkGameTokens(
        uint8 _gameIndex,
        uint8 _tokenIndex
    ) external view returns (uint256) {
        Game storage _game = treasuryGames[_gameIndex];
        return _checkAllocatedTokens(_game, _tokenIndex);
    }

    function withdrawGameTokens(
        uint8 _gameIndex,
        uint8 _tokenIndex,
        uint256 _amount
    ) external onlyCEO {
        Game storage _game = treasuryGames[_gameIndex];
        ERC20Token token = getTokenInstance(_tokenIndex);
        subGameTokens(_game, _tokenIndex, _amount);
        token.transfer(ceoAddress, _amount);
    }

    function withdrawTreasuryTokens(
        uint8 _tokenIndex
    ) public onlyCEO {

        ERC20Token token = getTokenInstance(_tokenIndex);

        uint256 amount = token.balanceOf(
            address(this)
        );

        for (uint256 i = 0; i < treasuryGames.length; i++) {
            treasuryGames[i].gameTokens[_tokenIndex] = 0;
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
        (bool result, uint gameIndex) = getGameIndex(msg.sender);
        require(
            result && treasuryGames[gameIndex].isActive,
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
            nt.addGame(
                treasuryGames[g].gameAddress,
                treasuryGames[g].gameName,
                treasuryGames[g].isActive
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
                uint256 amount = treasuryGames[j].gameTokens[t];
                uint128 maxBet = treasuryGames[j].maximumBet[t];
                nt.addFunds(j, t, amount);
                nt.setMaximumBet(j, t, maxBet);
                treasuryGames[j].gameTokens[t] = 0;
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
