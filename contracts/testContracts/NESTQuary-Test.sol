// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "../lib/AddressPayable.sol";

contract NestQuery {
    using address_make_payable for address;

	mapping(address=>uint128) avg;
	uint256 fee = 0.01 ether;

	constructor () public {}

    function params() public view 
        returns(uint256 single, uint64 leadTime, uint256 nestAmount) {
        return (fee, 0, 0);
    }

    function setPrice(address token, uint128 _avg) public {
    	avg[token] = _avg;
    }

    function queryPriceAvgVola(address token, 
    						   address payback)
        public 
        payable 
        returns (uint256 ethAmount, 
        	     uint256 tokenAmount, 
        	     uint128 avgPrice, 
        	     int128 vola, 
        	     uint256 bn) {
        require(msg.value >= fee, "value");
        if (msg.value > fee) {
            payEth(payback, uint256(msg.value)-fee);
        }
        return (0,0,avg[token],0,0);
    }

    function latestPrice(address token) 
        public view returns(uint256 ethAmount, 
                            uint256 tokenAmount, 
                            uint128 avgPrice, 
                            int128 vola, 
                            uint256 bn) {
        return (0,0,avg[token],0,0);
    }

    // 转ETH
    // account:转账目标地址
    // asset:资产数量
    function payEth(address account, uint256 asset) private {
        address payable add = account.make_payable();
        add.transfer(asset);
    }

}