/* global ethers */

async function deployToken(deployer, destination) {
  const api3TokenFactory = await ethers.getContractFactory(
    "Api3Token",
    deployer
  );
  const api3Token = await api3TokenFactory.deploy(destination);
  return api3Token;
}

module.exports = {
  deployAll: async function (
    deployer,
    epochPeriodInSeconds = 60 * 24 * 7, // week-long epochs
    firstEpochStartTimestamp = Math.floor(Date.now() / 1000), // first epoch starts right away
    startEpoch = 100 // inflationary rewards start 100 epoch later
  ) {
    const api3Token = await deployToken(deployer);

    const Api3Pool = await ethers.getContractFactory("TransferUtils", deployer);
    const api3Pool = await Api3Pool.deploy(
      api3Token.address,
      epochPeriodInSeconds,
      firstEpochStartTimestamp
    );

    const InflationManager = await ethers.getContractFactory(
      "InflationManager",
      deployer
    );
    const inflationManager = await InflationManager.deploy(
      api3Token.address,
      api3Pool.address,
      startEpoch
    );

    return { api3Token, api3Pool, inflationManager };
  },
  deployToken: deployToken,
};
