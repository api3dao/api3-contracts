const { api3DaoVaultAddresses } = require("@api3-contracts/helpers");
const { api3TokenAddresses } = require("@api3-contracts/helpers");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const api3DaoVaultAddress =
    api3DaoVaultAddresses[(await getChainId()).toString()];
  const api3TokenAddress = api3TokenAddresses[(await getChainId()).toString()];

  const timelockManager = await deploy("TimelockManager", {
    args: [api3TokenAddress, api3DaoVaultAddress],
    from: deployer,
  });

  log(`Deployed Timelock Manager at ${timelockManager.address}`);
};

module.exports.tags = ["deploy"];
