//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";


/// @title API3 token contract
/// @notice The API3 token contract is owned by the API3 DAO, which can grant
/// minting privileges to addresses
contract Api3Token is ERC20, Ownable, IApi3Token {
    /// @dev If an address is authorized to mint tokens
    mapping(address => bool) private isMinter;

    /// @param contractOwner Address that will receive the ownership of the
    /// token contract
    /// @param mintDestination Adress that will receive the minted tokens
    constructor(
        address contractOwner,
        address mintDestination
        )
        ERC20("API3", "API3")
        public
        {
            // Initial supply is 100 million (1e8)
            _mint(mintDestination, 1e8 * 1e18);
            transferOwnership(contractOwner);
        }

    /// @notice Updates if an address is authorized to mint tokens
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
    /// @param account Address that will receive the minted tokens
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
    /// returned
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
