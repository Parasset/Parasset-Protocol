const hre = require("hardhat");
const { ethers } = require("hardhat");
const {USDT,ETH,deployUSDT,deployNEST,deployNestQuery,deployInsurancePool,setInsurancePool,setMortgagePool,
	setPrice,setMaxRate,setQuaryAddress,
	deployMortgagePool,approve,create,
	getTokenInfo,allow,coin,getLedger,supplement,
	getFee,ERC20Balance,redemption,decrease,
	exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js");

async function main() {
	const accounts = await ethers.getSigners();
	// 准备工作
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	USDTContract = await deployUSDT();
	pool = await deployMortgagePool();
	NestQuery = await deployNestQuery();
	insurancePool = await deployInsurancePool();
	await approve(USDTContract.address, pool.address, USDT("999999"));
	await setInsurancePool(pool.address, insurancePool.address);
	await setMortgagePool(insurancePool.address, pool.address);
	await create(pool.address, USDTContract.address, "USDT");
	const tokens = await getTokenInfo(pool.address, insurancePool.address, USDTContract.address);
	const USDTPToken = tokens[0];
	const USDTShare = tokens[1];
	await allow(pool.address, USDTPToken, ETHAddress);
	await setMaxRate(pool.address, ETHAddress, "70");
	await approve(USDTPToken, pool.address, ETH("999999"));
	await setPrice(NestQuery.address,ETHAddress, ETH("1"));
	await setPrice(NestQuery.address,USDTContract.address, USDT("1"));
	await setQuaryAddress(pool.address,NestQuery.address);

	// 铸币
	await coin(pool.address, ETHAddress, USDTPToken, ETH("4"), "70", "4010000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, ETHAddress);
	// 增加抵押
	await supplement(pool.address, ETHAddress, USDTPToken, ETH("2"), "2010000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);
	// 减少抵押
	await decrease(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);
	// 赎回
	await redemption(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);

	// 认购保险
	await approve(USDTContract.address, insurancePool.address, USDT("999999"));
	await approve(USDTPToken, insurancePool.address, ETH("999999"));
	await ERC20Balance(USDTShare, accounts[0].address);
	await subscribeIns(insurancePool.address, USDTContract.address, USDT(2));
	await ERC20Balance(USDTShare, accounts[0].address);
	// 兑换
	await ERC20Balance(USDTPToken, insurancePool.address);
	await exchangePTokenToUnderlying(insurancePool.address, USDTPToken, ETH("1"));
	await ERC20Balance(USDTPToken, insurancePool.address);

	await ERC20Balance(USDTContract.address, insurancePool.address);
	await exchangeUnderlyingToPToken(insurancePool.address, USDTContract.address, USDT("1"));
	await ERC20Balance(USDTContract.address, insurancePool.address);

	// 赎回保险
	await approve(USDTShare, insurancePool.address, ETH("999999"));
	await ERC20Balance(USDTContract.address, insurancePool.address);
	await ERC20Balance(USDTContract.address, accounts[0].address);
	await ERC20Balance(USDTShare, accounts[0].address);
	await ERC20Balance(USDTPToken, insurancePool.address);
	await redemptionIns(insurancePool.address, USDTContract.address, ETH("2"));
	await ERC20Balance(USDTContract.address, insurancePool.address);
	await ERC20Balance(USDTContract.address, accounts[0].address);
	await ERC20Balance(USDTShare, accounts[0].address);
	await ERC20Balance(USDTPToken, insurancePool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});