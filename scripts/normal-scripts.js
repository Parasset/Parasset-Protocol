const hre = require("hardhat");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const usdtdec = BigNumber.from(10).pow(6);
const ethdec = BigNumber.from(10).pow(18);

exports.ETH = function (amount) {
    return BigNumber.from(amount).mul(ethdec);
}

exports.USDT = function (amount) {
    return BigNumber.from(amount).mul(usdtdec);
}

// 部署USDT
exports.deployUSDT= async function () {
    const USDTContract = await ethers.getContractFactory("USDT");
    const USDT = await USDTContract.deploy();
    const tx = USDT.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: USDT deployed, address=${USDT.address}, block=${tx.blockNumber}`);
    return USDT;
}

// 部署NEST
exports.deployNEST= async function () {
    const NESTContract = await ethers.getContractFactory("NEST");
    const NEST = await NESTContract.deploy();
    const tx = NEST.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: NEST deployed, address=${NEST.address}, block=${tx.blockNumber}`);
    return NEST;
}

// 部署价格合约
exports.deployNestQuery= async function () {
	const NestQueryContract = await ethers.getContractFactory("NestQuery");
    const NestQuery = await NestQueryContract.deploy();
    const tx = NestQuery.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: NestQuery deployed, address=${NestQuery.address}, block=${tx.blockNumber}`);
    return NestQuery;
}
// 修改价格
exports.setPrice = async function (quaryAddress, token, avg) {
	const NestQueryContract = await ethers.getContractAt("NestQuery", quaryAddress);
	const set = await NestQueryContract.setPrice(token, avg);
	await set.wait(3);
	console.log(`>>> [SETPRICE]: ${token} => ${avg}`);
}

// 部署抵押池
exports.deployMortgagePool = async function () {
	const MortgagePool = await hre.ethers.getContractFactory("MortgagePool");
    const pool = await MortgagePool.deploy();
    await pool.deployed();
    const tx = pool.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: MortgagePool deployed, address=${pool.address}, block=${tx.blockNumber}`);
    return pool;
}

