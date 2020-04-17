pragma solidity ^0.5.14;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";

contract Token is ERC20Detailed, ERC20Mintable {
    constructor() public ERC20Detailed("MANA", "MANA", 18) {
        _mint(msg.sender, 10000000000000 ether);
    }
}
