const hre = require("hardhat");
const { ethers } = require("hardhat");
const {USDT,ETH,deployUSDT,deployNEST,deployNestQuery,deployInsurancePool,setInsurancePool,setMortgagePool,
	setPrice,setMaxRate,setQuaryAddress,
	deployMortgagePool,create,
	getTokenInfo,allow,coin,getInsurancePool} = require("./normal-scripts.js");

// 部署脚本，只需执行一次
async function main() {
	const accounts = await ethers.getSigners();
	// 准备工作
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	// 部署USDT合约
	USDTContract = await deployUSDT();
	// 部署NEST合约
	NESTContract = await deployNEST();
	// 部署抵押池合约
	pool = await deployMortgagePool();
	// 部署Nest价格合约
	NestQuery = await deployNestQuery();
	// 部署保险池合约
	insurancePool = await deployInsurancePool();
	// 设置保险池合约
	await setInsurancePool(pool.address, insurancePool.address);
	// 设置抵押池合约
	await setMortgagePool(insurancePool.address, pool.address);
	// 查看保险池地址
	await getInsurancePool(pool.address);
	// 创建P资产-PUSDT
	await create(pool.address, USDTContract.address, "USDT");
	// 创建P资产-PETH
	await create(pool.address, ETHAddress, "ETH");
	// 获取P资产地址-PUSDT
	const USDTPToken = await getTokenInfo(pool.address, insurancePool.address, USDTContract.address);
	// 获取P资产地址-PETH
	const ETHPToken = await getTokenInfo(pool.address, insurancePool.address, ETHAddress);
	// 设置允许抵押ETH
	await allow(pool.address, USDTPToken, ETHAddress);
	// 设置允许抵押NEST
	await allow(pool.address, USDTPToken, NESTContract.address);
	await allow(pool.address, ETHPToken, NESTContract.address);
	// 设置抵押率-ETH
	await setMaxRate(pool.address, ETHAddress, "70");
	// 设置抵押率-NEST
	await setMaxRate(pool.address, NESTContract.address, "70");
	// 设置价格，USDT/ETH
	await setPrice(NestQuery.address,USDTContract.address, USDT("1"));
	// 设置价格，NEST/ETH
	await setPrice(NestQuery.address,NESTContract.address, ETH("1"));
	// 设置价格合约
	await setQuaryAddress(pool.address,NestQuery.address);
	console.log("network:ropsten");
	console.log(`NestContract:${NESTContract.address}`);
	console.log(`USDTContract:${USDTContract.address}`);
	console.log(`MortgagePool:${pool.address}`);
	console.log(`InsurancePool:${insurancePool.address}`);
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