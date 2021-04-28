const hre = require("hardhat");
const { ethers } = require("hardhat");

// 部署
const {deployUSDT,deployNEST,deployNestQuery,deployNTokenController,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")
// 设置
const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setLiquidationLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow} = require("./normal-scripts.js")
// 交互
const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns,liquidation} = require("./normal-scripts.js")
// 查询
const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool,getInsNegative} = require("./normal-scripts.js")

async function main() {
	const accounts = await ethers.getSigners();
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
	await approve(USDTContract.address, pool.address, USDT("999999999"));
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
	// 设置ETH平仓线
	await setLiquidationLine(pool.address, ETHAddress, "84");
	// 向抵押池合约授权PUSDT
	await approve(USDTPToken, pool.address, ETH("999999"));
	// 设置USDT价格
	await setAvg(NestQuery.address,USDTContract.address, USDT("10"));
	// 在抵押池合约中设置价格合约地址
	await setPriceController(pool.address,PriceController.address);

	// 铸币
	await coin(pool.address, ETHAddress, USDTPToken, ETH("4"), "50", "4010000000000000000");
	const ledger = await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	// 增加抵押
	await supplement(pool.address, ETHAddress, USDTPToken, ETH("2"), "2010000000000000000");
	await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);

	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("10"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("10"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("10"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("10"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("10"), "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), USDT("10"), "70", accounts[0].address);

	// 兑换
	await approve(USDTContract.address, insurancePool.address, USDT("999999"));
	await ERC20Balance(USDTPToken, insurancePool.address);
	await exchangeUnderlyingToPToken(insurancePool.address, USDTContract.address, USDT("10"), ETH("0"));
	await ERC20Balance(USDTPToken, insurancePool.address);

	// 修改价格
	await setAvg(NestQuery.address,USDTContract.address, "3968254");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), "3968254", "70", accounts[0].address);
	await getLedger(pool.address, USDTPToken, ETHAddress, accounts[0].address);
	
	// 清算
	await getInsNegative(insurancePool.address, USDTContract.address);
	await ERC20Balance(USDTPToken, accounts[0].address);
	await liquidation(pool.address, ETHAddress, USDTPToken, accounts[0].address, ETH("6"), "10000000000000000");
	await getInsNegative(insurancePool.address, USDTContract.address);
	await ERC20Balance(USDTPToken, accounts[0].address);

	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), "3968254", "70", accounts[0].address);
	await transfer(USDTContract.address, accounts[0].address, "1");
	await getInfoRealTime(pool.address, ETHAddress, USDTPToken, ETH("1"), "3968254", "70", accounts[0].address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});