const hre = require("hardhat");
const { ethers } = require("hardhat");


const {deployUSDT,deployNEST,deployNestQuery,deployNTokenController,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")

const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setLiquidationLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow,setNTokenMapping} = require("./normal-scripts.js")

const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")

const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool} = require("./normal-scripts.js")


async function main() {
	const accounts = await ethers.getSigners();

	const ETHAddress = "0x0000000000000000000000000000000000000000";

	USDTContract = await deployUSDT();

	NESTContract = await deployNEST();

	factory = await depolyFactory();

	pool = await deployMortgagePool(factory.address);

	NestQuery = await deployNestQuery();

	NTokenController = await deployNTokenController();

	PriceController = await deployPriceController(NestQuery.address, NTokenController.address);

	insurancePool = await deployInsurancePool(factory.address);

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

	const ETHPToken = await await getPTokenAddress(factory.address, "1");;

	await allow(pool.address, USDTPToken, ETHAddress);

	await allow(pool.address, USDTPToken, NESTContract.address);
	await allow(pool.address, ETHPToken, NESTContract.address);

	await setMaxRate(pool.address, ETHAddress, "70");

	await setMaxRate(pool.address, NESTContract.address, "40");

	await setLiquidationLine(pool.address, ETHAddress, "84");

	await setLiquidationLine(pool.address, NESTContract.address, "75");

	await setAvg(NestQuery.address,USDTContract.address, USDT("2"));

	await setAvg(NestQuery.address,NESTContract.address, ETH("3"));

	await setPriceController(pool.address,PriceController.address);

	await setInfo(pool.address, USDTContract.address, USDTPToken);
	await setInfo(pool.address, ETHAddress, ETHPToken);
	await setNTokenMapping(NTokenController.address, NestQuery.address, USDTContract.address, NESTContract.address);

	console.log("network:ropsten");
	console.log(`NestContract:${NESTContract.address}`);
	console.log(`USDTContract:${USDTContract.address}`);
	console.log(`PTokenFactory:${factory.address}`);
	console.log(`MortgagePool:${pool.address}`);
	console.log(`InsurancePool:${insurancePool.address}`);
	console.log(`PriceController:${PriceController.address}`);
	console.log(`NTokenController:${NTokenController.address}`);
	console.log(`NestQuery:${NestQuery.address}`);
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