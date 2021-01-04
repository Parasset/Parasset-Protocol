pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
import "./Iface/IERC20.sol";
import "./Iface/IShare.sol";
import "./Iface/IParasset.sol";
import "./lib/SafeERC20.sol";
import './lib/TransferHelper.sol';

contract MortgagePool {
	using SafeMath for uint256;
	using SafeERC20 for ERC20;

    // Mortgage authority
    mapping(address => bool) mortgageAuthority;
    // Liquidation line
    uint256 public liquidation_K = 2;

    // Personal Ledger
    struct PersonalLedger {
        uint256 mortgageAssets;         // Number of mortgaged assets
        address mortgageAddress;        // Mortgage asset address
        uint256 parassetAssets;         // Number of P assets
        address parassetAddress;        // P asset address
        uint256 debtAssets;             // debt
        uint256 rate;                   // Mortgage rate
        uint256 blockHeight;            // Last operation block height
    }
    // Insurance info
    struct InsuranceInfo {
        address shareAddress;           // Share token address
        address stableAssets;           // Stable assets
        uint256 stableAssetsAmount;     // Number of stable assets
        uint256 liabilities;            // Negative account
        uint256 pTokenAmount;           // ptoken number  
    }
    mapping(address => InsuranceInfo) pTokenInsurance;  // ptoken Insurance information
    // User address=>pToken=>Mortgage asset=>Debt information
    mapping(address => mapping(address => mapping(address => PersonalLedger))) personalInfo;
    // Administrator address
	address public governance;
    
    address public controller;

	constructor () public {
		governance = msg.sender;
	}

	//---------modifier---------

    modifier onlyGovernance() 
    {
        require(msg.sender == governance, "Log:Parasset:!gov");
        _;
    }

    modifier onlyController()
    {
        require(msg.sender == controller, "Log:Parasset:!controller");
        _;
    }

    modifier onlyGovOrBy(address _contract) 
    {
        require(msg.sender == governance || msg.sender == _contract, "Log:Parasset:!sender");
        _;
    }

    //---------governance---------

    function setGovernance(address _governance) external onlyGovernance {
    	governance = _governance;
    }

    function setController(address _controller) external onlyGovernance {
        controller = _controller;
    }

    //---------view---------

    function getGovernance() public view returns (address) {
    	return governance;
    }

    function getController() public view returns (address) {
        return controller;
    }

    // Calculate stability fee
    function getFee(PersonalLedger memory info, uint256 _rate) public view returns(uint256) {
        if (info.blockHeight == 0) {
            return 0;
        }
        return info.debtAssets.mul(_rate).mul(uint256(block.number).sub(info.blockHeight)).mul(_rate).mul(2).div(10);
    }

    // View mortgage rate
    function getMortgageRate(uint256 token_price, 
                             uint256 sToken_price, 
                             uint256 _debtAssets,
                             uint256 _mortgageAssets) 
    public pure returns (uint256) 
    {
        return _debtAssets.mul(token_price).div(sToken_price.mul(_mortgageAssets));
    }


    //---------mortgage---------

    // Increase p assets
    function addParassetInfo(address _sToken, address _pToken, address _shareToken) public onlyController {
        // InsuranceInfo insuranceInfo = 
        require(pTokenInsurance[_pToken].stableAssets == address(0x0), "Log:Parasset:!stableAssets");
        pTokenInsurance[_pToken].stableAssets = _sToken;
        pTokenInsurance[_pToken].shareAddress = _shareToken;
        // Create token
        
    }

    // Allow mortgage assets
    function setMortgageAuthority(address _token, bool _authority) public onlyGovOrBy(controller) {
        mortgageAuthority[_token] = _authority;
    }

    //  coin
    function coin(uint256 _amount, uint256 _rate, address _token, address _pToken) public payable {
        PersonalLedger memory info = personalInfo[address(msg.sender)][_pToken][_token];
        //1.Transfer into mortgage assets
        ERC20(_token).safeTransferFrom(address(msg.sender), address(this), _amount);
        //2.Get price
        (uint256 token_price, uint256 sToken_price) = getPrice(_token, pTokenInsurance[_pToken].stableAssets);
        //3.Issuing additional P assets
        uint256 p_amount = _amount.mul(sToken_price).mul(_rate).div(token_price.mul(100));
        IParasset(_pToken).issuance(p_amount, address(msg.sender));
        //4.Settlement stability fee
        uint256 c_rate = getMortgageRate(token_price, sToken_price, info.debtAssets, info.mortgageAssets);
        uint256 fee = getFee(info, c_rate);
        //4-1.Transfer fees, insurance account bookkeeping
        ERC20(_pToken).safeTransfer(address(this), fee);
        pTokenInsurance[_pToken].pTokenAmount = pTokenInsurance[_pToken].pTokenAmount.add(fee);

        //Update
        info.mortgageAssets = info.mortgageAssets.add(_amount);
        info.mortgageAddress = _token;
        info.parassetAssets = info.parassetAssets.add(p_amount);
        info.parassetAddress = _pToken;
        info.debtAssets = info.debtAssets.add(p_amount);
        info.blockHeight = block.number;
    }

    //  Supplementary mortgage
    function supplement(uint256 _amount, address _token, address _pToken) public payable{
        PersonalLedger memory info = personalInfo[address(msg.sender)][_pToken][_token];
        //1.Transfer into mortgage assets
        ERC20(_token).safeTransferFrom(address(msg.sender), address(this), _amount);
        //2.Settlement stability fee
        (uint256 token_price, uint256 sToken_price) = getPrice(_token, pTokenInsurance[_pToken].stableAssets);
        uint256 c_rate = getMortgageRate(token_price, sToken_price, info.debtAssets, info.mortgageAssets);
        uint256 fee = getFee(info, c_rate);
        //2-1.Transfer fees, insurance account bookkeeping
        ERC20(_pToken).safeTransfer(address(this), fee);
        pTokenInsurance[_pToken].pTokenAmount = pTokenInsurance[_pToken].pTokenAmount.add(fee);
        
        //Update
        info.mortgageAssets = info.mortgageAssets.add(_amount);
        info.blockHeight = block.number;
    }

    //  Partial redemption
    function redemption(uint256 _amount, address _token, address _pToken) public payable {
        PersonalLedger memory info = personalInfo[address(msg.sender)][_pToken][_token];
        //1.Settlement stability fee
        (uint256 token_price, uint256 sToken_price) = getPrice(_token, pTokenInsurance[_pToken].stableAssets);
        uint256 c_rate = getMortgageRate(token_price, sToken_price, info.debtAssets, info.mortgageAssets);
        uint256 fee = getFee(info, c_rate);
        //1-1.Transfer fees, insurance account bookkeeping
        ERC20(_pToken).safeTransfer(address(this), fee);
        pTokenInsurance[_pToken].pTokenAmount = pTokenInsurance[_pToken].pTokenAmount.add(fee);

        //2.Destroy P assets
        IParasset(_pToken).destroy(info.parassetAssets.mul(_amount).div(info.debtAssets), address(msg.sender));
        //3.Transfer the mortgage assets
        ERC20(_token).safeTransfer(address(msg.sender), info.mortgageAssets.mul(_amount).div(info.debtAssets));

        //Update
        info.mortgageAssets = info.mortgageAssets.sub(info.mortgageAssets.mul(_amount).div(info.debtAssets));
        info.parassetAssets = info.parassetAssets.sub(info.parassetAssets.mul(_amount).div(info.debtAssets));
        info.debtAssets = info.debtAssets.sub(_amount);
        info.blockHeight = block.number;
    }

    //  Redeem all
    function redemptionAll(address _token, address _pToken) public payable {
        PersonalLedger memory info = personalInfo[address(msg.sender)][_pToken][_token];
        //1.Settlement stability fee
        (uint256 token_price, uint256 sToken_price) = getPrice(_token, pTokenInsurance[_pToken].stableAssets);
        uint256 c_rate = getMortgageRate(token_price, sToken_price, info.debtAssets, info.mortgageAssets);
        uint256 fee = getFee(info, c_rate);
        //1-1.Transfer fees, insurance account bookkeeping
        ERC20(_pToken).safeTransfer(address(this), fee);
        pTokenInsurance[_pToken].pTokenAmount = pTokenInsurance[_pToken].pTokenAmount.add(fee);

        //2.Destroy P assets
        IParasset(_pToken).destroy(info.parassetAssets, address(msg.sender));
        //3.Transfer the mortgage assets
        ERC20(_token).safeTransfer(address(msg.sender), info.mortgageAssets);

        //Update
        info.mortgageAssets = 0;
        info.parassetAssets = 0;
        info.debtAssets = 0;
        info.blockHeight = 0;
    }

    //  Liquidation
    function liquidation(address _account, address _pToken, address _mortgageAddress) public payable{
        PersonalLedger storage info = personalInfo[_account][_pToken][_mortgageAddress];
        //1.Judging the liquidation line
        //1-1.Get price
        (uint256 token_price, uint256 sToken_price) = getPrice(info.mortgageAddress, pTokenInsurance[_pToken].stableAssets);
        uint256 c_rate = getMortgageRate(token_price, sToken_price, info.debtAssets, info.mortgageAssets);
        
        //2-1.Share to the liquidator

        //2-2.Transfer to cofix and change to pToken or sToken

        //3.Determine whether the insurance fund forms a negative account
        
    }

    //---------Insurance---------

	// Fast minting token=>pToken
	function quickIssuance(uint256 _amount, address _token, address _pToken) public {
        require(pTokenInsurance[_pToken].stableAssets == address(_token));
        ERC20(_token).safeTransferFrom(address(msg.sender), address(this), _amount);
		IParasset(_pToken).transfer(address(msg.sender), _amount);
	}

	// Fast redemption pToken=>token
	function quickDestroy(uint256 _amount, address _token, address _pToken) public {
	    InsuranceInfo storage insuranceInfo = pTokenInsurance[_pToken];
        if (insuranceInfo.liabilities > 0 && insuranceInfo.liabilities > _amount) {
            IParasset(_pToken).destroy(_amount, address(msg.sender));
            insuranceInfo.liabilities = insuranceInfo.liabilities.sub(_amount);
        } else if (insuranceInfo.liabilities > 0) {
            IParasset(_pToken).destroy(insuranceInfo.liabilities, address(msg.sender));
            IParasset(_pToken).transfer(address(this), _amount.sub(insuranceInfo.liabilities));
            insuranceInfo.liabilities = 0;
        } else {
            IParasset(_pToken).transfer(address(this), _amount);
        }
		
		ERC20(_token).safeTransfer(address(msg.sender), _amount);
	}

    // Subscribe for insurance
    function subscribeForInsurance(uint256 _amount, address _token, address _pToken) public {
        InsuranceInfo storage insuranceInfo = pTokenInsurance[_pToken];
        uint256 allValue = insuranceInfo.stableAssetsAmount.add(insuranceInfo.pTokenAmount).sub(insuranceInfo.liabilities);
        ERC20(_token).safeTransferFrom(address(msg.sender), address(this), _amount);
        if (_token != _pToken) {
            require(insuranceInfo.stableAssets == address(_token));
            insuranceInfo.stableAssetsAmount = insuranceInfo.stableAssetsAmount.add(_amount);
        } else {
            
        }
        // Calculate share
        uint256 shareAmount = _amount.mul(IERC20(insuranceInfo.shareAddress).totalSupply()).div(allValue);
        IShare(insuranceInfo.shareAddress).issuance(shareAmount, address(msg.sender));
    }

    // Redemption insurance
    function redemptionInsurance(uint256 _amount, address _token, address _pToken) public {
        InsuranceInfo storage insuranceInfo = pTokenInsurance[_pToken];
        uint256 allValue = insuranceInfo.stableAssetsAmount.add(insuranceInfo.pTokenAmount).sub(insuranceInfo.liabilities);
        if (_token != _pToken) {
            require(insuranceInfo.stableAssets == address(_token));
        }
        // Calculate the redemption amount
        uint256 r_amount = _amount.mul(allValue).div(IShare(_pToken).totalSupply());
        ERC20(_token).safeTransfer(address(msg.sender), r_amount);
        IShare(pTokenInsurance[_pToken].shareAddress).destroy(_amount, address(msg.sender));
    }

    //---------Other platforms---------

    // Get price
    function getPrice(address token, address sToken) public returns (uint256 token_price, uint256 sToken_price){

    }

    // Cofix exchange
    function exchange(address _token, uint256 _amount) internal returns (address token, uint256 amount) {

    }

}