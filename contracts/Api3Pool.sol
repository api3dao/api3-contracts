//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./EpochUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";
import "./interfaces/IInflationManager.sol";


contract Api3Pool is Ownable, EpochUtils {
    enum ClaimStatus { Pending, Accepted, Denied }

    struct Vesting
    {
        address userAddress;
        uint256 amount;
        uint256 epoch;
    }

    struct Iou
    {
        address userAddress;
        uint256 amountInShares;
        bytes32 claimId;
        ClaimStatus redemptionCondition;
    }

    struct Claim
    {
        address beneficiary;
        uint256 amount;
        ClaimStatus status;
    }

    IApi3Token public immutable api3Token;
    IInflationManager public inflationManager;
    address public claimsManager;

    // User balances, includes vested and unvested funds (not IOUs)
    mapping(address => uint256) internal balances;
    // User unvested funds
    mapping(address => uint256) internal unvestedFunds;

    // ~~~~~~Pooling~~~~~~
    // Total funds in the pool
    uint256 internal totalPoolFunds = 1;
    // Total number of pool shares
    uint256 internal totalPoolShares = 1;
    // User pool shares
    mapping(address => uint256) internal poolShares;
    // Epochs when users made their last unpool requests
    mapping(address => uint256) internal unpoolRequestEpochs;
    uint256 internal unpoolRequestCooldown; // in epochs (set to 0 for now)
    uint256 internal unpoolWaitingPeriod; // in epochs (set to 0 for now)
    // ~~~~~~Pooling~~~~~~

    // ~~~~~~Staking~~~~~~
    // Total staked pool shares at each epoch
    mapping(uint256 => uint256) internal totalStakesAtEpoch;
    // User staked pool shares at each epoch
    mapping(address => mapping(uint256 => uint256)) internal stakesAtEpoch;
    // Total rewards to be vested at each epoch (e.g., inflationary)
    mapping(uint256 => uint256) internal vestedRewardsAtEpoch;
    mapping(uint256 => uint256) internal unpaidVestedRewardsAtEpoch;
    // Total rewards received instantly at each epoch (e.g., revenue distribution)
    mapping(uint256 => uint256) internal instantRewardsAtEpoch;
    mapping(uint256 => uint256) internal unpaidInstantRewardsAtEpoch;
    uint256 internal rewardVestingPeriod = 52; // in epochs
    // ~~~~~~Staking~~~~~~

    // ~~~~~~Claims~~~~~~
    uint256 internal noClaims;
    mapping(bytes32 => Claim) internal claims;
    bytes32[] internal activeClaims;
    uint256 internal totalActiveClaimsAmount;
    // ~~~~~~Claims~~~~~~

    // ~~~~~~IOUs~~~~~~
    uint256 internal noIous;
    mapping(bytes32 => Iou) internal ious;
    // ~~~~~~IOUs~~~~~~

    // ~~~~~~Vesting~~~~~~
    uint256 internal noVestings;
    mapping(bytes32 => Vesting) internal vestings;
    // ~~~~~~Vesting~~~~~~

    event InflationManagerUpdated(address inflationManagerAddress);
    event RewardVestingPeriodUpdated(uint256 rewardVestingPeriod);
    event UnpoolRequestCooldownUpdated(uint256 unpoolRequestCooldown);
    event UnpoolWaitingPeriodUpdated(uint256 unpoolWaitingPeriod);

    constructor(
        address api3TokenAddress,
        uint256 epochPeriodInSeconds,
        uint256 firstEpochStartTimestamp
        )
        EpochUtils(
            epochPeriodInSeconds,
            firstEpochStartTimestamp
            )
        public
        {
            api3Token = IApi3Token(api3TokenAddress);
        }


    function updateInflationManager(address inflationManagerAddress)
        external
        onlyOwner
    {
        inflationManager = IInflationManager(inflationManagerAddress);
        emit InflationManagerUpdated(inflationManagerAddress);
    }

    function updateRewardVestingPeriod(uint256 _rewardVestingPeriod)
        external
        onlyOwner
    {
        rewardVestingPeriod = _rewardVestingPeriod;
        emit RewardVestingPeriodUpdated(rewardVestingPeriod);
    }

    function updateUnpoolRequestCooldown(uint256 _unpoolRequestCooldown)
        external
        onlyOwner
    {
        unpoolRequestCooldown = _unpoolRequestCooldown;
        emit UnpoolRequestCooldownUpdated(unpoolRequestCooldown);
    }

    function updateUnpoolWaitingPeriod(uint256 _unpoolWaitingPeriod)
        external
        onlyOwner
    {
        unpoolWaitingPeriod = _unpoolWaitingPeriod;
        emit UnpoolWaitingPeriodUpdated(unpoolWaitingPeriod);
    }

    function getPooledFundsOfUser(address userAddress)
        internal
        view
        returns(uint256 pooled)
    {
        pooled = totalPoolShares.mul(totalPoolFunds).div(poolShares[userAddress]);
    }

    function convertFundsToShares(uint256 amount)
        internal
        view
        returns(uint256 amountInShares)
    {
        amountInShares = amount.mul(totalPoolShares).div(totalPoolFunds);
    }

    function convertSharesToFunds(uint256 amountInShares)
        internal
        view
        returns(uint256 amount)
    {
        amount = amountInShares.mul(totalPoolFunds).div(totalPoolShares);
    }
}
