//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract EpochUtils {
    using SafeMath for uint256;

    uint256 public epochPeriodInSeconds;
    uint256 public firstEpochStartTimestamp;

    constructor(uint256 _epochPeriodInSeconds)
        public
        {
            require(_epochPeriodInSeconds != 0, "Epoch cannot be 0");
            firstEpochStartTimestamp = now;
            epochPeriodInSeconds = _epochPeriodInSeconds;
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
        return ((timestamp.sub(firstEpochStartTimestamp)).div(epochPeriodInSeconds)).add(1);
    }
}