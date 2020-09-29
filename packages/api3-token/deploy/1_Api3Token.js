/* global getChainId */
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const api3DaoAddresses = {
    1: 0,
    4: "0x0c26bb185ad09c5a41e8fd127bf7b8c99e81e5dc",
  };

  const api3Token = await deploy("Api3Token", {
    args: [api3DaoAddresses[await getChainId()], deployer],
    from: deployer,
  });

  log(`Deployed API3 token at ${api3Token.address}`);
};
