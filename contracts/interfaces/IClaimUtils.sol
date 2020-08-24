//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IClaimUtils {
    function createClaim(
        address beneficiary,
        uint256 amount
        )
        external;

    function acceptClaim(bytes32 claimId)
        external;

    function denyClaim(bytes32 claimId)
        external;
}
