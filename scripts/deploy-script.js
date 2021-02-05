const hre = require("hardhat");
const { BigNumber } = require('ethers');
const { ethers } = require("hardhat");

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

  // 创建p资产和保险池
  await pool.create("0x0000000000000000000000000000000000000000", "ETH");
  const tokensAdd = await pool.getPTokenAddressAndInsAddress("0x0000000000000000000000000000000000000000");
  const pTokenAddress = tokensAdd[0];
  const insAddress = tokensAdd[1];
  console.log("pTokenAddress=", pTokenAddress);
  console.log("insAddress=", insAddress);
  // 查询p资产和保险池信息
  const pToken = await ethers.getContractAt("IERC20", tokensAdd[0]);
  const pToken_name = await pToken.name();
  console.log("pToken name=", pToken_name);
  const pToken_d = await pToken.decimals();
  console.log("pToken decimals=", pToken_d.toString());
  const insToken = await ethers.getContractAt("IERC20", tokensAdd[1]);
  const insToken_name = await insToken.name();
  console.log("insToken name=", insToken_name);
  const insToken_d = await insToken.decimals();
  console.log("insToken decimals=", insToken_d.toString());

  // 允许ETH抵押
  const ethAllow = await pool.setMortgageAllow(pTokenAddress, "0x0000000000000000000000000000000000000000", "1");

  // 铸币
  const coin = await pool.coin("0x0000000000000000000000000000000000000000", 
                        pTokenAddress, 
                        "1000000000000000000", 
                        "70", 
                        { value: "1010000000000000000" });
  // 查询债仓信息
  const ledger = await pool.getLedger(pTokenAddress, "0x0000000000000000000000000000000000000000");
  console.log("ledger =", ledger[0].toString(), ledger[1].toString(), ledger[2].toString());

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });