// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "./iface/INestQuery.sol";
import "./lib/SafeMath.sol";
import "./iface/IERC20.sol";

contract PriceController {
	using SafeMath for uint256;

	// 价格合约
    INestQuery quary;

	constructor (address add) public {
		quary = INestQuery(add);
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

    // 查询单次价格调用费
    function getPriceSingleFee() public view returns(uint256) {
        (uint256 fee,,) = quary.params();
        return fee;
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

    // 获取价格
    // token:抵押资产地址
    // uToken:标的资产地址
    // pToken:p资产地址
    // payback:多余费用返还地址
    // tokenPrice:抵押资产Token数量
    // pTokenPrice:p资产Token数量
    function getPriceForPToken(address token, 
                               address uToken,
                               address pToken,
                               address payback) public payable returns (uint256 tokenPrice, 
                                                                        uint256 pTokenPrice) {
        uint256 fee = getPriceSingleFee();
        if (token == address(0x0)) {
            (,,uint256 avg,,) = quary.queryPriceAvgVola{value:msg.value}(uToken, payback);
            require(avg > 0, "Log:PriceController:!avg");
            return (1 ether, getDecimalConversion(uToken, avg, pToken));
        } else if (uToken == address(0x0)) {
            (,,uint256 avg,,) = quary.queryPriceAvgVola{value:msg.value}(token, payback);
            require(avg > 0, "Log:PriceController:!avg");
            return (getDecimalConversion(uToken, avg, pToken), 1 ether);
        }
        (,,uint256 avg1,,) = quary.queryPriceAvgVola{value:fee}(token, payback);
        (,,uint256 avg2,,) = quary.queryPriceAvgVola{value:uint256(msg.value).sub(fee)}(uToken, payback);
        require(avg1 > 0 && avg2 > 0, "Log:PriceController:!avg");
        return (avg1, getDecimalConversion(uToken, avg2, pToken));
    }
}