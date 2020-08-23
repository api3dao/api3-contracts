//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./StakeUtils.sol";
import "./interfaces/ITransferUtils.sol";


contract TransferUtils is StakeUtils, ITransferUtils {
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

    function deposit(
        address sourceAddress,
        uint256 amount,
        address userAddress
        )
        external
    {
        api3Token.transferFrom(sourceAddress, address(this), amount);
        balances[userAddress] = balances[userAddress].add(amount);
    }

    function depositWithVesting(
        address sourceAddress,
        uint256 amount,
        address userAddress,
        uint256 vestingEpoch
        )
        external
    {
        api3Token.transferFrom(sourceAddress, address(this), amount);
        balances[userAddress] = balances[userAddress].add(amount);
        createVesting(userAddress, amount, vestingEpoch);
    }

    function withdraw(
        address destinationAddress,
        uint256 amount
        )
        external
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

    function addVestedRewards(
        address sourceAddress,
        uint256 amount
        )
        external
        override
    {
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 updatedVestedRewards = vestedRewardsAtEpoch[currentEpochNumber].add(amount);
        vestedRewardsAtEpoch[currentEpochNumber] = updatedVestedRewards;
        unpaidVestedRewardsAtEpoch[currentEpochNumber] = updatedVestedRewards;
        api3Token.transferFrom(sourceAddress, address(this), amount);
    }

    function addInstantRewards(
        address sourceAddress,
        uint256 amount
        )
        external
    {
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 updatedInstantRewards = instantRewardsAtEpoch[currentEpochNumber].add(amount);
        instantRewardsAtEpoch[currentEpochNumber] = updatedInstantRewards;
        unpaidInstantRewardsAtEpoch[currentEpochNumber] = updatedInstantRewards;
        api3Token.transferFrom(sourceAddress, address(this), amount);
    }
}
