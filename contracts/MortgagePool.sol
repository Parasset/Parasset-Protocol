// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./PToken.sol";
import "./Insurance.sol";
import "./lib/SafeMath.sol";
import './lib/TransferHelper.sol';
import './lib/SafeERC20.sol';
import "./lib/AddressPayable.sol";
import "./iface/INestQuery.sol";
import "./iface/IERC20.sol";

contract MortgagePool {
	using SafeMath for uint256;
	using address_make_payable for address;
	using SafeERC20 for ERC20;

    // 管理员地址
	address public governance;
    // p资产地址=>保险池地址
	mapping(address=>address) pTokenToIns;
	// 标的资产地址=>p资产地址
	mapping(address=>address) underlyingToPToken;
	// p资产地址=>标的资产地址
	mapping(address=>address) pTokenToUnderlying;
    // p资产地址=>抵押资产地址=>bool
	mapping(address=>mapping(address=>bool)) mortgageAllow;
    // p资产=>抵押资产=>用户地址=>债仓数据
	mapping(address=>mapping(address=>mapping(address=>PersonalLedger))) ledger;
    // 保险池地址=>负账户资金数量
	mapping(address=>uint256) insNegative;

	// 市场基础利率，年化2%
	uint256 r0 = 0.02 ether;
	// 一年的出块量
	uint256 oneYear = 2400000;
	// k常数
	uint256 k = 120;
	// 平仓线
	uint256 liquidationLine = 90;
	// 减少抵押线
	uint256 decreaseLine = 70;

	struct PersonalLedger {
        uint256 mortgageAssets;         // 抵押资产数量
        uint256 parassetAssets;         // P资产
        uint256 blockHeight;            // 上次操作区块高度
    }

	constructor () public {
        governance = msg.sender;
    }

    //---------modifier---------

    modifier onlyGovernance() {
        require(msg.sender == governance, "Log:MortgagePool:!gov");
        _;
    }

    //---------view---------

    function strConcat(string memory _a, string memory _b) public pure returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ret = new string(_ba.length + _bb.length);
        bytes memory bret = bytes(ret);
        uint s = 0;
        for (uint i = 0; i < _ba.length; i++) {
            bret[s++] = _ba[i];
        } 
        for (uint i = 0; i < _bb.length; i++) {
            bret[s++] = _bb[i];
        } 
        return string(ret);
    } 

    // 计算稳定费
    // mortgageAssets:抵押资产数量
    // parassetAssets:债务资产数量
    // blockHeight:上次操作区块
    // tokenPrice:抵押资产价格数量
    // uTokenPrice:标的资产价格数量
    function getFee(uint256 mortgageAssets,
    	            uint256 parassetAssets, 
    	            uint256 blockHeight,
    	            uint256 tokenPrice, 
    	            uint256 uTokenPrice) public view returns(uint256) {
    	uint256 top = parassetAssets.mul(r0).mul(parassetAssets).mul(block.number.sub(blockHeight)).mul(tokenPrice);
    	uint256 bottom = oneYear.mul(uTokenPrice).mul(mortgageAssets);
    	return top.div(bottom);
    }

    // 计算K线
    // mortgageAssets:抵押资产数量
    // parassetAssets:债务资产数量
    // tokenPrice:抵押资产价格数量
    // uTokenPrice:标的资产价格数量
    // 注意：K线的计算需，债务（parassetAssets）要加上最后一段的稳定费
    function getKLine(uint256 mortgageAssets,
    	              uint256 parassetAssets, 
    	              uint256 tokenPrice, 
    	              uint256 uTokenPrice) public view returns(uint256) {
    	return parassetAssets.mul(k).mul(tokenPrice).mul(1 ether).div(uTokenPrice.mul(mortgageAssets).mul(100));
    }

    // 计算抵押率
    // mortgageAssets:抵押资产数量
    // parassetAssets:债务资产数量
    // tokenPrice:抵押资产价格数量
    // uTokenPrice:标的资产价格数量
    function getMortgageRate(uint256 mortgageAssets,
    	                     uint256 parassetAssets, 
    	                     uint256 tokenPrice, 
    	                     uint256 uTokenPrice) public pure returns(uint256) {
    	return parassetAssets.mul(tokenPrice).mul(1 ether).div(uTokenPrice.mul(mortgageAssets));
    }

    // 获取预言机费用
    // mortgageToken:抵押资产地址
    // underlyingToken:标的资产地址
    function getPriceFee(address mortgageToken, 
    	                 address underlyingToken) public view returns(uint256) {
    	if (mortgageToken == address(0x0) || underlyingToken == address(0x0)) {
    		return 0.02 ether;
    	}
    	return 0.01 ether;
    }
    
    // 小数转换
    // inputToken:输入资产地址
    // inputTokenAmount:输入资产数量
    // outputToken:输出资产地址
    function getDecimalConversion(address inputToken, 
    	                          uint256 inputTokenAmount, 
    	                          address outputToken) public view returns(uint256) {
    	return inputTokenAmount.mul(10^IERC20(outputToken).decimals()).div(10^IERC20(inputToken).decimals());
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

    // 查看平仓线
    function getLiquidationLine() public view returns(uint256) {
    	return liquidationLine;
    }

    // 查看减少抵押线
    function getDecreaseLine() public view returns(uint256) {
    	return decreaseLine;
    }

    //---------governance----------

    // 设置管理员
    function setGovernance(address add) public onlyGovernance {
    	governance = add;
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

    // 设置平仓线
    function setLiquidationLine(uint256 num) public onlyGovernance {
    	liquidationLine = num;
    }

    // 设置减少抵押线
    function setDecreaseLine(uint256 num) public onlyGovernance {
    	decreaseLine = num;
    }

    //---------transaction---------
    
    // 创建P资产和保险，需要生成PToken合约和对应的保险合约
    // token:P资产对应的标的资产，如USDT、ETH
    // name:P资产Token名称、保险Token名称
    function create(address token, 
    				string memory name) public onlyGovernance {
        require(underlyingToPToken[token] == address(0x0), "Log:MortgagePool:!underlyingToPToken");
        PToken pToken = new PToken(strConcat("P_", name), strConcat("P_", name));
        Insurance ins = new Insurance(strConcat("I_", name), strConcat("I_", name));
        underlyingToPToken[token] = address(pToken);
        pTokenToUnderlying[address(pToken)] = token;
        pTokenToIns[address(pToken)] = address(ins);
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
                  uint256 rate) public payable {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	// 获取价格
        (uint256 tokenAmount, uint256 underlyingAmount) = getPrice(mortgageToken, pTokenToUnderlying[pToken]);
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.mortgageAssets, pLedger.parassetAssets, pLedger.blockHeight, tokenAmount, underlyingAmount);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), fee);
            // 消除负账户
            eliminate(pToken);
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
        uint256 pTokenAmount = amount.mul(underlyingAmount).mul(rate).div(tokenAmount.mul(100));
        PToken(pToken).issuance(pTokenAmount, address(msg.sender));
        pLedger.mortgageAssets = pLedger.mortgageAssets.add(amount);
        pLedger.parassetAssets = pLedger.parassetAssets.add(pTokenAmount);
        pLedger.blockHeight = block.number;
    }
    
    // 补充抵押
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function supplement(address mortgageToken, 
                        address pToken, 
                        uint256 amount) public payable {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	// 获取价格
        (uint256 tokenAmount, uint256 underlyingAmount) = getPrice(mortgageToken, pTokenToUnderlying[pToken]);
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.mortgageAssets, pLedger.parassetAssets, pLedger.blockHeight, tokenAmount, underlyingAmount);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), fee);
            // 消除负账户
            eliminate(pToken);
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
    }

    // 减少抵押
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function decrease(address mortgageToken, 
                      address pToken, 
                      uint256 amount) public payable {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	// 获取价格
        (uint256 tokenAmount, uint256 underlyingAmount) = getPrice(mortgageToken, pTokenToUnderlying[pToken]);
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.mortgageAssets, pLedger.parassetAssets, pLedger.blockHeight, tokenAmount, underlyingAmount);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), fee);
            // 消除负账户
            eliminate(pToken);
    	}
    	uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
    	require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
    	pLedger.mortgageAssets = pLedger.mortgageAssets.sub(amount);
    	pLedger.blockHeight = block.number;
    	uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenAmount, underlyingAmount);
    	require(mortgageRate < decreaseLine.mul(1 ether).div(100), "Log:MortgagePool:!decreaseLine");
    	// 转出抵押token
    	if (mortgageToken != address(0x0)) {
    		ERC20(mortgageToken).safeTransfer(address(msg.sender), amount);
    	} else {
    		payEth(address(msg.sender), amount);
    	}
    }

    // 赎回抵押
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // amount:抵押资产数量
    // 注意：mortgageToken为0X0时，抵押资产为ETH。优先赎回标的资产，标的资产不够时赎回p资产
    function redemption(address mortgageToken, 
                        address pToken, 
                        uint256 amount) public payable {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
    	uint256 pTokenAmount = amount.mul(pLedger.parassetAssets).div(pLedger.mortgageAssets);
    	// 获取价格
        (uint256 tokenAmount, uint256 underlyingAmount) = getPrice(mortgageToken, pTokenToUnderlying[pToken]);
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            // 结算稳定费
            uint256 fee = getFee(pLedger.mortgageAssets, pLedger.parassetAssets, pLedger.blockHeight, tokenAmount, underlyingAmount);
            // 转入p资产
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), pTokenAmount.add(fee));
            // 消除负账户
            eliminate(pToken);
    	}
    	uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
    	require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
    	// 销毁p资产
    	destroyPToken(pToken, pTokenAmount);
    	// 更新信息
    	pLedger.mortgageAssets = pLedger.mortgageAssets.sub(amount);
    	if (pLedger.mortgageAssets == 0) {
    		pLedger.parassetAssets = 0;
        	pLedger.blockHeight = 0;
    	} else {
    		pLedger.parassetAssets = pLedger.parassetAssets.sub(pTokenAmount);
        	pLedger.blockHeight = block.number;
    	}
    	// 转出抵押资产
    	if (mortgageToken != address(0x0)) {
    		ERC20(mortgageToken).safeTransfer(address(msg.sender), amount);
    	} else {
    		payEth(address(msg.sender), amount);
    	}
    }

    // 清算
    // mortgageToken:抵押资产地址
    // pToken:p资产地址
    // account:债仓账户地址
    // 注意：mortgageToken为0X0时，抵押资产为ETH
    function liquidation(address mortgageToken, 
                         address pToken,
                         address account) public payable {
    	require(mortgageAllow[pToken][mortgageToken] == true, "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][account];
    	uint256 priceFee = getPriceFee(mortgageToken, pTokenToUnderlying[pToken]);
    	require(msg.value == priceFee, "Log:MortgagePool:msg.value!=priceFee");
    	// 调用预言机，计算p资产数量
    	(uint256 tokenAmount, uint256 underlyingAmount) = getPrice(mortgageToken, pTokenToUnderlying[pToken]);
    	uint256 pTokenAmount = pLedger.mortgageAssets.mul(underlyingAmount).mul(90).div(tokenAmount.mul(100));
    	// 计算稳定费
    	uint256 fee = 0;
    	if (pLedger.parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            fee = getFee(pLedger.mortgageAssets, pLedger.parassetAssets, pLedger.blockHeight, tokenAmount, underlyingAmount);
    	}
    	uint256 kLine = getKLine(pLedger.parassetAssets.add(fee), pLedger.mortgageAssets, tokenAmount, underlyingAmount);
    	require(kLine > liquidationLine.mul(1 ether).div(100), "Log:MortgagePool:!kLine");
    	// 转入P资产
    	ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), pTokenAmount);
    	// 消除负账户
        eliminate(pToken);
        // 销毁p资产
    	destroyPToken(pToken, pLedger.parassetAssets);
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

    // 兑换，p资产换标的资产
    // pToken:pToken地址
    // amount:pToken数量
    function exchangePTokenToUnderlying(address pToken, 
    	                                uint256 amount) public {
    	uint256 fee = amount.mul(2).div(1000);
    	ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), amount.add(fee));
        address underlyingToken = pTokenToUnderlying[pToken];
    	if (underlyingToken != address(0x0)) {
    		ERC20(underlyingToken).safeTransfer(address(msg.sender), getDecimalConversion(pToken, amount, underlyingToken));
    	} else {
    		payEth(address(msg.sender), getDecimalConversion(pToken, amount, underlyingToken));
    	}
    	// 消除负账户
        eliminate(pToken);
    }

    // 兑换，标的资产换p资产
    // token:标的资产地址
    // amount:标的资产数量
    function exchangeUnderlyingToPToken(address token, 
    	                                uint256 amount) public payable {
    	uint256 fee = amount.mul(2).div(1000);
    	if (token != address(0x0)) {
    		require(msg.value == 0, "Log:MortgagePool:msg.value!=0");
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), amount.add(fee));
    	} else {
    		require(msg.value == amount.add(fee), "Log:MortgagePool:!msg.value");
    	}
    	address pToken = underlyingToPToken[token];
    	ERC20(pToken).safeTransfer(address(msg.sender), getDecimalConversion(token, amount, pToken));
    }

    // 认购保险
    // token:标的资产地址，USDT、ETH...
    // amount:标的资产数量
    function subscribeIns(address token, 
    	                  uint256 amount) public payable {
    	require(underlyingToPToken[token] != address(0x0), "Log:MortgagePool:!underlyingToPToken");
    	uint256 tokenBalance;
    	address pToken = underlyingToPToken[token];
    	uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
    	if (token != address(0x0)) {
    		tokenBalance = ERC20(token).balanceOf(address(this));
    	} else {
    		require(msg.value == amount, "Log:MortgagePool:!msg.value");
    		tokenBalance = address(this).balance;
    	}
    	uint256 allValue = tokenBalance.add(pTokenBalance).sub(insNegative[pTokenToIns[pToken]]);
    	Insurance ins = Insurance(pTokenToIns[pToken]);
    	uint256 insAmount = amount;
    	uint256 insTotal = ins.totalSupply();
    	if (insTotal != 0) {
    		insAmount = amount.mul(insTotal).div(allValue);
    	}
    	// 转入标的资产
    	if (token != address(0x0)) {
    		require(msg.value == 0, "Log:MortgagePool:msg.value!=0");
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), amount);
    	}
    	// 增发份额
    	ins.issuance(insAmount, address(msg.sender));
    }

    // 赎回保险
    // token:标的资产地址，USDT、ETH...
    // amount:赎回份额
    function redemptionIns(address token, 
    	                   uint256 amount) public {
    	require(underlyingToPToken[token] != address(0x0), "Log:MortgagePool:!underlyingToPToken");
    	uint256 tokenBalance;
    	address pToken = underlyingToPToken[token];
    	uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
    	if (token != address(0x0)) {
    		tokenBalance = ERC20(token).balanceOf(address(this));
    	} else {
    		tokenBalance = address(this).balance;
    	}
    	uint256 allValue = tokenBalance.add(pTokenBalance).sub(insNegative[pTokenToIns[pToken]]);
    	Insurance ins = Insurance(pTokenToIns[pToken]);
    	uint256 insTotal = ins.totalSupply();
    	uint256 underlyingAmount = amount.mul(allValue).div(insTotal);
    	
    	// 转出标的资产
    	if (token != address(0x0)) {
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), underlyingAmount);
    	} else {
    		payEth(address(msg.sender), underlyingAmount);
    	}
    	// 销毁份额
    	ins.destroy(amount, address(msg.sender));
    }

    // 销毁P资产，更新负账户
    // pToken:p资产地址
    // amount:销毁数量
    function destroyPToken(address pToken, 
    	                   uint256 amount) internal {
    	PToken pErc20 = PToken(pToken);
    	uint256 pTokenBalance = pErc20.balanceOf(address(this));
    	if (pTokenBalance >= amount) {
    		pErc20.destroy(amount, address(this));
    	} else {
    		pErc20.destroy(pTokenBalance, address(this));
    		// 记录负账户
    		insNegative[pTokenToIns[pToken]] = insNegative[pTokenToIns[pToken]].add(amount.sub(pTokenBalance));
    	}
    }

    // 消除负账户
    // pToken:p资产地址
    function eliminate(address pToken) internal {
    	PToken pErc20 = PToken(pToken);
    	uint256 negative = insNegative[pTokenToIns[pToken]];
    	uint256 pTokenBalance = pErc20.balanceOf(address(this)); 
    	if (negative > 0 && pTokenBalance > 0) {
    		if (negative >= pTokenBalance) {
    			insNegative[pTokenToIns[pToken]] = insNegative[pTokenToIns[pToken]].sub(pTokenBalance);
    			pErc20.destroy(pTokenBalance, address(this));
    		} else {
    			insNegative[pTokenToIns[pToken]] = 0;
    			pErc20.destroy(insNegative[pTokenToIns[pToken]], address(this));
    		}
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
    // uTokenPrice:标的资产Token数量
    function getPrice(address token, 
    	              address uToken) 
    public 
    returns (uint256 tokenPrice, 
    	     uint256 uTokenPrice) {
    	return (uint256(1 ether), uint256(1000000));

    }
}