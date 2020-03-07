
// File: contracts/master-example/SafeMath.sol

pragma solidity ^0.5.14;

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

// File: contracts/master-example/AccessControl.sol

pragma solidity ^0.5.14;

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

// File: contracts/master-example/ERC20Token.sol

pragma solidity ^0.5.14;

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

// File: contracts/master-example/GameInterface.sol

pragma solidity ^0.5.14;

interface GameInstance {

    function createBet(
        uint _betID,
        address _player,
        uint _number,
        uint _value
    ) external;

    function launch(
        bytes32 _localhash,
        address _userAddress,
        uint256 _machineID,
        uint256 _landID
    ) external returns(uint256 winAmount);

    function getPayoutForType(
        uint256 _betID
    ) external returns(uint256);
}

// File: contracts/master-example/HashChain.sol

pragma solidity ^0.5.14;

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

// File: contracts/master-example/MasterParent.sol

pragma solidity ^0.5.14;






contract MasterParent is HashChain, AccessControl {

    using SafeMath for uint256;
    event NewBalance(uint256 _gameID, uint256 _balance);

    uint256 public globalMaximumBet = 1000 ether; // contract's bet price
    uint256 public winAmount = 0; // last winning amount
    uint256 public number = 0; // last reels numbers
    uint256 public maximumBetsAmount = 36; // contract's maximum amount of bets
    uint256[] public funds; // funds in contract per game

    ERC20Token public tokenInstance = ERC20Token(
        //0xDd1B834a483fD754c8021FF0938f69C1d10dA81F // Matic/MANA
        //0x7801E36D90A2d41a35fA3fA26533E6864de9F467 // Ropsten/MOL
        0x2a8Fd99c19271F4F04B1B7b9c4f7cF264b626eDB   // Ropsten/MANA
    );

    GameInstance[] public games;
    constructor() public {}

    function addGame(GameInstance _newGame) external onlyCEO {
        games.push(_newGame);
        funds.push(0);
    }

    function updateGame(uint256 _gameID, GameInstance _newGame) external onlyCEO {
        games[_gameID] = _newGame;
    }

    function removeGame(uint256 _gameID) external onlyCEO {
        delete games[_gameID];
        delete funds[_gameID];
    }

    function checkApproval(address _userAddress) public view whenNotPaused returns(uint approved) {
        approved = tokenInstance.allowance(_userAddress, address(this));
    }

    function bet(uint _gameID, uint _betID, address _userAddress, uint _number, uint _value) internal whenNotPaused {
        require(_value <= globalMaximumBet, "bet amount is more than maximum");
        games[_gameID].createBet(_betID, _userAddress, _number, _value);
    }

    function setTail(bytes32 _tail) external onlyCEO {
        _setTail(_tail);
    }

    function testing(bytes32 _localhash) external onlyCEO returns (bool) {
        _consume(_localhash);
        return true;
    }

    function play(
        uint256 _gameID,
        address _userAddress,
        uint256 _landID,
        uint256 _machineID,
        uint256[] calldata _betIDs,
        uint256[] calldata _betValues,
        uint256[] calldata _betAmount,
        bytes32 _localhash
    ) external whenNotPaused onlyCEO {

        _consume(_localhash); //hash-chain check

        require(_betIDs.length == _betValues.length, "inconsistent amount of bets/values");
        require(_betIDs.length == _betAmount.length, "inconsistent amount of bets/amount");
        require(_betIDs.length <= maximumBetsAmount, "maximum amount of bets per game is 36");

        //calculating totalBet based on all bets
        uint256 totalTokenBet = 0;
        for (uint i = 0; i < _betIDs.length; i++) {
            totalTokenBet = totalTokenBet.add(_betAmount[i]);
        }
        require(tokenInstance.allowance(_userAddress, address(this)) >= totalTokenBet, "must approve/allow this contract as spender");

        //check necessary funds for payout based on betID
        uint256 necessaryBalance = 0;
        for (uint i = 0; i < _betIDs.length; i++) {
            uint256 fundsPerBet = games[_gameID].getPayoutForType(_betIDs[i]);
            if (_betIDs[i] > 0) {
                necessaryBalance = necessaryBalance.add(fundsPerBet.mul(_betAmount[i]));
            } else {
                necessaryBalance = necessaryBalance.add(fundsPerBet);
            }
        }
        //funds[_gameID] = funds[_gameID].add(totalTokenBet);   //consider adding the bet to payout amount before calculating
        require(necessaryBalance <= funds[_gameID], 'must have enough funds for payouts');

        //get user tokens if approved
        funds[_gameID] = funds[_gameID].add(totalTokenBet);
        tokenInstance.transferFrom(_userAddress, address(this), totalTokenBet);

        //set bets for the game
        for (uint i = 0; i < _betIDs.length; i++) {
            if (_betIDs[i] > 0) {
                bet(_gameID, _betIDs[i], _userAddress, _betValues[i], _betAmount[i]);
            }
        }

        //play game
        (winAmount) = games[_gameID].launch(
            _localhash,
            _userAddress,
            _machineID,
            _landID
        );

        //issue reward
        if (winAmount > 0) {
            funds[_gameID] = funds[_gameID].sub(winAmount); //keep balance of tokens per game
            tokenInstance.transfer(_userAddress, winAmount); // transfer winning amount to player
        }

        // notify server of reels numbers and winning amount if any
        //emit GameResult(_userAddress, tokenSymbol, _landID, number, _machineID, winAmount);
    }

    function () payable external {} //can sends tokens directly

    function manaulAllocation(uint256 _gameID, uint256 _tokenAmount) external onlyCEO {
        funds[_gameID] = funds[_gameID].add(_tokenAmount);
    }

    function addFunds(uint256 _gameID, uint256 _tokenAmount) external onlyCEO {
        require(_tokenAmount > 0, "No funds sent");
        require(tokenInstance.allowance(msg.sender, address(this)) >= _tokenAmount, "must allow to transfer");
        require(tokenInstance.balanceOf(msg.sender) >= _tokenAmount, "user must have enough tokens");

        tokenInstance.transferFrom(msg.sender, address(this), _tokenAmount);
        funds[_gameID] = funds[_gameID].add(_tokenAmount);

        emit NewBalance(_gameID, funds[_gameID]); // notify server of new contract balance
    }

    function checkFunds(uint256 _gameID) external view returns (uint256 fundsInContract) {
        fundsInContract = funds[_gameID];
    }

    function setGlobalMaximumBet(uint256 _maximumBet) external onlyCEO {
        globalMaximumBet = _maximumBet;
    }

    function withdrawCollateral(uint256 _gameID, uint256 _amount) external onlyCEO {
        require(_amount <= funds[_gameID], "Amount more than game allocated balance");

        if (_amount == 0) {
            _amount = funds[_gameID];
        }

        funds[_gameID] = funds[_gameID].sub(_amount);
        tokenInstance.transfer(ceoAddress, _amount); // transfer contract funds to contract owner

        emit NewBalance(_gameID, funds[_gameID]); // notify server of new contract balance
    }

}
