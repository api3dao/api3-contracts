//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./InterfaceUtils.sol";
import "./EpochUtils.sol";


contract Api3Pool is InterfaceUtils, EpochUtils {
    enum ClaimStatus { Pending, Accepted, Denied }

    struct Vesting
    {
        address userAddress;
        uint256 amount;
        uint256 epoch;
    }

    struct Claim
    {
        address beneficiary;
        uint256 amount;
        ClaimStatus status;
    }

    struct IOU1
    {
        address userAddress;
        uint256 amount;
        bytes32 claimId;
    }

    // User balances, includes vested and unvested funds (not IOUs)
    mapping(address => uint256) private balances;
    // User unvested funds
    mapping(address => uint256) private unvestedFunds;

    // Total funds in the pool
    uint256 private totalPoolFunds;
    // Total number of pool shares
    uint256 private totalPoolShares;
    // User pool shares
    mapping(address => uint256) private poolShares;

    // Total staked pool shares at each epoch
    mapping(uint256 => uint256) private totalStakesPerEpoch;
    // User staked pool shares at each epoch
    mapping(address => mapping(uint256 => uint256)) private stakesPerEpoch;

    // Total rewards to be vested at each epoch
    mapping(uint256 => uint256) private vestedRewardsPerEpoch;
    mapping(uint256 => uint256) private unpaidVestedRewardsPerEpoch;
    // Total rewards received instantly at each epoch
    mapping(uint256 => uint256) private instantRewardsPerEpoch;
    mapping(uint256 => uint256) private unpaidInstantRewardsPerEpoch;

    // The epoch when the user made their last unpool request
    mapping(address => uint256) private unpoolRequestEpochs;

    // A record of vestings
    uint256 private noVestings;
    mapping(bytes32 => Vesting) private vestings;

    // A record of claims
    uint256 private noClaims;
    mapping(bytes32 => Claim) private claims;
    bytes32[] private activeClaims;

    // A record of IOUs
    uint256 private noIou1s;
    mapping(bytes32 => IOU1) private iou1s;
    

    // TODO: Make these updatable
    uint256 private unpoolRequestCooldown = 4; // in epochs
    uint256 private unpoolWaitingPeriod = 2; // in epochs
    uint256 private rewardVestingPeriod = 52; // in epochs

    constructor(
        address api3TokenAddress,
        address inflationScheduleAddress,
        uint256 epochPeriodInSeconds
        )
        InterfaceUtils(
            api3TokenAddress,
            inflationScheduleAddress
            )
        EpochUtils(epochPeriodInSeconds)
        public
        {}

    function deposit(
        address sourceAddress,
        uint256 amount,
        address userAddress,
        uint256 vestingEpoch
        )
        external
    {
        api3Token.transferFrom(sourceAddress, address(this), amount);
        balances[userAddress] = balances[userAddress].add(amount);
        if (vestingEpoch != 0)
        {
            createVesting(userAddress, amount, vestingEpoch);
        }
    }

    function vest(bytes32 vestingId)
        external
    {
        Vesting memory vesting = vestings[vestingId];
        require(getCurrentEpochNumber() < vesting.epoch, "It is not time to vest yet");
        unvestedFunds[vesting.userAddress] = unvestedFunds[vesting.userAddress].sub(vesting.amount);
        delete vestings[vestingId];
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
    }

    /// If a user has made a request to unpool at epoch t, they can't repeat
    /// their request at t+1 to postpone their unpooling to one epoch later.
    /// Should we allow this?
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
        /// Check if the user has staked in this epoch before unpooling and
        /// reduce their staked amount to their updated pooled amount if so
        pooled = pooled.sub(amount);
        uint256 nextEpochNumber = currentEpochNumber.add(1);
        uint256 staked = stakesPerEpoch[userAddress][nextEpochNumber];
        if (staked > pooled)
        {
            totalStakesPerEpoch[nextEpochNumber] = totalStakesPerEpoch[nextEpochNumber]
                .sub(staked.sub(pooled));
            stakesPerEpoch[userAddress][nextEpochNumber] = pooled;
        }

        uint256 poolShare = convertFundsToShares(amount);

        // Create the IOUs
        for (uint256 ind = 0; ind < activeClaims.length; ind++)
        {
            bytes32 claimId = activeClaims[ind];
            uint256 iouAmount = poolShare.mul(claims[claimId].amount).div(totalPoolShares);
            createIou1(userAddress, iouAmount, claimId);
            balances[userAddress] = balances[userAddress].sub(iouAmount);
        }

        poolShares[userAddress] = poolShares[userAddress].sub(poolShare);
        totalPoolShares = totalPoolShares.sub(poolShare);
        totalPoolFunds = totalPoolFunds.sub(amount);
    }

    function stake(address userAddress)
        external
    {
        uint256 nextEpochNumber = getCurrentEpochNumber().add(1);
        uint256 sharesStaked = stakesPerEpoch[userAddress][nextEpochNumber];
        uint256 sharesToStake = poolShares[userAddress];
        stakesPerEpoch[userAddress][nextEpochNumber] = sharesToStake;
        totalStakesPerEpoch[nextEpochNumber] = totalStakesPerEpoch[nextEpochNumber]
            .add(sharesToStake.sub(sharesStaked));
    }

    function collect(address userAddress)
        external
    {
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 previousEpochNumber = currentEpochNumber.sub(1);
        uint256 twoPreviousEpochNumber = currentEpochNumber.sub(2);
        uint256 totalStakesInPreviousEpoch = totalStakesPerEpoch[previousEpochNumber];
        uint256 stakeInPreviousEpoch = stakesPerEpoch[userAddress][previousEpochNumber];

        // Carry over vested rewards from two epochs ago
        if (unpaidVestedRewardsPerEpoch[twoPreviousEpochNumber] != 0)
        {
            vestedRewardsPerEpoch[previousEpochNumber] = vestedRewardsPerEpoch[previousEpochNumber]
                .add(unpaidVestedRewardsPerEpoch[twoPreviousEpochNumber]);
            unpaidVestedRewardsPerEpoch[twoPreviousEpochNumber] = 0;
        }

        uint256 vestedRewards = vestedRewardsPerEpoch[previousEpochNumber]
            .mul(totalStakesInPreviousEpoch)
            .div(stakeInPreviousEpoch);
        balances[userAddress] = balances[userAddress].add(vestedRewards);
        createVesting(userAddress, vestedRewards, currentEpochNumber.add(rewardVestingPeriod));

        // Carry over instant rewards from two epochs ago
        if (unpaidInstantRewardsPerEpoch[twoPreviousEpochNumber] != 0)
        {
            instantRewardsPerEpoch[previousEpochNumber] = instantRewardsPerEpoch[previousEpochNumber]
                .add(unpaidInstantRewardsPerEpoch[twoPreviousEpochNumber]);
            unpaidInstantRewardsPerEpoch[twoPreviousEpochNumber] = 0;
        }

        uint256 rewards = instantRewardsPerEpoch[previousEpochNumber]
            .mul(totalStakesInPreviousEpoch)
            .div(stakeInPreviousEpoch);
        balances[userAddress] = balances[userAddress].add(rewards);
    }

    function createVesting(
        address userAddress,
        uint256 amount,
        uint256 vestingEpoch
        )
        internal
    {
        unvestedFunds[userAddress] = unvestedFunds[userAddress].add(amount);
        bytes32 vestingId = keccak256(abi.encodePacked(
            noVestings,
            this
            ));
        noVestings = noVestings.add(1);
        vestings[vestingId] = Vesting({
            userAddress: userAddress,
            amount: amount,
            epoch: vestingEpoch
            });
    }

    function createIou1(
        address userAddress,
        uint256 amount,
        bytes32 claimId
        )
        internal
    {
        bytes32 iou1Id = keccak256(abi.encodePacked(
            noIou1s,
            this
            ));
        noIou1s = noIou1s.add(1);
        iou1s[iou1Id] = IOU1({
            userAddress: userAddress,
            amount: amount,
            claimId: claimId
            });
    }

    function createClaim(
        address beneficiary,
        uint256 amount
        )
        external
        onlyClaimsManager
    {
        require(totalPoolFunds >= amount, "Not enough funds in the collateral pool");
        bytes32 claimId = keccak256(abi.encodePacked(
            noClaims,
            this
            ));
        noClaims = noClaims.add(1);
        claims[claimId] = Claim({
            beneficiary: beneficiary,
            amount: amount,
            status: ClaimStatus.Pending
            });
        activeClaims.push(claimId);
    }

    function acceptClaim(bytes32 claimId)
        external
        onlyClaimsManager
    {
        require(deactivateClaim(claimId), "No such active claim exists");
        claims[claimId].status = ClaimStatus.Accepted;
        Claim memory claim = claims[claimId];
        api3Token.transferFrom(address(this), claim.beneficiary, claim.amount);
    }

    function denyClaim(bytes32 claimId)
        external
        onlyClaimsManager
    {
        require(deactivateClaim(claimId), "No such active claim exists");
        claims[claimId].status = ClaimStatus.Denied;
    }

    function deactivateClaim(bytes32 claimId)
        internal
        returns(bool success)
    {
        for (uint256 ind = 0; ind < activeClaims.length; ind++)
        {
            if (activeClaims[ind] == claimId)
            {
                delete activeClaims[ind];
                return true;
            }
        }
        return false;
    }

    function addVestedRewards(
        address sourceAddress,
        uint256 amount
        )
        external
    {
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 updatedVestedRewards = vestedRewardsPerEpoch[currentEpochNumber].add(amount);
        vestedRewardsPerEpoch[currentEpochNumber] = updatedVestedRewards;
        unpaidVestedRewardsPerEpoch[currentEpochNumber] = updatedVestedRewards;
        api3Token.transferFrom(sourceAddress, address(this), amount);
    }

    function addRewards(
        address sourceAddress,
        uint256 amount
        )
        external
    {
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 updatedInstantRewards = instantRewardsPerEpoch[currentEpochNumber].add(amount);
        instantRewardsPerEpoch[currentEpochNumber] = updatedInstantRewards;
        unpaidInstantRewardsPerEpoch[currentEpochNumber] = updatedInstantRewards;
        api3Token.transferFrom(sourceAddress, address(this), amount);
    }

    function getPooledFundsOfUser(address userAddress)
        internal
        view
        returns(uint256 pooled)
    {
        pooled = totalPoolShares.mul(totalPoolFunds).div(poolShares[userAddress]);
    }

    function convertFundsToShares(uint256 amountInFunds)
        internal
        view
        returns(uint256 amountInShares)
    {
        amountInShares = amountInFunds.mul(totalPoolShares).div(totalPoolFunds);
    }

    function convertSharesToFunds(uint256 amountInShares)
        internal
        view
        returns(uint256 amountInFunds)
    {
        amountInFunds = amountInShares.mul(totalPoolFunds).div(totalPoolShares);
    }
}
