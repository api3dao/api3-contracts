/* global ethers */
const { deployer } = require("@api3-contracts/helpers");

async function main() {
  const accounts = await ethers.getSigners();
  const api3Token = await deployer.deployToken(
    accounts[0],
    accounts[0]._address
  );
  console.log(api3Token.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
