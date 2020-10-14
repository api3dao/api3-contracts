const ethers = require("ethers");
const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
const { deployer } = require("@api3-contracts/helpers");
module.exports = async ({ deployments }) => {
  const { log } = deployments;
  const accounts = await provider.listAccounts();
  const signer = await provider.getSigner();
  let roles = {
    deployer: accounts[0],
    dao: accounts[1],
    owner1: accounts[2],
    owner2: accounts[3],
    randomPerson: accounts[9],
  };
  const currentTimestamp = parseInt(
    (await provider.send("eth_getBlockByNumber", ["latest", false])).timestamp
  );
  const timelocks = [
    {
      owner: roles.owner1,
      amount: ethers.utils.parseEther((2e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 40000),
      cliff: 0,
      reversible: true,
    },
    {
      owner: roles.owner2,
      amount: ethers.utils.parseEther((8e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 20000),
      cliff: 0,
      reversible: false,
    },
    {
      owner: roles.owner1,
      amount: ethers.utils.parseEther((5e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 10000),
      cliff: ethers.BigNumber.from(currentTimestamp + 2500),
      reversible: false,
    },
    {
      owner: roles.owner2,
      amount: ethers.utils.parseEther((3e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 30000),
      cliff: ethers.BigNumber.from(currentTimestamp + 10000),
      reversible: true,
    },
  ];
  let api3Token = await deployer.deployToken(signer, roles.deployer);
  log(`Deployed Token ${api3Token.address}`);
  let timelockManager = await deployer.deployTimelockManager(
    signer,
    roles.deployer,
    api3Token.address
  );
  log(`Deployed Timelock ${timelockManager.address}`);
  //api3Pool = await deployer.deployPool(signer, api3Token.address);
  await api3Token.connect(signer).approve(
    timelockManager.address,
    timelocks.reduce(
      (acc, timelock) => acc.add(timelock.amount),
      ethers.BigNumber.from(0)
    )
  );
  // Deploy timelocks individually
  log(`DAO: ${roles.deployer}\n`);
  log(`TIMELOCK OWNER: ${await timelockManager.owner()}`);
  for (const timelock of timelocks) {
    let tx = await timelockManager
      .connect(signer)
      .transferAndLock(
        roles.deployer,
        timelock.owner,
        timelock.amount,
        timelock.releaseStart,
        timelock.releaseEnd,
        timelock.cliff,
        timelock.reversible
      );
    log(`Submitted timelock: ${timelock.owner}, ${timelock.amount}\n
        txn: ${tx.hash}
    `);
  }
};
