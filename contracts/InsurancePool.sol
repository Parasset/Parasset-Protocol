// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "./lib/SafeMath.sol";
import './lib/TransferHelper.sol';
import './lib/SafeERC20.sol';
import "./iface/IERC20.sol";
import "./iface/IMortgagePool.sol";
import "./PToken.sol";
import "./iface/IPTokenFactory.sol";
import "./lib/ReentrancyGuard.sol";

contract InsurancePool is ReentrancyGuard {
	using SafeMath for uint256;
	using SafeERC20 for ERC20;

	// Governance address
	address public governance;
	// Underlying asset address => negative account funds
	mapping(address=>uint256) insNegative;
	// Underlying asset address => total LP
	mapping(address=>uint256) totalSupply;
	// Underlying asset address => latest redemption time
    mapping(address=>uint256) latestTime;
	// Redemption cycle, 2 days
	uint256 public redemptionCycle = 2 days;
	// Redemption duration, 7 days
	uint256 public waitCycle = 7 days;
    // User address => Underlying asset address => LP quantity
    mapping(address=>mapping(address=>uint256)) balances;
	// User address => Underlying asset address => Freeze LP data
	mapping(address=>mapping(address=>Frozen)) frozenIns;
	struct Frozen {
		uint256 amount;							// Frozen quantity
		uint256 time;							// Freezing time
	}
    // Mortgage pool address
    IMortgagePool mortgagePool;
    // PTokenFactory address
    IPTokenFactory pTokenFactory;
    // Status
    uint8 public flag;      // = 0: pause
                            // = 1: active
                            // = 2: redemption only
    // Rate(2/1000)
    uint256 feeRate = 2;

    event Destroy(address token, uint256 amount, address account);
    event Issuance(address token, uint256 amount, address account);
    event Negative(address token, uint256 amount, uint256 allValue);

    /// @dev Initialization method
    /// @param factoryAddress PTokenFactory address
	constructor (address factoryAddress) public {
        pTokenFactory = IPTokenFactory(factoryAddress);
        governance = pTokenFactory.getGovernance();
        flag = 0;
    }

	//---------modifier---------

    modifier onlyGovernance() {
        require(msg.sender == governance, "Log:InsurancePool:!gov");
        _;
    }

    modifier onlyMortgagePool() {
        require(msg.sender == address(mortgagePool), "Log:InsurancePool:!mortgagePool");
        _;
    }

    modifier onlyGovOrMor() {
        require(msg.sender == governance || msg.sender == address(mortgagePool), "Log:InsurancePool:!onlyGovOrMor");
        _;
    }

    modifier whenActive() {
        require(flag == 1, "Log:InsurancePool:!active");
        _;
    }

    modifier redemptionOnly() {
        require(flag != 0, "Log:InsurancePool:!0");
        _;
    }

    //---------view---------

    /// @dev View governance address
    /// @return governance address
    function getGovernance() external view returns(address) {
        return governance;
    }

    /// @dev View negative ledger
    /// @param token underlying asset address
    /// @return negative ledger
    function getInsNegative(address token) external view returns(uint256) {
        return insNegative[token];
    }

    /// @dev View total LP
    /// @param token underlying asset address
    /// @return total LP
    function getTotalSupply(address token) external view returns(uint256) {
        return totalSupply[token];
    }

    /// @dev View personal LP
    /// @param token underlying asset address
    /// @param add user address
    /// @return personal LP
    function getBalances(address token, 
                         address add) external view returns(uint256) {
        return balances[add][token];
    }

    /// @dev View rate
    /// @return rate
    function getFeeRate() external view returns(uint256) {
        return feeRate;
    }

    /// @dev View mortgage pool address
    /// @return mortgage pool address
    function getMortgagePool() external view returns(address) {
        return address(mortgagePool);
    }

    /// @dev View the latest redemption time
    /// @param token underlying asset address
    /// @return the latest redemption time
    function getLatestTime(address token) external view returns(uint256) {
        return latestTime[token];
    }

    /// @dev View redemption period, next time
    /// @param token underlying asset address
    /// @return startTime start time
    /// @return endTime end time
    function getRedemptionTime(address token) external view returns(uint256 startTime, 
                                                                    uint256 endTime) {
        uint256 time = latestTime[token];
        if (now > time) {
            uint256 subTime = now.sub(time).div(waitCycle);
            startTime = time.add(waitCycle.mul(uint256(1).add(subTime)));
        } else {
            startTime = time;
        }
        endTime = startTime.add(redemptionCycle);
    }

    /// @dev View redemption period, this period
    /// @param token underlying asset address
    /// @return startTime start time
    /// @return endTime end time
    function getRedemptionTimeFront(address token) external view returns(uint256 startTime, 
                                                                         uint256 endTime) {
        uint256 time = latestTime[token];
        if (now > time) {
            uint256 subTime = now.sub(time).div(waitCycle);
            startTime = time.add(waitCycle.mul(subTime));
        } else {
            startTime = time.sub(waitCycle);
        }
        endTime = startTime.add(redemptionCycle);
    }

    /// @dev View frozen LP and unfreeze time
    /// @param token underlying asset address
    /// @param add user address
    /// @return frozen LP
    /// @return unfreeze time
    function getFrozenIns(address token, 
                          address add) external view returns(uint256, uint256) {
        Frozen memory frozenInfo = frozenIns[add][token];
        return (frozenInfo.amount, frozenInfo.time);
    }

    /// @dev View frozen LP and unfreeze time, real time
    /// @param token underlying asset address
    /// @param add user address
    /// @return frozen LP
    function getFrozenInsInTime(address token, 
                                address add) external view returns(uint256) {
        Frozen memory frozenInfo = frozenIns[add][token];
        if (now > frozenInfo.time) {
            return 0;
        }
        return frozenInfo.amount;
    }

    /// @dev View redeemable LP, real time
    /// @param token underlying asset address
    /// @param add user address
    /// @return redeemable LP
    function getRedemptionAmount(address token, 
                                 address add) external view returns (uint256) {
        Frozen memory frozenInfo = frozenIns[add][token];
        uint256 balanceSelf = balances[add][token];
        if (now > frozenInfo.time) {
            return balanceSelf;
        } else {
            return balanceSelf.sub(frozenInfo.amount);
        }
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

    //---------governance----------

    /// @dev Set contract status
    /// @param num 0: pause, 1: active, 2: redemption only
    function setFlag(uint8 num) public onlyGovernance {
        flag = num;
    }

    /// @dev Set mortgage pool address
    function setMortgagePool(address add) public onlyGovernance {
    	mortgagePool = IMortgagePool(add);
    }

    /// @dev Set the latest redemption time
    function setLatestTime(address token) public onlyGovOrMor {
        latestTime[token] = now.add(waitCycle);
    }

    /// @dev Set the rate
    function setFeeRate(uint256 num) public onlyGovernance {
        feeRate = num;
    }

    /// @dev Set redemption cycle
    function setRedemptionCycle(uint256 num) public onlyGovernance {
        require(num > 0, "Log:InsurancePool:!zero");
        redemptionCycle = num * 1 days;
    }

    /// @dev Set redemption duration
    function setWaitCycle(uint256 num) public onlyGovernance {
        require(num > 0, "Log:InsurancePool:!zero");
        waitCycle = num * 1 days;
    }

    //---------transaction---------

    /// @dev Set governance address
    function setGovernance() public {
        governance = pTokenFactory.getGovernance();
    }

    /// @dev Exchange: ptoken exchanges the underlying asset
    /// @param pToken ptoken address
    /// @param amount amount of ptoken
    function exchangePTokenToUnderlying(address pToken, 
    	                                uint256 amount) public whenActive nonReentrant {
        // amount > 0
        require(amount > 0, "Log:InsurancePool:!amount");

        // Calculate the fee
    	uint256 fee = amount.mul(feeRate).div(1000);

        // Transfer to the ptoken
    	ERC20(pToken).safeTransferFrom(address(msg.sender), address(this), amount);

        // Verify ptoken
        address underlyingToken = mortgagePool.getPTokenToUnderlying(pToken);
        address pToken_s = mortgagePool.getUnderlyingToPToken(underlyingToken);
        require(pToken_s == pToken,"Log:InsurancePool:!pToken");

        // Calculate the amount of transferred underlying asset
        uint256 uTokenAmount = getDecimalConversion(pToken, amount.sub(fee), underlyingToken);
        require(uTokenAmount > 0, "Log:InsurancePool:!uTokenAmount");

        // Transfer out underlying asset
    	if (underlyingToken != address(0x0)) {
    		ERC20(underlyingToken).safeTransfer(address(msg.sender), uTokenAmount);
    	} else {
            TransferHelper.safeTransferETH(address(msg.sender), uTokenAmount);
    	}

    	// Eliminate negative ledger
        _eliminate(pToken, underlyingToken);
    }

    /// @dev Exchange: underlying asset exchanges the ptoken
    /// @param token underlying asset address
    /// @param amount amount of underlying asset
    function exchangeUnderlyingToPToken(address token, 
    	                                uint256 amount) public payable whenActive nonReentrant {
        // amount > 0
        require(amount > 0, "Log:InsurancePool:!amount");

        // Calculate the fee
    	uint256 fee = amount.mul(feeRate).div(1000);

        // Transfer to the underlying asset
    	if (token != address(0x0)) {
            // The underlying asset is ERC20
    		require(msg.value == 0, "Log:InsurancePool:msg.value!=0");
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), amount);
    	} else {
            // The underlying asset is ETH
    		require(msg.value == amount, "Log:InsurancePool:!msg.value");
    	}

        // Calculate the amount of transferred ptokens
    	address pToken = mortgagePool.getUnderlyingToPToken(token);
        uint256 pTokenAmount = getDecimalConversion(token, amount.sub(fee), pToken);
        require(pTokenAmount > 0, "Log:InsurancePool:!pTokenAmount");

        // Transfer out ptoken
        uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
        if (pTokenBalance < pTokenAmount) {
            // Insufficient ptoken balance,
            uint256 subNum = pTokenAmount.sub(pTokenBalance);
            PToken(pToken).issuance(subNum, address(this));
            insNegative[token] = insNegative[token].add(subNum);
        }
    	ERC20(pToken).safeTransfer(address(msg.sender), pTokenAmount);
    }

    /// @dev Subscribe for insurance
    /// @param token underlying asset address
    /// @param amount amount of underlying asset
    function subscribeIns(address token, 
    	                  uint256 amount) public payable whenActive nonReentrant {
        // amount > 0
        require(amount > 0, "Log:InsurancePool:!amount");

        // Verify ptoken
        address pToken = mortgagePool.getUnderlyingToPToken(token);
        require(pToken != address(0x0), "Log:InsurancePool:!pToken");

        // Update redemption time
    	updateLatestTime(token);

        // Thaw LP
    	Frozen storage frozenInfo = frozenIns[address(msg.sender)][token];
    	if (now > frozenInfo.time) {
    		frozenInfo.amount = 0;
    	}

        // ptoken balance 
    	uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
        // underlying asset balance
        uint256 tokenBalance;
    	if (token != address(0x0)) {
            // Underlying asset conversion 18 decimals
    		tokenBalance = getDecimalConversion(token, ERC20(token).balanceOf(address(this)), pToken);
    	} else {
            // The amount of ETH involved in the calculation does not include the transfer in this time
    		require(msg.value == amount, "Log:InsurancePool:!msg.value");
    		tokenBalance = address(this).balance.sub(amount);
    	}

        // Calculate LP
    	uint256 insAmount = 0;
    	uint256 insTotal = totalSupply[token];
        uint256 allBalance = tokenBalance.add(pTokenBalance);
    	if (insTotal != 0) {
            // Insurance pool assets must be greater than 0
            require(allBalance > insNegative[token], "Log:InsurancePool:allBalanceNotEnough");
            uint256 allValue = allBalance.sub(insNegative[token]);
    		insAmount = getDecimalConversion(token, amount, pToken).mul(insTotal).div(allValue);
    	} else {
            // The initial net value is 1
            insAmount = getDecimalConversion(token, amount, pToken);
        }

    	// Transfer to the underlying asset(ERC20)
    	if (token != address(0x0)) {
    		require(msg.value == 0, "Log:InsurancePool:msg.value!=0");
    		ERC20(token).safeTransferFrom(address(msg.sender), address(this), amount);
    	}

    	// Additional LP issuance
    	issuance(token, insAmount, address(msg.sender));

    	// Freeze insurance LP
    	frozenInfo.amount = frozenInfo.amount.add(insAmount);
    	frozenInfo.time = latestTime[token].add(waitCycle);
    }

    /// @dev Redemption insurance
    /// @param token underlying asset address
    /// @param amount redemption LP
    function redemptionIns(address token, 
    	                   uint256 amount) public redemptionOnly nonReentrant {
        // amount > 0
        require(amount > 0, "Log:InsurancePool:!amount");
        
        // Verify ptoken
        address pToken = mortgagePool.getUnderlyingToPToken(token);
        require(pToken != address(0x0), "Log:InsurancePool:!pToken");

        // Update redemption time
    	updateLatestTime(token);

        // Judging the redemption time
        uint256 tokenTime = latestTime[token];
    	require(now >= tokenTime.sub(waitCycle) && now <= tokenTime.sub(waitCycle).add(redemptionCycle), "Log:InsurancePool:!time");

        // Thaw LP
    	Frozen storage frozenInfo = frozenIns[address(msg.sender)][token];
    	if (now > frozenInfo.time) {
    		frozenInfo.amount = 0;
    	}
    	
        // ptoken balance
    	uint256 pTokenBalance = ERC20(pToken).balanceOf(address(this));
        // underlying asset balance
        uint256 tokenBalance;
    	if (token != address(0x0)) {
    		tokenBalance = getDecimalConversion(token, ERC20(token).balanceOf(address(this)), pToken);
    	} else {
    		tokenBalance = address(this).balance;
    	}

        // Insurance pool assets must be greater than 0
        uint256 allBalance = tokenBalance.add(pTokenBalance);
        require(allBalance > insNegative[token], "Log:InsurancePool:allBalanceNotEnough");
        // Calculated amount of assets
    	uint256 allValue = allBalance.sub(insNegative[token]);
    	uint256 insTotal = totalSupply[token];
    	uint256 underlyingAmount = amount.mul(allValue).div(insTotal);

        // Destroy LP
        destroy(token, amount, address(msg.sender));
        // Judgment to freeze LP
        require(balances[address(msg.sender)][token] >= frozenInfo.amount, "Log:InsurancePool:frozen");
    	
    	// Transfer out assets, priority transfer of the underlying assets, if the underlying assets are insufficient, transfer ptoken
    	if (token != address(0x0)) {
            // ERC20
            if (tokenBalance >= underlyingAmount) {
                ERC20(token).safeTransfer(address(msg.sender), getDecimalConversion(pToken, underlyingAmount, token));
            } else {
                ERC20(token).safeTransfer(address(msg.sender), getDecimalConversion(pToken, tokenBalance, token));
                ERC20(pToken).safeTransfer(address(msg.sender), underlyingAmount.sub(tokenBalance));
            }
    	} else {
            // ETH
            if (tokenBalance >= underlyingAmount) {
                TransferHelper.safeTransferETH(address(msg.sender), underlyingAmount);
            } else {
                TransferHelper.safeTransferETH(address(msg.sender), tokenBalance);
                ERC20(pToken).safeTransfer(address(msg.sender), 
                                           underlyingAmount.sub(tokenBalance));
            }
    	}
    }

    /// @dev Destroy ptoken, update negative ledger
    /// @param pToken ptoken address
    /// @param amount quantity destroyed
    /// @param token underlying asset address
    function destroyPToken(address pToken, 
    	                   uint256 amount,
                           address token) public onlyMortgagePool {
    	PToken pErc20 = PToken(pToken);
    	uint256 pTokenBalance = pErc20.balanceOf(address(this));
    	if (pTokenBalance >= amount) {
    		pErc20.destroy(amount, address(this));
    	} else {
    		pErc20.destroy(pTokenBalance, address(this));
    		// 记录负账户
            uint256 subAmount = amount.sub(pTokenBalance);
    		insNegative[token] = insNegative[token].add(subAmount);
            emit Negative(pToken, subAmount, insNegative[token]);
    	}
    }

    /// @dev Eliminate negative ledger
    /// @param pToken ptoken address
    /// @param token underlying asset address
    function eliminate(address pToken, 
                       address token) public onlyMortgagePool {
    	_eliminate(pToken, token);
    }

    function _eliminate(address pToken, 
                        address token) private {

    	PToken pErc20 = PToken(pToken);
        // negative ledger
    	uint256 negative = insNegative[token];
        // ptoken balance
    	uint256 pTokenBalance = pErc20.balanceOf(address(this)); 
    	if (negative > 0 && pTokenBalance > 0) {
    		if (negative >= pTokenBalance) {
                // Increase negative ledger
                pErc20.destroy(pTokenBalance, address(this));
    			insNegative[token] = insNegative[token].sub(pTokenBalance);
                emit Negative(pToken, pTokenBalance, insNegative[token]);
    		} else {
                // negative ledger = 0
                pErc20.destroy(negative, address(this));
    			insNegative[token] = 0;
                emit Negative(pToken, insNegative[token], insNegative[token]);
    		}
    	}
    }

    /// @dev Update redemption time
    /// @param token underlying asset address
    function updateLatestTime(address token) public {
        uint256 time = latestTime[token];
    	if (now > time) {
    		uint256 subTime = now.sub(time).div(waitCycle);
    		latestTime[token] = time.add(waitCycle.mul(uint256(1).add(subTime)));
    	}
    }

    /// @dev Destroy LP
    /// @param token underlying asset address
    /// @param amount quantity destroyed
    /// @param account destroy address
    function destroy(address token, 
                     uint256 amount, 
                     address account) private {
        require(balances[account][token] >= amount, "Log:InsurancePool:!destroy");
        balances[account][token] = balances[account][token].sub(amount);
        totalSupply[token] = totalSupply[token].sub(amount);
        emit Destroy(token, amount, account);
    }

    /// @dev Additional LP issuance
    /// @param token underlying asset address
    /// @param amount additional issuance quantity
    /// @param account additional issuance address
    function issuance(address token, 
                      uint256 amount, 
                      address account) private {
        balances[account][token] = balances[account][token].add(amount);
        totalSupply[token] = totalSupply[token].add(amount);
        emit Issuance(token, amount, account);
    }

    // function takeOutERC20(address token, uint256 amount, address to) public onlyGovernance {
    //     ERC20(token).safeTransfer(address(to), amount);
    // }

    // function takeOutETH(uint256 amount, address to) public onlyGovernance {
    //     TransferHelper.safeTransferETH(address(to), amount);
    // }
}