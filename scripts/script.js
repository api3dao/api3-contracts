/* global ethers */

async function main() {
  const Api3Token = await ethers.getContractFactory("Api3Token");
  const api3Token = await Api3Token.deploy();

  const InflationSchedule = await ethers.getContractFactory(
    "InflationSchedule"
  );
  const inflationSchedule = await InflationSchedule.deploy(
    api3Token.address,
    1
  );

  const Api3Pool = await ethers.getContractFactory("Api3Pool");
  const api3Pool = await Api3Pool.deploy(
    api3Token.address,
    inflationSchedule.address,
    60 * 24 * 7
  );

  await api3Pool.deployed();
  await api3Token.updateMinterStatus(api3Pool.address, true);

  console.log(api3Pool.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
