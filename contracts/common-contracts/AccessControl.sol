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
        require(msg.sender == ceoAddress, "CEO access denied");
        _;
    }

    // access modifier for Worker-only functionality
    modifier onlyWorker() {
        require(msg.sender == workerAddress, "Worker access denied");
        _;
    }

    // assigns new CEO address - only available to the current CEO
    function setCEO(address _newCEO) public onlyCEO {
        require(_newCEO != address(0), "must be non-zero address");
        ceoAddress = _newCEO;
        emit CEOSet(ceoAddress);
    }

    // assigns new Worker address - only available to the current CEO
    function setWorker(address _newWorker) public onlyWorker {
        require(_newWorker != address(0), "must be non-zero address");
        workerAddress = _newWorker;
        emit WorkerSet(workerAddress);
    }

    // modifier to allow actions only when the contract IS NOT paused
    modifier whenNotPaused() {
        require(!paused, "currently paused");
        _;
    }

    // modifier to allow actions only when the contract IS paused
    modifier whenPaused {
        require(paused, "currenlty not paused");
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
