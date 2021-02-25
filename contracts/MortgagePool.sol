// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./PToken.sol";
import "./lib/SafeMath.sol";
import './lib/TransferHelper.sol';
import './lib/SafeERC20.sol';
import "./lib/AddressPayable.sol";
import "./iface/INestQuery.sol";
import "./iface/IERC20.sol";
import "./iface/IInsurancePool.sol";
import "./iface/IPTokenFactory.sol";

contract MortgagePool {
	using SafeMath for uint256;
	using address_make_payable for address;
	using SafeERC20 for ERC20;

    // 管理员地址
	address public governance;
	// 标的资产地址=>p资产地址
	mapping(address=>address) public underlyingToPToken;
	// p资产地址=>标的资产地址
	mapping(address=>address) public pTokenToUnderlying;
    // p资产地址=>抵押资产地址=>bool
	mapping(address=>mapping(address=>bool)) mortgageAllow;
    // p资产=>抵押资产=>用户地址=>债仓数据
	mapping(address=>mapping(address=>mapping(address=>PersonalLedger))) ledger;
    // 抵押资产=>最高抵押率
    mapping(address=>uint256) maxRate;
    // 价格合约
    INestQuery quary;
    // 保险池合约
    IInsurancePool insurancePool;
    // 工厂合约地址
    IPTokenFactory pTokenFactory;
	// 市场基础利率，年化2%
	uint256 r0 = 0.02 ether;
	// 一年的出块量
	uint256 oneYear = 2400000;
	// k常数
	uint256 k = 120;
    // 状态
    uint8 public flag;      // = 0: 停止
                            // = 1: 启动
                            // = 2: 只能全部赎回

	struct PersonalLedger {
        uint256 mortgageAssets;         // 抵押资产数量
        uint256 parassetAssets;         // P资产
        uint256 blockHeight;            // 上次操作区块高度
        uint256 rate;                   // 抵押率
    }

	constructor (address factoryAddress) public {
        pTokenFactory = IPTokenFactory(factoryAddress);
        governance = pTokenFactory.getGovernance();
        flag = 0;
    }

    //---------modifier---------

    modifier onlyGovernance() {
        require(msg.sender == governance, "Log:MortgagePool:!gov");
        _;
    }

    modifier whenActive() {
        require(flag == 1, "Log:MortgagePool:!active");
        _;
    }

    modifier onleRedemptionAll {
        require(flag != 0, "Log:MortgagePool:!active");
        _;
    }

    //---------view---------

    // 计算稳定费
    // parassetAssets:债务资产数量
    // blockHeight:上次操作区块
    // rate:抵押率
    function getFee(uint256 parassetAssets, 
    	            uint256 blockHeight,
    	            uint256 rate) public view returns(uint256) {
    	uint256 top = parassetAssets.mul(r0).mul(rate).mul(block.number.sub(blockHeight));
    	uint256 bottom = oneYear.mul(1 ether).mul(1 ether);
    	return top.div(bottom);
    }

    // 计算K线
    // mortgageAssets:抵押资产数量
    // parassetAssets:债务资产数量
    // tokenPrice:抵押资产价格数量
    // pTokenPrice:标的资产价格数量
    // 注意：K线的计算需，债务（parassetAssets）要加上最后一段的稳定费
    function getKLine(uint256 mortgageAssets,
    	              uint256 parassetAssets, 
    	              uint256 tokenPrice, 
    	              uint256 pTokenPrice) public view returns(uint256) {
    	return parassetAssets.mul(k).mul(tokenPrice).mul(1 ether).div(pTokenPrice.mul(mortgageAssets).mul(100));
    }

    // 计算抵押率
    // mortgageAssets:抵押资产数量
    // parassetAssets:债务资产数量
    // tokenPrice:抵押资产价格数量
    // pTokenPrice:p资产价格数量
    function getMortgageRate(uint256 mortgageAssets,
    	                     uint256 parassetAssets, 
    	                     uint256 tokenPrice, 
    	                     uint256 pTokenPrice) public pure returns(uint256) {
    	return parassetAssets.mul(tokenPrice).mul(1 ether).div(pTokenPrice.mul(mortgageAssets));
    }

    // 获取当前债仓实时数据
    // mortgageToken:抵押资产地址
    // pToken:平行资产地址
    // tokenPrice:抵押资产价格数量
    // uTokenPrice:标的资产价格数量
    // maxRateNum:计算参照的最大抵押率
    // 返回：稳定费、抵押率、最大可减少抵押资产数量、最大可新增铸币数量
    function getInfoRealTime(address mortgageToken, 
                             address pToken, 
                             uint256 tokenPrice, 
                             uint256 uTokenPrice,
                             uint256 maxRateNum) public view 
                             returns(uint256 fee, uint256 mortgageRate, uint256 maxSubM, uint256 maxAddP) {
        PersonalLedger memory pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
        uint256 pTokenPrice = getDecimalConversion(pTokenToUnderlying[pToken], uTokenPrice, pToken);
        mortgageRate = getMortgageRate(pLedger.mortgageAssets, 
                                               pLedger.parassetAssets.add(fee), 
                                               tokenPrice,
                                               pTokenPrice);
        if (mortgageRate.mul(100).div(1 ether) >= maxRateNum) {
            maxSubM = 0;
            maxAddP = 0;
        } else {
            maxSubM = pLedger.mortgageAssets.sub(pLedger.parassetAssets.add(fee).mul(tokenPrice).mul(100).div(maxRateNum.mul(pTokenPrice)));
            maxAddP = pTokenPrice.mul(pLedger.mortgageAssets).mul(maxRateNum).div(uint256(100).mul(tokenPrice)).sub(pLedger.parassetAssets.add(fee));
        }
    }


    // 获取预言机费用
    // mortgageToken:抵押资产地址
    // underlyingToken:标的资产地址
    function getPriceFee(address mortgageToken, 
    	                 address underlyingToken) public view returns(uint256) {
    	if (mortgageToken == address(0x0) || underlyingToken == address(0x0)) {
    		return getPriceSingleFee();
    	}
    	return getPriceSingleFee().mul(2);
    }
    
    // 小数转换
    // inputToken:输入资产地址
    // inputTokenAmount:输入资产数量
    // outputToken:输出资产地址
    function getDecimalConversion(address inputToken, 
    	                          uint256 inputTokenAmount, 
    	                          address outputToken) public view returns(uint256) {
    	uint256 inputTokenDec = 18;
    	uint256 outputTokenDec = 18;
    	if (inputToken != address(0x0)) {
    		inputTokenDec = IERC20(inputToken).decimals();
    	}

    	if (outputToken != address(0x0)) {
    		outputTokenDec = IERC20(outputToken).decimals();
    	}
    	return inputTokenAmount.mul(10**outputTokenDec).div(10**inputTokenDec);
    }

    // 查看p资产地址和标的资产地址
    // function getPTokenAddressAndInsAddress(address underlyingToken) 
    // 	public view returns(address pTokenAddress, 
    // 						address insAddress) {
    // 	return (underlyingToPToken[underlyingToken], pTokenToIns[underlyingToPToken[underlyingToken]]);
    // }

    // 查看债仓数据
    function getLedger(address pToken, 
    	               address mortgageToken) 
    	public view returns(uint256 mortgageAssets, 
    		                uint256 parassetAssets, 
    		                uint256 blockHeight,
                            uint256 rate) {
    	PersonalLedger memory pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	return (pLedger.mortgageAssets, pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
    }

    // 查看管理员地址
    function getGovernance() public view returns(address) {
        return governance;
    }

    // 查看保险池地址
    function getInsurancePool() public view returns(address) {
        return address(insurancePool);
    }

    // 查看市场基础利率
    function getR0() public view returns(uint256) {
    	return r0;
    }

    // 查看一年的出块量
    function getOneYear() public view returns(uint256) {
    	return oneYear;
    }

    // 查看k常数
    function getK() public view returns(uint256) {
    	return k;
    }

    // 查看最高抵押率
    function getMaxRate(address mortgageToken) public view returns(uint256) {
    	return maxRate[mortgageToken];
    }

    // 查看清算线
    function clearingLine(address mortgageToken) public view returns(uint256) {
        return maxRate[mortgageToken].add(20).mul(1 ether).div(100);
    }

    // 查看价格合约地址
    function getQuaryAddress() public view returns(address) {
        return address(quary);
    }

    // 查询单次价格调用费
    function getPriceSingleFee() public view returns(uint256) {
        (uint256 fee,,) = quary.params();
        return fee;
    }

    // 根据标的资产查看p资产地址
    function getUnderlyingToPToken(address uToken) public view returns(address) {
        return underlyingToPToken[uToken];
    }

    // 根据p资产查看标的资产地址
    function getPTokenToUnderlying(address pToken) public view returns(address) {
        return pTokenToUnderlying[pToken];
    }

    //---------governance----------

    // 设置状态
    function setFlag(uint8 num) public onlyGovernance {
        flag = num;
    }

    // p资产允许抵押的Token
    // pToken:p资产地址
    // mortgageToken:抵押资产地址
    // allow:是否允许抵押
    function setMortgageAllow(address pToken, 
    	                      address mortgageToken, 
    	                      bool allow) public onlyGovernance {
    	mortgageAllow[pToken][mortgageToken] = allow;
    }

    // 设置保险池合约
    function setInsurancePool(address add) public onlyGovernance {
        insurancePool = IInsurancePool(add);
    }

    // 设置市场基础利率
    function setR0(uint256 num) public onlyGovernance {
    	r0 = num;
    }

    // 设置一年的出块量
    function setOneYear(uint256 num) public onlyGovernance {
    	oneYear = num;
    }

    // 设置k常数
    function setK(uint256 num) public onlyGovernance {
    	k = num;
    }

    // 设置最高抵押率
    function setMaxRate(address token, uint256 num) public onlyGovernance {
    	maxRate[token] = num;
    }

    // 设置价格合约地址
    function setQuaryAddress(address add) public onlyGovernance {
        quary = INestQuery(add);
    }

    // 设置p资产与标的资产、设置保险池
    // token:P资产对应的标的资产，如USDT、ETH
    // pToken:P资产地址
    function setInfo(address token, 
                    address pToken) public onlyGovernance {
        require(underlyingToPToken[token] == address(0x0), "Log:MortgagePool:underlyingToPToken");
        require(address(insurancePool) != address(0x0), "Log:MortgagePool:0x0");
        underlyingToPToken[token] = address(pToken);
        pTokenToUnderlying[address(pToken)] = token;
        insurancePool.setLatestTime(token);
    }

    //---------transaction---------

    // 设置管理员
    function setGovernance() public {
        governance = pTokenFactory.getGovernance();
        require(governance != address(0x0), "Log:MortgagePool:0x0");
    }
    
    // 铸币、再铸币
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // rate:抵押率
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function coin(address mortgageToken, 
                  address pToken, 
                  uint256 amount, 
                  uint256 rate) public payable whenActive {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
        require(rate != 0, "Log:MortgagePool:rate=0");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	// 获取价格
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken]);
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
    	}
    	// 转入抵押token
    	uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
    	if (mortgageToken != address(0x0)) {
    		require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
    		ERC20(mortgageToken).safeTransferFrom(address(msg.sender), address(this), amount);
    	} else {
    		require(msg.value == amount.add(priceFee), "Log:MortgagePool:!msg.value");
    	}
        // 计算铸币资产，增发P资产
        uint256 pTokenAmount = amount.mul(pTokenPrice).mul(rate).div(tokenPrice.mul(100));
        PToken(pToken).issuance(pTokenAmount, address(msg.sender));
        pLedger.mortgageAssets = pLedger.mortgageAssets.add(amount);
        pLedger.parassetAssets = pLedger.parassetAssets.add(pTokenAmount);
        pLedger.blockHeight = block.number;
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
        require(mortgageRate < maxRate[mortgageToken].mul(1 ether).div(100), "Log:MortgagePool:!maxRate");
        pLedger.rate = mortgageRate;
    }
    
    // 新增抵押
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function supplement(address mortgageToken, 
                        address pToken, 
                        uint256 amount) public payable whenActive {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	// 获取价格
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken]);
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
    	}
    	// 转入抵押token
    	uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
    	if (mortgageToken != address(0x0)) {
    		require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
    		ERC20(mortgageToken).safeTransferFrom(address(msg.sender), address(this), amount);
    	} else {
    		require(msg.value == amount.add(priceFee), "Log:MortgagePool:!msg.value");
    	}
    	pLedger.mortgageAssets = pLedger.mortgageAssets.add(amount);
    	pLedger.blockHeight = block.number;
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
        require(mortgageRate < maxRate[mortgageToken].mul(1 ether).div(100), "Log:MortgagePool:!maxRate");
        pLedger.rate = mortgageRate;
    }

    // 提取资产
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function decrease(address mortgageToken, 
                      address pToken, 
                      uint256 amount) public payable whenActive {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	// 获取价格
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken]);
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
    	}
    	uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
    	require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
    	pLedger.mortgageAssets = pLedger.mortgageAssets.sub(amount);
    	pLedger.blockHeight = block.number;
    	uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
        pLedger.rate = mortgageRate;
    	require(mortgageRate < maxRate[mortgageToken].mul(1 ether).div(100), "Log:MortgagePool:!maxRate");
    	// 转出抵押token
    	if (mortgageToken != address(0x0)) {
    		ERC20(mortgageToken).safeTransfer(address(msg.sender), amount);
    	} else {
    		payEth(address(msg.sender), amount);
    	}
    }

    // 新增铸币
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:新增铸币数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function increaseCoinage(address mortgageToken,
                             address pToken,
                             uint256 amount) public payable whenActive {
        require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
        PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        // 获取价格
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken]);
        if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
        }
        uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
        require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
        pLedger.parassetAssets = pLedger.parassetAssets.add(amount);
        pLedger.blockHeight = block.number;
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
        pLedger.rate = mortgageRate;
        require(mortgageRate < maxRate[mortgageToken].mul(1 ether).div(100), "Log:MortgagePool:!maxRate");
        PToken(pToken).issuance(amount, address(msg.sender));
    }

    // 减少铸币
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:减少铸币数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function reducedCoinage(address mortgageToken,
                            address pToken,
                            uint256 amount) public payable whenActive {
        require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
        PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        // 获取价格
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken]);
        if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), amount.add(fee));
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
        }
        uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
        require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
        pLedger.parassetAssets = pLedger.parassetAssets.sub(amount);
        pLedger.blockHeight = block.number;
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
        pLedger.rate = mortgageRate;
        // 销毁p资产
        insurancePool.destroyPToken(pToken, amount, pTokenToUnderlying[pToken]);
    }

    // 赎回抵押
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH。
    // function redemption(address mortgageToken, 
    //                     address pToken, 
    //                     uint256 amount) public payable {
    // 	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    // 	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    // 	uint256 pTokenAmount = amount.mul(pLedger.parassetAssets).div(pLedger.mortgageAssets);
    // 	// 获取价格
    //     (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken]);
    // 	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
    //         // 结算稳定费
    //         uint256 fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
    //         // 转入p资产
    //         ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), pTokenAmount.add(fee));
    //         // 消除负账户
    //         insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
    // 	}
    // 	uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
    // 	require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
    // 	// 销毁p资产
    // 	insurancePool.destroyPToken(pToken, pTokenAmount, pTokenToUnderlying[pToken]);
    // 	// 更新信息
    // 	pLedger.mortgageAssets = pLedger.mortgageAssets.sub(amount);
    // 	if (pLedger.mortgageAssets == 0) {
    // 		pLedger.parassetAssets = 0;
    //     	pLedger.blockHeight = 0;
    //         pLedger.rate = 0;
    // 	} else {
    // 		pLedger.parassetAssets = pLedger.parassetAssets.sub(pTokenAmount);
    //     	pLedger.blockHeight = block.number;
    //         uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
    //         pLedger.rate = mortgageRate;
    // 	}
    // 	// 转出抵押资产
    // 	if (mortgageToken != address(0x0)) {
    // 		ERC20(mortgageToken).safeTransfer(address(msg.sender), amount);
    // 	} else {
    // 		payEth(address(msg.sender), amount);
    // 	}
    // }

    // 赎回全部抵押
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // 注意：mortgageToken为0X0时，抵押资产为ETH。
    function redemptionAll(address mortgageToken, address pToken) public payable onleRedemptionAll {
        require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
        PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), pLedger.parassetAssets.add(fee));
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
        }
        // 销毁p资产
        insurancePool.destroyPToken(pToken, pLedger.parassetAssets, pTokenToUnderlying[pToken]);
        // 更新信息
        uint256 mortgageAssetsAmount = pLedger.mortgageAssets;
        pLedger.mortgageAssets = 0;
        pLedger.parassetAssets = 0;
        pLedger.blockHeight = 0;
        pLedger.rate = 0;
        // 转出抵押资产
        if (mortgageToken != address(0x0)) {
            ERC20(mortgageToken).safeTransfer(address(msg.sender), mortgageAssetsAmount);
        } else {
            payEth(address(msg.sender), mortgageAssetsAmount);
        }
    }

    // 清算
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // account:债仓账户地址
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function liquidation(address mortgageToken, 
                         address pToken,
                         address account) public payable whenActive {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][account];
    	uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
    	require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
    	// 调用预言机，计算p资产数量
    	(uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken]);
    	uint256 pTokenAmount = pLedger.mortgageAssets.mul(pTokenPrice).mul(90).div(tokenPrice.mul(100));
    	// 计算稳定费
    	uint256 fee = 0;
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate);
    	}
    	uint256 kLine = getKLine(pLedger.parassetAssets.add(fee), pLedger.mortgageAssets, tokenPrice, pTokenPrice);
    	require(kLine > clearingLine(mortgageToken), "Log:MortgagePool:!kLine");
    	// 转入P资产
    	ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), pTokenAmount);
    	// 消除负账户
        insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
        // 销毁p资产
    	insurancePool.destroyPToken(pToken, pLedger.parassetAssets, pTokenToUnderlying[pToken]);
    	// 更新信息
    	uint256 mortgageAssets = pLedger.mortgageAssets;
    	pLedger.mortgageAssets = 0;
        pLedger.parassetAssets = 0;
        pLedger.blockHeight = 0;
    	// 转移抵押资产
    	if (mortgageToken != address(0x0)) {
    		ERC20(mortgageToken).safeTransfer(address(msg.sender), mortgageAssets);
    	} else {
    		payEth(address(msg.sender), mortgageAssets);
    	}
    }

    // 转ETH
    // account:转账目标地址
    // asset:资产数量
    function payEth(address account, uint256 asset) private {
        address payable add = account.make_payable();
        add.transfer(asset);
    }

    // 获取价格
    // token:抵押资产地址
    // uToken:标的资产地址
    // tokenPrice:抵押资产Token数量
    // pTokenPrice:p资产Token数量
    function getPriceForPToken(address token, 
                               address uToken) 
        private
        returns (uint256 tokenPrice, 
                 uint256 pTokenPrice) {
        uint256 priceFee = getPriceSingleFee();
        if (token == address(0x0)) {
            (,,uint256 avg,,) = quary.queryPriceAvgVola{value:priceFee}(uToken, address(msg.sender));
            return (1 ether, getDecimalConversion(uToken, avg, underlyingToPToken[uToken]));
        } else if (uToken == address(0x0)) {
            (,,uint256 avg,,) = quary.queryPriceAvgVola{value:priceFee}(token, address(msg.sender));
            return (getDecimalConversion(uToken, avg, underlyingToPToken[uToken]), 1 ether);
        }
        (,,uint256 avg1,,) = quary.queryPriceAvgVola{value:priceFee}(token, address(msg.sender));
        (,,uint256 avg2,,) = quary.queryPriceAvgVola{value:priceFee}(uToken, address(msg.sender));
        return (avg1, getDecimalConversion(uToken, avg2, underlyingToPToken[uToken]));
    }
}