module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const timelockManager = await deploy("TimelockManager", {
    args: ["0xE59dF78C418Fbf9faA4b50d874C61823735de074", deployer],
    from: deployer,
  });

  log(`Deployed TimelockManager at ${timelockManager.address}`);
};
