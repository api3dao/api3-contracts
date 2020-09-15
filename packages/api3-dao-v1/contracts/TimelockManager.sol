//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@api3-contracts/api3-token/contracts/interfaces/IApi3Token.sol";
import "@api3-contracts/api3-pool/contracts/interfaces/IApi3Pool.sol";
import "./interfaces/ITimelockManager.sol";


/// @title Contract that timelocks API3 tokens until the pool is operational
/// @notice This contracts timelocks the tokens it receives for specific owners
/// until releaseTime that is set at deployment. Alternatively, after the owner
/// of this contract (i.e., API3 DAO) sets an api3Pool, the owners are allowed
/// to transfer their tokens to this pool. Note that these tokens will be not
/// be withdrawable from the pool until releaseTime. 
contract TimelockManager is Ownable, ITimelockManager {
    using SafeMath for uint256;

    IApi3Token public immutable api3Token;
    IApi3Pool public api3Pool;

    uint256 public immutable releaseTime;
    mapping(address => uint256) private ownersToAmounts;

    /// @param api3TokenAddress Address of the API3 token contract
    /// @param _releaseTime Time at which owners can withdraw their tokens
    constructor(
        address api3TokenAddress,
        uint256 _releaseTime
        )
        public
    {
        api3Token = IApi3Token(api3TokenAddress);
        releaseTime = _releaseTime;
    }

    /// @notice Allows the owner (i.e., API3 DAO) to set the address of the
    /// pool contract, which token owners can transfer their tokens to
    /// @param api3PoolAddress Address of the API3 pool contract
    function updateApi3Pool(address api3PoolAddress)
        external
        override
        onlyOwner
    {
        api3Pool = IApi3Pool(api3PoolAddress);
        emit Api3PoolUpdated(api3PoolAddress);
    }

    /// @notice Transfers amount number of API3 tokens to this contract to be
    /// received by owner after conditions are met
    /// @dev source needs to approve() this contract to transfer amount number
    /// of tokens beforehand
    /// @param source Source of tokens
    /// @param amount Amount of tokens
    /// @param owner Owner of tokens
    function transferAndLock(
        address source,
        uint256 amount,
        address owner
        )
        public
        override
    {
        api3Token.transferFrom(source, address(this), amount);
        ownersToAmounts[owner] = ownersToAmounts[owner].add(amount);
    }

    /// @notice Convenience funtion that calls transferAndLock() multiple times
    /// @param source Source of tokens
    /// @param amounts Array of amounts of tokens
    /// @param owners Array of owners of tokens
    function transferAndLockMultiple(
        address source,
        uint256[] calldata amounts,
        address[] calldata owners
        )
        external
        override
    {
        require(
            amounts.length == owners.length,
            "Must have the same number of amounts and owners"
            );
        for (uint256 ind = 0; ind < amounts.length; ind++)
        {
            transferAndLock(source, amounts[ind], owners[ind]);
        }
    }

    /// @notice Used by the owner to withdraw their tokens after release time
    /// @param destination Address that will receive the tokens
    /// @param amount Amount of tokens that will be withdrawn
    function withdraw(
        address destination,
        uint256 amount
        )
        external
        override
    {
        require(now > releaseTime, "Cannot withdraw yet");
        uint256 ownedAmount = ownersToAmounts[msg.sender];
        require(amount <= ownedAmount, "Not enough funds");
        api3Token.transfer(destination, amount);
        ownersToAmounts[msg.sender] = ownedAmount.sub(amount);
    }

    /// @notice Used by the owner to withdraw their tokens to the API3 pool
    /// after it has been designated by the API3 DAO
    /// @param beneficiary Address that the tokens will be deposited to the
    /// pool contract on behalf of
    /// @param amount Amount of tokens that will be withdrawn
    function withdrawToPool(
        address beneficiary,
        uint256 amount
        )
        external
        override
    {
        require(address(api3Pool) != address(0), "Pool not set yet");
        uint256 ownedAmount = ownersToAmounts[msg.sender];
        require(amount <= ownedAmount, "Not enough funds");
        api3Token.approve(address(api3Pool), amount);
        api3Pool.depositWithVesting(
            address(this),
            amount,
            beneficiary,
            api3Pool.getEpochIndex(releaseTime)
            );
        ownersToAmounts[msg.sender] = ownedAmount.sub(amount);
    }

    /// @notice Returns the amount of tokens an address has locked
    /// @param owner Owner of tokens
    /// @return amount Amount of tokens
    function getTokenAmount(address owner)
        external
        view
        override
        returns (uint256 amount)
    {
        amount = ownersToAmounts[owner];
    }
}
