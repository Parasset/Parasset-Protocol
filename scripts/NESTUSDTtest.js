const hre = require("hardhat");
const { ethers } = require("hardhat");
const {USDT,ETH,deployUSDT,deployNEST,deployNestQuery,setPrice,setMaxRate,setQuaryAddress,
	deployMortgagePool,approve,create,
	getTokenInfo,allow,coin,getLedger,supplement,
	getFee,ERC20Balance,redemption,decrease,
	exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js");

async function main() {
	const accounts = await ethers.getSigners();
	USDTContract = await deployUSDT();
	NESTContract = await deployNEST();
	NestQuery = await deployNestQuery();
	pool = await deployMortgagePool();
	await approve(USDTContract.address, pool.address, USDT("999999"));
	await approve(NESTContract.address, pool.address, ETH("999999"));
	await create(pool.address, USDTContract.address, "USDT");
	const tokens = await getTokenInfo(pool.address, USDTContract.address);
	const USDTPToken = tokens[0];
	const USDTShare = tokens[1];
	await allow(pool.address, USDTPToken, NESTContract.address);
	await setMaxRate(pool.address, NESTContract.address, "70");
	await setPrice(NestQuery.address,NESTContract.address, ETH("1"));
	await setPrice(NestQuery.address,USDTContract.address, USDT("1"));
	await setQuaryAddress(pool.address,NestQuery.address);
	// 铸币
	await coin(pool.address, NESTContract.address, USDTPToken, ETH("4"), "70", "20000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, NESTContract.address);

	await approve(USDTPToken, pool.address, ETH("999999"));

	// 增加抵押
	await supplement(pool.address, NESTContract.address, USDTPToken, ETH("2"), "20000000000000000");
	await getLedger(pool.address, USDTPToken, NESTContract.address);
	// 减少抵押
	await decrease(pool.address, NESTContract.address, USDTPToken, ETH("1"), "20000000000000000");
	await getLedger(pool.address, USDTPToken, NESTContract.address);
	// 赎回
	await redemption(pool.address, NESTContract.address, USDTPToken, ETH("1"), "20000000000000000");
	await getLedger(pool.address, USDTPToken, NESTContract.address);

	// 认购保险
	await ERC20Balance(USDTShare, accounts[0].address);
	await subscribeIns(pool.address, USDTContract.address, USDT(2));
	await ERC20Balance(USDTShare, accounts[0].address);
	// 兑换
	await ERC20Balance(USDTPToken, pool.address);
	await exchangePTokenToUnderlying(pool.address, USDTPToken, ETH("1"));
	await ERC20Balance(USDTPToken, pool.address);

	await ERC20Balance(USDTContract.address, pool.address);
	await exchangeUnderlyingToPToken(pool.address, USDTContract.address, USDT("1"));
	await ERC20Balance(USDTContract.address, pool.address);

	// 赎回保险
	await approve(USDTShare, pool.address, ETH("999999"));
	await ERC20Balance(USDTContract.address, pool.address);
	await ERC20Balance(USDTContract.address, accounts[0].address);
	await ERC20Balance(USDTShare, accounts[0].address);
	await ERC20Balance(USDTPToken, pool.address);
	await redemptionIns(pool.address, USDTContract.address, ETH("2"));
	await ERC20Balance(USDTContract.address, pool.address);
	await ERC20Balance(USDTContract.address, accounts[0].address);
	await ERC20Balance(USDTShare, accounts[0].address);
	await ERC20Balance(USDTPToken, pool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});