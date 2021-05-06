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

exports.deployUSDT= async function () {
    const USDTContract = await ethers.getContractFactory("USDT");
    const USDT = await USDTContract.deploy();
    const tx = USDT.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: USDT deployed, address=${USDT.address}, block=${tx.blockNumber}`);
    return USDT;
}

exports.deployNEST= async function () {
    const NESTContract = await ethers.getContractFactory("NEST");
    const NEST = await NESTContract.deploy();
    const tx = NEST.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: NEST deployed, address=${NEST.address}, block=${tx.blockNumber}`);
    return NEST;
}

exports.deployNestQuery= async function () {
	const NestQueryContract = await ethers.getContractFactory("NestQuery");
    const NestQuery = await NestQueryContract.deploy();
    const tx = NestQuery.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: NestQuery deployed, address=${NestQuery.address}, block=${tx.blockNumber}`);
    return NestQuery;
}

exports.deployNTokenController= async function () {
    const NTokenController = await ethers.getContractFactory("NTokenController");
    const controller = await NTokenController.deploy();
    const tx = controller.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: deployNTokenController deployed, address=${controller.address}, block=${tx.blockNumber}`);
    return controller;
}
exports.deployPriceController= async function (priceContract, ntokenController) {
    const PriceControllerContract = await ethers.getContractFactory("PriceController");
    const PriceController = await PriceControllerContract.deploy(priceContract,ntokenController);
    const tx = PriceController.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: PriceController deployed, address=${PriceController.address}, block=${tx.blockNumber}`);
    return PriceController;
}

exports.setAvg = async function (quaryAddress, token, avg) {
	const NestQueryContract = await ethers.getContractAt("NestQuery", quaryAddress);
	const set = await NestQueryContract.setAvg(token, avg);
	await set.wait(1);
	console.log(`>>> [SETPRICE]: ${token} => ${avg}`);
}

exports.depolyFactory = async function() {
	const factory = await hre.ethers.getContractFactory("PTokenFactory");
	const contract = await factory.deploy();
	await contract.deployed();
	const tx = contract.deployTransaction;
	await tx.wait(1);
	console.log(`>>> [DPLY]: factory deployed, address=${contract.address}, block=${tx.blockNumber}`);
	return contract;
}

exports.deployMortgagePool = async function (factory) {
	const MortgagePool = await hre.ethers.getContractFactory("MortgagePool");
    const pool = await MortgagePool.deploy(factory);
    await pool.deployed();
    const tx = pool.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: MortgagePool deployed, address=${pool.address}, block=${tx.blockNumber}`);
    return pool;
}

exports.deployInsurancePool = async function (factory) {
	const InsurancePool = await hre.ethers.getContractFactory("InsurancePool");
    const pool = await InsurancePool.deploy(factory);
    await pool.deployed();
    const tx = pool.deployTransaction;
    await tx.wait(1);
    console.log(`>>> [DPLY]: InsurancePool deployed, address=${pool.address}, block=${tx.blockNumber}`);
    return pool;
}

exports.setInsurancePool = async function (mortgagePool, add) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const set = await pool.setInsurancePool(add);
    await set.wait(1);
    console.log(`>>> [setInsurancePool SUCCESS]`);
}

exports.setMortgagePool = async function (insurancePool, add) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
    const set = await pool.setMortgagePool(add);
    await set.wait(1);
    console.log(`>>> [setMortgagePool SUCCESS]`);
}

exports.approve = async function (token, to, value) {
	const ERC20Contract = await ethers.getContractAt("IERC20", token);
    const approve = await ERC20Contract.approve(to, value);
    await approve.wait(1);
    console.log(`>>> [APPROVE]: ${token} approve ${value} to ${to}`);
}

exports.createPtoken = async function (factory, name) {
	const fac = await ethers.getContractAt("PTokenFactory", factory);
    const create = await fac.createPtoken(name);
    await create.wait(1);
    console.log(`>>> [CREATE SUCCESS]`);
}

exports.setInfo = async function (mortgagePool, token, pToken) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const setInfo = await pool.setInfo(token, pToken);
	await setInfo.wait(1);
    console.log(`>>> [setInfo SUCCESS]`);
}

exports.allow = async function (mortgagePool, PToken, MToken) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const allow = await pool.setMortgageAllow(PToken, MToken, "1");
    await allow.wait(1);
    console.log(`>>> [ALLOW SUCCESS]`);
}

exports.setPriceController = async function (mortgagePool, priceController) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const setPriceController = await pool.setPriceController(priceController);
    await setPriceController.wait(1);
    console.log(`>>> [setPriceController SUCCESS]`);
}

exports.setFlag = async function(mortgagePool, num) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const setFlag = await pool.setFlag(num);
    await setFlag.wait(1);
    console.log(`>>> [setFlag SUCCESS]`);
}

exports.setFlag2 = async function(insurancePool, num) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
    const setFlag = await pool.setFlag(num);
    await setFlag.wait(1);
    console.log(`>>> [setFlag SUCCESS]`);
}

