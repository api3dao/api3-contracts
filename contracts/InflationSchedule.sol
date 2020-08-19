//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IInflationSchedule.sol";


contract InflationSchedule is IInflationSchedule {
    using SafeMath for uint256;

    function getDelta(uint256 indEpoch)
        external
        view
        override
        returns(uint256 delta)
    {
        
        delta = uint256(100000).sub(indEpoch.mul(100)); // replace this with the actual schedule
    }
}