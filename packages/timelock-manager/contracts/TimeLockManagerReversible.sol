//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@api3-contracts/api3-token/contracts/interfaces/IApi3Token.sol";
import "./interfaces/ITimelockManagerReversible.sol";

/// @title Contract that the TimeLockManager Contract Owner uses to timelock API3 tokens
/// @notice The owner of TimelockManager can send tokens to
/// TimelockManager to timelock them. These tokens will then be vested to their
/// recipient linearly, starting from releaseStart and ending at releaseEnd of
/// the respective timelock.

contract TimelockManagerReversible is Ownable, ITimelockManagerReversible {
    using SafeMath for uint256;

    struct Timelock {
        uint256 totalAmount;
        uint256 remainingAmount;
        uint256 releaseStart;
        uint256 releaseEnd;
    }

    IApi3Token public immutable api3Token;
    mapping(address => Timelock) public timelocks;

    /// @param api3TokenAddress Address of the API3 token contract
    /// @param timelockManagerOwner Address that will receive the ownership of
    /// the TimelockManager contract
    constructor(
        address api3TokenAddress, 
        address timelockManagerOwner
        ) 
        public 
    {
        api3Token = IApi3Token(api3TokenAddress);
        transferOwnership(timelockManagerOwner);
    }

    /// @notice Called by the ContractOwner to stop the vesting of
    /// a recipient
    /// @param recipient Original recipient of tokens
    /// @param destination Destination of the excess tokens vested to the addresss
    function stopVesting(
        address recipient, 
        address destination
        )
        external
        override
        onlyOwner
        onlyIfRecipientHasRemainingTokens(recipient)
    {
        uint256 withdrawable = getWithdrawable(recipient);
        uint256 reclaimedTokens =
            timelocks[recipient].remainingAmount.sub(withdrawable);
        timelocks[recipient].remainingAmount = withdrawable;
        timelocks[recipient].releaseEnd = now;
        require(
            api3Token.transfer(destination, reclaimedTokens),
            "API3 token transfer failed"
        );
        emit StoppedVesting(recipient, destination, reclaimedTokens);
    }

    /// @notice Transfers API3 tokens to this contract and timelocks them
    /// @dev source needs to approve() this contract to transfer amount number
    /// of tokens beforehand.
    /// A recipient cannot have multiple timelocks.
    /// @param source Source of tokens
    /// @param recipient Recipient of tokens
    /// @param amount Amount of tokens
    /// @param releaseStart Start of release time
    /// @param releaseEnd End of release time
    function transferAndLock(
        address source,
        address recipient,
        uint256 amount,
        uint256 releaseStart,
        uint256 releaseEnd
        ) 
        public 
        override 
        onlyOwner
    {
        require(
            timelocks[recipient].remainingAmount == 0,
            "Recipient has remaining tokens"
        );
        require(amount != 0, "Amount cannot be 0");
        require(
            releaseEnd > releaseStart,
            "releaseEnd not larger than releaseStart"
        );
        timelocks[recipient] = Timelock({
            totalAmount: amount,
            remainingAmount: amount,
            releaseStart: releaseStart,
            releaseEnd: releaseEnd
        });
        require(
            api3Token.transferFrom(source, address(this), amount),
            "API3 token transferFrom failed"
        );
        emit TransferredAndLocked(
            source,
            recipient,
            amount,
            releaseStart,
            releaseEnd
        );
    }

    /// @notice Convenience function that calls transferAndLock() multiple times
    /// @dev source is expected to be a single address.
    /// source needs to approve() this contract to transfer the sum of the
    /// amounts of tokens to be transferred and locked.
    /// @param source Source of tokens
    /// @param recipients Array of recipients of tokens
    /// @param amounts Array of amounts of tokens
    /// @param releaseStarts Array of starts of release times
    /// @param releaseEnds Array of ends of release times
    function transferAndLockMultiple(
        address source,
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256[] calldata releaseStarts,
        uint256[] calldata releaseEnds
        ) 
        external 
        override 
        onlyOwner 
    {
        require(
            recipients.length == amounts.length &&
                recipients.length == releaseStarts.length &&
                recipients.length == releaseEnds.length,
            "Parameters are of unequal length"
        );
        require(recipients.length <= 30, "Parameters are longer than 30");
        for (uint256 ind = 0; ind < recipients.length; ind++) {
            transferAndLock(
                source,
                recipients[ind],
                amounts[ind],
                releaseStarts[ind],
                releaseEnds[ind]
            );
        }
    }

    /// @notice Used by the recipient to withdraw tokens
    function withdraw()
        external
        override
        onlyIfRecipientHasRemainingTokens(msg.sender)
    {
        address recipient = msg.sender;
        uint256 withdrawable = getWithdrawable(recipient);
        require(withdrawable != 0, "No withdrawable tokens yet");
        timelocks[recipient].remainingAmount = timelocks[recipient]
            .remainingAmount
            .sub(withdrawable);
        require(
            api3Token.transfer(recipient, withdrawable),
            "API3 token transfer failed"
        );
        emit Withdrawn(recipient, withdrawable);
    }

    /// @notice Returns the amount of tokens a recipient can currently withdraw
    /// @param recipient Address of the recipient
    /// @return withdrawable Amount of tokens withdrawable by the recipient
    function getWithdrawable(address recipient)
        public
        view
        override
        returns (uint256 withdrawable)
    {
        Timelock storage timelock = timelocks[recipient];
        uint256 unlocked = getUnlocked(recipient);
        uint256 withdrawn = timelock.totalAmount.sub(timelock.remainingAmount);
        withdrawable = unlocked.sub(withdrawn);
    }

    /// @notice Returns the amount of tokens that was unlocked for the
    /// recipient to date. Includes both withdrawn and non-withdrawn tokens.
    /// @param recipient Address of the recipient
    /// @return unlocked Amount of tokens unlocked for the recipient
    function getUnlocked(address recipient)
        private
        view
        returns (uint256 unlocked)
    {
        Timelock storage timelock = timelocks[recipient];
        if (now <= timelock.releaseStart) {
            unlocked = 0;
        } else if (now >= timelock.releaseEnd) {
            unlocked = timelock.totalAmount;
        } else {
            uint256 passedTime = now.sub(timelock.releaseStart);
            uint256 totalTime = timelock.releaseEnd.sub(timelock.releaseStart);
            unlocked = timelock.totalAmount.mul(passedTime).div(totalTime);
        }
    }

    /// @notice Returns the details of a timelock
    /// @param recipient Recipient of tokens
    /// @return totalAmount Total amount of tokens
    /// @return remainingAmount Remaining amount of tokens to be withdrawn
    /// @return releaseStart Release start time
    /// @return releaseEnd Release end time
    function getTimelock(address recipient)
        external
        view
        override
        returns (
            uint256 totalAmount,
            uint256 remainingAmount,
            uint256 releaseStart,
            uint256 releaseEnd
        )
    {
        Timelock storage timelock = timelocks[recipient];
        totalAmount = timelock.totalAmount;
        remainingAmount = timelock.remainingAmount;
        releaseStart = timelock.releaseStart;
        releaseEnd = timelock.releaseEnd;
    }

    /// @notice Returns remaining amount of a timelock
    /// @dev Provided separately to be used with Etherscan's "Read"
    /// functionality, in case getTimelock() output is too complicated for the
    /// user.
    /// @param recipient Recipient of tokens
    /// @return remainingAmount Remaining amount of tokens to be withdrawn
    function getRemainingAmount(address recipient)
        external
        view
        override
        returns (uint256 remainingAmount)
    {
        remainingAmount = timelocks[recipient].remainingAmount;
    }

    /// @dev Reverts if the recipient does not have remaining tokens
    modifier onlyIfRecipientHasRemainingTokens(address recipient) {
        require(
            timelocks[recipient].remainingAmount != 0,
            "Recipient does not have remaining tokens"
        );
        _;
    }
}
