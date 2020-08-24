//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./IApi3Pool.sol";


interface IIouUtils {
    event IouCreated(
        bytes32 indexed iouId,
        address indexed userAddress,
        uint256 amountInShares,
        bytes32 indexed claimId,
        IApi3Pool.ClaimStatus redemptionCondition
        );

    event IouRedeemed(bytes32 indexed iouId);

    function redeem(bytes32 iouId)
        external;
}
