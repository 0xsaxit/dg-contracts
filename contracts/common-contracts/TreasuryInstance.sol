pragma solidity ^0.5.14;

interface TreasuryInstance {

    function tokenAddress(
        string calldata _tokenName
    ) external view returns (address);

    function tokenInboundTransfer(
        string calldata _tokenName,
        address _from,
        uint256 _amount
    )  external returns (bool);

    function tokenOutboundTransfer(
        string calldata _tokenName,
        address _to,
        uint256 _amount
    ) external returns (bool);

    function checkAllocatedTokens(
        string calldata _tokenName
    ) external view returns (uint256);

    function checkApproval(
        address _userAddress,
        string calldata _tokenName
    ) external view returns (uint256 approved);

    function getMaximumBet(
        string calldata _tokenName
    ) external view returns (uint256);

    function consumeHash(
        bytes32 _localhash
    ) external returns (bool);
}
