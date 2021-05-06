const hre = require("hardhat");
const { ethers } = require("hardhat");

const {deployUSDT,deployNEST,deployNestQuery,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")

const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setLiquidationLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")

const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")

const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getInsurancePool,getTotalSupply,getBalances} = require("./normal-scripts.js")
const contractsDeployed_ropsten = require("./contracts_ropsten.js");


async function main() {
	const accounts = await ethers.getSigners();

	const ETHAddress = "0x0000000000000000000000000000000000000000";
	USDTContract = await await ethers.getContractAt("USDT", contractsDeployed_ropsten.USDTContract);
	NESTContract = await ethers.getContractAt("USDT", contractsDeployed_ropsten.NestContract);
	factory = await await ethers.getContractAt("PTokenFactory", contractsDeployed_ropsten.PTokenFactory);
	PriceController = await await ethers.getContractAt("PriceController", contractsDeployed_ropsten.PriceController);

	pool = await deployMortgagePool(factory.address);

	insurancePool = await deployInsurancePool(factory.address);

	await setInsurancePool(pool.address, insurancePool.address);

	await setMortgagePool(insurancePool.address, pool.address);

	await getInsurancePool(pool.address);

	const USDTPToken = await getPTokenAddress(factory.address, "0");

	const ETHPToken = await await getPTokenAddress(factory.address, "1");;

	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");

	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");

	await allow(pool.address, USDTPToken, ETHAddress);

	await allow(pool.address, USDTPToken, NESTContract.address);
	await allow(pool.address, ETHPToken, NESTContract.address);

	await setMaxRate(pool.address, ETHAddress, "70");

	await setMaxRate(pool.address, NESTContract.address, "40");

	await setLiquidationLine(pool.address, ETHAddress, "84");

	await setLiquidationLine(pool.address, NESTContract.address, "75");

	await setPriceController(pool.address,PriceController.address);

	await setInfo(pool.address, USDTContract.address, USDTPToken);
	await setInfo(pool.address, ETHAddress, ETHPToken);

	console.log("network:ropsten");
	console.log(`MortgagePool:${pool.address}`);
	console.log(`InsurancePool:${insurancePool.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});