const hre = require("hardhat");
const { ethers } = require("hardhat");
const {USDT,ETH,deployUSDT,deployNEST,deployNestQuery,deployInsurancePool,depolyFactory,setInsurancePool,setMortgagePool,
	setPrice,setMaxRate,setQuaryAddress,setPTokenOperator,setFlag,setFlag2,
	deployMortgagePool,createPtoken,setInfo,getPTokenAddress,
	getTokenInfo,allow,coin,getInsurancePool} = require("./normal-scripts.js");
const contractsDeployed_ropsten = require("./contracts_ropsten.js");

// 部署脚本，只需执行一次
async function main() {
	const accounts = await ethers.getSigners();
	// 准备工作
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	USDTContract = await await ethers.getContractAt("USDT", contractsDeployed_ropsten.USDTContract);
	NESTContract = await ethers.getContractAt("USDT", contractsDeployed_ropsten.NestContract);
	factory = await await ethers.getContractAt("PTokenFactory", contractsDeployed_ropsten.PTokenFactory);
	NestQuery = await await ethers.getContractAt("NestQuery", contractsDeployed_ropsten.NestQuery);
	// 部署抵押池合约
	pool = await deployMortgagePool(factory.address);
	// 部署保险池合约
	insurancePool = await deployInsurancePool(factory.address);
	// 设置保险池合约
	await setInsurancePool(pool.address, insurancePool.address);
	// 设置抵押池合约
	await setMortgagePool(insurancePool.address, pool.address);
	// 查看保险池地址
	await getInsurancePool(pool.address);
	// 获取P资产地址-PUSDT
	const USDTPToken = await getPTokenAddress(factory.address, "0");
	// 获取P资产地址-PETH
	const ETHPToken = await await getPTokenAddress(factory.address, "1");;
	// 设置可操作p资产地址
	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");
	// 设置flag
	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");
	// 设置允许抵押ETH
	await allow(pool.address, USDTPToken, ETHAddress);
	// 设置允许抵押NEST
	await allow(pool.address, USDTPToken, NESTContract.address);
	await allow(pool.address, ETHPToken, NESTContract.address);
	// 设置抵押率-ETH
	await setMaxRate(pool.address, ETHAddress, "70");
	// 设置抵押率-NEST
	await setMaxRate(pool.address, NESTContract.address, "70");
	// 设置价格合约
	await setQuaryAddress(pool.address,NestQuery.address);
	console.log("network:ropsten");
	console.log(`MortgagePool:${pool.address}`);
	console.log(`InsurancePool:${insurancePool.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});