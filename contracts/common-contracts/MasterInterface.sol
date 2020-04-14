pragma solidity ^0.5.14;

import "./ERC20Token.sol";

interface MasterInstance {

    function tokenAddress(
        string calldata _tokenName
    ) external view returns (address);

    function tokenInstance(
        string calldata _tokenName
    ) external view returns (ERC20Token);

    function tokenOutboundTransfer(
        string calldata _tokenName,
        address _to,
        uint256 _amount
    ) external returns (bool);

    function tokenInboundTransfer(
        string calldata _tokenName,
        address _from,
        uint256 _amount
    )  external returns (bool);
}
