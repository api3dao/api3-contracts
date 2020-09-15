//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";


/// @title API3 token contract
/// @notice The API3 token is owned by the API3 DAO, which can grant minting
/// privileges to addresses. For example, the DAO authorizes InflationManager
/// as a minter, which allows it to mint tokens each epoch according to its
/// immutable schedule.
contract Api3Token is ERC20, Ownable, IApi3Token {
    /// @dev Mapping of addresses to if they are authorized to mint tokens
    mapping(address => bool) private isMinter;

    constructor()
        ERC20("API3", "API3")
        public
        {
            // Initial supply is 100 million (1e8)
            _mint(msg.sender, 1e8 * 1e18);
        }

    /// @notice Updates if an address is authorized to mint tokens
    /// @dev Can only be called by the owner (i.e., the API3 DAO)
    /// @param minterAddress Address whose minter authorization status will be
    /// updated
    /// @param minterStatus Updated minter authorization status
    function updateMinterStatus(
        address minterAddress,
        bool minterStatus
        )
        external
        override
        onlyOwner
    {
        isMinter[minterAddress] = minterStatus;
        emit MinterStatusUpdated(minterAddress, minterStatus);
    }

    /// @notice Mints tokens
    /// @param account Account that will receive the minted tokens
    /// @param amount Amount that will be minted
    function mint(
        address account,
        uint256 amount
        )
        external
        override
    {
        require(isMinter[msg.sender], "Only minters are allowed to mint");
        _mint(account, amount);
    }

    /// @notice Returns if an address is authorized to mint tokens
    /// @param minterAddress Address whose minter authorization status will be
    /// gotten
    /// @return minterStatus Minter authorization status
    function getMinterStatus(address minterAddress)
        external
        view
        override
        returns(bool minterStatus)
    {
        minterStatus = isMinter[minterAddress];
    }
}
