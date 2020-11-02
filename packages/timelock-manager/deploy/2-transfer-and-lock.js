const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:1248");
const { deploymentAddresses } = require("@api3-contracts/helpers");
const transferAndLockInput = require("./transferAndLockInput.json");

module.exports = async ({ deployments }) => {
  const { log } = deployments;

  const TimelockManager = await deployments.get("TimelockManager");
  const timelockManager = new ethers.Contract(
    TimelockManager.address,
    TimelockManager.abi,
    await provider.getSigner()
  );

  const input = transferAndLockInput[await getChainId()];

  await timelockManager.transferAndLockMultiple(
    deploymentAddresses.api3DaoVault[await getChainId()],
    input.recipients,
    input.amounts,
    input.releaseStarts,
    input.releaseEnds,
    { gasLimit: 6000000 }
  );

  log(
    `Transferred and locked at ${
      timelockManager.address
    } with parameters ${JSON.stringify(input)}`
  );
};

module.exports.tags = ["transfer-and-lock"];
