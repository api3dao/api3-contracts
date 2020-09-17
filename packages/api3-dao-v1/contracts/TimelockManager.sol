//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@api3-contracts/api3-token/contracts/interfaces/IApi3Token.sol";
import "@api3-contracts/api3-pool/contracts/interfaces/IApi3Pool.sol";
import "./interfaces/ITimelockManager.sol";


/// @title Contract that timelocks API3 tokens sent to it until the vesting
/// period is over or the staking pool is operational
/// @notice The owner of TimelockManager (i.e., API3 DAO) can send tokens to
/// TimelockManager to be timelocked until releaseTime. After releaseTime, the
/// respective owner can withdraw the tokens.
/// Alternatively, if the owner of this contract sets api3Pool, the token
/// owners can transfer their tokens from TimelockManager to api3Pool before
/// releaseTime. These tokens will be not be withdrawable from api3Pool until
/// their respective releaseTimes.
contract TimelockManager is Ownable, ITimelockManager {
    using SafeMath for uint256;

    struct Timelock {
        address owner;
        uint256 amount;
        uint256 releaseTime;
        }

    IApi3Token public immutable api3Token;
    IApi3Pool public api3Pool;
    mapping(uint256 => Timelock) public timelocks;
    uint256 public noTimelocks = 0;

    /// @param api3TokenAddress Address of the API3 token contract
    /// @param timelockManagerOwner Address that will receive the ownership of
    /// the TimelockManager contract (i.e., the API3 DAO)
    constructor(
        address api3TokenAddress,
        address timelockManagerOwner
        )
        public
    {
        api3Token = IApi3Token(api3TokenAddress);
        transferOwnership(timelockManagerOwner);
    }

    /// @notice Allows the owner (i.e., API3 DAO) to set the address of
    /// api3Pool, which token owners can transfer their tokens to
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
    /// received by their owner after releaseTime
    /// @dev source needs to approve() this contract to transfer amount number
    /// of tokens beforehand.
    /// This method is put behind onlyOwner to prevent third parties from
    /// spamming timelocks (not an actual issue but it would be inconvenient
    /// to sift through).
    /// @param source Source of tokens
    /// @param owner Owner of tokens
    /// @param amount Amount of tokens
    /// @param releaseTime Release time
    function transferAndLock(
        address source,
        address owner,
        uint256 amount,
        uint256 releaseTime
        )
        public
        override
        onlyOwner
    {
        timelocks[noTimelocks] = Timelock({
            owner: owner,
            amount: amount,
            releaseTime: releaseTime
            });
        noTimelocks = noTimelocks.add(1);
        emit TransferredAndLocked(
            source,
            owner,
            amount,
            releaseTime
            );
        api3Token.transferFrom(source, address(this), amount);
    }

    /// @notice Convenience function that calls transferAndLock() multiple times
    /// @param source Source of tokens
    /// @param owners Array of owners of tokens
    /// @param amounts Array of amounts of tokens
    /// @param releaseTimes Array of release times
    function transferAndLockMultiple(
        address source,
        address[] calldata owners,
        uint256[] calldata amounts,
        uint256[] calldata releaseTimes
        )
        external
        override
        onlyOwner
    {
        require(
            owners.length == amounts.length && owners.length == releaseTimes.length,
            "Lengths of parameters do not match"
            );
        for (uint256 ind = 0; ind < owners.length; ind++)
        {
            transferAndLock(source, owners[ind], amounts[ind], releaseTimes[ind]);
        }
    }

    /// @notice Used by the owner to withdraw tokens kept by a specific
    /// timelock
    /// @param indTimelock Index of the timelock to be withdrawn from
    /// @param destination Address that will receive the tokens
    function withdraw(
        uint256 indTimelock,
        address destination
        )
        external
        override
    {
        Timelock memory timelock = timelocks[indTimelock];
        require(
            msg.sender == timelock.owner,
            "Only the owner of the timelock can withdraw from it"
            );
        require(
            now > timelock.releaseTime,
            "Timelock has not matured yet"
            );
        delete timelocks[indTimelock];
        api3Token.transfer(destination, timelock.amount);
    }

    /// @notice Used by the owner to withdraw their tokens kept by a specific
    /// timelock to the API3 pool
    /// @dev We ask the user to provide api3PoolAddress as a form of
    /// verification, i.e., the user confirms that the API3 pool address set at
    /// this contract is correct
    /// @param indTimelock Index of the timelock to be withdrawn from
    /// @param api3PoolAddress Address of the API3 pool contract
    /// @param beneficiary Address that the tokens will be deposited to the
    /// pool contract on behalf of
    function withdrawToPool(
        uint256 indTimelock,
        address api3PoolAddress,
        address beneficiary
        )
        external
        override
    {
        require(address(api3Pool) != address(0), "API3 pool not set yet");
        require(
            address(api3Pool) == api3PoolAddress,
            "API3 pool addresses do not match"
            );
        Timelock memory timelock = timelocks[indTimelock];
        require(
            msg.sender == timelock.owner,
            "Only the owner of the timelock can withdraw from it"
            );
        // We deliberately skip checking for timelock maturity
        delete timelocks[indTimelock];
        api3Token.approve(address(api3Pool), timelock.amount);
        // If (now > timelock.releaseTime), the beneficiary can immediately
        // have their tokens vested at the pool with an additional transaction
        api3Pool.depositWithVesting(
            address(this),
            timelock.amount,
            beneficiary,
            api3Pool.getEpochIndex(timelock.releaseTime)
            );
    }

    /// @notice Returns the details of a timelock
    /// @return owner Owner of tokens
    /// @return amount Amount of tokens
    /// @return releaseTime Release time
    function getTimelock(uint256 indTimelock)
        external
        view
        override
        returns (
            address owner,
            uint256 amount,
            uint256 releaseTime
            )
    {
        Timelock storage timelock = timelocks[indTimelock];
        owner = timelock.owner;
        amount = timelock.amount;
        releaseTime = timelock.releaseTime;
    }

    /// @notice Returns the details of all timelocks
    /// @return owners Owners of tokens
    /// @return amounts Amounts of tokens
    /// @return releaseTimes Release times
    function getTimelocks()
        external
        view
        override
        returns (
            address[] memory owners,
            uint256[] memory amounts,
            uint256[] memory releaseTimes
            )
    {
        owners = new address[](noTimelocks);
        amounts = new uint256[](noTimelocks);
        releaseTimes = new uint256[](noTimelocks);
        for (uint256 ind = 0; ind < noTimelocks; ind++)
        {
            Timelock storage timelock = timelocks[ind];
            owners[ind] = timelock.owner;
            amounts[ind] = timelock.amount;
            releaseTimes[ind] = timelock.releaseTime;
        }
    }
}
