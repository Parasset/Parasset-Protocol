const hre = require("hardhat");
const { ethers } = require("hardhat");
const {USDT,ETH,deployUSDT,deployNEST,deployNestQuery,deployInsurancePool,setInsurancePool,setMortgagePool,
	setPrice,setMaxRate,setQuaryAddress,
	deployMortgagePool,approve,create,
	getTokenInfo,allow,coin,getLedger,supplement,
	getFee,ERC20Balance,redemptionAll,decrease,increaseCoinage,reducedCoinage,getInfoRealTime,liquidation,getInsNegative,
	exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,getTotalSupply,getBalances,subscribeIns,redemptionIns} = require("./normal-scripts.js");

async function main() {
	const accounts = await ethers.getSigners();
	// 准备工作
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	// 部署USDT合约
	USDTContract = await deployUSDT();
	// 部署抵押池合约
	pool = await deployMortgagePool();
	// 部署价格合约
	NestQuery = await deployNestQuery();
	// 部署保险池合约
	insurancePool = await deployInsurancePool();
	// 向抵押池合约授权USDT
	await approve(USDTContract.address, pool.address, USDT("999999"));
	// 抵押池合约中设置保险池合约地址
	await setInsurancePool(pool.address, insurancePool.address);
	// 保险池合约中设置抵押池合约地址
	await setMortgagePool(insurancePool.address, pool.address);
	// 创建p资产
	await create(pool.address, USDTContract.address, "USDT");
	// 获取PUSDT地址
	const USDTPToken = await getTokenInfo(pool.address, insurancePool.address, USDTContract.address);
	// 允许抵押ETH生成PUSDT
	await allow(pool.address, USDTPToken, ETHAddress);
	// 设置ETH最高抵押率
	await setMaxRate(pool.address, ETHAddress, "70");
	// 向抵押池合约授权PUSDT
	await approve(USDTPToken, pool.address, ETH("999999"));
	// 设置USDT价格
	// await setPrice(NestQuery.address,ETHAddress, ETH("1"));
	await setPrice(NestQuery.address,USDTContract.address, USDT("1"));
	// 在抵押池合约中设置价格合约地址
	await setQuaryAddress(pool.address,NestQuery.address);

	// 铸币
	await coin(pool.address, ETHAddress, USDTPToken, ETH("4"), "50", "4010000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, ETHAddress);
	// 增加抵押
	await supplement(pool.address, ETHAddress, USDTPToken, ETH("2"), "2010000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);
	// 减少抵押
	await decrease(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);
	// 新增铸币
	await increaseCoinage(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);
	// 减少铸币
	await reducedCoinage(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress);
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("1"), "65");

	// 认购保险
	await approve(USDTContract.address, insurancePool.address, USDT("999999"));
	await approve(USDTPToken, insurancePool.address, ETH("999999"));
	await subscribeIns(insurancePool.address, USDTContract.address, USDT(2));

	// 测试清算
	// 修改价格，跌10倍
	await setPrice(NestQuery.address,USDTContract.address, "100000");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), "100000", "65");

	await getInsNegative(insurancePool.address, USDTContract.address);
	await ERC20Balance(USDTPToken, accounts[0].address);
	await liquidation(pool.address, ETHAddress, USDTPToken, accounts[0].address, "10000000000000000");
	await getInsNegative(insurancePool.address, USDTContract.address);
	await ERC20Balance(USDTPToken, accounts[0].address);

	
	// 兑换
	await getInsNegative(insurancePool.address, USDTContract.address);
	await ERC20Balance(USDTPToken, accounts[0].address);
	await ERC20Balance(USDTContract.address, accounts[0].address);
	await exchangePTokenToUnderlying(insurancePool.address, USDTPToken, ETH("1"));
	await getInsNegative(insurancePool.address, USDTContract.address);
	await ERC20Balance(USDTPToken, accounts[0].address);
	await ERC20Balance(USDTContract.address, accounts[0].address);


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});