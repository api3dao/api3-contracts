//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";


contract Api3Token is ERC20, Ownable, IApi3Token {
    mapping(address => bool) private isMinter;

    constructor()
        ERC20("api3", "api3")
        public
        {
            _mint(msg.sender, 100000000);
        }

    function updateMinterStatus(
        address minterAddress,
        bool minterStatus
        )
        external
        override
        onlyOwner
    {
        isMinter[minterAddress] = minterStatus;
    }

    function mint(
        address account,
        uint256 amount
        )
        external
        override
        onlyMinter
    {
        _mint(account, amount);
    }

    modifier onlyMinter()
    {
        require(isMinter[msg.sender], "Only minters are allowed to do this");
        _;
    }
}
