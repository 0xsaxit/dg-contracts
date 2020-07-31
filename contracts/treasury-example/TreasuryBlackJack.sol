pragma solidity ^0.5.17;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/AccessController.sol";
import "../common-contracts/TreasuryInstance.sol";

contract BlackJackHelper {

    function getCardsRawData(uint8 _card) public pure returns (uint8, uint8) {
        return (_card / 13, _card % 13);
    }

    function getCardsDetails(uint8 _card) public pure returns (string memory, string memory) {

        string[4] memory Suits = ["C", "D", "H", "S"];
        string[13] memory Vals = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K"];

        (uint8 _suit, uint8 _val) = getCardsRawData(_card);
        return (Suits[_suit], Vals[_val]);
    }

    function getRandomCardIndex(bytes32 _localhash, uint256 _length) internal pure returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    _localhash, _length
                )
            )
        ) % _length;
    }

    function getHandsPower(uint8[] memory _cards) public pure returns (uint8 powerMax) {

        bytes13 cardsPower = "\x0B\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0A\x0A\x0A";

        uint8 aces;
        uint8 power;
        for (uint8 i = 0; i < _cards.length; i++) {
            power = uint8(cardsPower[(_cards[i] + 12) % 12]);
            powerMax += power;
            if (power == 11) {
                aces += 1;
            }
        }
        if (powerMax > 21) {
            for (uint8 i = 0; i < aces; i++) {
                powerMax -= 10;
                if (powerMax <= 21) {
                    break;
                }
            }
        }
        return powerMax;
    }

    function isBlackJack(uint8[] memory _cards) public pure returns (bool) {
        return getHandsPower(_cards) == 21 && _cards.length == 2 ? true : false;
    }

}

