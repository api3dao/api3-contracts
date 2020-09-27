async function deployToken(deployer, contractOwner, mintDestination) {
  const api3TokenFactory = await ethers.getContractFactory(
    "Api3Token",
    deployer
  );
  const api3Token = await api3TokenFactory.deploy(
    contractOwner,
    mintDestination
  );
  return api3Token;
}

async function deployTimelockManager(deployer, ownerAddress, api3TokenAddress) {
  const timelockManagerFactory = await ethers.getContractFactory(
    "TimelockManager",
    deployer
  );
  const timelockManager = await timelockManagerFactory.deploy(
    api3TokenAddress,
    ownerAddress
  );
  return timelockManager;
}

async function deployPool(
  deployer,
  epochPeriodInSeconds,
  firstEpochStartTimestamp,
  api3Token
) {
  const api3PoolFactory = await ethers.getContractFactory("Api3Pool", deployer);
  const api3Pool = await api3PoolFactory.deploy(
    api3Token.address,
    epochPeriodInSeconds,
    firstEpochStartTimestamp
  );
  return api3Pool;
}

async function deployInflationManager(
  deployer,
  startEpoch,
  api3Token,
  api3Pool
) {
  const inflationManagerFactory = await ethers.getContractFactory(
    "InflationManager",
    deployer
  );
  const inflationManager = await inflationManagerFactory.deploy(
    api3Token.address,
    api3Pool.address,
    startEpoch
  );
  return inflationManager;
}

module.exports = {
  deployAll: async function (
    deployer,
    ownerAddress,
    epochPeriodInSeconds = 60 * 24 * 7, // week-long epochs
    firstEpochStartTimestamp = Math.floor(Date.now() / 1000), // first epoch starts right away
    startEpoch = 100 // inflationary rewards start 100 epoch later
  ) {
    const api3Token = await deployToken(deployer, ownerAddress);
    const timelockManager = await deployTimelockManager(
      deployer,
      ownerAddress,
      api3Token.address
    );
    const api3Pool = await deployPool(
      deployer,
      epochPeriodInSeconds,
      firstEpochStartTimestamp,
      api3Token
    );
    const inflationManager = await deployInflationManager(
      deployer,
      startEpoch,
      api3Token,
      api3Pool
    );
    return { api3Token, timelockManager, api3Pool, inflationManager };
  },
  deployPoolAndToken: async function (
    deployer,
    ownerAddress,
    epochPeriodInSeconds = 60 * 24 * 7, // week-long epochs
    firstEpochStartTimestamp = Math.floor(Date.now() / 1000), // first epoch starts right away
    startEpoch = 100 // inflationary rewards start 100 epoch later
  ) {
    const api3Token = await deployToken(deployer, ownerAddress);
    const api3Pool = await deployPool(
      deployer,
      epochPeriodInSeconds,
      firstEpochStartTimestamp,
      api3Token
    );
    const inflationManager = await deployInflationManager(
      deployer,
      startEpoch,
      api3Token,
      api3Pool
    );
    return { api3Token, api3Pool, inflationManager };
  },
  deployToken: deployToken,
  deployTimelockManager: deployTimelockManager,
};
