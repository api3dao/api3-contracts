//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Payer contract
/// @notice This contract is used to make multiple ERC20 payments by the DAO
/// with a single proposal. The owner of this contract sets which addresses
/// will be paid and how much, and the DAO simply transfer()s tokens to this
/// contract. Then, anyone can trigger this contract to send the tokens to
/// their destinations. This is to avoid having to make a separate approve()
/// proposal by the DAO.
contract Payer is Ownable {
    using SafeMath for uint256;

    IERC20 token;
    address[] private destinations;
    uint256[] private amounts;
    bool public paymentsSet = false;

    /// @param owner Contract owner
    /// @param tokenAddress Address of the token that the payments will be made
    /// in
    constructor(
        address owner,
        address tokenAddress
        )
        public
    {
        transferOwnership(owner);
        token = IERC20(tokenAddress);
    }

    /// @notice Called by the contract owner to set the parameters of the next
    /// payment
    /// @dev Since the payment parameters are designed to be immutable, if
    /// incorrect parameters are used, the contract will go out of order and
    /// will have to be redeployed. If tokens are sent to the contract despite
    /// incorrect parameters have been used, the tokens may get stuck.
    /// This method is put behind onlyOwner to prevent griefers from calling it
    /// with incorrect parameters.
    /// @param _destinations Addresses that the payments will be made to
    /// @param _amounts Amounts that will be paid
    function setPayments(
        address[] calldata _destinations,
        uint256[] calldata _amounts
        )
        external
        onlyOwner
    {
        require(!paymentsSet, "Payment already set");
        require(_amounts.length == _destinations.length, "Parameters not of equal length");
        require(_amounts.length != 0, "Parameters empty");
        require(_amounts.length <= 30, "Parameters longer than 30");
        paymentsSet = true;
        amounts = _amounts;
        destinations = _destinations;
    }

    /// @notice Called to have the contract make payments
    /// @dev The call will revert if the contract does not have adequate funds
    function makePayments()
        external
    {
        require(paymentsSet, "Payments not set");
        paymentsSet = false;
        for (uint256 ind = 0; ind < amounts.length; ind++)
        {
            require(token.transfer(destinations[ind], amounts[ind]), "Transfer failed");
        }
        delete destinations;
        delete amounts;
    }

    /// @notice Returns the required deposit to make the payments
    /// @return requiredDeposit Required deposit to make the payments
    function getRequiredDeposit()
        public
        view
        returns (uint256 requiredDeposit)
    {
        for (uint256 ind = 0; ind < amounts.length; ind++)
        {
            requiredDeposit = requiredDeposit.add(amounts[ind]);
        }
        uint256 currentBalance = token.balanceOf(address(this));
        if (currentBalance >= requiredDeposit)
        {
            requiredDeposit = 0;   
        }
        else
        {
            requiredDeposit = requiredDeposit.sub(currentBalance);
        }
    }

    /// @notice Called to check if makePayments() is ready to be called
    /// @return state If the contract is ready to pay
    function isReadyToPay()
        external
        view
        returns (bool state)
    {
        state = paymentsSet && getRequiredDeposit() == 0;
    }

    /// @notice Returns the address of the token that the payments are made in
    /// @return tokenAddress Token address
    function getTokenAddress()
        external
        view
        returns (address tokenAddress)
    {
        tokenAddress = address(token);
    }

    function getDestinationsAndAmounts()
        external
        view
        returns (
            address[] memory _destinations,
            uint256[] memory _amounts
            )
    {
        _destinations = destinations;
        _amounts = amounts;
    }
}
