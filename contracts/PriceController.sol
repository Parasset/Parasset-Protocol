// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./iface/INestPriceFacade.sol";
import "./iface/INTokenController.sol";
import "./lib/SafeMath.sol";
import "./iface/IERC20.sol";

contract PriceController {
	using SafeMath for uint256;

	// Nest price contract
    INestPriceFacade nestPriceFacade;
    // NTokenController
    INTokenController ntokenController;

    /// @dev Initialization method
    /// @param _nestPriceFacade Nest price contract
    /// @param _ntokenController NTokenController
	constructor (address _nestPriceFacade, address _ntokenController) public {
		nestPriceFacade = INestPriceFacade(_nestPriceFacade);
        ntokenController = INTokenController(_ntokenController);
    }

    /// @dev Is it a token-ntoken price pair
    /// @param tokenOne token address(USDT,HBTC...)
    /// @param tokenTwo ntoken address(NEST,NHBTC...)
    function checkNToken(address tokenOne, address tokenTwo) public view returns(bool) {
        if (ntokenController.getNTokenAddress(tokenOne) == tokenTwo) {
            return true;
        }
        return false;
    }

    /// @dev Uniform accuracy
    /// @param inputToken Initial token
    /// @param inputTokenAmount Amount of token
    /// @param outputToken Converted token
    /// @return stability Amount of outputToken
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

    /// @dev Get price
    /// @param token mortgage asset address
    /// @param uToken underlying asset address
    /// @param payback return address of excess fee
    /// @return tokenPrice Mortgage asset price(1 ETH = ? token)
    /// @return pTokenPrice PToken price(1 ETH = ? pToken)
    function getPriceForPToken(address token, 
                               address uToken,
                               address payback) public payable returns (uint256 tokenPrice, 
                                                                        uint256 pTokenPrice) {
        if (token == address(0x0)) {
            // The mortgage asset is ETH，get ERC20-ETH price
            (,,uint256 avg,) = nestPriceFacade.triggeredPriceInfo{value:msg.value}(uToken, payback);
            require(avg > 0, "Log:PriceController:!avg1");
            return (1 ether, getDecimalConversion(uToken, avg, address(0x0)));
        } else if (uToken == address(0x0)) {
            // The underlying asset is ETH，get ERC20-ETH price
            (,,uint256 avg,) = nestPriceFacade.triggeredPriceInfo{value:msg.value}(token, payback);
            require(avg > 0, "Log:PriceController:!avg2");
            return (getDecimalConversion(uToken, avg, address(0x0)), 1 ether);
        } else {
            // Get ERC20-ERC20 price
            if (checkNToken(token, uToken)) {
                (,,uint256 avg1,,,,uint256 avg2,) = nestPriceFacade.triggeredPriceInfo2{value:msg.value}(token, payback);
                require(avg1 > 0 && avg2 > 0, "Log:PriceController:!avg3");
                return (avg1, getDecimalConversion(uToken, avg2, address(0x0)));
            } else if (checkNToken(uToken, token)) {
                (,,uint256 avg1,,,,uint256 avg2,) = nestPriceFacade.triggeredPriceInfo2{value:msg.value}(uToken, payback);
                require(avg1 > 0 && avg2 > 0, "Log:PriceController:!avg4");
                return (avg2, getDecimalConversion(uToken, avg1, address(0x0)));
            } else {
                (,,uint256 avg1,) = nestPriceFacade.triggeredPriceInfo{value:uint256(msg.value).div(2)}(token, payback);
                (,,uint256 avg2,) = nestPriceFacade.triggeredPriceInfo{value:uint256(msg.value).div(2)}(uToken, payback);
                require(avg1 > 0 && avg2 > 0, "Log:PriceController:!avg5");
                return (avg1, getDecimalConversion(uToken, avg2, address(0x0)));
            }
        }
    }
}