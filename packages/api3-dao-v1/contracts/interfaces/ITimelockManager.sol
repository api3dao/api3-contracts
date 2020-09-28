//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface ITimelockManager {
    event Api3PoolUpdated(address api3PoolAddress);

    event TransferredAndLocked(
        uint256 indexed indTimelock,
        address source,
        address indexed owner,
        uint256 amount,
        uint256 releaseTime,
        bool reversible
    );

    event TimelockReversed(
        uint256 indexed indTimelock,
        address destination
    );

    event Withdrawn(
        uint256 indexed indTimelock,
        address destination
    );

    event WithdrawnToPool(
        uint256 indexed indTimelock,
        address api3PoolAddress,
        address beneficiary
    );

    function updateApi3Pool(address api3PoolAddress)
        external;

    function transferAndLock(
        address source,
        address owner,
        uint256 amount,
        uint256 releaseTime,
        bool reversible
        )
        external;

    function transferAndLockMultiple(
        address source,
        address[] calldata owners,
        uint256[] calldata amounts,
        uint256[] calldata releaseTimes,
        bool[] calldata reversibles
        )
        external;

    function reverseTimelock(
        uint256 indTimelock,
        address destination
        )
        external;

    function reverseTimelockMultiple(
        uint256[] calldata indTimelocks,
        address destination
        )
        external;

    function withdraw(
        uint256 indTimelock,
        address destination
        )
        external;

    function withdrawToPool(
        uint256 indTimelock,
        address api3PoolAddress,
        address beneficiary
        )
        external;

    function getTimelock(uint256 indTimelock)
        external
        view
        returns (
            address owner,
            uint256 amount,
            uint256 releaseTime,
            bool reversibles
            );

    function getTimelocks()
        external
        view
        returns (
            address[] memory owners,
            uint256[] memory amounts,
            uint256[] memory releaseTimes,
            bool[] memory reversibles
            );
}