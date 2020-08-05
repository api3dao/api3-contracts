const bre = require("@nomiclabs/buidler");

async function main() {
  const Api3Token = await ethers.getContractFactory("Api3Token");
  const api3Token = await Api3Token.deploy();

  const InflationSchedule = await ethers.getContractFactory("InflationSchedule");
  const inflationSchedule = await InflationSchedule.deploy();

  const Api3Pool = await ethers.getContractFactory("Api3Pool");
  const api3Pool = await Api3Pool.deploy(api3Token.address, inflationSchedule.address);

  await api3Pool.deployed();

  await api3Token.updateMinterStatus(api3Pool.address, true);
  await api3Token.transfer(api3Pool.address, 1);

  console.log(api3Pool.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
