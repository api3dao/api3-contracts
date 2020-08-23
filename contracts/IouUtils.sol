//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./ClaimUtils.sol";


contract IouUtils is ClaimUtils {
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
    }

    function redeem(bytes32 iouId)
        external
    {
        Iou memory iou = ious[iouId];
        uint256 amountInTokens = convertSharesToFunds(iou.amountInShares);
        require(
            iou.redemptionCondition == claims[iou.claimId].status,
            "IOU redemption condition is not met"
            );
        if (iou.redemptionCondition == ClaimStatus.Denied)
        {
            // Remove the ghost pool shares
            totalPoolShares = totalPoolShares.sub(iou.amountInShares);
            totalPoolFunds = totalPoolFunds.sub(amountInTokens);
        }
        balances[iou.userAddress] = balances[iou.userAddress].add(amountInTokens);
        delete ious[iouId];
    }
}
