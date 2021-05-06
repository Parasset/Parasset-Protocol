const hre = require("hardhat");
const { ethers } = require("hardhat");

const {deployUSDT,deployNEST,deployNestQuery,deployNTokenController,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")

const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setLiquidationLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")

const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")

const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances} = require("./normal-scripts.js")

async function main() {
	const accounts = await ethers.getSigners();

	const USDTPRICE = USDT("3");

	const ETHAddress = "0x0000000000000000000000000000000000000000";

	USDTContract = await deployUSDT();

	factory = await depolyFactory();

	pool = await deployMortgagePool(factory.address);

	NestQuery = await deployNestQuery();

	NTokenController = await deployNTokenController();

	PriceController = await deployPriceController(NestQuery.address, NTokenController.address);

	insurancePool = await deployInsurancePool(factory.address);

	await approve(USDTContract.address, pool.address, USDT("999999"));

	await setInsurancePool(pool.address, insurancePool.address);

	await setMortgagePool(insurancePool.address, pool.address);

	await createPtoken(factory.address, "USDT");

	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");

	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");

	const USDTPToken = await getPTokenAddress(factory.address, "0");

	await setInfo(pool.address, USDTContract.address, USDTPToken);

	await allow(pool.address, USDTPToken, ETHAddress);

	await setMaxRate(pool.address, ETHAddress, "70");

	await setLiquidationLine(pool.address, ETHAddress, "84");

	await approve(USDTPToken, pool.address, ETH("999999"));

	await setAvg(NestQuery.address,USDTContract.address, USDTPRICE);

	await setPriceController(pool.address,PriceController.address);

	console.log("====coin====");
	await coin(pool.address, ETHAddress, USDTPToken, ETH("10"), "50", "10010000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	console.log("====coin over====");

	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);
	await setAvg(NestQuery.address,USDTContract.address, USDT("4"));
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);

	console.log("====supplement====");
	await supplement(pool.address, ETHAddress, USDTPToken, ETH("2"), "2010000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	console.log("====supplement====");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);

	console.log("====decrease====");
	await decrease(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	console.log("====decrease====");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);

	console.log("====increaseCoinage====");
	await increaseCoinage(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	console.log("====increaseCoinage====");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);

	console.log("====reducedCoinage====");
	await reducedCoinage(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	console.log("====reducedCoinage====");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);
	
	console.log("====approve====");
	await approve(USDTContract.address, insurancePool.address, USDT("999999"));
	await approve(USDTPToken, insurancePool.address, ETH("999999"));
	console.log("====approve====");

	console.log("====subscribeIns====");
	await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	await subscribeIns(insurancePool.address, USDTContract.address, USDT(2), 0);
	await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	console.log("====subscribeIns====");

	console.log("====exchangePTokenToUnderlying====");
	await ERC20Balance(USDTPToken, insurancePool.address);
	await exchangePTokenToUnderlying(insurancePool.address, USDTPToken, ETH("1"));
	await ERC20Balance(USDTPToken, insurancePool.address);
	console.log("====exchangePTokenToUnderlying====");

	console.log("====exchangeUnderlyingToPToken====");
	await ERC20Balance(USDTContract.address, insurancePool.address);
	await ERC20Balance(USDTPToken, accounts[0].address);
	await exchangeUnderlyingToPToken(insurancePool.address, USDTContract.address, USDT("1000"), 0);
	await ERC20Balance(USDTContract.address, insurancePool.address);
	await ERC20Balance(USDTPToken, accounts[0].address);
	console.log("====exchangeUnderlyingToPToken====");


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