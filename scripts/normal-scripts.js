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

// 授权给抵押池
exports.approve = async function (token, to, value) {
	const ERC20Contract = await ethers.getContractAt("IERC20", token);
    const approve = await ERC20Contract.approve(to, value);
    console.log(`>>> [APPROVE]: ${token} approve ${value} to ${to}`);
}

// 创建
exports.create = async function (mortgagePool ,token, name) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const create = await pool.create(token, name);
    console.log(`>>> [CREATE SUCCESS]`);
}

// 查看抵押token信息
exports.getTokenInfo = async function (mortgagePool ,token) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const tokensAdd = await pool.getPTokenAddressAndInsAddress(token);
    console.log(`>>> pTokenAddress=${tokensAdd[0]}`);
    console.log(`>>> insAddress=${tokensAdd[1]}`);
    return [tokensAdd[0], tokensAdd[1]]
}

// 允许抵押
exports.allow = async function (mortgagePool, PToken, MToken) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const allow = await pool.setMortgageAllow(PToken, MToken, "1");
    console.log(`>>> [ALLOW SUCCESS]`);
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
exports.getPriceForPToken = async function (mortgagePool, MToken, token) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const price = await pool.getPriceForPToken(MToken, token);
	console.log(">>>>>> PRICE =", price[0].toString(), price[1].toString());
	return [price[0], price[1]];
}
exports.getPrice = async function (mortgagePool, MToken, token) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const price = await pool.getPrice(MToken, token);
	console.log(">>>>>> PRICE =", price[0].toString(), price[1].toString());
	return [price[0], price[1]];
}

// 查询ERC20余额
exports.ERC20Balance = async function (token, add) {
	const ERC20Contract = await ethers.getContractAt("IERC20", token);
	const balance = await ERC20Contract.balanceOf(add);
	console.log(">>>>>> BALANCE =", balance.toString());
}
