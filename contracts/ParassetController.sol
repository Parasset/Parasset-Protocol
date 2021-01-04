pragma solidity 0.6.12;

import "./lib/SafeMath.sol";

contract ParassetController {
	using SafeMath for uint256;
	// 管理员地址
	address public governance;
	// 抵押资产合约
	address public mortgagePool;

	constructor () public {
		governance = msg.sender;
	}

	//---------modifier---------

    modifier onlyGovernance() 
    {
        require(msg.sender == governance, "Log:ParassetController:!gov");
        _;
    }

	//  开通P资产
    function createParasset(address token) public {
        
    }

}