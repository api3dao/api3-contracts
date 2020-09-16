//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface ITimelockManager {
    event Api3PoolUpdated(address api3PoolAddress);

    function updateApi3Pool(address api3PoolAddress)
        external;

    function transferAndLock(
        address source,
        address owner,
        uint256 amount,
        uint256 releaseTime
        )
        external;

    function transferAndLockMultiple(
        address source,
        address[] calldata owners,
        uint256[] calldata amounts,
        uint256[] calldata releaseTimes
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

    function getTimelocks()
        external
        view
        returns (
            address[] memory owners,
            uint256[] memory amounts,
            uint256[] memory releaseTimes
            );
}