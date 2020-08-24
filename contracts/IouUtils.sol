//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./ClaimUtils.sol";
import "./interfaces/IIouUtils.sol";


/// @title Contract where the IOU logic of the API3 pool is implemented
contract IouUtils is ClaimUtils, IIouUtils {
    /// @param api3TokenAddress Address of the API3 token contract
    /// @param epochPeriodInSeconds Length of epochs used to quantize time
    /// @param firstEpochStartTimestamp Starting timestamp of epoch #1
    constructor(
        address api3TokenAddress,
        uint256 epochPeriodInSeconds,
        uint256 firstEpochStartTimestamp
        )
        ClaimUtils(
            api3TokenAddress,
            epochPeriodInSeconds,
            firstEpochStartTimestamp
            )
        public
        {}

    /// @notice Creates an IOU record
    /// @param userAddress User address that will receive the payout
    /// @param amountInShares Payout amount in shares
    /// @param claimId Claim ID
    /// @param redemptionCondition Claim status needed for the IOU to be
    /// redeemable
    function createIou(
        address userAddress,
        uint256 amountInShares,
        bytes32 claimId,
        ClaimStatus redemptionCondition
        )
        internal
    {
        bytes32 iouId = keccak256(abi.encodePacked(
            noIous,
            this
            ));
        noIous = noIous.add(1);
        ious[iouId] = Iou({
            userAddress: userAddress,
            amountInShares: amountInShares,
            claimId: claimId,
            redemptionCondition: redemptionCondition
            });
        emit IouCreated(
            iouId,
            userAddress,
            amountInShares,
            claimId,
            redemptionCondition
        );
    }

    /// @notice Redeems an IOU
    /// @param iouId IOU ID
    function redeem(bytes32 iouId)
        external
        override
    {
        Iou memory iou = ious[iouId];
        uint256 amountInTokens = convertSharesToFunds(iou.amountInShares);
        require(
            claims[iou.claimId].status == iou.redemptionCondition,
            "IOU redemption condition is not met"
            );
        if (iou.redemptionCondition == ClaimStatus.Denied)
        {
            // While unpooling with an active claim, the user is given an IOU
            // for the amount they would pay out to the claim, and this amount
            // is left in the pool as "ghost shares" to pay out the active
            // claim if necessary. If the claim is denied and the IOU is being
            // redeemed, these ghost shares should be removed.
            totalPoolShares = totalPoolShares.sub(iou.amountInShares);
            totalPoolFunds = totalPoolFunds.sub(amountInTokens);
        }
        balances[iou.userAddress] = balances[iou.userAddress].add(amountInTokens);
        delete ious[iouId];
        emit IouRedeemed(iouId);
    }
}
