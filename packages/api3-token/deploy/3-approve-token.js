const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:1248");
const { deploymentAddresses } = require("@api3-contracts/helpers");

module.exports = async ({ deployments }) => {
  const { log } = deployments;
  const Api3Token = await deployments.get("Api3Token");

  const api3Token = new ethers.Contract(
    Api3Token.address,
    Api3Token.abi,
    await provider.getSigner()
  );

  const amountToApprove = ethers.utils.parseEther((55e6).toString());
  await api3Token.approve(
    deploymentAddresses.timelockManager[await getChainId()],
    ethers.utils.parseEther((55e6).toString())
  );

  log(
    `Approved ${amountToApprove.toString()} API3 tokens to ${
      deploymentAddresses.timelockManager[await getChainId()]
    }`
  );
};

module.exports.tags = ["approve-token"];
