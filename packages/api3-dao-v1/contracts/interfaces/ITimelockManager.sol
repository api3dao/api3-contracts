//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface ITimelockManager {
    event Api3PoolUpdated(address api3PoolAddress);

    function updateApi3Pool(address api3PoolAddress)
        external;

    function transferAndLock(
        address source,
        uint256 amount,
        address owner
        )
        external;

    function transferAndLockMultiple(
        address source,
        uint256[] calldata amounts,
        address[] calldata owners
        )
        external;

    function withdraw(
        address destination,
        uint256 amount
        )
        external;

    function withdrawToPool(
        address beneficiary,
        uint256 amount
        )
        external;

    function getTokenAmount(address owner)
        external
        view
        returns (uint256 amount);
}