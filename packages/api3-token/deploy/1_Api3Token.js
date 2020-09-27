module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const api3Token = await deploy('Api3Token', {
    args: [deployer, deployer],
    from: deployer,
  });

  log(`Deployed API3 token at ${api3Token.address}`);
};
