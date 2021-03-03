const hre = require("hardhat");
const { ethers } = require("hardhat");
const {USDT,ETH,deployUSDT,deployNEST,deployNestQuery,deployInsurancePool,depolyFactory,setInsurancePool,setMortgagePool,
	setPrice,setMaxRate,setQuaryAddress,setPTokenOperator,setFlag,setFlag2,
	deployMortgagePool,approve,createPtoken,setInfo,getPTokenAddress,
	getTokenInfo,allow,coin,getLedger,supplement,
	getFee,ERC20Balance,redemptionAll,decrease,increaseCoinage,reducedCoinage,getInfoRealTime,
	exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,getTotalSupply,getBalances,subscribeIns,redemptionIns} = require("./normal-scripts.js");

async function main() {
	const accounts = await ethers.getSigners();
	// 准备工作
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	// 部署NEST合约
	NESTContract = await deployNEST();
	// 部署工厂合约
	factory = await depolyFactory();
	// 部署抵押池合约
	pool = await deployMortgagePool(factory.address);
	// 部署价格合约
	NestQuery = await deployNestQuery();
	// 部署保险池合约
	insurancePool = await deployInsurancePool(factory.address);
	// 向抵押池合约授权USDT
	await approve(NESTContract.address, pool.address, ETH("999999"));
	// 抵押池合约中设置保险池合约地址
	await setInsurancePool(pool.address, insurancePool.address);
	// 保险池合约中设置抵押池合约地址
	await setMortgagePool(insurancePool.address, pool.address);
	// 创建p资产
	await createPtoken(factory.address, "ETH");
	// 设置可操作p资产地址
	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");
	// 设置flag
	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");
	// 获取PETH地址
	const ETHPToken = await getPTokenAddress(factory.address, "0");
	// 设置p资产与标的资产地址
	await setInfo(pool.address, ETHAddress, ETHPToken);
	// 允许抵押NEST生成PETH
	await allow(pool.address, ETHPToken, NESTContract.address);
	// 设置NEST最高抵押率
	await setMaxRate(pool.address, NESTContract.address, "70");
	// 向抵押池合约授权PETH
	await approve(ETHPToken, pool.address, ETH("999999"));
	// 设置USDT价格
	// await setPrice(NestQuery.address,ETHAddress, ETH("1"));
	await setPrice(NestQuery.address,NESTContract.address, ETH("1"));
	// 在抵押池合约中设置价格合约地址
	await setQuaryAddress(pool.address,NestQuery.address);

	// 铸币
	await coin(pool.address, NESTContract.address, ETHPToken, ETH("4"), "50", "10000000000000000");
	const ledger = await getLedger(pool.address, ETHPToken, NESTContract.address);

	// 增加抵押
	await supplement(pool.address, NESTContract.address, ETHPToken, ETH("2"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address);
	await ERC20Balance(ETHPToken, insurancePool.address);
	// 减少抵押
	await decrease(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address);
	await ERC20Balance(ETHPToken, insurancePool.address);
	// 新增铸币
	await increaseCoinage(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address);
	// 减少铸币
	await reducedCoinage(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address);
	// 赎回
	// await redemptionAll(pool.address, NESTContract.address, USDTPToken);
	// await getLedger(pool.address, USDTPToken, NESTContract.address);
	await ERC20Balance(ETHPToken, insurancePool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});