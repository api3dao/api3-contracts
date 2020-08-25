//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./EpochUtils.sol";
import "./interfaces/IGetterUtils.sol";


/// @title Contract where getters and some convenience methods are implemented
/// for the API3 pool
contract GetterUtils is EpochUtils, IGetterUtils {
    /// @param api3TokenAddress Address of the API3 token contract
    /// @param epochPeriodInSeconds Length of epochs used to quantize time
    /// @param firstEpochStartTimestamp Starting timestamp of epoch #1
    constructor(
        address api3TokenAddress,
        uint256 epochPeriodInSeconds,
        uint256 firstEpochStartTimestamp
        )
        EpochUtils(
            api3TokenAddress,
            epochPeriodInSeconds,
            firstEpochStartTimestamp
            )
        public
        {}

    /// @notice Gets the amount of funds the user has pooled
    /// @param userAddress User address
    function getPooled(address userAddress)
        internal
        view
        returns(uint256 pooled)
    {
        pooled = totalShares.mul(totalPooled).div(shares[userAddress]);
    }

    /// @notice Calculates how many shares an amount of tokens corresponds to
    /// @param amount Amount of funds
    function convertToShares(uint256 amount)
        internal
        view
        returns(uint256 amountInShares)
    {
        amountInShares = amount.mul(totalShares).div(totalPooled);
    }

    /// @notice Calculates how many tokens an amount of shares corresponds to
    /// @param amountInShares Amount in shares
    function convertFromShares(uint256 amountInShares)
        internal
        view
        returns(uint256 amount)
    {
        amount = amountInShares.mul(totalPooled).div(totalShares);
    }

    /// @notice Gets the amount of voting power a user has at a given timestamp
    /// @dev Total voting power of all users adds up to 1e18
    /// @param userAddress User address
    /// @param timestamp Timestamp
    function getVotingPower(
        address userAddress,
        uint256 timestamp
        )
        external
        view
        override
        returns(uint256 votingPower)
    {
        uint256 epochIndex = getEpochIndex(timestamp);
        votingPower = stakedAtEpoch[userAddress][epochIndex]
            .mul(1e18).div(totalStakedAtEpoch[epochIndex]);
    }
}
