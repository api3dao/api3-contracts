//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StakeUtils.sol";
import "./interfaces/ITransferUtils.sol";


/// @title Contract where the transfer logic of the API3 pool is implemented
contract TransferUtils is StakeUtils, ITransferUtils {
    /// @param api3TokenAddress Address of the API3 token contract
    /// @param epochPeriodInSeconds Length of epochs used to quantize time
    /// @param firstEpochStartTimestamp Starting timestamp of epoch #1
    constructor(
        address api3TokenAddress,
        uint256 epochPeriodInSeconds,
        uint256 firstEpochStartTimestamp
        )
        StakeUtils(
            api3TokenAddress,
            epochPeriodInSeconds,
            firstEpochStartTimestamp
            )
        public
        {}

    /// @notice Deposits funds for a user, which can then be pooled and staked
    /// @param sourceAddress Source address of the funds
    /// @param amount Number of tokens to be deposited
    /// @param userAddress User that will receive the tokens
    function deposit(
        address sourceAddress,
        uint256 amount,
        address userAddress
        )
        external
        override
    {
        api3Token.transferFrom(sourceAddress, address(this), amount);
        balances[userAddress] = balances[userAddress].add(amount);
    }

    /// @notice Deposits funds for a user, which can then be pooled and staked.
    /// Note that the funds will not be instantly withdrawable and be vested
    /// after a period of time.
    /// @param sourceAddress Source address of the funds
    /// @param amount Number of tokens to be deposited
    /// @param userAddress User that will receive the tokens
    /// @param vestingEpoch Index of the epoch when the funds will be vested
    function depositWithVesting(
        address sourceAddress,
        uint256 amount,
        address userAddress,
        uint256 vestingEpoch
        )
        external
        override
    {
        api3Token.transferFrom(sourceAddress, address(this), amount);
        balances[userAddress] = balances[userAddress].add(amount);
        createVesting(userAddress, amount, vestingEpoch);
    }

    /// @notice Withdraws funds that are not pooled or locked in a vesting
    /// @param destinationAddress Destination address of the funds
    /// @param amount Number of tokens to be withdrawn
    function withdraw(
        address destinationAddress,
        uint256 amount
        )
        external
        override
    {
        address userAddress = msg.sender;
        uint256 unvested = unvestedFunds[userAddress];
        uint256 pooled = getPooledFundsOfUser(userAddress);
        uint256 nonWithdrawable = unvested > pooled ? unvested: pooled;
        uint256 balance = balances[userAddress];
        uint256 withdrawable = balance.sub(nonWithdrawable);
        require(withdrawable >= amount, "Not enough withdrawable funds");
        balances[userAddress] = balance.sub(amount);
        api3Token.transferFrom(address(this), destinationAddress, amount);
    }

    /// @notice Deposits funds to the vested rewards pool for this epoch
    /// @param sourceAddress Source address of the funds
    /// @param amount Number of tokens to be deposited
    function addVestedRewards(
        address sourceAddress,
        uint256 amount
        )
        external
        override
    {
        uint256 currentEpochIndex = getCurrentEpochIndex();
        uint256 updatedVestedRewards = vestedRewardsAtEpoch[currentEpochIndex].add(amount);
        vestedRewardsAtEpoch[currentEpochIndex] = updatedVestedRewards;
        unpaidVestedRewardsAtEpoch[currentEpochIndex] = updatedVestedRewards;
        api3Token.transferFrom(sourceAddress, address(this), amount);
    }

    /// @notice Deposits funds to the instant rewards pool for this epoch
    /// @param sourceAddress Source address of the funds
    /// @param amount Number of tokens to be deposited
    function addInstantRewards(
        address sourceAddress,
        uint256 amount
        )
        external
        override
    {
        uint256 currentEpochIndex = getCurrentEpochIndex();
        uint256 updatedInstantRewards = instantRewardsAtEpoch[currentEpochIndex].add(amount);
        instantRewardsAtEpoch[currentEpochIndex] = updatedInstantRewards;
        unpaidInstantRewardsAtEpoch[currentEpochIndex] = updatedInstantRewards;
        api3Token.transferFrom(sourceAddress, address(this), amount);
    }
}
