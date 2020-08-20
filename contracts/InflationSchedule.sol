//SPDX-License-Identifier: Unlicense
pragma solidity >=0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IInflationSchedule.sol";
import "./interfaces/IApi3Token.sol";
import "./Math.sol";

contract InflationSchedule is IInflationSchedule {
    using SafeMath for uint256;
    using SafeDecimalMath for uint;
    using Math for uint;

    IApi3Token public immutable api3Token;
    uint256 public startEpoch;

    /**
      Initial annual inflation rate: 0.75
      Initial weekly inflation rate: 0.75 / 52
      Initial token supply (in Wei): 1e8 * 1e18 = 1e26
      Initial weekly inflationary supply: 1e26 * 0.75 / 52 = 1442307692307692307692307
    */
    uint256 public constant INITIAL_WEEKLY_SUPPLY = 1442307692307692307692307;

    // Weekly supply decay rate: 0.00965
    // Weekly supply update coefficient: 1e18 * (1 - 0.00965) = 990350000000000000
    uint256 public constant WEEKLY_SUPPLY_UPDATE_COEFF = 990350000000000000;

    // Terminal annual inflation rate: 0.025
    // Terminal weekly inflation rate: 0.025 / 52
    // Terminal weekly inflationary supply rate: 1e18 * 0.025 / 52
    uint256 public constant TERMINAL_WEEKLY_SUPPLY_RATE = 480769230769230;

    // 5 years * 52 weeks/year = 260
    uint256 public DECAY_PERIOD_IN_EPOCHS = 5 * 52;

    // Epoch/week number when terminal inflation rate begins to take effect
    uint256 public TERMINAL_EPOCH;

    constructor(
        address api3TokenAddress,
        uint256 _startEpoch
        )
        public
        {
            api3Token = IApi3Token(api3TokenAddress);
            startEpoch = _startEpoch;
            TERMINAL_EPOCH = startEpoch + DECAY_PERIOD_IN_EPOCHS;
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
            uint effectiveDecay = (WEEKLY_SUPPLY_UPDATE_COEFF).powDecimal(currentEpoch - startEpoch);
            uint supplyForWeek = INITIAL_WEEKLY_SUPPLY.multiplyDecimal(effectiveDecay);
            return supplyForWeek;
        } else {
            uint supplyForWeek = api3Token.totalSupply().multiplyDecimal(TERMINAL_WEEKLY_SUPPLY_RATE);
            return supplyForWeek;
        }
    }
}
