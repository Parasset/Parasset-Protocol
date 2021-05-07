// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./PToken.sol";
import "./lib/SafeMath.sol";
import './lib/TransferHelper.sol';
import './lib/SafeERC20.sol';
import "./iface/IERC20.sol";
import "./iface/IInsurancePool.sol";
import "./iface/IPTokenFactory.sol";
import "./iface/IPriceController.sol";
import "./lib/ReentrancyGuard.sol";

contract MortgagePool is ReentrancyGuard {
	using SafeMath for uint256;
	using SafeERC20 for ERC20;

    // Governance address
	address public governance;
	// Underlying asset address => PToken address
	mapping(address=>address) public underlyingToPToken;
	// PToken address => Underlying asset address
	mapping(address=>address) public pTokenToUnderlying;
    // PToken address => Mortgage asset address => Bool
	mapping(address=>mapping(address=>bool)) mortgageAllow;
    // PToken address => Mortgage asset address => User address => Debt data
	mapping(address=>mapping(address=>mapping(address=>PersonalLedger))) ledger;
    // PToken address => Mortgage asset address => Users who have created debt positions(address)
    mapping(address=>mapping(address=>address[])) ledgerArray;
    // Mortgage asset address => Maximum mortgage rate
    mapping(address=>uint256) maxRate;
    // Mortgage asset address => Liquidation line
    mapping(address=>uint256) liquidationLine;
    // PriceController contract
    IPriceController quary;
    // Insurance pool contract
    IInsurancePool insurancePool;
    // PToken creation factory contract
    IPTokenFactory pTokenFactory;
	// Market base interest rate
	uint256 r0 = 0.025 ether;
	// Amount of blocks produced in a year
	uint256 oneYear = 2400000;
    // Status
    uint8 public flag;      // = 0: pause
                            // = 1: active
                            // = 2: out only

	struct PersonalLedger {
        uint256 mortgageAssets;         // Amount of mortgaged assets
        uint256 parassetAssets;         // Amount of debt(Ptoken,Stability fee not included)
        uint256 blockHeight;            // The block height of the last operation
        uint256 rate;                   // Mortgage rate(Initial mortgage rate,Mortgage rate after the last operation)
        bool created;                   // Is it created
    }

    event FeeValue(address pToken, uint256 value);

    /// @dev Initialization method
    /// @param factoryAddress PToken creation factory contract
	constructor (address factoryAddress) public {
        pTokenFactory = IPTokenFactory(factoryAddress);
        governance = pTokenFactory.getGovernance();
        flag = 0;
    }

    //---------modifier---------

    modifier onlyGovernance() {
        require(msg.sender == governance, "Log:MortgagePool:!gov");
        _;
    }

    modifier whenActive() {
        require(flag == 1, "Log:MortgagePool:!active");
        _;
    }

    modifier outOnly() {
        require(flag != 0, "Log:MortgagePool:!0");
        _;
    }

    //---------view---------

    /// @dev Calculate the stability fee
    /// @param parassetAssets Amount of debt(Ptoken,Stability fee not included)
    /// @param blockHeight The block height of the last operation
    /// @param rate Mortgage rate(Initial mortgage rate,Mortgage rate after the last operation)
    /// @param nowRate Current mortgage rate (not including stability fee)
    /// @return fee
    function getFee(uint256 parassetAssets, 
    	            uint256 blockHeight,
    	            uint256 rate,
                    uint256 nowRate) public view returns(uint256) {
        uint256 topOne = parassetAssets.mul(r0).mul(block.number.sub(blockHeight));
        uint256 ratePlus = rate.add(nowRate);
        uint256 topTwo = parassetAssets.mul(r0).mul(block.number.sub(blockHeight)).mul(uint256(3).mul(ratePlus));
    	uint256 bottom = oneYear.mul(1 ether);
    	return topOne.div(bottom).add(topTwo.div(bottom.mul(1 ether).mul(2)));
    }

    /// @dev Calculate the mortgage rate
    /// @param mortgageAssets Amount of mortgaged assets
    /// @param parassetAssets Amount of debt
    /// @param tokenPrice Mortgage asset price(1 ETH = ? token)
    /// @param pTokenPrice PToken price(1 ETH = ? pToken)
    /// @return mortgage rate
    function getMortgageRate(uint256 mortgageAssets,
    	                     uint256 parassetAssets, 
    	                     uint256 tokenPrice, 
    	                     uint256 pTokenPrice) public pure returns(uint256) {
        if (mortgageAssets == 0 || pTokenPrice == 0) {
            return 0;
        }
    	return parassetAssets.mul(tokenPrice).mul(1 ether).div(pTokenPrice.mul(mortgageAssets));
    }

    /// @dev Get real-time data of the current debt warehouse
    /// @param mortgageToken Mortgage asset address
    /// @param pToken PToken address
    /// @param tokenPrice Mortgage asset price(1 ETH = ? token)
    /// @param uTokenPrice Underlying asset price(1 ETH = ? Underlying asset)
    /// @param maxRateNum Maximum mortgage rate
    /// @param owner Debt owner
    /// @return fee Stability fee
    /// @return mortgageRate Real-time mortgage rate(Including stability fee)
    /// @return maxSubM The maximum amount of mortgage assets can be reduced
    /// @return maxAddP Maximum number of coins that can be added
    function getInfoRealTime(address mortgageToken, 
                             address pToken, 
                             uint256 tokenPrice, 
                             uint256 uTokenPrice,
                             uint256 maxRateNum,
                             uint256 owner) public view returns(uint256 fee, 
                                                                uint256 mortgageRate, 
                                                                uint256 maxSubM, 
                                                                uint256 maxAddP) {
        PersonalLedger memory pLedger = ledger[pToken][mortgageToken][address(owner)];
        if (pLedger.mortgageAssets == 0 && pLedger.parassetAssets == 0) {
            return (0,0,0,0);
        }
        uint256 pTokenPrice = getDecimalConversion(pTokenToUnderlying[pToken], uTokenPrice, pToken);
        uint256 tokenPriceAmount = tokenPrice;
        fee = getFee(pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate, getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPriceAmount, pTokenPrice));
        mortgageRate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets.add(fee), tokenPriceAmount, pTokenPrice);
        uint256 maxRateEther = maxRateNum.mul(0.01 ether);
        if (mortgageRate >= maxRateEther) {
            maxSubM = 0;
            maxAddP = 0;
        } else {
            maxSubM = pLedger.mortgageAssets.sub(pLedger.parassetAssets.mul(tokenPriceAmount).mul(1 ether).div(maxRateEther.mul(pTokenPrice)));
            maxAddP = pLedger.mortgageAssets.mul(pTokenPrice).mul(maxRateEther).div(uint256(1 ether).mul(tokenPriceAmount)).sub(pLedger.parassetAssets);
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

    /// @dev View debt warehouse data
    /// @param pToken pToken address
    /// @param mortgageToken mortgage asset address
    /// @param owner debt owner
    /// @return mortgageAssets amount of mortgaged assets
    /// @return parassetAssets amount of debt(Ptoken,Stability fee not included)
    /// @return blockHeight the block height of the last operation
    /// @return rate Mortgage rate(Initial mortgage rate,Mortgage rate after the last operation)
    /// @return created is it created
    function getLedger(address pToken, 
    	               address mortgageToken,
                       address owner) public view returns(uint256 mortgageAssets, 
    		                                              uint256 parassetAssets, 
    		                                              uint256 blockHeight,
                                                          uint256 rate,
                                                          bool created) {
    	PersonalLedger memory pLedger = ledger[pToken][mortgageToken][address(owner)];
    	return (pLedger.mortgageAssets, pLedger.parassetAssets, pLedger.blockHeight, pLedger.rate, pLedger.created);
    }

    /// @dev View governance address
    /// @return governance address
    function getGovernance() external view returns(address) {
        return governance;
    }

    /// @dev View insurance pool address
    /// @return insurance pool address
    function getInsurancePool() external view returns(address) {
        return address(insurancePool);
    }

    /// @dev View the market base interest rate
    /// @return market base interest rate
    function getR0() external view returns(uint256) {
    	return r0;
    }

    /// @dev View the amount of blocks produced in a year
    /// @return amount of blocks produced in a year
    function getOneYear() external view returns(uint256) {
    	return oneYear;
    }

    /// @dev View the maximum mortgage rate
    /// @param mortgageToken Mortgage asset address
    /// @return maximum mortgage rate
    function getMaxRate(address mortgageToken) external view returns(uint256) {
    	return maxRate[mortgageToken];
    }

    /// @dev View the liquidation line
    /// @param mortgageToken Mortgage asset address
    /// @return liquidation line
    function getLiquidationLine(address mortgageToken) external view returns(uint256) {
        return liquidationLine[mortgageToken];
    }

    /// @dev View the priceController contract address
    /// @return priceController contract address
    function getPriceController() external view returns(address) {
        return address(quary);
    }

    /// @dev View the ptoken address according to the underlying asset
    /// @param uToken Underlying asset address
    /// @return ptoken address
    function getUnderlyingToPToken(address uToken) external view returns(address) {
        return underlyingToPToken[uToken];
    }

    /// @dev View the underlying asset according to the ptoken address
    /// @param pToken ptoken address
    /// @return underlying asset
    function getPTokenToUnderlying(address pToken) external view returns(address) {
        return pTokenToUnderlying[pToken];
    }

    /// @dev View the debt array length
    /// @param pToken ptoken address
    /// @param mortgageToken mortgage asset address
    /// @return debt array length
    function getLedgerArrayNum(address pToken, 
                               address mortgageToken) external view returns(uint256) {
        return ledgerArray[pToken][mortgageToken].length;
    }

    /// @dev View the debt owner
    /// @param pToken ptoken address
    /// @param mortgageToken mortgage asset address
    /// @param index array subscript
    /// @return debt owner
    function getLedgerAddress(address pToken, 
                              address mortgageToken, 
                              uint256 index) external view returns(address) {
        return ledgerArray[pToken][mortgageToken][index];
    }

    //---------governance----------

    /// @dev Set contract status
    /// @param num 0: pause, 1: active, 2: out only
    function setFlag(uint8 num) public onlyGovernance {
        flag = num;
    }

    /// @dev Allow asset mortgage to generate ptoken
    /// @param pToken ptoken address
    /// @param mortgageToken mortgage asset address
    /// @param allow allow mortgage
    function setMortgageAllow(address pToken, 
    	                      address mortgageToken, 
    	                      bool allow) public onlyGovernance {
    	mortgageAllow[pToken][mortgageToken] = allow;
    }

    /// @dev Set insurance pool contract
    /// @param add insurance pool contract
    function setInsurancePool(address add) public onlyGovernance {
        insurancePool = IInsurancePool(add);
    }

    /// @dev Set market base interest rate
    /// @param num market base interest rate(num = ? * 1 ether)
    function setR0(uint256 num) public onlyGovernance {
    	r0 = num;
    }

    /// @dev Set the amount of blocks produced in a year
    /// @param num amount of blocks produced in a year
    function setOneYear(uint256 num) public onlyGovernance {
    	oneYear = num;
    }

    /// @dev Set liquidation line
    /// @param mortgageToken mortgage asset address
    /// @param num liquidation line(num = ? * 100)
    function setLiquidationLine(address mortgageToken, 
                                uint256 num) public onlyGovernance {
        liquidationLine[mortgageToken] = num.mul(0.01 ether);
    }

    /// @dev Set the maximum mortgage rate
    /// @param mortgageToken mortgage asset address
    /// @param num maximum mortgage rate(num = ? * 100)
    function setMaxRate(address mortgageToken, 
                        uint256 num) public onlyGovernance {
    	maxRate[mortgageToken] = num.mul(0.01 ether);
    }

    /// @dev Set priceController contract address
    /// @param add priceController contract address
    function setPriceController(address add) public onlyGovernance {
        quary = IPriceController(add);
    }

    /// @dev Set the underlying asset and ptoken mapping and
    ///      Set the latest redemption time of ptoken insurance
    /// @param uToken underlying asset address
    /// @param pToken ptoken address
    function setInfo(address uToken, 
                     address pToken) public onlyGovernance {
        require(underlyingToPToken[uToken] == address(0x0), "Log:MortgagePool:underlyingToPToken");
        require(address(insurancePool) != address(0x0), "Log:MortgagePool:0x0");
        underlyingToPToken[uToken] = address(pToken);
        pTokenToUnderlying[address(pToken)] = uToken;
        insurancePool.setLatestTime(uToken);
    }

    //---------transaction---------

    /// @dev Set governance address
    function setGovernance() public {
        governance = pTokenFactory.getGovernance();
        require(governance != address(0x0), "Log:MortgagePool:0x0");
    }

    /// @dev Mortgage asset casting ptoken
    /// @param mortgageToken mortgage asset address
    /// @param pToken ptoken address
    /// @param amount amount of mortgaged assets
    /// @param rate custom mortgage rate
    function coin(address mortgageToken, 
                  address pToken, 
                  uint256 amount, 
                  uint256 rate) public payable whenActive nonReentrant {

    	require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        require(rate > 0 && rate <= maxRate[mortgageToken], "Log:MortgagePool:rate!=0");
        require(amount > 0, "Log:MortgagePool:amount!=0");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;

    	// Get the price and transfer to the mortgage token
        uint256 tokenPrice;
        uint256 pTokenPrice;
        if (mortgageToken != address(0x0)) {
            ERC20(mortgageToken).safeTransferFrom(address(msg.sender), address(this), amount);
            (tokenPrice, pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], msg.value);
        } else {
            require(msg.value >= amount, "Log:MortgagePool:!msg.value");
            (tokenPrice, pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], uint256(msg.value).sub(amount));
        }

        // Calculate the stability fee
        uint256 blockHeight = pLedger.blockHeight;
        uint256 fee = 0;
    	if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            fee = getFee(parassetAssets, blockHeight, pLedger.rate, getMortgageRate(mortgageAssets, parassetAssets, tokenPrice, pTokenPrice));
            // The stability fee is transferred to the insurance pool
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // Eliminate negative accounts
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
            emit FeeValue(pToken, fee);
    	}

        // Additional ptoken issuance
        uint256 pTokenAmount = amount.mul(pTokenPrice).mul(rate).div(tokenPrice.mul(100));
        PToken(pToken).issuance(pTokenAmount, address(msg.sender));

        // Update debt information
        pLedger.mortgageAssets = mortgageAssets.add(amount);
        pLedger.parassetAssets = parassetAssets.add(pTokenAmount);
        pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(pLedger.mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);

        // Tag created
        if (pLedger.created == false) {
            ledgerArray[pToken][mortgageToken].push(address(msg.sender));
            pLedger.created = true;
        }
    }
    
    /// @dev Increase mortgage assets
    /// @param mortgageToken mortgage asset address
    /// @param pToken ptoken address
    /// @param amount amount of mortgaged assets
    function supplement(address mortgageToken, 
                        address pToken, 
                        uint256 amount) public payable outOnly nonReentrant {

    	require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        require(amount > 0, "Log:MortgagePool:!amount");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;
        require(pLedger.created, "Log:MortgagePool:!created");

    	// Get the price and transfer to the mortgage token
        uint256 tokenPrice;
        uint256 pTokenPrice;
        if (mortgageToken != address(0x0)) {
            ERC20(mortgageToken).safeTransferFrom(address(msg.sender), address(this), amount);
            (tokenPrice, pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], msg.value);
        } else {
            require(msg.value >= amount, "Log:MortgagePool:!msg.value");
            (tokenPrice, pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], uint256(msg.value).sub(amount));
        }

        // Calculate the stability fee
        uint256 blockHeight = pLedger.blockHeight;
        uint256 fee = 0;
    	if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            fee = getFee(parassetAssets, blockHeight, pLedger.rate, getMortgageRate(mortgageAssets, parassetAssets, tokenPrice, pTokenPrice));
            // The stability fee is transferred to the insurance pool
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // Eliminate negative accounts
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
            emit FeeValue(pToken, fee);
    	}

        // Update debt information
    	pLedger.mortgageAssets = mortgageAssets.add(amount);
    	pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
    }

    /// @dev Reduce mortgage assets
    /// @param mortgageToken mortgage asset address
    /// @param pToken ptoken address
    /// @param amount amount of mortgaged assets
    function decrease(address mortgageToken, 
                      address pToken, 
                      uint256 amount) public payable outOnly nonReentrant {

    	require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;
        require(amount > 0 && amount <= mortgageAssets, "Log:MortgagePool:!amount");
        require(pLedger.created, "Log:MortgagePool:!created");

    	// Get the price
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], msg.value);

        // Calculate the stability fee
        uint256 blockHeight = pLedger.blockHeight;
        uint256 fee = 0;
    	if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            fee = getFee(parassetAssets, blockHeight, pLedger.rate, getMortgageRate(mortgageAssets, parassetAssets, tokenPrice, pTokenPrice));
            // The stability fee is transferred to the insurance pool
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // Eliminate negative accounts
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
            emit FeeValue(pToken, fee);
    	}

        // Update debt information
    	pLedger.mortgageAssets = mortgageAssets.sub(amount);
    	pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);

        // The debt warehouse mortgage rate cannot be greater than the maximum mortgage rate
    	require(pLedger.rate <= maxRate[mortgageToken], "Log:MortgagePool:!maxRate");

    	// Transfer out mortgage assets
    	if (mortgageToken != address(0x0)) {
    		ERC20(mortgageToken).safeTransfer(address(msg.sender), amount);
    	} else {
            TransferHelper.safeTransferETH(address(msg.sender), amount);
    	}
    }

    /// @dev Increase debt (increase coinage)
    /// @param mortgageToken mortgage asset address
    /// @param pToken ptoken address
    /// @param amount amount of debt
    function increaseCoinage(address mortgageToken,
                             address pToken,
                             uint256 amount) public payable whenActive nonReentrant {

        require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        require(amount > 0, "Log:MortgagePool:!amount");
        PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;
        require(pLedger.created, "Log:MortgagePool:!created");

        // Get the price
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, pTokenToUnderlying[pToken], msg.value);

        // Calculate the stability fee
        uint256 blockHeight = pLedger.blockHeight;
        uint256 fee = 0;
        if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            fee = getFee(parassetAssets, blockHeight, pLedger.rate, getMortgageRate(mortgageAssets, parassetAssets, tokenPrice, pTokenPrice));
            // The stability fee is transferred to the insurance pool
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), fee);
            // Eliminate negative accounts
            insurancePool.eliminate(pToken, pTokenToUnderlying[pToken]);
            emit FeeValue(pToken, fee);
        }

        // Update debt information
        pLedger.parassetAssets = parassetAssets.add(amount);
        pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);

        // The debt warehouse mortgage rate cannot be greater than the maximum mortgage rate
        require(pLedger.rate <= maxRate[mortgageToken], "Log:MortgagePool:!maxRate");

        // Additional ptoken issuance
        PToken(pToken).issuance(amount, address(msg.sender));
    }

    /// @dev Reduce debt (increase coinage)
    /// @param mortgageToken mortgage asset address
    /// @param pToken ptoken address
    /// @param amount amount of debt
    function reducedCoinage(address mortgageToken,
                            address pToken,
                            uint256 amount) public payable outOnly nonReentrant {

        require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
        PersonalLedger storage pLedger = ledger[pToken][mortgageToken][address(msg.sender)];
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;
        address uToken = pTokenToUnderlying[pToken];
        require(amount > 0 && amount <= parassetAssets, "Log:MortgagePool:!amount");
        require(pLedger.created, "Log:MortgagePool:!created");

        // Get the price
        (uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, uToken, msg.value);

        // Calculate the stability fee
        uint256 blockHeight = pLedger.blockHeight;
        uint256 fee = 0;
        if (parassetAssets > 0 && block.number > blockHeight && blockHeight != 0) {
            fee = getFee(parassetAssets, blockHeight, pLedger.rate, getMortgageRate(mortgageAssets, parassetAssets, tokenPrice, pTokenPrice));
            // The stability fee is transferred to the insurance pool
            ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), amount.add(fee));
            // Eliminate negative accounts
            insurancePool.eliminate(pToken, uToken);
            emit FeeValue(pToken, fee);
        }

        // Update debt information
        pLedger.parassetAssets = parassetAssets.sub(amount);
        pLedger.blockHeight = block.number;
        pLedger.rate = getMortgageRate(mortgageAssets, pLedger.parassetAssets, tokenPrice, pTokenPrice);

        // Destroy ptoken
        insurancePool.destroyPToken(pToken, amount, uToken);
    }

    /// @dev Liquidation of debt
    /// @param mortgageToken mortgage asset address
    /// @param pToken ptoken address
    /// @param account debt owner address
    /// @param amount amount of mortgaged assets
    function liquidation(address mortgageToken, 
                         address pToken,
                         address account,
                         uint256 amount) public payable outOnly nonReentrant {

    	require(mortgageAllow[pToken][mortgageToken], "Log:MortgagePool:!mortgageAllow");
    	PersonalLedger storage pLedger = ledger[pToken][mortgageToken][account];
        require(pLedger.created, "Log:MortgagePool:!created");
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;
        require(amount > 0 && amount <= mortgageAssets, "Log:MortgagePool:!amount");

    	// Get the price
        address uToken = pTokenToUnderlying[pToken];
    	(uint256 tokenPrice, uint256 pTokenPrice) = getPriceForPToken(mortgageToken, uToken, msg.value);
        
        // Judging the liquidation line
        checkLine(pLedger, tokenPrice, pTokenPrice, mortgageToken);

        // Calculate the amount of ptoken
        uint256 pTokenAmount = amount.mul(pTokenPrice).mul(90).div(tokenPrice.mul(100));
    	// Transfer to ptoken
    	ERC20(pToken).safeTransferFrom(address(msg.sender), address(insurancePool), pTokenAmount);

    	// Eliminate negative accounts
        insurancePool.eliminate(pToken, uToken);

        // Calculate the debt for destruction
        uint256 offset = parassetAssets.mul(amount).div(mortgageAssets);

        // Destroy ptoken
    	insurancePool.destroyPToken(pToken, offset, uToken);

    	// Update debt information
    	pLedger.mortgageAssets = mortgageAssets.sub(amount);
        pLedger.parassetAssets = parassetAssets.sub(offset);
        // MortgageAssets liquidation, mortgage rate and block number are not updated
        if (pLedger.mortgageAssets == 0) {
            pLedger.parassetAssets = 0;
            pLedger.blockHeight = 0;
            pLedger.rate = 0;
        }

    	// Transfer out mortgage asset
    	if (mortgageToken != address(0x0)) {
    		ERC20(mortgageToken).safeTransfer(address(msg.sender), amount);
    	} else {
            TransferHelper.safeTransferETH(address(msg.sender), amount);
    	}
    }

    /// @dev Check the liquidation line
    /// @param pLedger debt warehouse ledger
    /// @param tokenPrice Mortgage asset price(1 ETH = ? token)
    /// @param pTokenPrice PToken price(1 ETH = ? pToken)
    /// @param mortgageToken mortgage asset address
    function checkLine(PersonalLedger memory pLedger, 
                       uint256 tokenPrice, 
                       uint256 pTokenPrice, 
                       address mortgageToken) private view {
        uint256 parassetAssets = pLedger.parassetAssets;
        uint256 mortgageAssets = pLedger.mortgageAssets;
        // The current mortgage rate cannot exceed the liquidation line
        uint256 mortgageRate = getMortgageRate(pLedger.mortgageAssets, parassetAssets, tokenPrice, pTokenPrice);
        uint256 fee = 0;
        if (parassetAssets > 0 && block.number > pLedger.blockHeight && pLedger.blockHeight != 0) {
            fee = getFee(parassetAssets, pLedger.blockHeight, pLedger.rate, mortgageRate);
        }
        require(getMortgageRate(mortgageAssets, parassetAssets.add(fee), tokenPrice, pTokenPrice) > liquidationLine[mortgageToken], "Log:MortgagePool:!liquidationLine");
    }

    /// @dev Get price
    /// @param mortgageToken mortgage asset address
    /// @param uToken underlying asset address
    /// @param priceValue price fee
    /// @return tokenPrice Mortgage asset price(1 ETH = ? token)
    /// @return pTokenPrice PToken price(1 ETH = ? pToken)
    function getPriceForPToken(address mortgageToken, 
                               address uToken,
                               uint256 priceValue) private returns (uint256 tokenPrice, 
                                                                    uint256 pTokenPrice) {
        (tokenPrice, pTokenPrice) = quary.getPriceForPToken{value:priceValue}(mortgageToken, uToken, msg.sender);   
    }


    // function takeOutERC20(address token, uint256 amount, address to) public onlyGovernance {
    //     ERC20(token).safeTransfer(address(to), amount);
    // }

    // function takeOutETH(uint256 amount, address to) public onlyGovernance {
    //     TransferHelper.safeTransferETH(address(to), amount);
    // }

}