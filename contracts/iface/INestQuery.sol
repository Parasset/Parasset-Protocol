// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

interface INestQuery {
	function queryPriceAvgVola(address token, address payback) 
        external payable returns (uint256, uint256, uint128, int128, uint256);
    function params() external view 
        returns(uint256 single, uint64 leadTime, uint256 nestAmount);
}