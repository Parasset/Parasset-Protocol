const hre = require("hardhat");
const { ethers } = require("hardhat");
// 部署
const {deployUSDT,deployNEST,deployNestQuery,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")
// 设置
const {setInsurancePool,setMortgagePool,setPrice,setMaxRate,setLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")
// 交互
const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")
// 查询
const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool,getLedgerArrayNum,getLedgerAddress} = require("./normal-scripts.js")

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
	// 部署获取价格合约
	PriceController = await deployPriceController(NestQuery.address);
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
	// 设置ETH平仓线
	await setLine(pool.address, NESTContract.address, "80");
	// 向抵押池合约授权PETH
	await approve(ETHPToken, pool.address, ETH("999999"));
	// 设置NEST价格
	await setPrice(NestQuery.address,NESTContract.address, ETH("3"));
	// 在抵押池合约中设置价格合约地址
	await setPriceController(pool.address,PriceController.address);

	// 铸币
	await coin(pool.address, NESTContract.address, ETHPToken, ETH("12"), "50", "10000000000000000");
	const ledger = await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);

	// await getLedgerArrayNum(pool.address, ETHPToken, NESTContract.address);
	// await getLedgerAddress(pool.address, ETHPToken, NESTContract.address, 0);

	// 增加抵押
	await supplement(pool.address, NESTContract.address, ETHPToken, ETH("2"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);
	await ERC20Balance(ETHPToken, insurancePool.address);
	// 减少抵押
	await decrease(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);
	await ERC20Balance(ETHPToken, insurancePool.address);
	// 新增铸币
	await increaseCoinage(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);
	// 减少铸币
	await reducedCoinage(pool.address, NESTContract.address, ETHPToken, ETH("1"), "10000000000000000");
	await getLedger(pool.address, ETHPToken, NESTContract.address, accounts[0].address);
	// 赎回
	// await redemptionAll(pool.address, NESTContract.address, USDTPToken);
	// await getLedger(pool.address, USDTPToken, NESTContract.address);
	await ERC20Balance(ETHPToken, insurancePool.address);

	// 认购保险
	await approve(ETHPToken, insurancePool.address, ETH("999999"));
	await getBalances(insurancePool.address, ETHAddress, accounts[0].address);
	await getTotalSupply(insurancePool.address,ETHAddress);
	await subscribeIns(insurancePool.address, ETHAddress, ETH(1), ETH(1));
	await getTotalSupply(insurancePool.address,ETHAddress);
	await getBalances(insurancePool.address, ETHAddress, accounts[0].address);
	await subscribeIns(insurancePool.address, ETHAddress, "100000000000000000", "100000000000000000");
	await getTotalSupply(insurancePool.address,ETHAddress);
	await getBalances(insurancePool.address, ETHAddress, accounts[0].address);
	// 兑换
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