//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface ITimelockManager {
    event Api3PoolUpdated(address api3PoolAddress);

    event TransferredAndLocked(
        address source,
        address indexed recipient,
        uint256 amount,
        uint256 releaseStart,
        uint256 releaseEnd,
        bool reversible
    );

    event TimelockReversed(
        address indexed recipient,
        address destination
    );

    event Withdrawn(
        address indexed recipient,
        address destination
    );

    event WithdrawnToPool(
        address indexed recipient,
        address api3PoolAddress,
        address beneficiary
    );

    function updateApi3Pool(address api3PoolAddress)
        external;

    function transferAndLock(
        address source,
        address recipient,
        uint256 amount,
        uint256 releaseStart,
        uint256 releaseEnd,
        bool reversible
        )
        external;

    function transferAndLockMultiple(
        address source,
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256[] calldata releaseStarts,
        uint256[] calldata releaseEnds,
        bool[] calldata reversibles
        )
        external;

    function reverseTimelock(
        address recipient,
        address destination
        )
        external;

    function withdraw(address destination)
        external;

    function withdrawToPool(
        address api3PoolAddress,
        address beneficiary
        )
        external;

    function getTimelock(address recipient)
        external
        view
        returns (
            uint256 totalAmount,
            uint256 remainingAmount,
            uint256 releaseStart,
            uint256 releaseEnd,
            bool reversible
            );
}