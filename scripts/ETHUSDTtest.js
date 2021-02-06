const hre = require("hardhat");
const { ethers } = require("hardhat");
const {USDT,ETH,deployUSDT,deployMortgagePool,approve,create,
	getTokenInfo,allow,coin,getLedger,supplement,getPriceForPToken,
	getFee,ERC20Balance,redemption,decrease} = require("./normal-scripts.js");

async function main() {
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	USDTContract = await deployUSDT();
	pool = await deployMortgagePool();
	await approve(USDTContract.address, pool.address, USDT("999999"));
	await create(pool.address, USDTContract.address, "USDT");
	const tokens = await getTokenInfo(pool.address, USDTContract.address);
	const USDTPToken = tokens[0];
	const USDTShare = tokens[1];
	await allow(pool.address, USDTPToken, ETHAddress);
	await coin(pool.address, ETHAddress, USDTPToken, ETH("2"), "70", "2010000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, ETHAddress);

	await approve(USDTPToken, pool.address, ETH("999999"));
	// const price = await getPriceForPToken(pool.address, ETHAddress, USDTContract.address);
	// await getFee(pool.address, ledger[0], ledger[1], ledger[2], price[0], price[1]);
	await supplement(pool.address, ETHAddress, USDTPToken, ETH("2"), "2010000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);
	// await ERC20Balance(USDTPToken, pool.address);

	await decrease(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);

	await redemption(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);
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