const hre = require("hardhat");
const { ethers } = require("hardhat");
const {USDT,ETH,deployUSDT,setMaxRate,deployMortgagePool,approve,create,
	getTokenInfo,allow,coin,getLedger,supplement,getPriceForPToken,
	getFee,ERC20Balance,redemption,decrease,
	exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js");

async function main() {
	const accounts = await ethers.getSigners();
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	USDTContract = await deployUSDT();
	pool = await deployMortgagePool();
	await approve(USDTContract.address, pool.address, USDT("999999"));
	await create(pool.address, USDTContract.address, "USDT");
	const tokens = await getTokenInfo(pool.address, USDTContract.address);
	const USDTPToken = tokens[0];
	const USDTShare = tokens[1];
	await allow(pool.address, USDTPToken, ETHAddress);
	await setMaxRate(pool.address, ETHAddress, "70");
	// 铸币
	await coin(pool.address, ETHAddress, USDTPToken, ETH("4"), "70", "4010000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, ETHAddress);

	await approve(USDTPToken, pool.address, ETH("999999"));

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

  8166666666
  16333333333