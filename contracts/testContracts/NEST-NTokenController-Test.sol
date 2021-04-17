// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

contract NTokenController {

	mapping(address=>address) ntokenMapping;

	constructor () public { }

	function setNTokenMapping(address token, address nToken) public {
		ntokenMapping[token] = nToken;
	}

	function getNTokenAddress(address tokenAddress) external view returns (address) {
		return ntokenMapping[tokenAddress];
	}

}