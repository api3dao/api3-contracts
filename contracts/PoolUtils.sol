//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./IouUtils.sol";


contract PoolUtils is IouUtils {
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

    function pool(uint256 amount)
        external
    {
        address userAddress = msg.sender;
        uint256 poolable = balances[userAddress].sub(getPooledFundsOfUser(userAddress));
        require(poolable >= amount, "Not enough poolable funds");
        uint256 poolShare = convertFundsToShares(amount);
        poolShares[userAddress] = poolShares[userAddress].add(poolShare);
        totalPoolShares = totalPoolShares.add(poolShare);
        totalPoolFunds = totalPoolFunds.add(amount);

        // Create an IOU for each active claim
        for (uint256 ind = 0; ind < activeClaims.length; ind++)
        {
            bytes32 claimId = activeClaims[ind];
            uint256 totalPoolFundsAfterPayout = totalPoolFunds.sub(claims[claimId].amount);
            uint256 poolSharesRequiredToNotSufferFromPayout = amount
                .mul(totalPoolShares).div(totalPoolFundsAfterPayout);
            uint256 iouAmountInShares = poolSharesRequiredToNotSufferFromPayout.sub(poolShare);
            createIou(userAddress, iouAmountInShares, claimId, ClaimStatus.Accepted);
        }
    }

    /// If a user has made a request to unpool at epoch t, they can't repeat
    /// their request at t+1 to postpone their unpooling to one epoch later.
    function requestToUnpool()
        external
    {
        address userAddress = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        require(
            unpoolRequestEpochs[userAddress].add(unpoolRequestCooldown) <= currentEpochNumber,
            "Have to wait at least unpoolRequestCooldown to request a new unpool"
            );
        unpoolRequestEpochs[userAddress] = currentEpochNumber;
    }

    /// This doesn't take unpoolWaitingPeriod changing after the unpool request
    /// into account
    function unpool(uint256 amount)
        external
    {
        address userAddress = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        require(
            unpoolRequestEpochs[userAddress].add(unpoolWaitingPeriod) == currentEpochNumber,
            "Have to unpool unpoolWaitingPeriod epochs after the request"
            );
        uint256 pooled = getPooledFundsOfUser(userAddress);
        require(
            pooled >= amount,
            "Not enough unpoolable funds"
        );

        uint256 poolShare = convertFundsToShares(amount);
        poolShares[userAddress] = poolShares[userAddress].sub(poolShare);
        totalPoolShares = totalPoolShares.sub(poolShare);
        totalPoolFunds = totalPoolFunds.sub(amount);

        // Create the IOUs
        uint256 totalIouAmount = 0;
        for (uint256 ind = 0; ind < activeClaims.length; ind++)
        {
            bytes32 claimId = activeClaims[ind];
            uint256 iouAmount = poolShare.mul(claims[claimId].amount).div(totalPoolShares);
            uint256 iouAmountInShares = iouAmount.mul(totalPoolShares).div(totalPoolFunds);
            createIou(userAddress, iouAmountInShares, claimId, ClaimStatus.Denied);
            totalIouAmount = totalIouAmount.add(iouAmount);
        }
        // Deduct the IOUs from the user's balance
        balances[userAddress] = balances[userAddress].sub(totalIouAmount);

        // Leave the total IOU amount in the pool as ghost shares
        uint256 totalIouAmountInShares = convertFundsToShares(totalIouAmount);
        totalPoolShares = totalPoolShares.add(totalIouAmountInShares);
        totalPoolFunds = totalPoolFunds.add(totalIouAmount);
        
        /// Check if the user has staked in this epoch before unpooling and
        /// reduce their staked amount to their updated pooled amount if so
        uint256 updatedPoolShare = poolShares[userAddress];
        uint256 nextEpochNumber = currentEpochNumber.add(1);
        uint256 staked = stakesAtEpoch[userAddress][nextEpochNumber];
        if (staked > updatedPoolShare)
        {
            totalStakesAtEpoch[nextEpochNumber] = totalStakesAtEpoch[nextEpochNumber]
                .sub(staked.sub(updatedPoolShare));
            stakesAtEpoch[userAddress][nextEpochNumber] = updatedPoolShare;
        }
    }
}
