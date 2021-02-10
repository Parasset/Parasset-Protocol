// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "./lib/SafeMath.sol";
import './lib/TransferHelper.sol';
import './lib/SafeERC20.sol';
import "./lib/AddressPayable.sol";
import "./iface/IERC20.sol";
import "./iface/IMortgagePool.sol";
import "./Insurance.sol";
import "./PToken.sol";

contract InsurancePool {
	using SafeMath for uint256;
	using address_make_payable for address;
	using SafeERC20 for ERC20;

	// 管理员地址
	address public governance;
	// p资产地址=>保险LP地址
	mapping(address=>address) pTokenToIns;
	// 保险LP地址=>负账户资金数量
	mapping(address=>uint256) insNegative;
    // 保险池地址
	IMortgagePool mortgagePool;
	// 最新赎回节点
	uint256 latestTime;
	// 赎回周期
	uint256 redemptionCycle = 1 days;
	// 等待周期
	uint256 waitCycle = 90 days;
	// 冻结保险份额,用户地址=>冻结份额数据
	mapping(address=>Frozen) frozenIns;
	struct Frozen {
		uint256 amount;							//	冻结数量
		uint256 time;							//  冻结时间
	}

	constructor () public {
        governance = msg.sender;
        latestTime = now.add(waitCycle);
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

    //---------view---------

	// 小数转换
    // inputToken:输入资产地址
    // inputTokenAmount:输入资产数量
    // outputToken:输出资产地址
    function getDecimalConversion(address inputToken, 
    	                          uint256 inputTokenAmount, 
    	                          address outputToken) public view returns(uint256) {
    	uint256 inputTokenDec = 6;
    	uint256 outputTokenDec = 18;
    	if (inputToken != address(0x0)) {
    		inputTokenDec = IERC20(inputToken).decimals();
    	}

    	if (outputToken != address(0x0)) {
    		outputTokenDec = IERC20(outputToken).decimals();
    	}
    	return inputTokenAmount.mul(10**outputTokenDec).div(10**inputTokenDec);
    }

    // 通过p资产查询保险LP地址
    function getPTokenToIns(address pToken) public view returns(address) {
    	return pTokenToIns[pToken];
    }

    //---------governance----------

    // 设置抵押池地址
    function setMortgagePool(address add) public onlyGovernance {
    	mortgagePool = IMortgagePool(add);
    }

    // 设置管理员
    function loadGovernance() public {
    	address add = mortgagePool.getGovernance();
    	require(add != address(0x0), "Log:InsurancePool:0x0");
    	governance = add;
    }

    //---------transaction---------

    // 设置pToken=>保险LP的映射
    // pToken:pToken地址
    // ins:保险LP地址
    function setPTokenToIns(address pToken, address ins) public onlyMortgagePool {
    	pTokenToIns[pToken] = ins;
    }

	// 兑换，p资产换标的资产
    // pToken:pToken地址
    // amount:pToken数量
    function exchangePTokenToUnderlying(address pToken, 
    	                                uint256 amount) public {
    	uint256 fee = amount.mul(2).div(1000);
    	ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), amount);
        address underlyingToken = mortgagePool.getPTokenToUnderlying(pToken);
    	if (underlyingToken != address(0x0)) {
    		ERC20(underlyingToken).safeTransfer(address(msg.sender), getDecimalConversion(pToken, amount.sub(fee), underlyingToken));
    	} else {
    		payEth(address(msg.sender), getDecimalConversion(pToken, amount.sub(fee), underlyingToken));
    	}
    	// 消除负账户
        _eliminate(pToken);
    }

    // 兑换，标的资产换p资产
    // token:标的资产地址
    // amount:标的资产数量
    function exchangeUnderlyingToPToken(address token, 
    	                                uint256 amount) public payable {
    	uint256 fee = amount.mul(2).div(1000);
    	if (token != address(0x0)) {
    		require(msg.value == 0, "Log:InsurancePool:msg.value!=0");
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), amount);
    	} else {
    		require(msg.value == amount, "Log:InsurancePool:!msg.value");
    	}
    	address pToken = mortgagePool.getUnderlyingToPToken(token);
    	ERC20(pToken).safeTransfer(address(msg.sender), getDecimalConversion(token, amount.sub(fee), pToken));
    }

    // 认购保险
    // token:标的资产地址，USDT、ETH...
    // amount:标的资产数量
    function subscribeIns(address token, 
    	                  uint256 amount) public payable {
    	// updateLatestTime();
    	// Frozen storage frozenInfo = frozenIns[address(msg.sender)];
    	// if (now > frozenInfo.time) {
    	// 	frozenInfo.amount = 0;
    	// }
    	uint256 tokenBalance;
    	address pToken = mortgagePool.getUnderlyingToPToken(token);
        require(pToken != address(0x0), "Log:InsurancePool:!pToken");
    	uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
    	if (token != address(0x0)) {
    		tokenBalance = ERC20(token).balanceOf(address(this));
    	} else {
    		require(msg.value == amount, "Log:InsurancePool:!msg.value");
    		tokenBalance = address(this).balance;
    	}
    	uint256 allValue = tokenBalance.add(pTokenBalance).sub(insNegative[pTokenToIns[pToken]]);
    	Insurance ins = Insurance(pTokenToIns[pToken]);
    	uint256 insAmount = getDecimalConversion(token, amount, pToken);
    	uint256 insTotal = ins.totalSupply();
    	if (insTotal != 0) {
    		insAmount = getDecimalConversion(token, amount, pToken).mul(insTotal).div(allValue);
    	}
    	// 转入标的资产
    	if (token != address(0x0)) {
    		require(msg.value == 0, "Log:InsurancePool:msg.value!=0");
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), amount);
    	}
    	// 增发份额
    	ins.issuance(insAmount, address(msg.sender));
    	// 冻结保险份额
    	// frozenInfo.amount = frozenInfo.amount.add(insAmount);
    	// frozenInfo.time = latestTime;
    }

    // 赎回保险
    // token:标的资产地址，USDT、ETH...
    // amount:赎回份额
    function redemptionIns(address token, 
    	                   uint256 amount) public {
    	// updateLatestTime();
    	// require(now >= latestTime.sub(waitCycle) && now <= latestTime.sub(waitCycle).add(redemptionCycle), "Log:InsurancePool:!time");
    	// Frozen storage frozenInfo = frozenIns[address(msg.sender)];
    	// if (now > frozenInfo.time) {
    	// 	frozenInfo.amount = 0;
    	// }
    	uint256 tokenBalance;
    	address pToken = mortgagePool.getUnderlyingToPToken(token);
    	require(pToken != address(0x0), "Log:InsurancePool:!pToken");
    	uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
    	if (token != address(0x0)) {
    		tokenBalance = ERC20(token).balanceOf(address(this));
    	} else {
    		tokenBalance = address(this).balance;
    	}
    	uint256 allValue = tokenBalance.add(getDecimalConversion(pToken, pTokenBalance, token))
                           .sub(getDecimalConversion(pToken, insNegative[pTokenToIns[pToken]], token));
    	Insurance ins = Insurance(pTokenToIns[pToken]);
    	uint256 insTotal = ins.totalSupply();
    	uint256 underlyingAmount = amount.mul(allValue).div(insTotal);
    	
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
    	// 销毁份额
    	ins.destroy(amount, address(msg.sender));
    }

    // 销毁P资产，更新负账户
    // pToken:p资产地址
    // amount:销毁数量
    function destroyPToken(address pToken, 
    	                   uint256 amount) public onlyMortgagePool {
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
    function eliminate(address pToken) public onlyMortgagePool {
    	_eliminate(pToken);
    }
    function _eliminate(address pToken) private {
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

    // 解冻份额
    function unFrozen() private {
    	
    }

    // 更新赎回节点
    function updateLatestTime() public {
    	if (now > latestTime) {
    		uint256 subTime = now.sub(latestTime).div(waitCycle);
    		latestTime = latestTime.add(waitCycle.mul(uint256(1).add(subTime)));
    	}
    }

}