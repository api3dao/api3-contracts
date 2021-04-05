const { deploymentAddresses } = require("@api3-contracts/helpers");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const timelockManagerReversibleOwner =
    deploymentAddresses.timelockManagerReversibleOwner[
      (await getChainId()).toString()
    ];
  const api3TokenAddress =
    deploymentAddresses.api3Token[(await getChainId()).toString()];

  const timelockManagerReversible = await deploy("TimelockManagerReversible", {
    args: [api3TokenAddress, timelockManagerReversibleOwner],
    from: deployer,
  });

  log(`Deployed Timelock Manager at ${timelockManagerReversible.address}`);
};

module.exports.tags = ["deploy-reversible"];
