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

    function getDelta(uint256 indEpoch)
        external
        view
        override
        returns(uint256 delta)
    {
        if (indEpoch < startEpoch)
        {
            return 0;
        }
        uint256 passedEpochs = indEpoch - startEpoch;
        delta = uint256(100000).sub(passedEpochs.mul(100)); // replace this with the actual schedule
    }
}