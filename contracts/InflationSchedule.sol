//SPDX-License-Identifier: Unlicense
pragma solidity >=0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IInflationSchedule.sol";
import "./SafeDecimalMath.sol";

contract InflationSchedule is IInflationSchedule {
    using SafeMath for uint256;

    uint256 public immutable startEpoch;


    /**
      The initial inflation rate starts at 75% annual.
      Thus, the initial weekly inflationary supply is 75% / 52 * 100,000,000 API3.
      We have: 75e6 * SafeDecimalMath.unit() / 52 = 1442307692307692307692307
    */
    uint public constant INITIAL_WEEKLY_SUPPLY = 1442307692307692307692307;

    // Weekly percentage decay of inflationary supply from previous week
    uint public constant DECAY_RATE = 9650000000000000; // 0.965% weekly

    // Percentage growth of terminal supply per annum
    uint public constant TERMINAL_ANNUAL_SUPPLY_RATE = 25000000000000000; // 2.5%

    // Epoch/week number when terminal inflation rate begins to take effect.
    // 5 years * 52 weeks/year = 260
    uint8 public constant TERMINAL_EPOCH = startEpoch + 260; // terminal inflation rate begins after 5 years

    constructor(uint256 _startEpoch)
        public
        {
            startEpoch = _startEpoch;
        }

    /**
     * @notice Set the API3TokenProxy.
     * InflationSchedule requires the API3 token address since we need to know total supply
     * in order to compute terminal weekly token emissions. 
     * */
    function setAPI3Proxy(IApi3Token _API3TokenProxy) external onlyOwner {
        require(address(_API3TokenProxy) != address(0), "Address cannot be 0");
        API3TokenProxy = address(uint160(address(_API3TokenProxy)));
        emit API3TokenProxyUpdated(API3TokenProxy);
    }


    function getDeltaTokenSupply(uint256 currentEpoch)
        external
        view
        override
        returns(uint256 deltaTokenSupply)
    {
        if (currentEpoch < startEpoch) {
            return 0;
        } else if (currentEpoch == startEpoch) {
            return INITIAL_WEEKLY_SUPPLY;
        } else if (currentEpoch < TERMINAL_EPOCH) {
            // from: https://github.com/Synthetixio/synthetix/blob/master/contracts/SupplySchedule.sol#L117
            uint effectiveDecay = (SafeDecimalMath.unit().sub(DECAY_RATE)).powDecimal(currentEpoch - startEpoch);
            uint supplyForWeek = INITIAL_WEEKLY_SUPPLY.multiplyDecimal(effectiveDecay);
            return supplyForWeek;
        } else {
            uint terminalWeeklyRate = TERMINAL_SUPPLY_RATE_ANNUAL.div(52);
            uint supplyForWeek = totalSupply.multiplyDecimal(terminalWeeklyRate);
            return supplyForWeek;
        }
    }


    /**
     * @notice Emitted when API3 Token Proxy address is updated
     * */
    event API3TokenProxyUpdated(address newAddress);
}
