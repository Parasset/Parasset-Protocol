// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "./lib/SafeMath.sol";
import './lib/TransferHelper.sol';
import './lib/SafeERC20.sol';
import "./lib/AddressPayable.sol";
import "./iface/IERC20.sol";
import "./iface/IMortgagePool.sol";
import "./PToken.sol";
import "./iface/IPTokenFactory.sol";

contract InsurancePool {
	using SafeMath for uint256;
	using address_make_payable for address;
	using SafeERC20 for ERC20;

	// 管理员地址
	address public governance;
	// 标的资产地址=>负账户资金数量
	mapping(address=>uint256) insNegative;
	// LP总量,标的资产=>LP总量
	mapping(address=>uint256) totalSupply;
	// 个人LP,个人地址=>标的资产地址=>LP数量
	mapping(address=>mapping(address=>uint256)) balances;
	// 最新赎回节点, 标的资产地址=>最新赎回时间
    mapping(address=>uint256) latestTime;
	// 赎回周期
	uint256 redemptionCycle = 5 minutes;
	// 等待周期
	uint256 waitCycle = 10 minutes;
	// 冻结保险份额,用户地址=>标的资产地址=>冻结份额数据
	mapping(address=>mapping(address=>Frozen)) frozenIns;
	struct Frozen {
		uint256 amount;							//	冻结数量
		uint256 time;							//  冻结时间
	}
    // 保险池地址
    IMortgagePool mortgagePool;
    // 工厂合约地址
    IPTokenFactory pTokenFactory;
    // 状态
    uint8 public flag;      // = 0: 停止
                            // = 1: 启动

    event Destroy(address token, uint256 amount, address account);
    event Issuance(address token, uint256 amount, address account);

	constructor (address factoryAddress) public {
        pTokenFactory = IPTokenFactory(factoryAddress);
        governance = pTokenFactory.getGovernance();
        flag = 0;
    }

	//---------modifier---------

    modifier onlyGovernance() {
        require(msg.sender == governance, "Log:InsurancePool:!gov");
        _;
    }

    modifier onlyMortgagePool() {
        require(msg.sender == address(mortgagePool), "Log:InsurancePool:!mortgagePool");
        _;
    }

    modifier whenActive() {
        require(flag == 1, "Log:InsurancePool:!active");
        _;
    }

    //---------view---------

    // 查询管理员地址
    function getGovernance() public view returns(address) {
        return governance;
    }

    // 查询负账户
    function getInsNegative(address token) public view returns(uint256) {
        return insNegative[token];
    }

    // 查询LP总量
    function getTotalSupply(address token) public view returns(uint256) {
        return totalSupply[token];
    }

    // 查询个人LP
    function getBalances(address token, address add) public view returns(uint256) {
        return balances[add][token];
    }

    // 查询保险池地址
    function getMortgagePool() public view returns(address) {
        return address(mortgagePool);
    }

    // 查询最新赎回时间
    function getLatestTime(address token) public view returns(uint256) {
        return latestTime[token];
    }

    // 查询赎回时间段-实时
    function getRedemptionTime(address token) public view returns(uint256 startTime, uint256 endTime) {
        uint256 time = latestTime[token];
        if (now > time) {
            uint256 subTime = now.sub(time).div(waitCycle);
            startTime = time.add(waitCycle.mul(uint256(1).add(subTime)));
        } else {
            startTime = time;
        }
        endTime = startTime.add(redemptionCycle);
    }

    // 查询被冻结份额及解冻时间
    function getFrozenIns(address token, address add) public view returns(uint256, uint256) {
        Frozen memory frozenInfo = frozenIns[add][token];
        return (frozenInfo.amount, frozenInfo.time);
    }

    // 查询被冻结份额实时（in time）
    function getFrozenInsInTime(address token, address add) public view returns(uint256) {
        Frozen memory frozenInfo = frozenIns[add][token];
        if (now > frozenInfo.time) {
            return 0;
        }
        return frozenInfo.amount;
    }

    // 查询可赎回份额实时
    function getRedemptionAmount(address token, address add) public view returns (uint256) {
        Frozen memory frozenInfo = frozenIns[add][token];
        uint256 balanceSelf = balances[add][token];
        if (now > frozenInfo.time) {
            return balanceSelf;
        } else {
            return balanceSelf.sub(frozenInfo.amount);
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

    //---------governance----------

    // 设置状态
    function setFlag(uint8 num) public onlyGovernance {
        flag = num;
    }

    // 设置抵押池地址
    function setMortgagePool(address add) public onlyGovernance {
    	mortgagePool = IMortgagePool(add);
    }

    // 设置最新赎回节点
    function setLatestTime(address token) public onlyMortgagePool {
        latestTime[token] = now.add(waitCycle);
    }

    //---------transaction---------

    // 设置管理员
    function setGovernance() public {
        governance = pTokenFactory.getGovernance();
    }

	// 兑换，p资产换标的资产
    // pToken:pToken地址
    // amount:pToken数量
    function exchangePTokenToUnderlying(address pToken, 
    	                                uint256 amount) public whenActive {
    	uint256 fee = amount.mul(2).div(1000);
    	ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), amount);
        address underlyingToken = mortgagePool.getPTokenToUnderlying(pToken);
    	if (underlyingToken != address(0x0)) {
    		ERC20(underlyingToken).safeTransfer(address(msg.sender), getDecimalConversion(pToken, amount.sub(fee), underlyingToken));
    	} else {
    		payEth(address(msg.sender), getDecimalConversion(pToken, amount.sub(fee), underlyingToken));
    	}
    	// 消除负账户
        _eliminate(pToken, underlyingToken);
    }

    // 兑换，标的资产换p资产
    // token:标的资产地址
    // amount:标的资产数量
    function exchangeUnderlyingToPToken(address token, 
    	                                uint256 amount) public payable whenActive {
    	uint256 fee = amount.mul(2).div(1000);
    	if (token != address(0x0)) {
    		require(msg.value == 0, "Log:InsurancePool:msg.value!=0");
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), amount);
    	} else {
    		require(msg.value == amount, "Log:InsurancePool:!msg.value");
    	}
    	address pToken = mortgagePool.getUnderlyingToPToken(token);
        uint256 pTokenAmount = getDecimalConversion(token, amount.sub(fee), pToken);
        uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
        if (pTokenBalance < pTokenAmount) {
            uint256 subNum = pTokenAmount.sub(pTokenBalance);
            PToken(pToken).issuance(subNum, address(this));
            insNegative[token] = insNegative[token].add(subNum);
        }
    	ERC20(pToken).safeTransfer(address(msg.sender), pTokenAmount);
    }

    // 认购保险
    // token:标的资产地址，USDT、ETH...
    // amount:标的资产数量
    function subscribeIns(address token, 
    	                  uint256 amount) public payable whenActive {
        uint256 tokenBalance;
        address pToken = mortgagePool.getUnderlyingToPToken(token);
        require(pToken != address(0x0), "Log:InsurancePool:!pToken");
    	updateLatestTime(token);
    	Frozen storage frozenInfo = frozenIns[address(msg.sender)][token];
    	if (now > frozenInfo.time) {
    		frozenInfo.amount = 0;
    	}
    	uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
    	if (token != address(0x0)) {
    		tokenBalance = ERC20(token).balanceOf(address(this));
    	} else {
    		require(msg.value == amount, "Log:InsurancePool:!msg.value");
    		tokenBalance = address(this).balance;
    	}
    	uint256 insAmount = getDecimalConversion(token, amount, pToken);
    	uint256 insTotal = totalSupply[token];
    	if (insTotal != 0 && tokenBalance.add(pTokenBalance) > insNegative[token]) {
            uint256 allValue = tokenBalance.add(pTokenBalance).sub(insNegative[token]);
    		insAmount = getDecimalConversion(token, amount, pToken).mul(insTotal).div(allValue);
    	}
    	// 转入标的资产
    	if (token != address(0x0)) {
    		require(msg.value == 0, "Log:InsurancePool:msg.value!=0");
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), amount);
    	}
    	// 增发份额
    	issuance(token, insAmount, address(msg.sender));
    	// 冻结保险份额
    	frozenInfo.amount = frozenInfo.amount.add(insAmount);
    	frozenInfo.time = latestTime[token];
    }

    // 赎回保险
    // token:标的资产地址，USDT、ETH...
    // amount:赎回份额
    function redemptionIns(address token, 
    	                   uint256 amount) public whenActive {
        uint256 tokenBalance;
        address pToken = mortgagePool.getUnderlyingToPToken(token);
    	updateLatestTime(token);
    	require(now >= latestTime[token].sub(waitCycle) && now <= latestTime[token].sub(waitCycle).add(redemptionCycle), "Log:InsurancePool:!time");
    	Frozen storage frozenInfo = frozenIns[address(msg.sender)][token];
    	if (now > frozenInfo.time) {
    		frozenInfo.amount = 0;
    	}
    	require(pToken != address(0x0), "Log:InsurancePool:!pToken");
    	uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
    	if (token != address(0x0)) {
    		tokenBalance = ERC20(token).balanceOf(address(this));
    	} else {
    		tokenBalance = address(this).balance;
    	}
    	uint256 allValue = tokenBalance.add(getDecimalConversion(pToken, pTokenBalance, token))
                           .sub(getDecimalConversion(pToken, insNegative[token], token));
    	uint256 insTotal = totalSupply[token];
    	uint256 underlyingAmount = amount.mul(allValue).div(insTotal);

        // 销毁份额
        destroy(token, amount, address(msg.sender));
        require(balances[address(msg.sender)][pToken] >= frozenInfo.amount, "Log:InsurancePool:frozen");
    	
    	// 转出标的资产
    	if (token != address(0x0)) {
            if (tokenBalance >= underlyingAmount) {
                ERC20(token).safeTransfer(address(msg.sender), underlyingAmount);
            } else {
                ERC20(token).safeTransfer(address(msg.sender), tokenBalance);
                ERC20(pToken).safeTransfer(address(msg.sender), 
                                           getDecimalConversion(token, underlyingAmount.sub(tokenBalance), pToken));
            }
    	} else {
            if (tokenBalance >= underlyingAmount) {
                payEth(address(msg.sender), underlyingAmount);
            } else {
                payEth(address(msg.sender), tokenBalance);
                ERC20(pToken).safeTransfer(address(msg.sender), 
                                           underlyingAmount.sub(tokenBalance));
            }
    	}
    }

    // 销毁P资产，更新负账户
    // pToken:p资产地址
    // amount:销毁数量
    // token:标的资产地址
    function destroyPToken(address pToken, 
    	                   uint256 amount,
                           address token) public onlyMortgagePool {
    	PToken pErc20 = PToken(pToken);
    	uint256 pTokenBalance = pErc20.balanceOf(address(this));
    	if (pTokenBalance >= amount) {
    		pErc20.destroy(amount, address(this));
    	} else {
    		pErc20.destroy(pTokenBalance, address(this));
    		// 记录负账户
    		insNegative[token] = insNegative[token].add(amount.sub(pTokenBalance));
    	}
    }

    // 消除负账户
    // pToken:p资产地址
    // token:标的资产地址
    function eliminate(address pToken, address token) public onlyMortgagePool {
    	_eliminate(pToken, token);
    }
    function _eliminate(address pToken, address token) private {
    	PToken pErc20 = PToken(pToken);
    	uint256 negative = insNegative[token];
    	uint256 pTokenBalance = pErc20.balanceOf(address(this)); 
    	if (negative > 0 && pTokenBalance > 0) {
    		if (negative >= pTokenBalance) {
    			insNegative[token] = insNegative[token].sub(pTokenBalance);
    			pErc20.destroy(pTokenBalance, address(this));
    		} else {
    			insNegative[token] = 0;
    			pErc20.destroy(insNegative[token], address(this));
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

    // 更新赎回节点
    function updateLatestTime(address token) public {
        uint256 time = latestTime[token];
    	if (now > time) {
    		uint256 subTime = now.sub(time).div(waitCycle);
    		latestTime[token] = time.add(waitCycle.mul(uint256(1).add(subTime)));
    	}
    }
    // 销毁份额
    // token:标的资产地址
    // amount:销毁数量数量
    // account:销毁用户地址
    function destroy(address token, uint256 amount, address account) private {
        require(balances[account][token] >= amount, "Log:InsurancePool:!destroy");
        balances[account][token] = balances[account][token].sub(amount);
        totalSupply[token] = totalSupply[token].sub(amount);
        emit Destroy(token, amount, account);
    }

    // 增发份额
    // token:标的资产地址
    // amount:增发数量
    // account:增发用户地址
    function issuance(address token, uint256 amount, address account) private {
        balances[account][token] = balances[account][token].add(amount);
        totalSupply[token] = totalSupply[token].add(amount);
        emit Issuance(token, amount, account);
    }

}