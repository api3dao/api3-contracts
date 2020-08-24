//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IPoolUtils {
    event Pooled(
        address indexed userAddress,
        uint256 amount
        );
    
    event RequestedToUnpool(address indexed userAddress);

    event Unpooled(
        address indexed userAddress,
        uint256 amount
    );

    function pool(uint256 amount)
        external;

    function requestToUnpool()
        external;

    function unpool(uint256 amount)
        external;
}
