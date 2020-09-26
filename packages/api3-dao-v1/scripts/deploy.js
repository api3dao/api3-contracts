const { deployer } = require("@api3-contracts/helpers");

async function main() {
  const accounts = await ethers.getSigners();
  const timelockManager = await deployer.deployTimelockManager(
    accounts[0],
    accounts[0]._address,
    "0x3426d85D140c85C5ebB6E4D343C5be8e4E001869"
  );
  console.log(timelockManager.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
