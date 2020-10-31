const { deploymentAddresses } = require("@api3-contracts/helpers");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const api3DaoVaultAddress =
    deploymentAddresses.api3DaoVault[(await getChainId()).toString()];

  const api3Token = await deploy("Api3Token", {
    args: [api3DaoVaultAddress, deployer],
    from: deployer,
  });

  log(`Deployed API3 token at ${api3Token.address}`);
};

module.exports.tags = ["deploy"];
