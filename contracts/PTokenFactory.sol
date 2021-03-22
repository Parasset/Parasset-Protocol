// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "./PToken.sol";

contract PTokenFactory {

	// 管理员地址
	address public governance;
	// 可操作PToken地址
	mapping(address=>bool) allowAddress;
	// P资产地址
	mapping(address=>bool) pTokenMapping;
	address[] pTokenList;

	// p资产地址
    event createLog(address pTokenAddress);
    // 可操作PToken地址
    event pTokenOperator(address contractAddress, bool allow);

	constructor () public {
        governance = msg.sender;
    }

    //---------modifier---------

    modifier onlyGovernance() {
        require(msg.sender == governance, "Log:PTokenFactory:!gov");
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

    // 查看管理员地址
    function getGovernance() public view returns(address) {
        return governance;
    }

    // 查询可操作PToken地址
    function getPTokenOperator(address contractAddress) public view returns(bool) {
    	return allowAddress[contractAddress];
    }

    // 查询是否真实P资产
    function getPTokenAuthenticity(address pToken) public view returns(bool) {
    	return pTokenMapping[pToken];
    }

    // 查询p资产数量
    function getPTokenNum() public view returns(uint256) {
    	return pTokenList.length;
    }

    // 查询p资产地址
    function getPTokenAddress(uint256 index) public view returns(address) {
    	return pTokenList[index];
    }

    //---------governance----------

    // 设置管理员
    function setGovernance(address add) public onlyGovernance {
    	require(add != address(0x0), "Log:PTokenFactory:0x0");
    	governance = add;
    }

    // 创建PToken
    function createPtoken(string memory name) public onlyGovernance {
    	PToken pToken = new PToken(strConcat("P_", name), strConcat("P_", name));
    	pTokenMapping[address(pToken)] = true;
    	pTokenList.push(address(pToken));
    	emit createLog(address(pToken));
    }

    // 设置可操作PToken地址
    function setPTokenOperator(address contractAddress, 
                               bool allow) public onlyGovernance {
    	allowAddress[contractAddress] = allow;
    	emit pTokenOperator(contractAddress, allow);
    }
}