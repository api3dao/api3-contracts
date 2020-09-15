/* global ethers */

async function main() {
  const Api3Token = await ethers.getContractFactory("Api3Token");
  const api3Token = await Api3Token.deploy();
  console.log(api3Token.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
