module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const payer = await deploy("Payer", {
    args: [
      "0x5846711b4b7485392c1f0feaec203aa889071717",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    ],
    from: deployer,
  });

  log(`Deployed Payer at ${payer.address}`);
};
