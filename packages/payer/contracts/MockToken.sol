//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockToken is ERC20 {
    constructor()
        ERC20("Mock Token", "MCK")
        public
    {
        _mint(msg.sender, 1e6 ether);
    }
}
