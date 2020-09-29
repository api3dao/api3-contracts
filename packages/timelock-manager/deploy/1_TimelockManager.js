/* global getChainId */
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const api3DaoAddresses = {
    1: 0,
    4: "0x0c26bb185ad09c5a41e8fd127bf7b8c99e81e5dc",
  };

  const api3TokenAddresses = {
    1: 0,
    4: "0x6B3998970db68A9Cb7Ab240017C20D22F08A3cC1",
  };

  const chainId = await getChainId();
  const timelockManager = await deploy("Api3Token", {
    args: [api3TokenAddresses[chainId], api3DaoAddresses[chainId]],
    from: deployer,
  });

  log(`Deployed Timelock Manager at ${timelockManager.address}`);
};
