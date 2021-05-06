const hre = require("hardhat");
const { ethers } = require("hardhat");


const {deployUSDT,deployNEST,deployNestQuery,deployNTokenController,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")

const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setLiquidationLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow,setNTokenMapping} = require("./normal-scripts.js")

const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")

const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool} = require("./normal-scripts.js")

async function main() {
	const accounts = await ethers.getSigners();

	const ETHAddress = "0x0000000000000000000000000000000000000000";
	const NTokenControllerAdd = "0xc4f1690eCe0145ed544f0aee0E2Fa886DFD66B62";
	const USDTContractAdd = "0xdac17f958d2ee523a2206206994597c13d831ec7";
	const NESTContractAdd = "0x04abEdA201850aC0124161F037Efd70c74ddC74C";
	const NestQueryAdd = "0xB5D2890c061c321A5B6A4a4254bb1522425BAF0A";

	factory = await depolyFactory();

	pool = await deployMortgagePool(factory.address);

	PriceController = await deployPriceController(NestQueryAdd, NTokenControllerAdd);

	insurancePool = await deployInsurancePool(factory.address);


	// factory = await ethers.getContractAt("PTokenFactory", "0x978f0038A69a0ecA925df4510e0085747744dDA8");

	// pool = await ethers.getContractAt("MortgagePool", "0xd49bFB7e44E3E66a59b934D45CcBf9165AcE34b3");

	// PriceController = await ethers.getContractAt("PriceController", "0x2Ce14C65cD3cCC546433E3b1E8c712E102377635");

	// insurancePool = await deployInsurancePool(factory.address);


	await setInsurancePool(pool.address, insurancePool.address);

	await setMortgagePool(insurancePool.address, pool.address);

	await getInsurancePool(pool.address);

	await createPtoken(factory.address, "USDT");

	await createPtoken(factory.address, "ETH");

	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");

	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");

	const USDTPToken = await getPTokenAddress(factory.address, "0");

	const ETHPToken = await getPTokenAddress(factory.address, "1");;

	await allow(pool.address, USDTPToken, ETHAddress);

	await allow(pool.address, USDTPToken, NESTContractAdd);
	await allow(pool.address, ETHPToken, NESTContractAdd);

	await setMaxRate(pool.address, ETHAddress, "70");

	await setMaxRate(pool.address, NESTContractAdd, "40");

	await setLiquidationLine(pool.address, ETHAddress, "84");

	await setLiquidationLine(pool.address, NESTContractAdd, "75");

	await setPriceController(pool.address,PriceController.address);

	await setInfo(pool.address, USDTContractAdd, USDTPToken);
	await setInfo(pool.address, ETHAddress, ETHPToken);

	console.log("network:ropsten");
	console.log(`NestContract:${NESTContractAdd}`);
	console.log(`USDTContract:${USDTContractAdd}`);
	console.log(`PTokenFactory:${factory.address}`);
	console.log(`MortgagePool:${pool.address}`);
	console.log(`InsurancePool:${insurancePool.address}`);
	console.log(`PriceController:${PriceController.address}`);
	console.log(`NTokenController:${NTokenControllerAdd}`);
	console.log(`NestQuery:${NestQueryAdd}`);
	console.log(`PUSDT:${USDTPToken}`);
	console.log(`PETH:${ETHPToken}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});