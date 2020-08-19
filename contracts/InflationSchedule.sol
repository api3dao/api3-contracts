//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IInflationSchedule.sol";


contract InflationSchedule is IInflationSchedule {
    using SafeMath for uint256;

    uint256 public immutable startEpoch;

    constructor(uint256 _startEpoch)
        public
        {
            startEpoch = _startEpoch;
        }

    function getDeltaTokenSupply(uint256 currentEpoch)
        external
        view
        override
        returns(uint256 deltaTokenSupply)
    {
        if (currentEpoch < startEpoch)
        {
            return 0;
        }
        uint256 deltaEpoch = currentEpoch - startEpoch;
        deltaTokenSupply = uint256(100000).sub(deltaEpoch.mul(100)); // replace this with the actual schedule
    }
}