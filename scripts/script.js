/* global ethers */

async function main() {
  const Api3Token = await ethers.getContractFactory("Api3Token");
  const api3Token = await Api3Token.deploy();

  const Api3Pool = await ethers.getContractFactory("Api3Pool");
  const api3Pool = await Api3Pool.deploy(
    api3Token.address,
    60 * 24 * 7,
    Math.floor(Date.now() / 1000)
  );

  const InflationManager = await ethers.getContractFactory(
    "InflationManager"
  );
  const inflationManager = await InflationManager.deploy(
    api3Token.address,
    api3Pool.address,
    100
  );

  console.log(inflationManager.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
