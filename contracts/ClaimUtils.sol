//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./Api3Pool.sol";


contract ClaimUtils is Api3Pool {
    event ClaimsManagerUpdated(address claimsManager);

    constructor(
        address api3TokenAddress,
        uint256 epochPeriodInSeconds,
        uint256 firstEpochStartTimestamp
        )
        Api3Pool(
            api3TokenAddress,
            epochPeriodInSeconds,
            firstEpochStartTimestamp
            )
        public
        {}

    function createClaim(
        address beneficiary,
        uint256 amount
        )
        external
        onlyClaimsManager
    {
        totalActiveClaimsAmount = totalActiveClaimsAmount.add(amount);
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
        totalActiveClaimsAmount = totalActiveClaimsAmount.sub(claim.amount);
        api3Token.transferFrom(address(this), claim.beneficiary, claim.amount);
    }

    function denyClaim(bytes32 claimId)
        external
        onlyClaimsManager
    {
        require(deactivateClaim(claimId), "No such active claim exists");
        claims[claimId].status = ClaimStatus.Denied;
        totalActiveClaimsAmount = totalActiveClaimsAmount.sub(claims[claimId].amount);
    }

    function deactivateClaim(bytes32 claimId)
        private
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

    function updateClaimsManager(address claimsManagerAddress)
        external
        onlyOwner
    {
        claimsManager = claimsManagerAddress;
        emit ClaimsManagerUpdated(claimsManager);
    }

    modifier onlyClaimsManager()
    {
        require(msg.sender == claimsManager, "Not authorized to manage claims processes");
        _;
    }
}
