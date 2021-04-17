// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./PToken.sol";
import "./lib/SafeMath.sol";
import './lib/TransferHelper.sol';
import './lib/SafeERC20.sol';
import "./lib/AddressPayable.sol";
import "./iface/IERC20.sol";
import "./iface/IInsurancePool.sol";
import "./iface/IPTokenFactory.sol";
import "./iface/IPriceController.sol";
import "./lib/ReentrancyGuard.sol";

contract MortgagePool is ReentrancyGuard {
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
    // p资产=>抵押资产=>创建过债仓的地址
    mapping(address=>mapping(address=>address[])) ledgerArray;
    // 抵押资产=>最高抵押率
    mapping(address=>uint256) maxRate;
    // 抵押资产=>k
    mapping(address=>uint256) k;
    // 价格合约
    IPriceController quary;
    // 保险池合约
    IInsurancePool insurancePool;
    // 工厂合约地址
    IPTokenFactory pTokenFactory;
	// 市场基础利率，年化2%
	uint256 r0 = 0.02 ether;
	// 一年的出块量
	uint256 oneYear = 2400000;
    // 状态
    uint8 public flag;      // = 0: 停止
                            // = 1: 启动
                            // = 2: 只能全部赎回

	struct PersonalLedger {
        uint256 mortgageAssets;         // 抵押资产数量
        uint256 parassetAssets;         // P资产
        uint256 blockHeight;            // 上次操作区块高度
        uint256 rate;                   // 抵押率
        bool created;                   // 是否创建
    }

    event FeeValue(address pToken, uint256 value);

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
    	            uint256 rate,
                    uint256 nowRate) public view returns(uint256) {
        uint256 topOne = parassetAssets.mul(r0).mul(block.number.sub(blockHeight));
        uint256 ratePlus = rate.add(nowRate);
        uint256 topTwo = parassetAssets.mul(r0).mul(block.number.sub(blockHeight)).mul(uint256(3).mul(ratePlus));
    	uint256 bottom = oneYear.mul(1 ether);
    	return topOne.div(bottom).add(topTwo.div(bottom.mul(1 ether).mul(2)));
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
        if (mortgageAssets == 0 || pTokenPrice == 0) {
            return 0;
        }
    	return parassetAssets.mul(tokenPrice).mul(1 ether).div(pTokenPrice.mul(mortgageAssets));
    }

    // 获取当前债仓实时数据
    // mortgageToken:抵押资产地址
    // pToken:平行资产地址
    // tokenPrice:抵押资产价格数量
    // uTokenPrice:标的资产价格数量
    // maxRateNum:计算参照的最大抵押率
    // owner:查询用户地址
    // 返回：稳定费、抵押率、最大可减少抵押资产数量、最大可新增铸币数量
    function getInfoRealTime(address mortgageToken, 
                             address pToken, 
                             uint256 tokenPrice, 
                             uint256 uTokenPrice,
                             uint256 maxRateNum,
                             uint256 owner) public view returns(uint256 fee, 
                                                                uint256 mortgageRate, 
                                                                uint256 maxSubM, 
                                                                uint256 maxAddP) {
        PersonalLedger memory pLedger = ledger[pToken][mortgageToken][address(owner)];
        if (pLedger.mortgageAssets == 0 && pLedger.parassetAssets == 0) {
            return (0,0,0,0);
        }
        uint256 pTokenPrice = getDecimalConversion(pTokenToUnderlying[pToken], uTokenPrice, pToken);
        uint256 tokenPriceAmount = tokenPrice;
        fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate, getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPriceAmount, pTokenPrice));
        mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets.add(fee), tokenPriceAmount, pTokenPrice);
        uint256 maxRateEther = maxRateNum.mul(0.01 ether);
        if (mortgageRate >= maxRateEther) {
            maxSubM = 0;
            maxAddP = 0;
        } else {
            maxSubM = pLedger.mortgageAssets.sub(pLedger.parassetAssets.add(fee).mul(tokenPriceAmount).mul(1 ether).div(maxRateEther.mul(pTokenPrice)));
            maxAddP = pLedger.mortgageAssets.mul(pTokenPrice).mul(maxRateEther).div(uint256(1 ether).mul(tokenPriceAmount)).sub(pLedger.parassetAssets.add(fee));
        }
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

    // 查看债仓数据
    function getLedger(address pToken, 
    	               address mortgageToken,
                       address owner) public view returns(uint256 mortgageAssets, 
    		                                              uint256 parassetAssets, 
    		                                              uint256 blockHeight,
                                                          uint256 rate,
                                                          bool created,
                                                          uint256 kLine) {
    	PersonalLedger memory pLedger = ledger[pToken][mortgageToken][address(owner)];
    	return (pLedger.mortgageAssets, pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate, pLedger.created, getKLine(pLedger.rate, mortgageToken));
    }

    // 查看管理员地址
    function getGovernance() external view returns(address) {
        return governance;
    }

    // 查看保险池地址
    function getInsurancePool() external view returns(address) {
        return address(insurancePool);
    }

    // 查看市场基础利率
    function getR0() external view returns(uint256) {
    	return r0;
    }

    // 查看一年的出块量
    function getOneYear() external view returns(uint256) {
    	return oneYear;
    }

    // 查看最高抵押率
    function getMaxRate(address mortgageToken) external view returns(uint256) {
    	return maxRate[mortgageToken];
    }

    // 查看k
    function getK(address mortgageToken) external view returns(uint256) {
        return k[mortgageToken];
    }

    // 查看价格合约地址
    function getPriceController() external view returns(address) {
        return address(quary);
    }

    // 根据标的资产查看p资产地址
    function getUnderlyingToPToken(address uToken) external view returns(address) {
        return underlyingToPToken[uToken];
    }

    // 根据p资产查看标的资产地址
    function getPTokenToUnderlying(address pToken) external view returns(address) {
        return pTokenToUnderlying[pToken];
    }

    // 债仓数组长度
    function getLedgerArrayNum(address pToken, 
                               address mortgageToken) external view returns(uint256) {
        return ledgerArray[pToken][mortgageToken].length;
    }

    // 查看创建债仓地址
    function getLedgerAddress(address pToken, 
                              address mortgageToken, 
                              uint256 index) external view returns(address) {
        return ledgerArray[pToken][mortgageToken][index];
    }

    // 查看清算线
    function getKLine(uint256 rate, address mortgageToken) public view returns(uint256) {
        return rate.mul(k[mortgageToken]).div(1000);
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

    // 设置清算线
    function setK(address mortgageToken, 
                  uint256 num) public onlyGovernance {
        k[mortgageToken] = num;
    }

    // 设置最高抵押率
    function setMaxRate(address token, 
                        uint256 num) public onlyGovernance {
    	maxRate[token] = num.mul(0.01 ether);
    }

    // 设置价格合约地址
    function setPriceController(address add) public onlyGovernance {
        quary = IPriceController(add);
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
                  uint256 rate) public payable whenActive nonReentrant {
    	require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        require(rate > 0 && rate <= maxRate[mortgageToken], "Log:MortgagePool:rate!=0");
        require(amount > 0, "Log:MortgagePool:amount!=0");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	// 获取价格
        uint256 tokenPrice;
        uint256 pTokenPrice;
        // 转入抵押token
        if (mortgageToken != address(0x0)) {
            ERC20(mortgageToken).safeTransferFrom(address(msg.sender), address(this), amount);
            (tokenPrice, pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], msg.value);
        } else {
            require(msg.value >= amount, "Log:MortgagePool:!msg.value");
            (tokenPrice, pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], uint256(msg.value).sub(amount));
        }
        uint256 blockHeight = pLedger.blockHeight;
        uint256 parassetAssets = pLedger.parassetAssets;
        // 判断当前抵押率不能超过清算线
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
        require(mortgageRate <= getKLine(pLedger.rate, mortgageToken), "Log:MortgagePool:!line");
    	if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(parassetAssets, blockHeight, pLedger.rate, mortgageRate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
            emit FeeValue(pToken, fee);
    	}
        // 计算铸币资产，增发P资产
        uint256 pTokenAmount = amount.mul(pTokenPrice).mul(rate).div(tokenPrice.mul(100));
        PToken(pToken).issuance(pTokenAmount, address(msg.sender));
        pLedger.mortgageAssets = pLedger.mortgageAssets.add(amount);
        pLedger.parassetAssets = parassetAssets.add(pTokenAmount);
        pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
        if (pLedger.created == false) {
            ledgerArray[pToken][mortgageToken].push(address(msg.sender));
            pLedger.created = true;
        }
    }
    
    // 新增抵押
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function supplement(address mortgageToken, 
                        address pToken, 
                        uint256 amount) public payable whenActive {
    	require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        require(amount > 0, "Log:MortgagePool:!amount");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        require(pLedger.created, "Log:MortgagePool:!created");
    	// 获取价格
        uint256 tokenPrice;
        uint256 pTokenPrice;
        // 转入抵押token
        if (mortgageToken != address(0x0)) {
            ERC20(mortgageToken).safeTransferFrom(address(msg.sender), address(this), amount);
            (tokenPrice, pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], msg.value);
        } else {
            require(msg.value >= amount, "Log:MortgagePool:!msg.value");
            (tokenPrice, pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], uint256(msg.value).sub(amount));
        }
        uint256 blockHeight = pLedger.blockHeight;
        uint256 parassetAssets = pLedger.parassetAssets;
        // 判断当前抵押率不能超过清算线
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
        require(mortgageRate <= getKLine(pLedger.rate, mortgageToken), "Log:MortgagePool:!line");
    	if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(parassetAssets, blockHeight, pLedger.rate, mortgageRate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
            emit FeeValue(pToken, fee);
    	}
    	pLedger.mortgageAssets = pLedger.mortgageAssets.add(amount);
    	pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
    }

    // 提取资产
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function decrease(address mortgageToken, 
                      address pToken, 
                      uint256 amount) public payable whenActive nonReentrant {
    	require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        require(amount > 0, "Log:MortgagePool:!amount");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        require(pLedger.created, "Log:MortgagePool:!created");
    	// 获取价格
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], msg.value);
        uint256 blockHeight = pLedger.blockHeight;
        uint256 parassetAssets = pLedger.parassetAssets;
        // 判断当前抵押率不能超过清算线
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
        require(mortgageRate <= getKLine(pLedger.rate, mortgageToken), "Log:MortgagePool:!line");
    	if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(parassetAssets, blockHeight, pLedger.rate, mortgageRate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
            emit FeeValue(pToken, fee);
    	}
    	pLedger.mortgageAssets = pLedger.mortgageAssets.sub(amount);
    	pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
    	require(pLedger.rate <= maxRate[mortgageToken], "Log:MortgagePool:!maxRate");
    	// 转出抵押token
    	if (mortgageToken != address(0x0)) {
    		ERC20(mortgageToken).safeTransfer(address(msg.sender), amount);
    	} else {
            TransferHelper.safeTransferETH(address(msg.sender), amount);
    	}
    }

    // 新增铸币
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:新增铸币数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function increaseCoinage(address mortgageToken,
                             address pToken,
                             uint256 amount) public payable whenActive nonReentrant {
        require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        require(amount > 0, "Log:MortgagePool:!amount");
        PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        require(pLedger.created, "Log:MortgagePool:!created");
        // 获取价格
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], msg.value);
        uint256 blockHeight = pLedger.blockHeight;
        uint256 parassetAssets = pLedger.parassetAssets;
        // 判断当前抵押率不能超过清算线
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
        require(mortgageRate <= getKLine(pLedger.rate, mortgageToken), "Log:MortgagePool:!line");
        if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(parassetAssets, blockHeight, pLedger.rate, mortgageRate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // 消除负账户
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
            emit FeeValue(pToken, fee);
        }
        pLedger.parassetAssets = parassetAssets.add(amount);
        pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
        require(pLedger.rate <= maxRate[mortgageToken], "Log:MortgagePool:!maxRate");
        PToken(pToken).issuance(amount, address(msg.sender));
    }

    // 减少铸币
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:减少铸币数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function reducedCoinage(address mortgageToken,
                            address pToken,
                            uint256 amount) public payable whenActive nonReentrant {
        require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        uint256 parassetAssets = pLedger.parassetAssets;
        require(amount > 0 && amount <= parassetAssets, "Log:MortgagePool:!amount");
        require(pLedger.created, "Log:MortgagePool:!created");
        address uToken = pTokenToUnderlying[pToken];
        // 获取价格
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, uToken, msg.value);
        uint256 blockHeight = pLedger.blockHeight;
        // 判断当前抵押率不能超过清算线
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
        require(mortgageRate <= getKLine(pLedger.rate, mortgageToken), "Log:MortgagePool:!line");
        if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(parassetAssets, blockHeight, pLedger.rate, mortgageRate);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), amount.add(fee));
            // 消除负账户
            insurancePool.eliminate(pToken, uToken);
            emit FeeValue(pToken, fee);
        }
        pLedger.parassetAssets = parassetAssets.sub(amount);
        pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);
        // 销毁p资产
        insurancePool.destroyPToken(pToken, amount, uToken);
    }

    // // 赎回全部抵押
    // // mortgageToken:抵押资产地址
    // // pToken:p资产地址
    // // 注意：mortgageToken为0X0时，抵押资产为ETH。
    // function redemptionAll(address mortgageToken, 
    //                        address pToken) public onleRedemptionAll nonReentrant {
    //     require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
    //     PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    //     require(pLedger.created, "Log:MortgagePool:!created");
    //     address uToken = pTokenToUnderlying[pToken];
    //     uint256 blockHeight = pLedger.blockHeight;
    //     uint256 parassetAssets = pLedger.parassetAssets;
    //     if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
    //         // 结算稳定费
    //         uint256 fee = getFee(parassetAssets, blockHeight, pLedger.rate);
    //         // 转入p资产
    //         ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), parassetAssets.add(fee));
    //         // 消除负账户
    //         insurancePool.eliminate(pToken, uToken);
    //         emit FeeValue(pToken, fee);
    //     }
    //     // 销毁p资产
    //     insurancePool.destroyPToken(pToken, parassetAssets, uToken);
    //     // 更新信息
    //     uint256 mortgageAssetsAmount = pLedger.mortgageAssets;
    //     pLedger.mortgageAssets = 0;
    //     pLedger.parassetAssets = 0;
    //     pLedger.blockHeight = 0;
    //     pLedger.rate = 0;
    //     // 转出抵押资产
    //     if (mortgageToken != address(0x0)) {
    //         ERC20(mortgageToken).safeTransfer(address(msg.sender), mortgageAssetsAmount);
    //     } else {
    //         TransferHelper.safeTransferETH(address(msg.sender), mortgageAssetsAmount);
    //     }
    // }

    // 清算
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // account:债仓账户地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function liquidation(address mortgageToken, 
                         address pToken,
                         address account,
                         uint256 amount) public payable whenActive nonReentrant {
    	require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][account];
        require(pLedger.created, "Log:MortgagePool:!created");
    	// 调用预言机，计算p资产数量
        address uToken = pTokenToUnderlying[pToken];
    	(uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, uToken, msg.value);
    	// 计算稳定费
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;
        uint256 pTokenAmount = amount.mul(pTokenPrice).mul(90).div(tokenPrice.mul(100));
        require(amount > 0 && amount <= mortgageAssets, "Log:MortgagePool:!amount");
        // 判断清算线
        checkLine(pLedger, tokenPrice, pTokenPrice, mortgageToken);
    	// 转入P资产
    	ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), pTokenAmount);
    	// 消除负账户
        insurancePool.eliminate(pToken, uToken);
        // 计算抵消的债务
        uint256 offset = parassetAssets.mul(amount).div(mortgageAssets);
        // 销毁p资产
    	insurancePool.destroyPToken(pToken, offset, uToken);
    	// 更新信息
    	pLedger.mortgageAssets = mortgageAssets.sub(amount);
        pLedger.parassetAssets = parassetAssets.sub(offset);
        if (pLedger.parassetAssets == 0) {
            pLedger.blockHeight = 0;
            pLedger.rate = 0;
        }
    	// 转移抵押资产
    	if (mortgageToken != address(0x0)) {
    		ERC20(mortgageToken).safeTransfer(address(msg.sender), amount);
    	} else {
            TransferHelper.safeTransferETH(address(msg.sender), amount);
    	}
    }

    function checkLine(PersonalLedger memory pLedger, uint256 tokenPrice, uint256 pTokenPrice, address mortgageToken) private view {
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;
        // 判断当前抵押率不能超过清算线
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
        uint256 fee = 0;
        if (parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            fee = getFee(parassetAssets, pLedger.blockHeight, pLedger.rate, mortgageRate);
        }
        uint256 kLineNum = getKLine(pLedger.rate, mortgageToken);
        require(getMortgageRate(mortgageAssets, parassetAssets.add(fee), tokenPrice, pTokenPrice) > kLineNum, "Log:MortgagePool:!line");
    }

    // 获取价格
    // token:抵押资产地址
    // uToken:标的资产地址
    // priceValue:价格费用
    // tokenPrice:抵押资产Token数量
    // pTokenPrice:p资产Token数量
    function getPriceForPToken(address token, 
                               address uToken,
                               uint256 priceValue) private returns (uint256 tokenPrice, 
                                                                    uint256 pTokenPrice) {
        (tokenPrice, pTokenPrice) = quary.getPriceForPToken{value:priceValue}(token, uToken, msg.sender);   
    }
}