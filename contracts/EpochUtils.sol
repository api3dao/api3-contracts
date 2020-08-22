//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract EpochUtils {
    using SafeMath for uint256;

    uint256 public immutable epochPeriodInSeconds;
    uint256 public immutable firstEpochStartTimestamp;

    constructor(uint256 _epochPeriodInSeconds)
        public
        {
            require(_epochPeriodInSeconds != 0, "Epoch period cannot be 0");
            epochPeriodInSeconds = _epochPeriodInSeconds;
            firstEpochStartTimestamp = now;
        }

    function getCurrentEpochNumber()
        public
        view
        returns(uint256)
    {
        return getEpochNumber(now);
    }

    function getEpochNumber(uint256 timestamp)
        public
        view
        returns(uint256)
    {
        if (timestamp < firstEpochStartTimestamp)
        {
            return 0;
        }
        return timestamp.sub(firstEpochStartTimestamp).div(epochPeriodInSeconds).add(1);
    }
}
