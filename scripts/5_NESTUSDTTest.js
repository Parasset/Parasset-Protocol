const hre = require("hardhat");
const { ethers } = require("hardhat");

const {deployUSDT,deployNEST,deployNestQuery,deployNTokenController,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")

const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setLiquidationLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow,setNTokenMapping} = require("./normal-scripts.js")

const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")

const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool} = require("./normal-scripts.js")

async function main() {
	const accounts = await ethers.getSigners();

	USDTContract = await deployUSDT();
	NESTContract = await deployNEST();
	factory = await depolyFactory();
	NestQuery = await deployNestQuery();

	NTokenController = await deployNTokenController();

	PriceController = await deployPriceController(NestQuery.address, NTokenController.address);
	pool = await deployMortgagePool(factory.address);
	insurancePool = await deployInsurancePool(factory.address);
	await approve(USDTContract.address, pool.address, USDT("999999"));
	await approve(NESTContract.address, pool.address, ETH("999999"));
	await setInsurancePool(pool.address, insurancePool.address);
	await setMortgagePool(insurancePool.address, pool.address);
	await createPtoken(factory.address, "USDT");
	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");
	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");
	const USDTPToken = await getPTokenAddress(factory.address, "0");
	await setInfo(pool.address, USDTContract.address, USDTPToken);
	await allow(pool.address, USDTPToken, NESTContract.address);
	await setMaxRate(pool.address, NESTContract.address, "40");
	await setLiquidationLine(pool.address, NESTContract.address, "75");
	await setAvg(NestQuery.address,NESTContract.address, ETH("2"));
	await setAvg(NestQuery.address,USDTContract.address, USDT("4"));
	await setPriceController(pool.address,PriceController.address);
	await approve(USDTPToken, pool.address, ETH("999999"));
	await setNTokenMapping(NTokenController.address, NestQuery.address, USDTContract.address, NESTContract.address);


	await coin(pool.address, NESTContract.address, USDTPToken, ETH("4"), "30", "10000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, NESTContract.address, accounts[0].address);

	await supplement(pool.address, NESTContract.address, USDTPToken, ETH("2"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, NESTContract.address, accounts[0].address);
	await ERC20Balance(USDTPToken, insurancePool.address);

	await decrease(pool.address, NESTContract.address, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, NESTContract.address, accounts[0].address);
	await ERC20Balance(USDTPToken, insurancePool.address);

	await increaseCoinage(pool.address, NESTContract.address, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, NESTContract.address, accounts[0].address);

	await reducedCoinage(pool.address, NESTContract.address, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, NESTContract.address, accounts[0].address);

	await ERC20Balance(USDTPToken, insurancePool.address);


	await approve(USDTContract.address, insurancePool.address, USDT("999999"));
	await approve(USDTPToken, insurancePool.address, ETH("999999"));
	await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	await subscribeIns(insurancePool.address, USDTContract.address, USDT(2), 0);
	await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);

	await ERC20Balance(USDTPToken, insurancePool.address);
	await exchangePTokenToUnderlying(insurancePool.address, USDTPToken, ETH("1"));
	await ERC20Balance(USDTPToken, insurancePool.address);

	await ERC20Balance(USDTContract.address, insurancePool.address);
	await exchangeUnderlyingToPToken(insurancePool.address, USDTContract.address, USDT("1"), 0);
	await ERC20Balance(USDTContract.address, insurancePool.address);

	// await ERC20Balance(USDTContract.address, insurancePool.address);
	// await ERC20Balance(USDTContract.address, accounts[0].address);
	// await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	// await ERC20Balance(USDTPToken, insurancePool.address);
	// await redemptionIns(insurancePool.address, USDTContract.address, ETH("2"));
	// await ERC20Balance(USDTContract.address, insurancePool.address);
	// await ERC20Balance(USDTContract.address, accounts[0].address);
	// await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	// await ERC20Balance(USDTPToken, insurancePool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});