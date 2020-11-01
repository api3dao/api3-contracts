const { deploymentAddresses } = require("@api3-contracts/helpers");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const api3DaoVaultAddress =
    deploymentAddresses.api3DaoVault[(await getChainId()).toString()];
  const api3TokenAddress = deploymentAddresses.api3Token[(await getChainId()).toString()];

  const timelockManager = await deploy("TimelockManager", {
    args: [api3TokenAddress, api3DaoVaultAddress],
    from: deployer,
  });

  log(`Deployed Timelock Manager at ${timelockManager.address}`);
};

module.exports.tags = ["deploy"];