contract TreasuryBlackJack is AccessController, BlackJackHelper {

    using SafeMath for uint128;
    using SafeMath for uint256;

    enum GameState { NewGame, OnGoingGame, EndedGame }
    enum PlayerState { notDetected, notBusted, isSettled, isBusted, BlackJack }
    // enum PlayerState {Busted, Double, Insured, Split, Win}

    struct Game {
        address[] players;
        uint128[] bets;
        uint8[] tokens;
        uint8[] deck;
        // bool[] wins;
        // uint8[] scores;
        GameState state;
    }

    struct Card {
        bytes32 hashChild;
        bytes32 hashParent;
        uint8 index;
    }

    mapping(bytes16 => Game) public Games;
    mapping(bytes16 => Card[]) public DealersHidden;
    mapping(bytes16 => uint8[]) public DealersVisible;
    // mapping(address => mapping(bytes16 => Card[])) public PlayersHand;
    mapping(address => mapping(bytes16 => uint8[])) public PlayersHand;
    mapping(address => mapping(bytes16 => PlayerState)) public playersState;

    modifier onlyOnGoingGame(bytes16 gameId) {
        require(
            Games[gameId].state == GameState.OnGoingGame,
            'BlackJack: must be ongoing game'
        );
        _;
    }

    modifier isPlayerInGame(bytes16 _gameId, address _player) {
        require(
            playersState[_player][_gameId] != PlayerState.notDetected,
            "BlackJack: given player is not in the current game"
        );
        _;
    }

    modifier onlyNonBusted(bytes16 _gameId, address _player) {
        require(
            playersState[_player][_gameId] == PlayerState.notBusted,
            "BlackJack: given player already busted in this game"
        );
        _;
    }

    modifier onlyNotSettled(bytes16 _gameId, address _player) {
        require(
            playersState[_player][_gameId] != PlayerState.isSettled,
            "BlackJack: given player already settled in this game"
        );
        _;
    }

    modifier whenTableSettled(bytes16 gameId) {
        address[] memory _players = Games[gameId].players;
        for (uint8 i = 0; i < _players.length; i++) {
            require(
                uint8(playersState[_players[i]][gameId]) > 1,
                'BlackJack: not all players finished their turn'
            );
        }
        _;
    }

    TreasuryInstance public treasury;

    uint256 private store;
    uint8 maxPlayers; // consider moving to store

    event GameInitialized(
        bytes16 gameId,
        address[] players,
        uint128[] bets,
        uint8[] tokens,
        uint256 landId,
        uint256 tableId
    );

    event DealersMove(
        bytes16 gameId,
        bytes32 firsthash,
        bytes32 localhash
    );

    constructor(address _treasuryAddress, uint8 _maxPlayers) public {
        treasury = TreasuryInstance(_treasuryAddress);
        maxPlayers = _maxPlayers;
    }

    function initializeGame(
        address[] calldata _players,
        uint128[] calldata _bets,
        uint8[] calldata _tokens,
        uint256 _landId,
        uint256 _tableId,
        bytes32 _localhash
    )
        external
        whenNotPaused
        onlyWorker
        returns (bytes16 gameId)
    {
        require(
            _bets.length == _tokens.length &&
            _tokens.length == _players.length,
            'BlackJack: inconsistent parameters'
        );

        require(
            _players.length <= maxPlayers,
            'BlackJack: too many players'
        );

        gameId = getGameId(_landId, _tableId, _players);

        require(
            Games[gameId].state == GameState.NewGame ||
            Games[gameId].state == GameState.EndedGame,
            'BlackJack: cannot initialize running game'
        );

        uint8[] storage _deck = prepareDeck(gameId);

        Game memory _game = Game(
            _players,
            _bets,
            _tokens,
            _deck,
            GameState.OnGoingGame
        );

        Games[gameId] = _game;

        // first card drawn to each player + take bets
        for (uint8 i = 0; i < _players.length; i++) {

            /* treasury.tokenInboundTransfer(
                _tokens[i], _players[i], _bets[i]
            );*/

            PlayersHand[_players[i]][gameId].push(
                drawCard(gameId, getRandomCardIndex(
                        _localhash, _deck.length
                    )
                )
            );

            playersState[_players[i]][gameId] = PlayerState.notBusted;
        }

        // first card drawn to dealer (visible)
        DealersVisible[gameId].push(
            drawCard(gameId, getRandomCardIndex(
                    _localhash, _deck.length
                )
            )
        );

        // second card drawn to each player
        for (uint8 i = 0; i < _players.length; i++) {
            PlayersHand[_players[i]][gameId].push(
                drawCard(gameId, getRandomCardIndex(
                        _localhash, _deck.length
                    )
                )
            );
            if (isBlackJack(PlayersHand[_players[i]][gameId])) {
                playersState[_players[i]][gameId] = PlayerState.BlackJack;
            }
        }

        // second card drawn to dealer (hidden)

        emit GameInitialized(
            gameId,
            _players,
            _bets,
            _tokens,
            _landId,
            _tableId
        );
    }

    function verifyCard(
        bytes32 _hashChild,
        bytes32 _hashParent
    ) public pure returns (bool) {
        keccak256(
            abi.encodePacked(_hashParent)
        ) == _hashChild ? true : false;
    }

    function prepareDeck(bytes16 _gameId) internal returns (uint8[] storage _deck) {
        _deck = Games[_gameId].deck;
		for (uint8 i = 0; i < 52; i++) {
			_deck.push(i);
		}
    }

    function drawCard(
        bytes16 _gameId,
        uint256 _card
    ) internal returns (uint8) {
        uint8[] storage _deck = Games[_gameId].deck;
        uint8 card = _deck[_card];
        _deck[_card] = _deck[_deck.length - 1];
        _deck.pop();
        return card;
    }

    function hitMove(
        bytes16 _gameId,
        address _player,
        bytes32 _localhash
    )
        external
        onlyWorker
        onlyNonBusted(_gameId, _player)
        onlyOnGoingGame(_gameId)
    {
        PlayersHand[_player][_gameId].push(
            drawCard(_gameId, getRandomCardIndex(
                    _localhash, Games[_gameId].deck.length
                )
            )
        );

        uint8 playersPower = getHandsPower(
            PlayersHand[_player][_gameId]
        );

        if (playersPower > 21) {
            playersState[_player][_gameId] = PlayerState.isBusted;
        }

        if (playersPower == 21) {
            playersState[_player][_gameId] = PlayerState.isSettled;
        }
    }

    function stayMove(
        bytes16 _gameId,
        address _player
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        onlyNonBusted(_gameId, _player)
    {
        playersState[_player][_gameId] = PlayerState.isSettled;
    }

    function dealersTurn(
        bytes16 _gameId,
        bytes32 _firsthash,
        bytes32 _localhash
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        whenTableSettled(_gameId)
    {
        // reveal dealers card with _firsthash

        // draw cards for dealer with _localhash

        // calculate any winnings and payout

        Games[_gameId].state = GameState.EndedGame;

        emit DealersMove (
            _gameId,
            _firsthash,
            _localhash
        );
    }

    /* TO-DO:

    function insuranceMove(
        bytes16 _gameId,
        address _player
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        onlyNonBusted(_gameId, _player)
    {

    }

    function splittingPairs(
        bytes16 _gameId,
        address _player
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        onlyNonBusted(_gameId, _player)
    {

    }

    function doublingDown(
        bytes16 _gameId,
        address _player
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        isPlayerInGame(_gameId, _player)
        onlyNonBusted(_gameId, _player)
    {

    }

    */

    function checkDeck(bytes16 _gameId) public view returns (uint8[] memory _deck) {
        return Games[_gameId].deck;
    }

    function getGameId(
        uint256 _landID,
        uint256 _tableID,
        address[] memory _players
    )
        public
        pure
        returns (bytes16 gameId)
    {
        gameId = bytes16(
            keccak256(
                abi.encodePacked(_landID, _tableID, _players)
            )
        );
    }

    function checkPlayerInGame(
        bytes16 _gameId,
        address _player
    )
        external
        view
        returns (bool)
    {
        return playersState[_player][_gameId] == PlayerState.notDetected ? false : true;
    }

    function changeTreasury(
        address _newTreasuryAddress
    )
        external
        onlyCEO
    {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }
}