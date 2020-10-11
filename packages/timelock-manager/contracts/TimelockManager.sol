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
/// TimelockManager to be timelocked until releaseStart. After releaseStart, the
/// respective owner can withdraw the tokens, either immedietly or on a cliff.
/// Alternatively, if the owner of this contract sets api3Pool, the token
/// owners can transfer their tokens from TimelockManager to api3Pool before
/// releaseStart. These tokens will be not be withdrawable from api3Pool until
/// their respective releaseTimes.
/// API3 DAO can also reverse timelocks (i.e., annul them) and send the tokens
/// to a destination of its choice. Note that timelocks can be specified not to
/// be reversible.
contract TimelockManager is Ownable, ITimelockManager {
    using SafeMath for uint256;

    struct Timelock { 
        address owner;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 releaseStart;
        uint256 releaseEnd;  
        uint256 cliffTime;  
        bool reversible;
    } 

    IApi3Token public immutable api3Token;
    IApi3Pool public api3Pool;
    mapping(uint256 => Timelock) public timelocks;
    uint256 public noTimelocks = 0;

    /// @dev api3Pool is not initialized in the constructor because this
    /// contract will be deployed before api3Pool
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
    /// received by their owner after releaseStart
    /// @dev source needs to approve() this contract to transfer amount number
    /// of tokens beforehand.
    /// This method is put behind onlyOwner to prevent third parties from
    /// spamming timelocks (not an actual issue but it would be inconvenient
    /// to sift through).
    /// @param source Source of tokens
    /// @param owner Owner of tokens
    /// @param amount Amount of tokens
    /// @param releaseStart Release start time
    /// @param releaseEnd Release end time
    /// @param cliff Time of the vesting cliff. 0 for no cliff.
    /// @param reversible Flag indicating if the timelock is reversible
    function transferAndLock(
        address source,
        address owner,
        uint256 amount,
        uint256 releaseStart,
        uint256 releaseEnd,
        uint256 cliff,
        bool reversible
        )
        public
        override
        onlyOwner
    {
        require(amount != 0, "Transferred and locked amount cannot be 0");
        timelocks[noTimelocks] = Timelock({
            owner: owner,
            totalAmount: amount,
            releasedAmount: 0,
            releaseStart: releaseStart,
            releaseEnd: releaseEnd,
            cliffTime: cliff,
            reversible: reversible
        });

        emit TransferredAndLocked(
            noTimelocks,
            source,
            owner,
            amount,
            releaseStart,
            releaseEnd,
            cliff,
            reversible
            );
        noTimelocks = noTimelocks.add(1);
        require(
            api3Token.transferFrom(source, address(this), amount),
            "API3 token transferFrom failed"
            );
    }

    /// @notice Convenience function that calls transferAndLock() multiple times
    /// @dev source is expected to be a single address, i.e., the DAO
    /// @param source Source of tokens
    /// @param owners Array of owners of tokens
    /// @param amounts Array of amounts of tokens
    /// @param releaseStarts Array of release start times
    /// @param reversibles Array of flags indicating if the timelocks are
    /// reversible
    function transferAndLockMultiple(
        address source,
        address[] calldata owners,
        uint256[] calldata amounts,
        uint256[] calldata releaseStarts,
        uint256[] calldata releaseEnds,
        uint256[] calldata cliffs,
        bool[] calldata reversibles
        )
        external
        override
        onlyOwner
        onlyIfParameterLengthIsShortEnough(owners.length)
    {
        require(
            owners.length == amounts.length
                && owners.length == releaseStarts.length
                && owners.length == reversibles.length,
            "Lengths of parameters do not match"
            );
        for (uint256 ind = 0; ind < owners.length; ind++)
        {
            transferAndLock(
                source,
                owners[ind],
                amounts[ind],
                releaseStarts[ind],
                releaseEnds[ind],
                cliffs[ind],
                reversibles[ind]);
        }
    }

    /// @notice Cancels the timelock and sends the locked tokens to destination
    /// @dev The reversible field of the timelock must be true
    /// @param indTimelock Index of the timelock to be reversed
    /// @param destination Address that will receive the tokens
    function reverseTimelock(
        uint256 indTimelock,
        address destination
        )
        public
        override
        onlyOwner
        onlyIfTimelockWithIndexExists(indTimelock)
        onlyIfDestinationIsValid(destination)
    {
        Timelock memory timelock = timelocks[indTimelock];
        require(
            timelock.reversible,
            "Timelock is not reversible"
            );
        require(
            timelock.releasedAmount < timelock.totalAmount,
            "Timelock is already withdrawn"
            );
        // Do not check if msg.sender is the timelock owner
        // Do not check if the timelock has matured
        uint256 amountToTransfer = timelock.totalAmount.sub(timelock.releasedAmount);
        timelocks[indTimelock].releasedAmount = timelock.totalAmount;
        emit TimelockReversed(
            indTimelock,
            destination
            );
        require(
            api3Token.transfer(destination, amountToTransfer),
            "API3 token transfer failed"
            );
    }

    /// @notice Convenience function that calls reverseTimelock() multiple times
    /// @dev destination is expected to be a single address, i.e., the DAO
    /// @param indTimelocks Array of indices of timelocks to be reversed
    /// @param destination Address that will receive the tokens
    function reverseTimelockMultiple(
        uint256[] calldata indTimelocks,
        address destination
        )
        external
        override
        onlyOwner
        onlyIfParameterLengthIsShortEnough(indTimelocks.length)
    {
        for (uint256 ind = 0; ind < indTimelocks.length; ind++)
        {
            reverseTimelock(indTimelocks[ind], destination);
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
        onlyIfTimelockWithIndexExists(indTimelock)
        onlyIfDestinationIsValid(destination)
    {
        Timelock memory timelock = timelocks[indTimelock];
        require(
            timelock.releasedAmount < timelock.totalAmount,
            "Timelock is already withdrawn"
            );
        require(
            msg.sender == timelock.owner,
            "Only the owner of the timelock can withdraw from it"
            );
        require(
            now > timelock.cliffTime,
            "Timelock has not matured yet"
            );

        uint256 withdrawableAmount;
        if (now > timelock.releaseEnd) {
            //Release all remaining funds
            withdrawableAmount = timelock.totalAmount.sub(timelock.releasedAmount);
        } else {
            //Release linear
            uint256 percentComplete = ((now.sub(timelock.releaseStart)).mul(10**19))
                .div(timelock.releaseEnd.sub(timelock.releaseStart));
            withdrawableAmount = ((timelock.totalAmount.mul(percentComplete))
                .div(10**19)).sub(timelock.releasedAmount);
        }

        timelocks[indTimelock].releasedAmount = timelock.releasedAmount.add(withdrawableAmount);
        emit Withdrawn(
            indTimelock,
            destination
            );
        require(
            api3Token.transfer(destination, withdrawableAmount),
            "API3 token transfer failed"
            );
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
        onlyIfTimelockWithIndexExists(indTimelock)
    {
        require(
            beneficiary != address(0),
            "Cannot withdraw to benefit address 0"
            );
        require(address(api3Pool) != address(0), "API3 pool not set yet");
        require(
            address(api3Pool) == api3PoolAddress,
            "API3 pool addresses do not match"
            );
        Timelock memory timelock = timelocks[indTimelock];
        require(
            timelock.releasedAmount < timelock.totalAmount,
            "Timelock is already withdrawn"
            );
        require(
            msg.sender == timelock.owner,
            "Only the owner of the timelock can withdraw from it"
            );
        // Do not check if the timelock has matured
        uint256 amountToTransfer = timelock.totalAmount.sub(timelock.releasedAmount);
        timelocks[indTimelock].releasedAmount = timelock.totalAmount;
        emit WithdrawnToPool(
            indTimelock,
            api3PoolAddress,
            beneficiary
            );
        api3Token.approve(address(api3Pool), amountToTransfer);
        // If (now > timelock.releaseStart), the beneficiary can immediately
        // have their tokens vested at the pool with an additional transaction
        api3Pool.depositWithVesting(
            address(this),
            amountToTransfer,
            beneficiary,
            timelock.releaseStart
            );
    }

    /// @notice Returns the details of a timelock
    /// @return owner Owner of tokens
    /// @return totalAmount Total amount of tokens
    /// @return releasedAmount Amounts of tokens released already
    /// @return releaseStart Release start time, ignoring cliff
    /// @return releaseEnd Release end time
    /// @return reversible Flag indicating if the timelock is reversible
    /// @return cliffTime Time when the cliff ends for this timelock
    function getTimelock(uint256 indTimelock)
        external
        view
        override
        onlyIfTimelockWithIndexExists(indTimelock)
        returns (
            address owner,
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 releaseStart,
            uint256 releaseEnd,
            bool reversible,
            uint256 cliffTime
            )
    {
        Timelock storage timelock = timelocks[indTimelock];
        owner = timelock.owner;
        totalAmount = timelock.totalAmount;
        releasedAmount = timelock.releasedAmount;
        releaseStart = timelock.releaseStart;
        releaseEnd = timelock.releaseEnd;
        reversible = timelock.reversible;
        cliffTime = timelock.cliffTime;
    }

    /// @notice Returns the details of all timelocks
    /// @dev This is a convenience method for the user to be able to retrieve
    /// all timelocks with a single call and loop through them to find the
    /// timelocks they are looking for. In case timelocks grow too large and
    /// this method starts reverting (not expected), the user can go through
    /// the events emitted during locking, or even go through individual
    /// indices using getTimelock().
    /// @return owners Owners of tokens
    /// @return totalAmounts Total amounts of tokens
    /// @return releasedAmounts Amounts of tokens released already
    /// @return releaseStarts Release start times ignoring the cliff
    /// @return releaseEnds Release end times
    /// @return reversibles Array of flags indicating if the timelocks are
    /// @return cliffTimes Time when the cliff ends for this timelock
    /// reversible
    function getTimelocks()
        external
        view
        override
        returns (
            address[] memory owners,
            uint256[] memory totalAmounts,
            uint256[] memory releasedAmounts,
            uint256[] memory releaseStarts,
            uint256[] memory releaseEnds,
            bool[] memory reversibles,
            uint256[] memory cliffTimes
            )
    {
        owners = new address[](noTimelocks);
        totalAmounts = new uint256[](noTimelocks);
        releasedAmounts = new uint256[](noTimelocks);
        releaseStarts = new uint256[](noTimelocks);
        releaseEnds = new uint256[](noTimelocks);
        reversibles = new bool[](noTimelocks);
        cliffTimes = new uint256[](noTimelocks);
        for (uint256 ind = 0; ind < noTimelocks; ind++)
        {
            Timelock storage timelock = timelocks[ind];
            owners[ind] = timelock.owner;
            totalAmounts[ind] = timelock.totalAmount;
            releasedAmounts[ind] = timelock.releasedAmount;
            releaseStarts[ind] = timelock.releaseStart;
            releaseEnds[ind] = timelock.releaseEnd;
            reversibles[ind] = timelock.reversible;
            cliffTimes[ind] = timelock.cliffTime;
        }
    }

    /// @dev Reverts if a timelock with index indTimelock does not exist
    modifier onlyIfTimelockWithIndexExists(uint256 indTimelock)
    {
        require(
            indTimelock < noTimelocks,
            "No such timelock exists"
            );
        _;
    }

    /// @dev Reverts if the parameter array is longer than 30
    modifier onlyIfParameterLengthIsShortEnough(uint256 parameterLength)
    {
        require(
            parameterLength <= 30,
            "Parameters are longer than 30"
            );
        _;
    }

    /// @dev Reverts if the destination is address(0)
    modifier onlyIfDestinationIsValid(address destination)
    {
        require(
            destination != address(0),
            "Cannot withdraw to address 0"
            );
        _;
    }
}
