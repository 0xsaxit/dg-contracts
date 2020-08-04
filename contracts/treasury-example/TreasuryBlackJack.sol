pragma solidity ^0.5.17;

import "../common-contracts/SafeMath.sol";
import "../common-contracts/HashChain.sol";
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
            power = uint8(cardsPower[_cards[i] % 13]);
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

    function verifyHiddenCard(bytes32 _hashChild, bytes32 _hashParent) public pure returns (bool) {
        return keccak256(
            abi.encodePacked(_hashParent)
        ) == _hashChild ? true : false;
    }
}

contract TreasuryBlackJack is AccessController, BlackJackHelper, HashChain {

    using SafeMath for uint128;
    using SafeMath for uint256;

    enum GameState { NewGame, OnGoingGame, EndedGame }
    enum PlayerState { notDetected, notBusted, isSettled, isBusted, hasBlackJack }

    // enum PlayerState {Busted, Double, Insured, Split, Win}

    struct Game {
        address[] players;
        uint128[] bets;
        uint8[] tokens;
        uint8[] deck;
        GameState state;
    }

    struct HiddenCard {
        bytes32 hashChild;
        bytes32 hashParent;
    }

    mapping(bytes16 => Game) public Games;
    mapping(bytes16 => HiddenCard) public DealersHidden;
    mapping(bytes16 => uint8[]) public DealersVisible;
    mapping(address => mapping(bytes16 => uint8[])) public PlayersHand;
    mapping(address => mapping(bytes16 => uint8[])) public PlayersSplit;
    mapping(address => mapping(bytes16 => bool)) public PlayersInsurance;
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
        for (uint256 i = 0; i < _players.length; i++) {
            require(
                uint8(playersState[_players[i]][gameId]) > uint8(PlayerState.notBusted),
                'BlackJack: not all players finished their turn'
            );
        }
        _;
    }

    TreasuryInstance public treasury;

    uint8 maxPlayers;

    event BetPlaced(
        uint8 tokenIndex,
        address player,
        uint256 betAmount
    );

    event GameInitializing(
        bytes16 gameId
    );

    event GameInitialized(
        bytes16 gameId,
        address[] players,
        uint128[] bets,
        uint8[] tokens,
        uint256 landId,
        uint256 tableId
    );

    event PlayerCardDrawn(
        bytes16 gameId,
        address player,
        uint8 playerIndex,
        uint8 cardsIndex,
        string cardSuit,
        string cardVal
    );

    event DealersMove(
        bytes16 gameId,
        bytes32 localhashB
    );

    constructor(address _treasuryAddress, uint8 _maxPlayers) public {
        require(_maxPlayers < 10);
        treasury = TreasuryInstance(_treasuryAddress);
        maxPlayers = _maxPlayers;
    }

    function takePlayersBet(bytes16 _gameId, uint8 _playerIndex) private {

        uint8 tokenIndex = Games[_gameId].tokens[_playerIndex];
        address player = Games[_gameId].players[_playerIndex];
        uint256 betAmount = Games[_gameId].bets[_playerIndex];

        require(
            treasury.getMaximumBet(tokenIndex) >= betAmount,
            'BlackJack: bet amount is more than maximum'
        );

        treasury.tokenInboundTransfer(
            tokenIndex, player, betAmount
        );

        emit BetPlaced(
            tokenIndex, player, betAmount
        );
    }

    function initializePlayer(bytes16 _gameId, address _player) private {
        playersState[_player][_gameId] = PlayerState.notBusted;
    }

    function checkForBlackJack(bytes16 _gameId, address _player) private {
        if (isBlackJack(PlayersHand[_player][_gameId])) {
            playersState[_player][_gameId] = PlayerState.hasBlackJack;
        }
    }

    function drawPlayersCard(
        bytes16 _gameId,
        uint8 _pIndex,
        bytes32 _localhashA,
        uint256 _deckLength
    )
        private
    {
        address _player = Games[_gameId].players[_pIndex];

        uint8 _card = drawCard(_gameId, getRandomCardIndex(
                _localhashA, _deckLength
            )
        );

        (
            string memory _cardsSuit,
            string memory _cardsVal
        ) = getCardsDetails(_card);

        PlayersHand[_player][_gameId].push(_card);

        emit PlayerCardDrawn(
            _gameId,
            _player,
            _pIndex,
            _card,
            _cardsSuit,
            _cardsVal
        );
    }

    function initializeGame(
        address[] calldata _players,
        uint128[] calldata _bets,
        uint8[] calldata _tokens,
        uint256 _landId,
        uint256 _tableId,
        bytes32 _localhashA,
        bytes32 _localhashB
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

        treasury.consumeHash(_localhashA);
        gameId = getGameId(_landId, _tableId, _players);

        require(
            Games[gameId].state == GameState.NewGame ||
            Games[gameId].state == GameState.EndedGame,
            'BlackJack: cannot initialize running game'
        );

        // starting to initialize game
        emit GameInitializing(gameId);

        uint8[] storage _deck = prepareDeck(gameId);

        Game memory _game = Game(
            _players,
            _bets,
            _tokens,
            _deck,
            GameState.OnGoingGame
        );

        Games[gameId] = _game;

        uint8 pIndex; // playersIndex

        // first card drawn to each player + take bets
        for (pIndex = 0; pIndex < _players.length; pIndex++) {

            initializePlayer(
                gameId, _players[pIndex]
            );

            takePlayersBet(
                gameId, pIndex
            );

            drawPlayersCard(
                gameId, pIndex, _localhashA, _deck.length
            );
        }

        // dealers first card (visible)
        DealersVisible[gameId].push(
            drawCard(gameId, getRandomCardIndex(
                    _localhashA, _deck.length
                )
            )
        );

        // emit event for dealers card;

        // players second cards (visible)
        for (pIndex = 0; pIndex < _players.length; pIndex++) {

            drawPlayersCard(
                gameId, pIndex, _localhashA, _deck.length
            );

            checkForBlackJack(
                gameId, _players[pIndex]
            );
        }

        delete pIndex;

        // dealers second card (hidden)
        DealersHidden[gameId] =
            HiddenCard({
                hashChild: _localhashB,
                hashParent: 0x0
            });

        // game initialized
        emit GameInitialized(
            gameId,
            _players,
            _bets,
            _tokens,
            _landId,
            _tableId
        );
    }

    function prepareDeck(
        bytes16 _gameId
    )
        internal
        returns (uint8[] storage _deck)
    {
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
        address _player, // consider removing
        uint8 _pIndex,
        bytes32 _localhashA
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        onlyNonBusted(_gameId, _player)
    {
        require(
            Games[_gameId].players[_pIndex] == _player,
            'BlackJack: wrong player arguments supplied'
        );

        treasury.consumeHash(_localhashA);

        drawPlayersCard(
           _gameId, _pIndex, _localhashA, Games[_gameId].deck.length
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
        address _player,
        uint8 _pIndex
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        onlyNonBusted(_gameId, _player)
    {

        require(
            Games[_gameId].players[_pIndex] == _player,
            'BlackJack: wrong player arguments supplied'
        );

        playersState[_player][_gameId] = PlayerState.isSettled;
    }

    function dealersTurn(
        bytes16 _gameId,
        bytes32 _localhashA,
        bytes32 _localhashB
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        whenTableSettled(_gameId)
    {
        require(
            DealersHidden[_gameId].hashParent == 0x0,
            "BlackJack: delaers move done in this game"
        );

        DealersHidden[_gameId].hashParent = _localhashB;

        require(
            verifyHiddenCard(
                DealersHidden[_gameId].hashChild,
                DealersHidden[_gameId].hashParent
            ) == true
        );

        treasury.consumeHash(_localhashA);
        treasury.consumeHash(_localhashB);

        uint8 revealed = drawCard(_gameId, getRandomCardIndex(
            _localhashB, Games[_gameId].deck.length
            )
        );

        DealersVisible[_gameId].push(revealed);

        delete revealed;

        uint256[] memory _leftPlayers = getNotBustedPlayers(_gameId);

        // check if any player left in game
        if (_leftPlayers.length > 0) {

            // check if dealer has a blackjack - proceed to payout

            if (isBlackJack(DealersVisible[_gameId])) {

                $payoutAgainstBlackJack(_gameId, _leftPlayers);

            // check if dealer needs more cards
            } else {

                uint8 dealersPower = getHandsPower(
                    DealersVisible[_gameId]
                );

                // draw cards for dealer with _localhashA
                while (dealersPower <= 16) {

                    DealersVisible[_gameId].push(
                        drawCard(_gameId, getRandomCardIndex(
                                _localhashA, Games[_gameId].deck.length
                            )
                        )
                    );

                    dealersPower = getHandsPower(
                        DealersVisible[_gameId]
                    );
                }

                // calculate any winnings and payout
                $payoutAgainstDealersHand(_gameId, _leftPlayers, dealersPower);
            }
        }

        Games[_gameId].state = GameState.EndedGame;

        emit DealersMove(
            _gameId,
            _localhashB
        );

        emit FinishedGame(
            _gameId,
            _localhashB
        );
    }

    function $payoutAgainstBlackJack(bytes16 _gameId, uint8[] memory _leftPlayers) private {
        for (uint256 i = 0; i < _leftPlayers.length; i++) {

            address player = Games[_gameId].players[_leftPlayers[i]];
            if (playersStatus[player][_gameId]) == PlayerState.hasBlackJack) {

                payoutAmount(
                    Games[_gameId].tokens[_leftPlayers[i]],
                    player, // payout same amount back 1x
                    Games[_gameId].bets[_leftPlayers[i]]
                );
            }
        }
    }

    function $payoutAgainstDealersHand(bytes16 _gameId, uint8[] memory _leftPlayers, uint8 _dealersPower) private {
        for (uint256 i = 0; i < _leftPlayers.length; i++) {

            uint8 pi = _leftPlayers[i]; // players index
            address player = Games[_gameId].players[pi];
            uint8 playersPower = getHandsPower(PlayersHand[player][_gameId]);
            uint128 payout;

            if (playersState[player][_gameId] == PlayerState.hasBlackJack) {
                payout = Games[_gameId].bets[pi] * 250 / 100;
            }
            else if (playersPower > _dealersPower) {
                payout = Games[_gameId].bets[pi] * 200 / 100;
            }
            else if (playersPower == _dealersPower) {
                payout = Games[_gameId].bets[pi];
            }

            if (payout > 0) {
                payoutAmount(
                    Games[_gameId].tokens[pi],
                    player,
                    payout
                );
            }
        }
    }

    function getNotBustedPlayers(bytes16 _gameId) public view returns (uint8[] memory) {

        address[] memory _players = Games[_gameId].players;
        uint8[] memory _leftPlayers;
        uint8 _index = 0;

        for (uint8 i = 0; i < _players.length; i++) {
            if (
                playersState[_players[i]][_gameId] == PlayerState.isSettled ||
                playersState[_players[i]][_gameId] == PlayerState.hasBlackJack
            ) _leftPlayers[_index] = i; _index++;
        }
    }

    function payoutAmount(uint8 _tokenIndex, address _player, uint128 _amount) private {
        treasury.tokenOutboundTransfer(
            _tokenIndex, _player, uint256(_amount)
        );
    }

    /* TO-DO:

    function revealIfBlackJack(
        bytes16 _gameId,
        bytes16 _localhashB;
    ) {
        verifyHiddenCard(

        );
    }

    function insuranceMove(
        bytes16 _gameId,
        address _player,
        bool isBuying
    )
        external
        onlyWorker
        onlyOnGoingGame(_gameId)
        onlyNonBusted(_gameId, _player)
    {
        require (
            PlayersInsurance[_gameId] == false;
            'BlackJack: insurance already purchased'
        );

        // dealers visible is ace -->
        // takePlayersBet() +0.5bet (buying insurance)
        PlayersInsurance[_gameId] = true;
        //
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
        // split based on cardsPower
        // create another hand
        // takePlayersBet()
        PlayersSplit
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
        // can take only one card
        // double the bet takePlayersBet()
    }

    */

    function checkDeck(
        bytes16 _gameId
    )
        public
        view
        returns (uint8[] memory _deck)
    {
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

    function checkPlayersHand(
        bytes16 _gameId,
        address _player
    )
        external
        view
        returns (uint8[] memory)
    {
        return PlayersHand[_player][_gameId];
    }

    function checkMyHand(
        bytes16 _gameId
    )
        external
        view
        returns (uint8[] memory)
    {
        return PlayersHand[msg.sender][_gameId];
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