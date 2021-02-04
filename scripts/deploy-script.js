const hre = require("hardhat");
const ethers = require('ethers');

async function main() {
  // 部署抵押池合约
  const MortgagePool = await hre.ethers.getContractFactory("MortgagePool");
  const pool = await MortgagePool.deploy();
  await pool.deployed();
  console.log("pool address:", pool.address);
  
  // 查询参数
  const r0 = await pool.getR0();
  console.log("r0=", r0.toString());

  const oneYear = await pool.getOneYear();
  console.log("oneYear=", oneYear.toString());

  const k = await pool.getK();
  console.log("k=", k.toString());

  const liquidationLine = await pool.getLiquidationLine();
  console.log("liquidationLine=", liquidationLine.toString());

  const decreaseLine = await pool.getDecreaseLine();
  console.log("decreaseLine=", decreaseLine.toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });