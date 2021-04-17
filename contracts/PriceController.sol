// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./iface/INestPriceFacade.sol";
import "./iface/INTokenController.sol";
import "./lib/SafeMath.sol";
import "./iface/IERC20.sol";

contract PriceController {
	using SafeMath for uint256;

	// 价格合约
    INestPriceFacade nestPriceFacade;
    // NToken控制合约
    INTokenController ntokenController;

	constructor (address _nestPriceFacade, address _ntokenController) public {
		nestPriceFacade = INestPriceFacade(_nestPriceFacade);
        ntokenController = INTokenController(_ntokenController);
    }

    // 获取是否是token-ntoken对
    function checkNToken(address tokenOne, address tokenTwo) public view returns(bool) {
        if (ntokenController.getNTokenAddress(tokenOne) == tokenTwo) {
            return true;
        }
        return false;
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
    // payback:多余费用返还地址
    // tokenPrice:抵押资产Token数量
    // pTokenPrice:p资产Token数量
    function getPriceForPToken(address token, 
                               address uToken,
                               address payback) public payable returns (uint256 tokenPrice, 
                                                                        uint256 pTokenPrice) {
        if (token == address(0x0)) {
            // 抵押资产是ETH，获取ERC20-ETH价格
            (,,uint256 avg,) = nestPriceFacade.triggeredPriceInfo{value:msg.value}(uToken, payback);
            require(avg > 0, "Log:PriceController:!avg1");
            return (1 ether, getDecimalConversion(uToken, avg, address(0x0)));
        } else if (uToken == address(0x0)) {
            // 标的资产是ETH，获取ERC20-ETH价格
            (,,uint256 avg,) = nestPriceFacade.triggeredPriceInfo{value:msg.value}(token, payback);
            require(avg > 0, "Log:PriceController:!avg2");
            return (getDecimalConversion(uToken, avg, address(0x0)), 1 ether);
        } else {
            // 获取ERC20-ERC20价格
            // 判断是否是token-ntoken
            if (checkNToken(token, uToken)) {
                (,,uint256 avg1,,,,uint256 avg2,) = nestPriceFacade.triggeredPriceInfo2{value:msg.value}(token, payback);
                require(avg1 > 0 && avg2 > 0, "Log:PriceController:!avg3");
                return (getDecimalConversion(token, avg1, address(0x0)), getDecimalConversion(uToken, avg2, address(0x0)));
            } else if (checkNToken(uToken, token)) {
                (,,uint256 avg1,,,,uint256 avg2,) = nestPriceFacade.triggeredPriceInfo2{value:msg.value}(uToken, payback);
                require(avg1 > 0 && avg2 > 0, "Log:PriceController:!avg4");
                return (getDecimalConversion(token, avg2, address(0x0)), getDecimalConversion(uToken, avg1, address(0x0)));
            } else {
                // 其他ERC20-ERC20
                (,,uint256 avg1,) = nestPriceFacade.triggeredPriceInfo{value:uint256(msg.value).div(2)}(token, payback);
                (,,uint256 avg2,) = nestPriceFacade.triggeredPriceInfo{value:uint256(msg.value).div(2)}(uToken, payback);
                require(avg1 > 0 && avg2 > 0, "Log:PriceController:!avg5");
                return (getDecimalConversion(token, avg1, address(0x0)), getDecimalConversion(uToken, avg2, address(0x0)));
            }
        }
    }
}