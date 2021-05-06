const hre = require("hardhat");
const { ethers } = require("hardhat");


const {deployUSDT,deployNEST,deployNestQuery,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")

const {setInsurancePool,setMortgagePool,setPrice,setMaxRate,setLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")

const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")

const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool} = require("./normal-scripts.js")
const contractsDeployed_ropsten = require("./contracts_ropsten.js");

async function main() {
	const accounts = await ethers.getSigners();

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


	await approve(NESTContract.address, MortgagePool.address, ETH("999999"));

	await coin(MortgagePool.address, NESTContract.address, PETH.address, ETH("4"), "50", "10000000000000000");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});