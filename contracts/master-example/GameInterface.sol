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
        uint256 _machineID,
        uint256 _landID,
        string calldata _tokenName
    ) external returns(uint256[] memory winAmounts, uint256 number);

    function getPayoutForType(
        uint256 _betID
    ) external returns(uint256);
}