exports.setMaxRate = async function (mortgagePool, MToken, rate) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const maxRate = await pool.setMaxRate(MToken, rate);
    await maxRate.wait(1);
    console.log(`>>> [setMaxRate SUCCESS]`);
}

exports.setLiquidationLine = async function (mortgagePool, MToken, num) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const line = await pool.setLiquidationLine(MToken, num);
    await line.wait(1);
    console.log(`>>> [setLiquidationLine SUCCESS]`);
}

exports.setPTokenOperator = async function(factory, add, allow) {
	const fac = await ethers.getContractAt("PTokenFactory", factory);
    const Operator = await fac.setPTokenOperator(add, allow);
    await Operator.wait(1);
    console.log(`>>> [SetPTokenOperator SUCCESS]`);
}

exports.setNTokenMapping = async function(controller, priceContract, token, nToken) {
    const NTokenController = await ethers.getContractAt("NTokenController", controller);
    const tx1 = await NTokenController.setNTokenMapping(token, nToken);
    await tx1.wait(1);
    const price = await ethers.getContractAt("NestQuery", priceContract);
    const tx2 = await price.setNTokenMapping(token, nToken);
    await tx2.wait(1);
    console.log(`>>> [SetNTokenMapping SUCCESS]`);
}

exports.coin = async function (mortgagePool, MToken, PToken, MTokenAmount, rate, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const coin = await pool.coin(MToken, 
                        PToken, 
                        MTokenAmount, 
                        rate, 
                        { value: valueNum });
    console.log(`>>> [COIN SUCCESS]`);
}

exports.supplement = async function(mortgagePool, MToken, PToken, MTokenAmount, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const supplement = await pool.supplement(MToken, PToken, MTokenAmount, {value:valueNum});
	console.log(`>>> [supplement SUCCESS], supplement:${MTokenAmount}`);
}

exports.decrease = async function(mortgagePool, MToken, PToken, MTokenAmount, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const decrease = await pool.decrease(MToken, PToken, MTokenAmount, {value:valueNum});
	console.log(`>>> [decrease SUCCESS], decrease:${MTokenAmount}`);
}

exports.increaseCoinage = async function(mortgagePool, MToken, PToken, PTokenAmount, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const increaseCoinage = await pool.increaseCoinage(MToken, PToken, PTokenAmount, {value:valueNum});
	console.log(`>>> [increaseCoinage SUCCESS], supplement:${PTokenAmount}`);
}

exports.reducedCoinage = async function(mortgagePool, MToken, PToken, PTokenAmount, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const reducedCoinage = await pool.reducedCoinage(MToken, PToken, PTokenAmount, {value:valueNum});
	console.log(`>>> [reducedCoinage SUCCESS], supplement:${PTokenAmount}`);
}

exports.redemptionAll = async function(mortgagePool, MToken, PToken) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const supplement = await pool.redemptionAll(MToken, PToken);
	console.log(`>>> [redemption SUCCESS]`);
}

exports.liquidation = async function(mortgagePool, MToken, PToken, account, amount, valueNum) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const supplement = await pool.liquidation(MToken, PToken, account, amount, {value:valueNum});
	console.log(`>>> [liquidation SUCCESS]`);
}

exports.exchangePTokenToUnderlying = async function(insurancePool, PToken, amount) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
	const exchange = await pool.exchangePTokenToUnderlying(PToken, amount);
	console.log(`>>> [exchange SUCCESS], exchange:${PToken}->${amount}`);
}

exports.exchangeUnderlyingToPToken = async function(insurancePool, token, amount, valueNum) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
	const exchange = await pool.exchangeUnderlyingToPToken(token, amount, {value:valueNum});
	console.log(`>>> [exchange SUCCESS], exchange:${token}->${amount}`);
}

exports.subscribeIns = async function(insurancePool, token, amount, valueNum) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
	const subscribe = await pool.subscribeIns(token, amount, {value:valueNum});
	console.log(`>>> [subscribeIns SUCCESS], subscribeIns:${token}->${amount}`);
}

exports.redemptionIns = async function(insurancePool, token, amount) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
	const redemption = await pool.redemptionIns(token, amount);
	console.log(`>>> [redemption SUCCESS], redemption:${token}->${amount}`);
}

exports.transfer = async function(token, to, value) {
	const ERC20Contract = await ethers.getContractAt("IERC20", token);
    const transfer = await ERC20Contract.transfer(to, value);
    console.log(`>>> [transfer]: ${token} transfer ${value} to ${to}`);
    console.log(`~~~区块号:${transfer.blockNumber}`);
}

exports.getTotalSupply = async function (insurancePool, token) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
    const totalSupply = await pool.getTotalSupply(token);
    console.log(">>>>>> totalSupply =", totalSupply.toString());
    return totalSupply;
}

