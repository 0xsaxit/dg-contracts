pragma solidity ^0.5.14;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessControl.sol";
import "../common-contracts/ERC20Token.sol";
import "../common-contracts/HashChain.sol";

contract Treasury is HashChain, AccessControl {

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

    constructor(address _defaultToken, string memory _tokenName, address _migrationAddress) public {

        _migrationAddress == address(0x0)
            ? setDefaultToken(_defaultToken, _tokenName)
            : setCEO(_migrationAddress);
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

        selfdestruct(msg.sender);
    }
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
