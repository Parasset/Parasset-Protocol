// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "./lib/SafeMath.sol";
import "./iface/IParasset.sol";

contract PToken is IParasset {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowed;
    uint256 public _totalSupply = 0;                                        
    string public name = "";
    string public symbol = "";
    uint8 public decimals = 18;

    address public mortgagePool;
    address public insurancePool;

    event Destroy(uint256 amount, address account);
    event Issuance(uint256 amount, address account);

    constructor (string memory _name, 
                 string memory _symbol,
                 address _mortgagePool, 
                 address _insurancePool) public {
    	name = _name;                                                               
    	symbol = _symbol;
    	mortgagePool = _mortgagePool;
        insurancePool = _insurancePool;
    }

    //---------modifier---------

    modifier onlyPool()
    {
    	require(msg.sender == mortgagePool || msg.sender == insurancePool, "Log:PToken:!Pool");
    	_;
    }

    //---------view---------

    /// @notice The view of totalSupply
    /// @return The total supply of ntoken
    function totalSupply() override public view returns (uint256) {
        return _totalSupply;
    }

    /// @dev The view of balances
    /// @param owner The address of an account
    /// @return The balance of the account
    function balanceOf(address owner) override public view returns (uint256) {
        return _balances[owner];
    }

    function allowance(address owner, address spender) override public view returns (uint256) 
    {
        return _allowed[owner][spender];
    }

    //---------transaction---------

    function transfer(address to, uint256 value) override public returns (bool) 
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) override public returns (bool) 
    {
        require(spender != address(0));
        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) override public returns (bool) 
    {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) 
    {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) 
    {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].sub(subtractedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    function destroy(uint256 amount, address account) override external onlyPool{
    	require(_balances[account] >= amount, "Log:PToken:!destroy");
    	_balances[account] = _balances[account].sub(amount);
    	_totalSupply = _totalSupply.sub(amount);
    	emit Destroy(amount, account);
    }

    function issuance(uint256 amount, address account) override external onlyPool{
    	_balances[account] = _balances[account].add(amount);
    	_totalSupply = _totalSupply.add(amount);
    	emit Issuance(amount, account);
    }
}