exports.getBalances = async function (insurancePool, token, add) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
    const balances = await pool.getBalances(token, add);
    console.log(">>>>>> balances =", balances.toString());
    return balances;
}

exports.getLedger = async function (mortgagePool, PToken, MToken, owner) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const ledger = await pool.getLedger(PToken, MToken, owner);
    console.log(`>>>> 抵押资产数量:${ledger[0].toString()}`);
    console.log(`>>>> 债务数量:${ledger[1].toString()}`);
    console.log(`>>>> 最近操作区块号:${ledger[2].toString()}`);
    console.log(`>>>> 抵押率:${ledger[3].toString()}`);
    console.log(`>>>> 是否创建:${ledger[4].toString()}`);
    return [ledger[0], ledger[1], ledger[2], ledger[3], ledger[4]];
}

exports.getInfoRealTime = async function (mortgagePool, MToken, PToken, tokenPrice, uTokenPrice, maxRateNum, owner) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const info = await pool.getInfoRealTime(MToken, PToken, tokenPrice, uTokenPrice, maxRateNum, owner);
    console.log("~~~实时数据~~~")
    console.log(`~~~稳定费:${info[0].toString()}`);
    console.log(`~~~抵押率:${info[1].toString()}`);
    console.log(`~~~最大可减少抵押资产数量:${info[2].toString()}`);
    console.log(`~~~最大可新增铸币数量:${info[3].toString()}`);
    return [info[0], info[1], info[2], info[3]];
}

exports.getFee = async function (mortgagePool, mortgageAssets, parassetAssets, blockHeight, tokenPrice, pTokenPrice) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
	const getFee = await pool.getFee(mortgageAssets, parassetAssets, blockHeight, tokenPrice, pTokenPrice);
	console.log(">>>>>> FEE =", getFee.toString());
}

exports.getInsNegative = async function(insurancePool, token) {
	const pool = await ethers.getContractAt("InsurancePool", insurancePool);
    const num = await pool.getInsNegative(token);
    console.log(">>>>>> InsNegative =", num.toString());
    return num;
}

exports.ERC20Balance = async function (token, add) {
	const ERC20Contract = await ethers.getContractAt("IERC20", token);
	const balance = await ERC20Contract.balanceOf(add);
	console.log(">>>>>> BALANCE =", balance.toString());
}

exports.getTokenInfo = async function (mortgagePool, insurancePool ,token) {
	const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const pToken = await pool.underlyingToPToken(token);
    console.log(`>>> pTokenAddress=${pToken}`);
    return pToken;
}

exports.getPTokenAddress = async function (factory, index) {
	const fac = await ethers.getContractAt("PTokenFactory", factory);
    const address = await fac.getPTokenAddress(index);
    console.log(`>>> pTokenAddress=${address}`);
    return address;
}

exports.getGovernance = async function (mortgagePool) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const governance  = await pool.getGovernance();
    console.log(`>>> governance=${governance}`);
    return governance;
}

exports.getInsurancePool = async function (mortgagePool) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const insurancePool  = await pool.getInsurancePool();
    console.log(`>>> insurancePool=${insurancePool}`);
    return insurancePool;
}

exports.getR0 = async function (mortgagePool) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const r0  = await pool.getR0();
    console.log(`>>> r0=${r0.toString()}`);
    return r0.toString();
}

exports.getOneYear = async function (mortgagePool) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const oneYear  = await pool.getOneYear();
    console.log(`>>> oneYear=${oneYear.toString()}`);
    return oneYear.toString();
}

exports.getMaxRate = async function (mortgagePool, MToken) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const maxRate  = await pool.getMaxRate(MToken);
    console.log(`>>> oneYear=${maxRate.toString()}`);
    return maxRate.toString();
}

exports.getLine = async function (mortgagePool, MToken) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const line  = await pool.getLine(MToken);
    console.log(`>>> line=${line.toString()}`);
    return line.toString();
}

exports.getPriceController = async function (mortgagePool) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const priceController  = await pool.getPriceController();
    console.log(`>>> priceController=${priceController}`);
    return priceController;
}

exports.getUnderlyingToPToken = async function (mortgagePool, uToken) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const pToken  = await pool.getUnderlyingToPToken(uToken);
    console.log(`>>> pToken=${pToken}`);
    return pToken;
}

exports.getPTokenToUnderlying = async function (mortgagePool, pToken) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const uToken  = await pool.getPTokenToUnderlying(pToken);
    console.log(`>>> uToken=${uToken}`);
    return uToken;
}

exports.getLedgerArrayNum = async function (mortgagePool, pToken, MToken) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const num  = await pool.getLedgerArrayNum(pToken, MToken);
    console.log(`>>> length=${num}`);
    return num;
}

exports.getLedgerAddress = async function (mortgagePool, pToken, MToken, num) {
    const pool = await ethers.getContractAt("MortgagePool", mortgagePool);
    const address  = await pool.getLedgerAddress(pToken, MToken,num);
    console.log(`>>> address=${address}`);
    return address;
}
