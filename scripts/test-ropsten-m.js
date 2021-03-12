const hre = require("hardhat");
const { ethers } = require("hardhat");

// 部署
const {deployUSDT,deployNEST,deployNestQuery,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")
// 设置
const {setInsurancePool,setMortgagePool,setPrice,setMaxRate,setLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")
// 交互
const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")
// 查询
const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool} = require("./normal-scripts.js")
const contractsDeployed_ropsten = require("./contracts_ropsten.js");

// 部署脚本，只需执行一次
async function main() {
	const accounts = await ethers.getSigners();
	// 准备工作
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	USDTContract = await await ethers.getContractAt("USDT", contractsDeployed_ropsten.USDTContract);
	NESTContract = await ethers.getContractAt("USDT", contractsDeployed_ropsten.NestContract);
	factory = await await ethers.getContractAt("PTokenFactory", contractsDeployed_ropsten.PTokenFactory);
	PriceController = await await ethers.getContractAt("PriceController", contractsDeployed_ropsten.PriceController);
	MortgagePool = await ethers.getContractAt("MortgagePool", contractsDeployed_ropsten.MortgagePool);
	PETH = await ethers.getContractAt("PToken", contractsDeployed_ropsten.PETH);
	PUSDT = await ethers.getContractAt("PToken", contractsDeployed_ropsten.PUSDT);

	// await setInfo(MortgagePool.address, USDTContract.address, PUSDT.address);
	// await setInfo(MortgagePool.address, ETHAddress, PETH.address);

	// // 授权NEST给MortgagePool
	// await approve(NESTContract.address, MortgagePool.address, ETH("999999"));
	// // 铸币
	// await coin(MortgagePool.address, NESTContract.address, PETH.address, ETH("4"), "50", "20000000000000000");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});