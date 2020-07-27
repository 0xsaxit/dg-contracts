pragma solidity ^0.5.17;

import "./common-contracts/SafeMath.sol";
import "./common-contracts/AccessController.sol";
import "./common-contracts/TreasuryInstance.sol";

contract BlackJackHelper {

    bytes13 cardsPower = "\x0B\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0A\x0A\x0A";

    function getCardsRawData(uint8 _card) public pure returns (uint8, uint8) {
        return (_card / 13, _card % 13);
    }

    function getCardsDetails(uint8 _card) public pure returns (string memory, string memory) {

        string[4] memory Suits = ["C", "D", "H", "S"];
        string[13] memory Vals = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K"];

        (uint8 _suit, uint8 _val) = getCardsRawData(_card);
        return (Suits[_suit], Vals[_val]);
    }

    function getRandomCardIndex(
        bytes32 _localhash,
        uint256 _length
    ) internal pure returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    _localhash, _length
                )
            )
        ) % _length;
    }

    function getHandsPower(uint[] memory cards) public view returns (uint8 powerMax) {
        uint8 aces;
        uint8 power;
        for (uint8 i = 0; i < cards.length; i++) {
            power = uint8(cardsPower[(cards[i] + 12) % 12]);
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

}

contract TreasuryBlackJack is AccessController, BlackJackHelper {

    using SafeMath for uint128;
    using SafeMath for uint256;

    enum GameState {NewGame, OnGoingGame, EndedGame}
    // enum PlayerState {Busted, Double, Insured, BlackJack, Win}

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
    mapping(bytes16 => Card[]) public DealersHandHidden;
    mapping(bytes16 => uint8[]) public DealersHandVisible;
    // mapping(address => mapping(bytes16 => Card[])) public PlayersHand;
    mapping(address => mapping(bytes16 => uint8[])) public PlayersHand;

    modifier onlyOnGoingGame(bytes16 gameId) {
        require(
            Games[gameId].state == GameState.OnGoingGame,
            'must be ongoing game'
        );
        _;
    }

    modifier isPlayerInGame(bytes16 gameId, address player) {
        require(
            1 == 1,
            // player == Games[gameId].playerOne ||
            // player == Games[gameId].playerTwo,
            'must be one of the players'
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
    returns (
        bytes16 gameId
    )
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
        for (uint8 i = 0; i < _players.length; i++){

            /* treasury.tokenInboundTransfer(
                _tokens[i], _players[i], _bets[i]
            );*/

            PlayersHand[_players[i]][gameId].push(
                drawCard(gameId, getRandomCardIndex(
                        _localhash, _deck.length
                    )
                )
            );
        }

        // first card drawn to dealer (visible)

        // second card drawn to each player
        for (uint8 i = 0; i < _players.length; i++) {
            PlayersHand[_players[i]][gameId].push(
                drawCard(gameId, getRandomCardIndex(
                        _localhash, _deck.length
                    )
                )
            );
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
        // onlyNonBusted(_player)
        onlyOnGoingGame(_gameId) {

    }

    function stayMove(
        bytes16 _gameId,
        address _player
    )
        external
        onlyWorker
        // onlyNonBusted(_player)
        onlyOnGoingGame(_gameId)
    {

    }

    function insuranceMove(
        bytes16 _gameId,
        address _player
    )
        external
        onlyWorker
        // onlyNonBusted(_player)
        onlyOnGoingGame(_gameId)
    {

    }

    function splittingPairs(
        bytes16 _gameId,
        address _player
    )
        external
        onlyWorker
        // onlyNonBusted(_player)
        onlyOnGoingGame(_gameId)
    {

    }

    function doublingDown(
        bytes16 _gameId,
        address _player
    )
        external
        onlyWorker
        // onlyNonBusted(_player)
        onlyOnGoingGame(_gameId)
    {

    }

    function dealersTurn(
        bytes16 _gameId,
        bytes32 _localhash
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        // whenTableSettled
    {

    }

    function applyPercent(uint256 _value) public view returns (uint256) {
        return _value.mul(
            100 - uint256(uint8(store>>8))
        ).div(100);
    }

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
        uint256 gameId,
        address player
    )
        external
        view
        returns (bool)
    {
        //if (
          //  player == Games[gameId].playerOne ||
        //    player == Games[gameId].playerTwo
        //) return true;
    }

    function changeSafeFactor(uint8 _newFactor) external onlyCEO {
        require(_newFactor > 0, 'must be above zero');
        store ^= uint8(store)<<0;
        store |= _newFactor<<0;
    }

    function changeFeePercent(uint8 _newFeePercent) external onlyCEO {
        require(_newFeePercent < 20, 'must be below 20');
        store ^= (store>>8)<<8;
        store |= uint256(_newFeePercent)<<8;
    }


    function changeTreasury(address _newTreasuryAddress) external onlyCEO {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }

    function _changeTreasury(address _newTreasuryAddress) external onlyTreasury {
        treasury = TreasuryInstance(_newTreasuryAddress);
    }

    function subBytes(bytes1 a, bytes1 b) internal pure returns (bytes1 x) {
        assembly {
            x := sub(a, b)
        }
    }

    function addBytes(bytes1 a, bytes1 b) internal pure returns (bytes1 x) {
        assembly {
            x := add(a, b)
        }
    }

    function getCardsPower2(uint[] memory cards) public view returns (uint8 powerMax) {
        uint8 aces;
        uint8 power;
        for (uint8 i = 0; i < cards.length; i++) {
            power = uint8(cardsPower[(cards[i] + 12) % 12]);
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

    function getCardsPower(uint8[] memory cards) public view returns (bytes1 powerMax) {
        bytes1 aces;
        bytes1 power;
        for (uint8 i = 0; i < cards.length; i++) {
            power = cardsPower[(cards[i] + 12) % 12];
            powerMax = addBytes(powerMax, power);
            if (power == cardsPower[0]) {
                aces = addBytes(aces, '\x01');
            }
        }
        if (powerMax > '\x15') {
            for (uint8 i = 0; i < uint8(aces); i++) {
                powerMax = subBytes(powerMax, '\x0A');
                if (powerMax <= '\x15') {
                    break;
                }
            }
        }
        return powerMax;
    }

    function migrateTreasury(address _newTreasuryAddress) external {
        require(
            msg.sender == address(treasury),
            'wrong current treasury address'
        );
        treasury = TreasuryInstance(_newTreasuryAddress);
    }
}