// 部署保险池
exports.deployInsurancePool = async function () {
	const InsurancePool = await hre.ethers.getContractFactory("InsurancePoolV2");
    const pool = await InsurancePool.deploy();
    await pool.deployed();
    const tx = pool.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: InsurancePool deployed, address=${pool.address}, block=${tx.blockNumber}`);
    return pool;
}

// 抵押合约-设置保险池
exports.setInsurancePool = async function (mortgagePool, add) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const set = await pool.setInsurancePool(add);
    await set.wait(10);
    console.log(`>>> [setInsurancePool SUCCESS]`);
}

// 保险合约-设置抵押池
exports.setMortgagePool = async function (insurancePool, add) {
	const pool = await ethers.getContractAt("InsurancePoolV2", insurancePool);
    const set = await pool.setMortgagePool(add);
    await set.wait(10);
    console.log(`>>> [setMortgagePool SUCCESS]`);
}

// 授权
exports.approve = async function (token, to, value) {
	const ERC20Contract = await ethers.getContractAt("IERC20", token);
    const approve = await ERC20Contract.approve(to, value);
    console.log(`>>> [APPROVE]: ${token} approve ${value} to ${to}`);
}

// 创建
exports.create = async function (mortgagePool ,token, name) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const create = await pool.create(token, name);
    await create.wait(10);
    console.log(`>>> [CREATE SUCCESS]`);
}

// 允许抵押
exports.allow = async function (mortgagePool, PToken, MToken) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const allow = await pool.setMortgageAllow(PToken, MToken, "1");
    console.log(`>>> [ALLOW SUCCESS]`);
}

// 设置价格合约
exports.setQuaryAddress = async function (mortgagePool, quary) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const setQuary = await pool.setQuaryAddress(quary);
    console.log(`>>> [setQuaryAddress SUCCESS]`);
}

// 设置最高抵押
exports.setMaxRate = async function (mortgagePool, MToken, rate) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const maxRate = await pool.setMaxRate(MToken, rate);
    console.log(`>>> [setMaxRate SUCCESS]`);
}

// 抵押铸币
exports.coin = async function (mortgagePool, MToken, PToken, MTokenAmount, rate, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const coin = await pool.coin(MToken, 
                        PToken, 
                        MTokenAmount, 
                        rate, 
                        { value: valueNum });
    console.log(`>>> [COIN SUCCESS]`);
}

// 补充抵押
exports.supplement = async function(mortgagePool, MToken, PToken, MTokenAmount, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const supplement = await pool.supplement(MToken, PToken, MTokenAmount, {value:valueNum});
	console.log(`>>> [supplement SUCCESS], supplement:${MTokenAmount}`);
}

// 减少抵押
exports.decrease = async function(mortgagePool, MToken, PToken, MTokenAmount, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const decrease = await pool.decrease(MToken, PToken, MTokenAmount, {value:valueNum});
	console.log(`>>> [decrease SUCCESS], decrease:${MTokenAmount}`);
}

// 赎回抵押
exports.redemption = async function(mortgagePool, MToken, PToken, MTokenAmount, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const supplement = await pool.redemption(MToken, PToken, MTokenAmount, {value:valueNum});
	console.log(`>>> [redemption SUCCESS], redemption:${MTokenAmount}`);
}

// 兑换
exports.exchangePTokenToUnderlying = async function(insurancePool, PToken, amount) {
	const pool = await ethers.getContractAt("InsurancePoolV2", insurancePool);
	const exchange = await pool.exchangePTokenToUnderlying(PToken, amount);
	console.log(`>>> [exchange SUCCESS], exchange:${PToken}->${amount}`);
}
exports.exchangeUnderlyingToPToken = async function(insurancePool, token, amount) {
	const pool = await ethers.getContractAt("InsurancePoolV2", insurancePool);
	const exchange = await pool.exchangeUnderlyingToPToken(token, amount);
	console.log(`>>> [exchange SUCCESS], exchange:${token}->${amount}`);
}

// 认购保险
exports.subscribeIns = async function(insurancePool, token, amount) {
	const pool = await ethers.getContractAt("InsurancePoolV2", insurancePool);
	const subscribe = await pool.subscribeIns(token, amount);
	console.log(`>>> [subscribeIns SUCCESS], subscribeIns:${token}->${amount}`);
}

// 赎回保险
exports.redemptionIns = async function(insurancePool, token, amount) {
	const pool = await ethers.getContractAt("InsurancePoolV2", insurancePool);
	const redemption = await pool.redemptionIns(token, amount);
	console.log(`>>> [redemption SUCCESS], redemption:${token}->${amount}`);
}

// 转账ERC20
exports.transfer = async function(token, to, value) {
	const ERC20Contract = await ethers.getContractAt("IERC20", token);
    const approve = await ERC20Contract.transfer(to, value);
    console.log(`>>> [transfer]: ${token} transfer ${value} to ${to}`);
}

// 查看保险池地址
exports.getInsurancePool = async function(mortgagePool) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const insurancePool = await pool.getInsurancePool();
	console.log(`>>> InsurancePool=${insurancePool}`);
}

// 查询LP总量
exports.getTotalSupply = async function (insurancePool, token) {
	const pool = await ethers.getContractAt("InsurancePoolV2", insurancePool);
    const totalSupply = await pool.getTotalSupply(token);
    console.log(">>>>>> totalSupply =", totalSupply.toString());
    return totalSupply;
}
// 查询个人LP
exports.getBalances = async function (insurancePool, token) {
	const pool = await ethers.getContractAt("InsurancePoolV2", insurancePool);
    const balances = await pool.getBalances(token);
    console.log(">>>>>> balances =", balances.toString());
    return balances;
}

// 查看债仓信息
exports.getLedger = async function (mortgagePool, PToken, MToken) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const ledger = await pool.getLedger(PToken, MToken);
    console.log(">>>>>> ledger =", ledger[0].toString(), ledger[1].toString(), ledger[2].toString());
    return [ledger[0], ledger[1], ledger[2]];
}

// 查看稳定费
exports.getFee = async function (mortgagePool, mortgageAssets, parassetAssets, blockHeight, tokenPrice, pTokenPrice) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const getFee = await pool.getFee(mortgageAssets, parassetAssets, blockHeight, tokenPrice, pTokenPrice);
	console.log(">>>>>> FEE =", getFee.toString());
}

// 查看价格
// exports.getPriceForPToken = async function (mortgagePool, MToken, token) {
// 	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
// 	const price = await pool.getPriceForPToken(MToken, token);
// 	console.log(">>>>>> PRICE =", price[0].toString(), price[1].toString());
// 	return [price[0], price[1]];
// }

// 查询ERC20余额
exports.ERC20Balance = async function (token, add) {
	const ERC20Contract = await ethers.getContractAt("IERC20", token);
	const balance = await ERC20Contract.balanceOf(add);
	console.log(">>>>>> BALANCE =", balance.toString());
}

// 查看抵押token信息
exports.getTokenInfo = async function (mortgagePool, insurancePool ,token) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const pToken = await pool.underlyingToPToken(token);
    console.log(`>>> pTokenAddress=${pToken}`);
    return pToken;
}
