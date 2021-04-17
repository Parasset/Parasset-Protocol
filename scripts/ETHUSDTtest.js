const hre = require("hardhat");
const { ethers } = require("hardhat");

// 部署
const {deployUSDT,deployNEST,deployNestQuery,deployNTokenController,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")
// 设置
const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setK,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")
// 交互
const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")
// 查询
const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances} = require("./normal-scripts.js")

async function main() {
	const accounts = await ethers.getSigners();
	// USDT价格
	const USDTPRICE = USDT("3");

	// 准备工作
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	// 部署USDT合约
	USDTContract = await deployUSDT();
	// 部署工厂合约
	factory = await depolyFactory();
	// 部署抵押池合约
	pool = await deployMortgagePool(factory.address);
	// 部署价格合约
	NestQuery = await deployNestQuery();
	// 部署NTokenController
	NTokenController = await deployNTokenController();
	// 部署获取价格合约
	PriceController = await deployPriceController(NestQuery.address, NTokenController.address);
	// 部署保险池合约
	insurancePool = await deployInsurancePool(factory.address);

	// 向抵押池合约授权USDT
	await approve(USDTContract.address, pool.address, USDT("999999"));
	// 抵押池合约中设置保险池合约地址
	await setInsurancePool(pool.address, insurancePool.address);
	// 保险池合约中设置抵押池合约地址
	await setMortgagePool(insurancePool.address, pool.address);
	// 创建p资产
	await createPtoken(factory.address, "USDT");
	// 设置可操作p资产地址
	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");
	// 设置flag
	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");
	// 获取PUSDT地址
	const USDTPToken = await getPTokenAddress(factory.address, "0");
	// 设置p资产与标的资产地址
	await setInfo(pool.address, USDTContract.address, USDTPToken);
	// 允许抵押ETH生成PUSDT
	await allow(pool.address, USDTPToken, ETHAddress);
	// 设置ETH最高抵押率
	await setMaxRate(pool.address, ETHAddress, "70");
	// 设置ETH的k
	await setK(pool.address, ETHAddress, "1250");
	// 向抵押池合约授权PUSDT
	await approve(USDTPToken, pool.address, ETH("999999"));
	// 设置USDT价格
	await setAvg(NestQuery.address,USDTContract.address, USDTPRICE);
	// 在抵押池合约中设置价格合约地址
	await setPriceController(pool.address,PriceController.address);

	// 铸币
	console.log("====铸币====");
	await coin(pool.address, ETHAddress, USDTPToken, ETH("10"), "50", "10010000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	console.log("====铸币结束====");

	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);
	// await setAvg(NestQuery.address,USDTContract.address, USDT("4"));
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("4"), "70", accounts[0].address);

	// 增加抵押
	// console.log("====增加抵押====");
	// await supplement(pool.address, ETHAddress, USDTPToken, ETH("2"), "2010000000000000000");
	// await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	// console.log("====增加抵押结束====");
	// await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);
	// // 减少抵押
	// console.log("====减少抵押====");
	// await decrease(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	// await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	// console.log("====减少抵押结束====");
	// await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);
	// // 新增铸币
	// console.log("====新增铸币====");
	// await increaseCoinage(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	// await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	// console.log("====新增铸币结束====");
	// await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);
	// // 减少铸币
	// console.log("====减少铸币====");
	// await reducedCoinage(pool.address, ETHAddress, USDTPToken, ETH("1"), "10000000000000000");
	// await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	// console.log("====减少铸币结束====");
	// await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);
	

	// // 认购保险
	// console.log("====保险授权====");
	// await approve(USDTContract.address, insurancePool.address, USDT("999999"));
	// await approve(USDTPToken, insurancePool.address, ETH("999999"));
	// console.log("====保险授权结束====");

	// console.log("====购买保险====");
	// await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	// await subscribeIns(insurancePool.address, USDTContract.address, USDT(2), 0);
	// await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	// console.log("====购买保险结束====");
	// // 兑换
	// console.log("====P资产兑换标的资产====");
	// await ERC20Balance(USDTPToken, insurancePool.address);
	// await exchangePTokenToUnderlying(insurancePool.address, USDTPToken, ETH("1"));
	// await ERC20Balance(USDTPToken, insurancePool.address);
	// console.log("====P资产兑换标的资产结束====");

	// console.log("====标的资产兑换P资产====");
	// await ERC20Balance(USDTContract.address, insurancePool.address);
	// await ERC20Balance(USDTPToken, accounts[0].address);
	// await exchangeUnderlyingToPToken(insurancePool.address, USDTContract.address, USDT("1000"), 0);
	// await ERC20Balance(USDTContract.address, insurancePool.address);
	// await ERC20Balance(USDTPToken, accounts[0].address);
	// console.log("====标的资产兑换P资产结束====");

	// 全部赎回
	// console.log("====全部赎回（个人债仓）====");
	// await redemptionAll(pool.address, ETHAddress, USDTPToken);
	// await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	// await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDTPRICE, "70", accounts[0].address);
	// console.log("====全部赎回（个人债仓）结束====");


	// 赎回保险--本地私链测试时注释掉，被冻结无法测试
	// await ERC20Balance(USDTContract.address, insurancePool.address);
	// await ERC20Balance(USDTContract.address, accounts[0].address);
	// await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	// await ERC20Balance(USDTPToken, insurancePool.address);
	// await redemptionIns(insurancePool.address, USDTContract.address, ETH("2"));
	// await ERC20Balance(USDTContract.address, insurancePool.address);
	// await ERC20Balance(USDTContract.address, accounts[0].address);
	// await getBalances(insurancePool.address, USDTContract.address, accounts[0].address);
	// await ERC20Balance(USDTPToken, insurancePool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});