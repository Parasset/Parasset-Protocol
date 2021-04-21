// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "./PToken.sol";

contract PTokenFactory {

	// Governance address
	address public governance;
	// contract address => bool, ptoken operation permissions
	mapping(address=>bool) allowAddress;
	// ptoken address => bool, ptoken verification
	mapping(address=>bool) pTokenMapping;
    // ptoken list
	address[] pTokenList;

    event createLog(address pTokenAddress);
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

    /// @dev View governance address
    /// @return governance address
    function getGovernance() public view returns(address) {
        return governance;
    }

    /// @dev View ptoken operation permissions
    /// @param contractAddress contract address
    /// @return bool
    function getPTokenOperator(address contractAddress) public view returns(bool) {
    	return allowAddress[contractAddress];
    }

    /// @dev View ptoken operation permissions
    /// @param pToken ptoken verification
    /// @return bool
    function getPTokenAuthenticity(address pToken) public view returns(bool) {
    	return pTokenMapping[pToken];
    }

    /// @dev View ptoken list length
    /// @return ptoken list length
    function getPTokenNum() public view returns(uint256) {
    	return pTokenList.length;
    }

    /// @dev View ptoken address
    /// @param index array subscript
    /// @return ptoken address
    function getPTokenAddress(uint256 index) public view returns(address) {
    	return pTokenList[index];
    }

    //---------governance----------

    /// @dev Set governance address
    /// @param add new governance address
    function setGovernance(address add) public onlyGovernance {
    	require(add != address(0x0), "Log:PTokenFactory:0x0");
    	governance = add;
    }

    /// @dev Set governance address
    /// @param contractAddress contract address
    /// @param allow bool
    function setPTokenOperator(address contractAddress, 
                               bool allow) public onlyGovernance {
        allowAddress[contractAddress] = allow;
        emit pTokenOperator(contractAddress, allow);
    }

    /// @dev Create PToken
    /// @param name token name
    function createPtoken(string memory name) public onlyGovernance {
    	PToken pToken = new PToken(strConcat("PToken_", name), strConcat("P", name));
    	pTokenMapping[address(pToken)] = true;
    	pTokenList.push(address(pToken));
    	emit createLog(address(pToken));
    }
}