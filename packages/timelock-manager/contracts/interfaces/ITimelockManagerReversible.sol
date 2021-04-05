//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ITimelockManagerReversible {

    event StoppedVesting(
        address recipient, 
        address destination, 
        uint256 amount
    );

    event TransferredAndLocked(
        address source,
        address indexed recipient,
        uint256 amount,
        uint256 releaseStart,
        uint256 releaseEnd
    );

    event Withdrawn(
        address indexed recipient, 
        uint256 amount
    );

    function stopVesting(
        address recipient, 
        address destination
    ) external;

    function transferAndLock(
        address source,
        address recipient,
        uint256 amount,
        uint256 releaseStart,
        uint256 releaseEnd
    ) external;

    function transferAndLockMultiple(
        address source,
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256[] calldata releaseStarts,
        uint256[] calldata releaseEnds
    ) external;

    function withdraw() external;

    function getWithdrawable(address recipient)
        external
        view
        returns (
            uint256 withdrawable
        );

    function getTimelock(address recipient)
        external
        view
        returns (
            uint256 totalAmount,
            uint256 remainingAmount,
            uint256 releaseStart,
            uint256 releaseEnd
        );

    function getRemainingAmount(address recipient)
        external
        view
        returns (
            uint256 remainingAmount
        );
}
