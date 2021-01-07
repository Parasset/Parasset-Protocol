pragma solidity 0.6.12;

import "./lib/SafeMath.sol";

contract ParassetController {
	using SafeMath for uint256;
	address public governance;
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

    function createParasset(address token) public {
        
    }

}
