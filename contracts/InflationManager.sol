//SPDX-License-Identifier: Unlicense
pragma solidity >=0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IInflationManager.sol";
import "./interfaces/IApi3Token.sol";
import "./interfaces/IApi3Pool.sol";
import "./interfaces/IEpochUtils.sol";


contract InflationManager is IInflationManager {
    using SafeMath for uint256;

    ///  Initial annual inflation rate: 0.75
    ///  Initial weekly inflation rate: 0.75 / 52
    ///  Initial token supply (in Wei): 1e8 * 1e18 = 1e26
    ///  Initial weekly inflationary supply: 1e26 * 0.75 / 52 = 1442307692307692307692307
    uint256 public constant INITIAL_WEEKLY_SUPPLY = 1442307692307692307692307;

    /// Weekly supply decay rate: 0.00965
    /// Weekly supply update coefficient: 1e18 * (1 - 0.00965) = 990350000000000000
    uint256 public constant WEEKLY_SUPPLY_UPDATE_COEFF = 990350000000000000;

    /// Terminal annual inflation rate: 0.025
    /// Terminal weekly inflation rate: 0.025 / 52
    /// Terminal weekly inflationary supply rate: 1e18 * 0.025 / 52 = 480769230769230
    uint256 public constant TERMINAL_WEEKLY_SUPPLY_RATE = 480769230769230;

    // 5 years * 52 weeks/year = 260
    uint256 public constant DECAY_PERIOD = 260;

    IApi3Token public immutable api3Token;
    IApi3Pool public immutable api3Pool;
    IEpochUtils public immutable epochUtils;
    uint256[] public weeklySupplyCoeffs;
    uint256 public immutable startEpoch;
    uint256 public immutable terminalEpoch;
    mapping(uint256 => bool) private addedInflationaryRewardsForEpoch;

    constructor(
        address api3TokenAddress,
        address api3PoolAddress,
        uint256 _startEpoch
        )
        public
        {
            api3Token = IApi3Token(api3TokenAddress);
            api3Pool = IApi3Pool(api3PoolAddress);
            epochUtils = IEpochUtils(api3PoolAddress);
            startEpoch = _startEpoch;
            terminalEpoch = _startEpoch + DECAY_PERIOD;
            weeklySupplyCoeffs = new uint256[](DECAY_PERIOD);
            uint supplyCoeff = 1e18;
            weeklySupplyCoeffs[0] = supplyCoeff;
            // Costs ~6.2e6 gas for a 5 year decay period
            for (uint256 indWeek = 1; indWeek < DECAY_PERIOD; indWeek++)
            {
                supplyCoeff = supplyCoeff
                    .mul(WEEKLY_SUPPLY_UPDATE_COEFF)
                    .div(1e18);
                weeklySupplyCoeffs[indWeek] = supplyCoeff;
            }
        }
    
    function mintInflationaryRewardsToPool()
        external
        override
      {
          uint256 currentEpochNumber = epochUtils.getCurrentEpochNumber();
          require(
              !addedInflationaryRewardsForEpoch[currentEpochNumber],
              "Inflationary rewards for this epoch has already been added"
              );
          uint256 amount = getDeltaTokenSupply(currentEpochNumber);
          api3Token.mint(address(this), amount);
          api3Token.approve(address(api3Pool), amount);
          api3Pool.addVestedRewards(address(this), amount);
          addedInflationaryRewardsForEpoch[currentEpochNumber] = true;
      }

    function getDeltaTokenSupply(uint256 indEpoch)
        public
        view
        override
        returns(uint256 deltaTokenSupply)
    {
        if (indEpoch < startEpoch)
        {
            return 0;
        }
        else if (indEpoch <= terminalEpoch)
        {
            uint256 indWeek = indEpoch - startEpoch;
            return weeklySupplyCoeffs[indWeek]
                .mul(INITIAL_WEEKLY_SUPPLY)
                .div(1e18);
        }
        else
        {
            return api3Token.totalSupply()
                .mul(TERMINAL_WEEKLY_SUPPLY_RATE)
                .div(1e18);
        }
    }
}
