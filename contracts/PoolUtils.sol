//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./IouUtils.sol";
import "./interfaces/IPoolUtils.sol";


/// @title Contract where the pooling logic of the API3 pool is implemented
contract PoolUtils is IouUtils, IPoolUtils {
    /// @param api3TokenAddress Address of the API3 token contract
    /// @param epochPeriodInSeconds Length of epochs used to quantize time
    /// @param firstEpochStartTimestamp Starting timestamp of epoch #1
    constructor(
        address api3TokenAddress,
        uint256 epochPeriodInSeconds,
        uint256 firstEpochStartTimestamp
        )
        IouUtils(
            api3TokenAddress,
            epochPeriodInSeconds,
            firstEpochStartTimestamp
            )
        public
        {}

    /// @notice Has the user pool amount number of tokens and receive pool
    /// shares
    /// @param amount Number of tokens to be pooled
    function pool(uint256 amount)
        external
        override
    {
        // First have the user pool as if there are no active claims
        address userAddress = msg.sender;
        uint256 poolable = balances[userAddress].sub(getPooledFundsOfUser(userAddress));
        require(poolable >= amount, "Not enough poolable funds");
        uint256 poolShare = convertFundsToShares(amount);
        poolShares[userAddress] = poolShares[userAddress].add(poolShare);
        totalPoolShares = totalPoolShares.add(poolShare);
        totalPoolFunds = totalPoolFunds.add(amount);

        // Then create an IOU for each active claim
        for (uint256 ind = 0; ind < activeClaims.length; ind++)
        {
            // Simulate a payout for the claim
            bytes32 claimId = activeClaims[ind];
            uint256 totalPoolFundsAfterPayout = totalPoolFunds.sub(claims[claimId].amount);
            // After the payout, if the user redeems their IOU and unpool, they
            // should get exactly amount number of tokens. Calculate how many
            // shares that many tokens would correspond to after the claim
            // payout.
            uint256 poolSharesRequiredToNotSufferFromPayout = amount
                .mul(totalPoolShares).div(totalPoolFundsAfterPayout);
            // User already received poolShare number of shares. They will
            // receive the rest as an IOU.
            uint256 iouAmountInShares = poolSharesRequiredToNotSufferFromPayout.sub(poolShare);
            createIou(userAddress, iouAmountInShares, claimId, ClaimStatus.Accepted);
        }
    }

    /// @notice Creates a request to unpool, which must be done
    /// unpoolWaitingPeriod epochs before when the user wants to unpool.
    /// The user can request to unpool once every unpoolRequestCooldown epochs.
    /// @dev If a user has made a request to unpool at epoch t, they can't
    /// repeat their request at t+1 to postpone their unpooling to one epoch
    /// later, so they need to be specific.
    function requestToUnpool()
        external
        override
    {
        address userAddress = msg.sender;
        uint256 currentEpochIndex = getCurrentEpochIndex();
        require(
            unpoolRequestEpochs[userAddress].add(unpoolRequestCooldown) <= currentEpochIndex,
            "Have to wait at least unpoolRequestCooldown to request a new unpool"
            );
        unpoolRequestEpochs[userAddress] = currentEpochIndex;
    }

    /// @notice Has the user unpool amount number of tokens worth of shares
    /// @dev This doesn't take unpoolWaitingPeriod changing after the unpool
    /// request into account.
    /// The user can unpool multiple times with a single unpooling request.
    /// @param amount Number of tokens that will be unpooled
    function unpool(uint256 amount)
        external
        override
    {
        address userAddress = msg.sender;
        uint256 currentEpochIndex = getCurrentEpochIndex();
        require(
            currentEpochIndex == unpoolRequestEpochs[userAddress].add(unpoolWaitingPeriod),
            "Have to unpool unpoolWaitingPeriod epochs after the request"
            );
        require(
            amount <= getPooledFundsOfUser(userAddress),
            "Not enough unpoolable funds"
        );

        // Unlike pool(), we create the IOUs before altering the pool state.
        // This is because these IOUs will be redeemable if the claim is not
        // paid out.
        uint256 poolShare = convertFundsToShares(amount);
        // We do not want to deduct the entire unpooled amount from the pool
        // because we still need them to potentially pay out the current active
        // claims. To this end, the amount that is secured by IOUs will be left
        // in the pool as "ghost shares" (i.e., pool shares with no owner). We
        // calculate totalIouAmount for this purpose.
        uint256 totalIouAmount = 0;
        for (uint256 ind = 0; ind < activeClaims.length; ind++)
        {
            // Simulate a payout for the claim had the user not unpooled
            bytes32 claimId = activeClaims[ind];
            uint256 iouAmount = poolShare.mul(claims[claimId].amount).div(totalPoolShares);
            uint256 iouAmountInShares = convertFundsToShares(iouAmount);
            createIou(userAddress, iouAmountInShares, claimId, ClaimStatus.Denied);
            totalIouAmount = totalIouAmount.add(iouAmount);
        }

        // Update the pool status
        poolShares[userAddress] = poolShares[userAddress].sub(poolShare);
        totalPoolShares = totalPoolShares.sub(poolShare);
        totalPoolFunds = totalPoolFunds.sub(amount);
        
        // Deduct the IOUs from the user's balance
        balances[userAddress] = balances[userAddress].sub(totalIouAmount);

        // Leave the total IOU amount in the pool as ghost shares
        uint256 totalIouAmountInShares = convertFundsToShares(totalIouAmount);
        totalPoolShares = totalPoolShares.add(totalIouAmountInShares);
        totalPoolFunds = totalPoolFunds.add(totalIouAmount);
        
        // Check if the user has staked in this epoch before unpooling and
        // reduce their staked amount to their updated pooled amount if so
        uint256 updatedPoolShare = poolShares[userAddress];
        uint256 nextEpochIndex = currentEpochIndex.add(1);
        uint256 staked = stakesAtEpoch[userAddress][nextEpochIndex];
        if (staked > updatedPoolShare)
        {
            totalStakesAtEpoch[nextEpochIndex] = totalStakesAtEpoch[nextEpochIndex]
                .sub(staked.sub(updatedPoolShare));
            stakesAtEpoch[userAddress][nextEpochIndex] = updatedPoolShare;
        }
    }
}
