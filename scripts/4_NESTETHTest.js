const hre = require("hardhat");
const { ethers } = require("hardhat");

const {deployUSDT,deployNEST,deployNestQuery,deployNTokenController,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")

const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setLiquidationLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")

const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")

const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool,getLedgerArrayNum,getLedgerAddress} = require("./normal-scripts.js")

async function main() {
	const accounts = await ethers.getSigners();

	const ETHAddress = "0x0000000000000000000000000000000000000000";

	NESTContract = await deployNEST();

	factory = await depolyFactory();

	pool = await deployMortgagePool(factory.address);

	NestQuery = await deployNestQuery();

	NTokenController = await deployNTokenController();

	PriceController = await deployPriceController(NestQuery.address, NTokenController.address);

	insurancePool = await deployInsurancePool(factory.address);

	await approve(NESTContract.address, pool.address, ETH("999999"));

	await setInsurancePool(pool.address, insurancePool.address);

	await setMortgagePool(insurancePool.address, pool.address);

	await createPtoken(factory.address, "ETH");

	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");

	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");

	const ETHPToken = await getPTokenAddress(factory.address, "0");

	await setInfo(pool.address, ETHAddress, ETHPToken);

	await allow(pool.address, ETHPToken, NESTContract.address);

	await setMaxRate(pool.address, NESTContract.address, "70");

	await setLiquidationLine(pool.address, NESTContract.address, "75");

	await approve(ETHPToken, pool.address, ETH("999999"));

	await setAvg(NestQuery.address,NESTContract.address, ETH("3"));

	await setPriceController(pool.address,PriceController.address);


	await coin(pool.address, NESTContract.address, ETHPToken, ETH("12"), "50", "10000000000000000");
	const ledger = await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);


	await supplement(pool.address, NESTContract.address, ETHPToken, ETH("2"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);
	await ERC20Balance(ETHPToken, insurancePool.address);

	await decrease(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);
	await ERC20Balance(ETHPToken, insurancePool.address);

	await increaseCoinage(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);

	await reducedCoinage(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);

	await ERC20Balance(ETHPToken, insurancePool.address);

	await approve(ETHPToken, insurancePool.address, ETH("999999"));
	await getBalances(insurancePool.address, ETHAddress, accounts[0].address);
	await getTotalSupply(insurancePool.address,ETHAddress);
	await subscribeIns(insurancePool.address, ETHAddress, ETH(1), ETH(1));
	await getTotalSupply(insurancePool.address,ETHAddress);
	await getBalances(insurancePool.address, ETHAddress, accounts[0].address);
	await subscribeIns(insurancePool.address, ETHAddress, "100000000000000000", "100000000000000000");
	await getTotalSupply(insurancePool.address,ETHAddress);
	await getBalances(insurancePool.address, ETHAddress, accounts[0].address);

	await ERC20Balance(ETHPToken, insurancePool.address);
	await exchangePTokenToUnderlying(insurancePool.address, ETHPToken, ETH("1"));
	await ERC20Balance(ETHPToken, insurancePool.address);

	await exchangeUnderlyingToPToken(insurancePool.address, ETHAddress, ETH("1"), ETH("1"));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});