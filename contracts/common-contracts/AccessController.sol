// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

contract AccessController {

    address public ceoAddress;
    address public workerAddress;

    bool public paused = false;

    // mapping (address => enumRoles) accessRoles; // multiple operators idea

    event CEOSet(address newCEO);
    event WorkerSet(address newWorker);

    event Paused();
    event Unpaused();

    constructor() {
        ceoAddress = msg.sender;
        workerAddress = msg.sender;
        emit CEOSet(ceoAddress);
        emit WorkerSet(workerAddress);
    }

    modifier onlyCEO() {
        require(
            msg.sender == ceoAddress
        );
        _;
    }

    modifier onlyWorker() {
        require(
            msg.sender == workerAddress
        );
        _;
    }

    modifier whenNotPaused() {
        require(
            !paused
        );
        _;
    }

    modifier whenPaused {
        require(
            paused
        );
        _;
    }

    function setCEO(address _newCEO) public onlyCEO {
        require(
            _newCEO != address(0x0)
        );
        ceoAddress = _newCEO;
        emit CEOSet(ceoAddress);
    }

    function setWorker(address _newWorker) external {
        require(
            _newWorker != address(0x0)
        );
        require(
            msg.sender == ceoAddress || msg.sender == workerAddress
        );
        workerAddress = _newWorker;
        emit WorkerSet(workerAddress);
    }

    function pause() external onlyWorker whenNotPaused {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyCEO whenPaused {
        paused = false;
        emit Unpaused();
    }
}