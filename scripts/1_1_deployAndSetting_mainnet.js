const hre = require("hardhat");
const { ethers } = require("hardhat");

// 部署
const {deployUSDT,deployNEST,deployNestQuery,deployNTokenController,deployPriceController,deployInsurancePool,depolyFactory,deployMortgagePool} = require("./normal-scripts.js")
// 设置
const {setInsurancePool,setMortgagePool,setAvg,setMaxRate,setLiquidationLine,setPriceController,setPTokenOperator,setFlag,setFlag2,setInfo,allow,setNTokenMapping} = require("./normal-scripts.js")
// 交互
const {approve,createPtoken,coin,supplement,redemptionAll,decrease,increaseCoinage,reducedCoinage,exchangePTokenToUnderlying,exchangeUnderlyingToPToken,transfer,subscribeIns,redemptionIns} = require("./normal-scripts.js")
// 查询
const {USDT,ETH,getPTokenAddress,getTokenInfo,getLedger,getFee,ERC20Balance,getInfoRealTime,getTotalSupply,getBalances,getInsurancePool} = require("./normal-scripts.js")

// 部署脚本，只需执行一次
async function main() {
	const accounts = await ethers.getSigners();
	// 准备工作
	const ETHAddress = "0x0000000000000000000000000000000000000000";
	const NTokenControllerAdd = "0x0000000000000000000000000000000000000001";
	const USDTContractAdd = "0x0000000000000000000000000000000000000001";
	const NESTContractAdd = "0x0000000000000000000000000000000000000001";
	const NestQueryAdd = "0x0000000000000000000000000000000000000001";
	// 部署工厂合约
	factory = await depolyFactory();
	// 部署抵押池合约
	pool = await deployMortgagePool(factory.address);
	// 部署获取价格合约
	PriceController = await deployPriceController(NestQueryAdd, NTokenControllerAdd);
	// 部署保险池合约
	insurancePool = await deployInsurancePool(factory.address);
	// 设置保险池合约
	await setInsurancePool(pool.address, insurancePool.address);
	// 设置抵押池合约
	await setMortgagePool(insurancePool.address, pool.address);
	// 查看保险池地址
	await getInsurancePool(pool.address);
	// 创建P资产-PUSDT
	await createPtoken(factory.address, "USDT");
	// 创建P资产-PETH
	await createPtoken(factory.address, "ETH");
	// 设置可操作p资产地址
	await setPTokenOperator(factory.address, pool.address, "1");
	await setPTokenOperator(factory.address, insurancePool.address, "1");
	// 设置flag
	await setFlag(pool.address, "1");
	await setFlag2(insurancePool.address, "1");
	// 获取P资产地址-PUSDT
	const USDTPToken = await getPTokenAddress(factory.address, "0");
	// 获取P资产地址-PETH
	const ETHPToken = await getPTokenAddress(factory.address, "1");;
	// 设置允许抵押ETH
	await allow(pool.address, USDTPToken, ETHAddress);
	// 设置允许抵押NEST
	await allow(pool.address, USDTPToken, NESTContractAdd);
	await allow(pool.address, ETHPToken, NESTContractAdd);
	// 设置抵押率-ETH
	await setMaxRate(pool.address, ETHAddress, "70");
	// 设置抵押率-NEST
	await setMaxRate(pool.address, NESTContractAdd, "40");
	// 设置清算线-ETH
	await setLiquidationLine(pool.address, ETHAddress, "84");
	// 设置清算线-NEST
	await setLiquidationLine(pool.address, NESTContractAdd, "75");
	// 设置价格合约
	await setPriceController(pool.address,PriceController.address);
	// 设置标的资产与p资产映射
	await setInfo(pool.address, USDTContractAdd, USDTPToken);
	await setInfo(pool.address, ETHAddress, ETHPToken);

	console.log("network:ropsten");
	console.log(`NestContract:${NESTContractAdd}`);
	console.log(`USDTContract:${USDTContractAdd}`);
	console.log(`PTokenFactory:${factory.address}`);
	console.log(`MortgagePool:${pool.address}`);
	console.log(`InsurancePool:${insurancePool.address}`);
	console.log(`PriceController:${PriceController.address}`);
	console.log(`NTokenController:${NTokenControllerAdd}`);
	console.log(`NestQuery:${NestQueryAdd}`);
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