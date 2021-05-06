const hre = require("hardhat");
const { ethers } = require("hardhat");


const {deployUSDT,deployNEST,deployNestQuery,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")

const {setInsurancePool,setMortgagePool,setPrice,setMaxRate,setLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")

const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")

const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool,
	getGovernance, getR0, getOneYear, getMaxRate, getLine, getPriceController, getUnderlyingToPToken, getPTokenToUnderlying} = require("./normal-scripts.js")
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

	await getGovernance(MortgagePool.address);
	await getInsurancePool(MortgagePool.address);
	await getR0(MortgagePool.address);
	await getOneYear(MortgagePool.address);
	await getMaxRate(MortgagePool.address, NESTContract.address);
	await getMaxRate(MortgagePool.address, ETHAddress);
	await getLine(MortgagePool.address, NESTContract.address);
	await getLine(MortgagePool.address, ETHAddress);
	await getPriceController(MortgagePool.address);
	
	await getUnderlyingToPToken(MortgagePool.address, ETHAddress);
	await getUnderlyingToPToken(MortgagePool.address, USDTContract.address);
	await getPTokenToUnderlying(MortgagePool.address, PETH.address);
	await getPTokenToUnderlying(MortgagePool.address, PUSDT.address);
}	

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});