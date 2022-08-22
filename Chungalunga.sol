
pragma solidity ^0.8.3;

// SPDX-License-Identifier: MIT

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IChungalunga.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

/**
*
* https://www.chungalungacoin.com/
* https://t.me/chungalunga
* https://twitter.com/chungalungacoin
*
*/
contract Chungalunga is IChungalunga, ERC20, Ownable, AccessControlEnumerable {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    event StateProgress (
        bool liquidityAdded,
        bool whitelistStarted,
        bool tradeOpened
    );

    event WHStart (
        uint256 duration
    );
    
    struct TaxedValues{
      uint256 amount;
      uint256 tAmount;
      uint256 tMarketing;
      uint256 tLiquidity;
    }
	
	struct SwapValues{
		uint256 tMarketing;
		uint256 tLiquidity;
		uint256 tHalfLiquidity;
		uint256 tTotal;
		uint256 swappedBalance;
	}
	
	// 
	// CONSTANTS
	//
	//uint256 private constant MAX = ~uint256(0);

	/* Using 18 decimals */
	uint8 private constant DECIMALS = 18;
	
	/* Total supply : 10_000_000_000 tokens (10 Billion) */
	uint256 private constant TOKENS_INITIAL = 10 * 10 ** 9;
	
	/* Minimal number of tokens that must be collected before swap can be triggered: 1000. Real threshold cannot be set below this value */
	uint256 private constant MIN_SWAP_THRESHOLD = 1 * 10 ** 3 * 10 ** uint256(DECIMALS);

    /* By what to divide calculated fee to compensate for supported decimals */
    uint256 private constant DECIMALS_FEES = 1000;
	
	/* Max amount of individual fee. 9.0% */
	uint256 private constant LIMIT_FEES = 90;
	
	/* Max amount of total fees. 10.0% */
	uint256 private constant LIMIT_TOTAL_FEES = 100;

    /* Number of minutes between 2 sales. 117 seconds */
    uint256 private constant TCS_TIME_INTERVAL = 117;
	
	/* Dead address */
	address private constant deadAddress = 0x000000000000000000000000000000000000dEaD;
	
	bytes32 private constant ADMIN_ROLE = keccak256("CL_ADMIN_ROLE");
    bytes32 private constant CTRL_ROLE = keccak256("CL_CTRL_ROLE");
	
	// 
	// MEMBERS
	//
	
	/* How much can each address allow for another address */
    mapping (address => mapping (address => uint256)) private _allowances;
	
	/* Map of addresses and whether they are excluded from fee */
    mapping (address => bool) private _isExcludedFromFee;
    
    /* Map of addresses and whether they are excluded from max TX check */
    mapping (address => bool) private _isExcludedFromMaxTx;
    
    /* Map of blacklisted addresses */
    mapping(address => bool) private _blacklist;
	
	/* Map of whitelisted addresses */
    mapping(address => bool) private _whitelist;
	
	/* Fee that will be charged to blacklisted accounts. Default is 90% */
	uint256 private _blacklistFee = 900;
    
    /* Marketing wallet address */
    address public marketingWalletAddress;

    /* Number of tokens currently pending swap for marketing */
    uint256 public tPendingMarketing;
    /* Number of tokens currently pending swap for liquidity */
    uint256 public tPendingLiquidity;
	
	/* Total tokens in wei. Will be created during initial mint in constructor */
    uint256 private _tokensTotal = TOKENS_INITIAL * 10 ** uint256(DECIMALS);
	
	/* Total fees taken so far */
    Fees private _totalTakenFees = Fees(
    {marketingFee: 0,
      liquidityFee: 0
    });
    
    Fees private _buyFees = Fees(
    {marketingFee: 40,
      liquidityFee: 10
    });
    
    Fees private _previousBuyFees = Fees(
     {marketingFee: _buyFees.marketingFee,
      liquidityFee: _buyFees.liquidityFee
    });
    
    Fees private _sellFees = Fees(
     {marketingFee: 40,
      liquidityFee: 10
    });
    
    Fees private _previousSellFees = Fees(
     {marketingFee: _sellFees.marketingFee,
      liquidityFee: _sellFees.liquidityFee
    });
    
	/* Swap and liquify safety flag */
    bool private _inSwapAndLiquify;
	
	/* Whether swap and liquify is enabled or not. Enabled by default */
    bool private _swapAndLiquifyEnabled = true;
    
	/* Anti Pajeet system */
    bool public apsEnabled = false;

    /* Trade control system */
    bool public tcsEnabled = false;

    /* Is whitelisted process active */
    bool private _whProcActive = false;

    /* When did whitelisted process start? */
    uint256 private _whStart = 0;

    /* Duration of whitelisted process */
    uint256 private _whDuration = 1;

    /* Account sharing system (sending of tokens between accounts. Disabled by default */
    bool private _accSharing = false;

    /* Anti Pajeet system threshold. If a single account holds more that that number of tokens APS limits will be applied */
    uint256 private _apsThresh = 20 * 10 ** 6 * 10 ** uint256(DECIMALS);

    /* Anti Pajeet system interval between two consecutive sales. In minutes. It defines when is the earlies user can sell depending on his last sale. Can be as low as 1 min. Defaults to 1440 mins (24 hours).  */
    uint256 private _apsInterval = 1440;
	
	/* Was LP provided? False by default */
	bool public liquidityAdded = false;
	
	/* Is trade open? False by default */
	bool public tradingOpen = false;
	
	/* Should tokens in marketing wallet be swapped automatically */
	bool private _swapMarketingTokens = true;
	
	/* Should fees be applied only on swaps? Otherwise, all transactions will be taxed */
	bool public feeOnlyOnSwap = false;
	
	/* Mapping of previous sales by address. Used to limit sell occurrence */
    mapping (address => uint256) private _previousSale;

    /* Mapping of previous buys by address. Used to limit buy occurrence */
    mapping (address => uint256) private _previousBuy;
    
	/* Maximal transaction amount -> cannot be higher than available token supply. It will be dynamically adjusted upon start */
    uint256 private _maxTxAmount = 0;

    /* Maximal amount single holder can possess -> cannot be higher than available token supply. Initially it will be set to 1% of total supply. It will be dynamically adjusted */
    uint256 private _maxHolderAmount = (_tokensTotal * 1) / 100;
	
	/* Min number of tokens to trigger sell and add to liquidity. Initially, 300k tokens */
    uint256 private _swapThresh =  300 * 10 ** 3 * 10 ** uint256(DECIMALS);

    /* Number of block when liquidity was added */
    uint256 private _lpCreateBlock = 0;

    /* Number of block when WH process was started */
    uint256 private _whStartBlock = 0;
    
    /* *Swap V2 router */
    IUniswapV2Router02 private _swapV2Router;
    
    /* Swap V2 pair */
    address private _swapV2Pair;
	
	/* Map of AMMs. Special rules apply when AMM is "to" */
	mapping (address => bool) public ammPairs;
    
    constructor () ERC20("Chungalunga", "CL") {
		
        _changeMarketingWallet(address(0x69cEC9B2FFDfE02481fBDC372Cd885FE83F3f694));
		
		_setupRole(CTRL_ROLE, msg.sender);
	
        // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D is RouterV2 on mainnet
        _setupSwap(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
        _setupExclusions();
		
		_setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(CTRL_ROLE, ADMIN_ROLE);

        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, address(this));

        _setupRole(CTRL_ROLE, msg.sender);
        _setupRole(CTRL_ROLE, address(this));
		
        _mint(msg.sender, _tokensTotal);
		
		transferOwnership(msg.sender);
    }
    
    //
    // EXTERNAL ACCESS
    //

	function addCTRLMember(address account) public virtual onlyRole(ADMIN_ROLE) {
        grantRole(CTRL_ROLE, account);
    }

    function removeCTRLMember(address account) public virtual onlyRole(ADMIN_ROLE) {
        revokeRole(CTRL_ROLE, account);
    }

    function renounceAdminRole() public virtual onlyRole(ADMIN_ROLE) {
        revokeRole(CTRL_ROLE, msg.sender);
        revokeRole(ADMIN_ROLE, msg.sender);
    }

    /**
    * Fetches how many tokens were taken as fee so far
    *
    * @return (marketingFeeTokens, liquidityFeeTokens)
    */
    function totalTakenFees() public view returns (uint256, uint256) {
        return (_totalTakenFees.marketingFee, _totalTakenFees.liquidityFee);
    }

    /**
    * Fetches current fee settings: buy or sell.
    *
    * @param isBuy  true if buy fees are requested, otherwise false
    * @return (marketingFee, liquidityFee)
    */
    function currentFees(bool isBuy) public view returns (uint256, uint256) {
        if(isBuy){
            return (_buyFees.marketingFee, _buyFees.liquidityFee);
        } else {
            return (_sellFees.marketingFee, _sellFees.liquidityFee);
        }
    }
    
    function feeControl(address account, bool exclude) override external onlyRole(CTRL_ROLE) {
        _isExcludedFromFee[account] = exclude;
    }
    
    /* Check whether account is exclude from fee */
    function isExcludedFromFee(address account) override external view returns(bool) {
        return _isExcludedFromFee[account];
    }
    
    function maxTxControl(address account, bool exclude) external override onlyRole(CTRL_ROLE) {
        _isExcludedFromMaxTx[account] = exclude;
    }
    
    function isExcludedFromMaxTx(address account) public view override returns(bool) {
        return _isExcludedFromMaxTx[account];
    }

    function setHolderLimit(uint256 limit) external override onlyRole(CTRL_ROLE) {
        require(limit > 0 && limit < TOKENS_INITIAL, "HOLDER_LIMIT1");

        uint256 new_limit = limit * 10 ** uint256(DECIMALS);

        // new limit cannot be less than 0.5%
        require(new_limit > ((_tokensTotal * 5) / DECIMALS_FEES), "HOLDER_LIMIT2");

        _maxHolderAmount = new_limit;

        emit TCSStateUpdate(tcsEnabled, _maxTxAmount, _maxHolderAmount, TCS_TIME_INTERVAL);
    }

    /* It will exclude sale helper router address and presale router address from fee's and rewards */
    function setHelperSaleAddress(address helperRouter, address presaleRouter) external override onlyRole(CTRL_ROLE) {
        _excludeAccount(helperRouter, true);
        _excludeAccount(presaleRouter, true);
    }

    /* Enable Trade control system. Imposes limitations on buy/sell */
    function setTCS(bool enabled) override external onlyRole(CTRL_ROLE) {
        tcsEnabled = enabled;

        emit TCSStateUpdate(tcsEnabled, _maxTxAmount, _maxHolderAmount, TCS_TIME_INTERVAL);
    }

    /**
     * Returns TCS state:
     * - max TX amount in wei
     * - max holder amount in wei
     * - TCS buy/sell interval in minutes
     */
    function getTCSState() public view onlyRole(CTRL_ROLE) returns(uint256, uint256, uint256) {
        return (_maxTxAmount, _maxHolderAmount, TCS_TIME_INTERVAL);
    }
    
	/* Enable anti-pajeet system. Imposes limitations on sale */
    function setAPS(bool enabled) override external onlyRole(CTRL_ROLE) {
        apsEnabled = enabled;

        emit APSStateUpdate(apsEnabled, _apsThresh, _apsInterval);
    }

	/* Sets new APS threshold. It cannot be set to more than 5% */
    function setAPSThreshPercent(uint256 thresh) override external onlyRole(CTRL_ROLE) {
        require(thresh < 50, "APS-THRESH-PERCENT");

        _apsThresh = _tokensTotal.mul(thresh).div(DECIMALS_FEES);

        emit APSStateUpdate(apsEnabled, _apsThresh, _apsInterval);
    }

    function setAPSThreshAmount(uint256 thresh) override external onlyRole(CTRL_ROLE) {
        require(thresh > 1000 && thresh < TOKENS_INITIAL, "APS-THRESH-AMOUNT");

        _apsThresh = thresh * 10 ** uint256(DECIMALS);

        emit APSStateUpdate(apsEnabled, _apsThresh, _apsInterval);
    }

    /* Sets new min APS sale interval. In minutes */
    function setAPSInterval(uint256 interval) override external onlyRole(CTRL_ROLE) {
        require(interval > 0, "APS-INTERVAL-0");

        _apsInterval = interval;

        emit APSStateUpdate(apsEnabled, _apsThresh, _apsInterval);
    }

    /**
     * Returns APS state:
     * - threshold in tokens
     * - interval in minutes
     */
    function getAPSState() public view onlyRole(CTRL_ROLE) returns(uint256, uint256) {
        return (_apsThresh, _apsInterval);
    }

    /* wnables/disables account sharing: sending of tokens between accounts */
    function setAccountShare(bool enabled) override external onlyRole(CTRL_ROLE) {
        _accSharing = enabled;
    }
    
	/* Changing marketing wallet */
    function changeMarketingWallet(address account) override external onlyRole(CTRL_ROLE) {
        _changeMarketingWallet(account);
    }
    
    function setFees(uint256 liquidityFee, uint256 marketingFee, bool isBuy) external override onlyRole(CTRL_ROLE) {
        // fees are setup so they can not exceed 10% in total
        // and specific limits for each one.
        require(marketingFee + liquidityFee <= LIMIT_TOTAL_FEES, "FEE-MAX");
       
        _setMarketingFeePercent(marketingFee, isBuy);
        _setLiquidityFeePercent(liquidityFee, isBuy);
    }
   
    /* Define MAX TX amount. In percentage of total supply */
    function setMaxTxPercent(uint256 maxTxPercent) override external onlyRole(CTRL_ROLE) {
        require(maxTxPercent <= 1000, "MAXTX_PERC_LIMIT");
        _maxTxAmount = _tokensTotal.mul(maxTxPercent).div(DECIMALS_FEES);

        emit TCSStateUpdate(tcsEnabled, _maxTxAmount, _maxHolderAmount, TCS_TIME_INTERVAL);
    }
    
	/* Define MAX TX amount. In token count */
    function setMaxTxAmount(uint256 maxTxAmount) override external onlyRole(CTRL_ROLE) {
        require(maxTxAmount <= TOKENS_INITIAL, "MAXTX_AMNT_LIMIT");
        _maxTxAmount = maxTxAmount * 10 ** uint256(DECIMALS);

        emit TCSStateUpdate(tcsEnabled, _maxTxAmount, _maxHolderAmount, TCS_TIME_INTERVAL);
    }

    /* Enable LP provisioning */
    function setSwapAndLiquifyEnabled(bool enabled) override external onlyRole(CTRL_ROLE) {
        _swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(enabled);
    }
	
	/* Define new swap threshold. Cannot be less than MIN_SWAP_THRESHOLD: 1000 tokens */
	function changeSwapThresh(uint256 thresh) override external onlyRole(CTRL_ROLE){
        uint256 newThresh = thresh * 10 ** uint256(DECIMALS);

		require(newThresh > MIN_SWAP_THRESHOLD, "THRESH-LOW");

		_swapThresh = newThresh;
	}

    /* take a look at current swap threshold */
    function swapThresh() public view onlyRole(CTRL_ROLE) returns(uint256) {
        return _swapThresh;
    }
    
	/* Once presale is done and LP is created, trading can be enabled for all. Only once this is set will normal transactions be completed successfully */
    function tradeCtrl(bool on) override external onlyRole(CTRL_ROLE) {
        require(liquidityAdded, "LIQ-NONE");
       _tradeCtrl(on);
    }

    function _tradeCtrl(bool on) internal {
        tradingOpen = on;

        emit StateProgress(true, true, true);
    }

    function wlProcess(uint256 duration) override external onlyRole(CTRL_ROLE) {
        require(liquidityAdded && _lpCreateBlock > 0, "LIQ-NONE");
        require(duration > 1, "WHT-DUR-LOW");

        _whStartBlock = block.number;

        _whProcActive = true;
        _whDuration = duration;
        _whStart = block.timestamp;

        // set MAX TX limit to 10M tokens
        _maxTxAmount = 10 * 10 ** 6 * 10 ** uint256(DECIMALS);

        // make sure trading is closed
        tradingOpen = false;

        // enable aps
        apsEnabled = true;

        // enable tcs
        tcsEnabled = true;

        // return APS thresh to 20M
        _apsThresh = 20 * 10 ** 6 * 10 ** uint256(DECIMALS);

        // emit current state
        emit StateProgress(true, true, false);

        // emit start of whitelist process
        emit WHStart(duration);
    }

	/* Sets should tokens collected through fees be automatically swapped to ETH or not */
    function setSwapOfFeeTokens(bool enabled) override external onlyRole(CTRL_ROLE) {
        _swapMarketingTokens = enabled;
    }
    
	/* Sets should fees be taken only on swap or on all transactions */
    function takeFeeOnlyOnSwap(bool onSwap) override external onlyRole(CTRL_ROLE) {
        feeOnlyOnSwap = onSwap;
        emit TakeFeeOnlyOnSwap(feeOnlyOnSwap);
    }
	
	/* Should be called once LP is created. Manually or programatically (by calling #addInitialLiquidity()) */
	function defineLiquidityAdded() public onlyRole(CTRL_ROLE) {
        liquidityAdded = true;

        if(_lpCreateBlock == 0) {
            _lpCreateBlock = block.number;
        }

        emit StateProgress(true, false, false);
    }
    
	/* withdraw any ETH balance stuck in contract */
    function withdrawLocked(address payable recipient) external override onlyRole(CTRL_ROLE) {
        require(recipient != address(0), 'ADDR-0');
        require(address(this).balance > 0, 'BAL-0');
	
        uint256 amount = address(this).balance;
        // address(this).balance = 0;
    
        (bool success,) = payable(recipient).call{value: amount}('');
    
        if(!success) {
          revert();
        }
    }

    function withdrawFees() external override onlyRole(CTRL_ROLE) {
        require(!_swapAndLiquifyEnabled, "WITHDRAW-SWAP");

        super._transfer(address(this), marketingWalletAddress, balanceOf(address(this)));

        tPendingMarketing = 0;
        tPendingLiquidity = 0;
    }
    
    function isBlacklisted(address account) external view override returns(bool) {
        return _blacklist[account];
    }
	
	function isWhitelisted(address account) external view override returns(bool) {
        return _whitelist[account];
    }
    
    function setBlacklist(address account, bool add) external override onlyRole(CTRL_ROLE) {
		_setBlacklist(account, add);
    }
    
    function setWhitelist(address account, bool add) external override onlyRole(CTRL_ROLE) {
        _whitelist[account] = add;
    }
	
	function setBlacklistFee(uint256 blacklistFee) external override onlyRole(CTRL_ROLE) {
		_blacklistFee = blacklistFee;
	}

    function _setBlacklist(address account, bool add) private {
        _blacklist[account] = add;

        emit BlacklistedAddress(account);
    }

    function bulkWhitelist(address[] calldata addrs, bool add) external onlyRole(CTRL_ROLE) {
        for (uint i=0; i<addrs.length; i++){
            _whitelist[addrs[i]] = add;
        }
    }

    function bulkBlacklist(address[] calldata addrs, bool add) external onlyRole(CTRL_ROLE) {
        for (uint i=0; i<addrs.length; i++){
            _blacklist[addrs[i]] = add;
        }
    }

    function provisionPrivate(address[] calldata addrs, uint256 amount) external onlyRole(CTRL_ROLE) {
        for (uint i=0; i<addrs.length; i++){
            super.transfer(addrs[i], amount);
        }
    }
	
	/* To be called whan presale begins/ends. It will remove/add fees */
	function setPreSale(bool start) external override onlyRole(CTRL_ROLE) {
		if(start) { // presale started
			// remove all fees (buy)
			_removeAllFee(true);
			// remove all fees (sell)
			_removeAllFee(false);
		} else { // presale stopped
			// restore all fees (buy)
			_restoreAllFee(true);
			// restore all fees (sell)
			_restoreAllFee(false);
		}
    }
    
    function updateSwapV2Router(address newAddress) external override onlyRole(CTRL_ROLE) {
        require(newAddress != address(0), "R2-1");
        _setupSwap(newAddress);
    }
    
     //to receive ETH from *swapV2Router when swaping. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    //fallback() external payable {}
    
    //
    // PRIVATE ACCESS
    //
    
    function _setupSwap(address routerAddress) private {
        // Uniswap V2 router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        
        _swapV2Router = IUniswapV2Router02(routerAddress);
    
        // create a swap pair for this new token
        _swapV2Pair = IUniswapV2Factory(_swapV2Router.factory()).createPair(address(this), _swapV2Router.WETH());

		_setAMMPair(address(_swapV2Pair), true);

        //_approve(owner(), address(_swapV2Router), type(uint256).max);

        _isExcludedFromMaxTx[address(_swapV2Router)] = true;

        _approve(owner(), address(_swapV2Router), type(uint256).max);
        ERC20(address(_swapV2Router.WETH())).approve(address(_swapV2Router), type(uint256).max);
        ERC20(address(_swapV2Router.WETH())).approve(address(this), type(uint256).max);
		
		emit UpdateSwapV2Router(routerAddress);
    }
	
	function setLPP(address pair, bool value) external override onlyRole(CTRL_ROLE) {
        _setAMMPair(pair, value);

        if (!liquidityAdded) {
            defineLiquidityAdded();
        }
    }

    function _setAMMPair(address pair, bool value) private {
        ammPairs[pair] = value;

        _isExcludedFromMaxTx[pair] = value;
    }
    
    function _excludeAccount(address addr, bool ex) private {
         _isExcludedFromFee[addr] = ex;
         _isExcludedFromMaxTx[addr] = ex;
    }
    
    function _setupExclusions() private {
        _excludeAccount(msg.sender, true);
        _excludeAccount(address(this), true);
        _excludeAccount(owner(), true);
		_excludeAccount(deadAddress, true);
        _excludeAccount(marketingWalletAddress, true);
    }
    
    function _changeMarketingWallet(address addr) internal {
        require(addr != address(0), "ADDR-0");
        _excludeAccount(marketingWalletAddress, false);
		
        marketingWalletAddress = addr;
		
		_excludeAccount(addr, true);
    }
    
    function _isBuy(address from) internal view returns(bool) {
        //return from == address(_swapV2Pair) || ammPairs[from];
        return ammPairs[from];
    }
    
    function _isSell(address to) internal view returns(bool) {
        //return to == address(_swapV2Pair) || ammPairs[to];
        return ammPairs[to];
    }
    
    function _checkTxLimit(address from, address to, uint256 amount) internal view {
        if (_isBuy(from)) { // buy
			require(amount <= _maxTxAmount || _isExcludedFromMaxTx[to], "TX-LIMIT-BUY");
        } else  if (_isSell(to)) { // sell
            require(amount <= _maxTxAmount || _isExcludedFromMaxTx[from], "TX-LIMIT-SELL");
        } else { // transfer
			require(amount <= _maxTxAmount || (_isExcludedFromMaxTx[from] || _isExcludedFromMaxTx[to]), "TX-LIMIT");
        }
    }
    
    function _setMarketingFeePercent(uint256 fee, bool isBuy) internal {
        require(fee <= LIMIT_FEES, "FEE-LIMIT-M");
        
        if(isBuy){
            _previousBuyFees.marketingFee = _buyFees.marketingFee;
            _buyFees.marketingFee = fee;
        } else {
            _previousSellFees.marketingFee = _sellFees.marketingFee;
            _sellFees.marketingFee = fee;
        }
    }
    
    function _setLiquidityFeePercent(uint256 liquidityFee, bool isBuy) internal {
        require(liquidityFee <= LIMIT_FEES, "FEE-LIMIT-L");
        
         if(isBuy){
            _previousBuyFees.liquidityFee = _buyFees.liquidityFee;
            _buyFees.liquidityFee = liquidityFee;
        } else {
            _previousSellFees.liquidityFee = _sellFees.liquidityFee;
            _sellFees.liquidityFee = liquidityFee;
        }
    }

    function _getValues(uint256 amount, bool isBuy) private view returns (TaxedValues memory totalValues) {
        totalValues.amount = amount;
        totalValues.tMarketing = _calculateMarketingFee(amount, isBuy);
        totalValues.tLiquidity = _calculateLiquidityFee(amount, isBuy);
        
        totalValues.tAmount = amount.sub(totalValues.tMarketing).sub(totalValues.tLiquidity);
        
        return totalValues;
    }
    
    function _calculateMarketingFee(uint256 amount, bool isBuy) private view returns (uint256) {
        if(isBuy){
            return _buyFees.marketingFee > 0 ?
                amount.mul(_buyFees.marketingFee).div(DECIMALS_FEES) : 0;
        } else {
            return _sellFees.marketingFee > 0 ?
                amount.mul(_sellFees.marketingFee).div(DECIMALS_FEES) : 0;
        }
    }

    function _calculateLiquidityFee(uint256 amount, bool isBuy) private view returns (uint256) {
        if(isBuy){
            return _buyFees.liquidityFee > 0 ?
                amount.mul(_buyFees.liquidityFee).div(DECIMALS_FEES) : 0;
        } else {
            return _sellFees.liquidityFee > 0 ?
                amount.mul(_sellFees.liquidityFee).div(DECIMALS_FEES) : 0; 
        }
    }
    
    function _removeAllFee(bool isBuy) private {
        if(isBuy){
            _previousBuyFees = _buyFees;
            _buyFees.liquidityFee = 0;
            _buyFees.marketingFee = 0;
        } else {
            _previousSellFees = _sellFees;
            _sellFees.liquidityFee = 0;
            _sellFees.marketingFee = 0;
        }
    }
    
    function _restoreAllFee(bool isBuy) private {
        if(isBuy){
            _buyFees = _previousBuyFees;
        } else {
            _sellFees = _previousSellFees;
        }
    }
    
    /**
    * Transfer codes:
    *   - FROM-ADDR-0 -> from address is 0
    *   - TO-ADDR-0 -> to address is 0
    *   - ADDR-0 -> if some address is 0 
    *   - CNT-0 -> if some amount is 0
    */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "FROM-ADDR-0");
        require(to != address(0), "TO-ADDR-0");
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if(_blacklist[from] || _blacklist[to]) {
			_blacklistDefense(from, to, amount);
            return;
        }

        if (!_inSwapAndLiquify) {

            // whitelist process check
            _whitelistProcessCheck();

            // general rules of conduct
            _generalRules(from, to, amount);

            // TCS  (Trade Control System) check
            _tcsCheck(from, to, amount);
            
            // APS (Anti Pajeet System) check
            _apsCheck(from, to, amount);

            // DLP (Delayed Provision)
            _delayedProvision(from, to);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = !_inSwapAndLiquify;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to] ) {
            takeFee = false;
        }

        /*
        // take fee only on swaps depending on input flag
        if (feeOnlyOnSwap && !_isBuy(from) && !_isSell(to)) {
            takeFee = false;
        }
        */
        
        //transfer amount, it will take tax, special, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function _defense(address from, address to, uint256 amount, uint256 fee) private {
		uint256 tFee = amount * fee / DECIMALS_FEES;
		uint256 tRest = amount - tFee;

        super._transfer(from, address(this), tFee);
        super._transfer(from, to, tRest);

        uint256 totalFeeP = 0;
        uint256 mFee = 0;
        uint256 lFee = 0;
        if (_isBuy(from)) {
            totalFeeP = _buyFees.liquidityFee + _buyFees.marketingFee;
            if (totalFeeP > 0) {
                lFee = _buyFees.liquidityFee > 0 ? tFee * _buyFees.liquidityFee / totalFeeP : 0;
                mFee = tFee - lFee;
            }
        } else {
            totalFeeP = _sellFees.liquidityFee + _sellFees.marketingFee;
            if (totalFeeP > 0) {
                lFee = _sellFees.liquidityFee > 0 ? tFee * _sellFees.liquidityFee / totalFeeP : 0;
                mFee = tFee - lFee;
            }
        }

        if (totalFeeP > 0) {
            tPendingMarketing += mFee;
            tPendingLiquidity += lFee;
            _totalTakenFees.marketingFee += mFee;
            _totalTakenFees.liquidityFee += lFee;
        }
		
	}
	
	function _blacklistDefense(address from, address to, uint256 amount) private {
        _defense(from, to, amount, _blacklistFee);		
	}

    function _whitelistProcessCheck() private {
        if (_whProcActive) {

            require(block.number - _whStartBlock >= 2, "SNIPER-WL");

            if (_whStart + (_whDuration * 1 minutes) < block.timestamp) {
                // whitelist process has expired. Disable it
                _whProcActive = false;

            	// set MAX TX limit to 15M tokens
                _maxTxAmount = 15 * 10 ** 6 * 10 ** uint256(DECIMALS);

                // open trading
                _tradeCtrl(true);
            }
        }
    }

    /**
    * GENERAL codes:
    *   - ACC-SHARE -> account sharing is disabled
    *   - TX-LIMIT-BUY -> transaction limit has been reached during buy
    *   - TX-LIMIT-SELL -> transaction limit has been reached during sell
    *   - TX-LIMIT -> transaction limit has been reached during share
    */
    function _generalRules(address from, address to, uint256 amount) private view {

        // acc sharing
        require(_accSharing || _isBuy(from) || _isSell(to) || from == owner() || to == owner(), "ACC-SHARE"); // either acc sharing is enabled, or at least one of from-to is AMM

        // anti bot
        if (!tradingOpen && liquidityAdded && from != owner() && to != owner()) {

            require(block.number - _lpCreateBlock >= 3, "SNIPER-LP" );

            require(_whProcActive && (_whitelist[from] || _whitelist[to]), "WH-ILLEGAL");
        }

        // check TX limit
        _checkTxLimit(from, to, amount);

    }
    
    
    /**
    * TCS codes:
    *   - TCS-HOLDER-LIMIT -> holder limit is exceeded
    *   - TCS-TIME -> must wait for at least 2min before another sell
    */
    function _tcsCheck(address from, address to, uint256 amount) private view {
        //
        // TCS (Trade Control System):
        // 1. trade imposes MAX tokens that single holder can possess
        // 2. buy/sell time limits of 2 mins
		//

        if (tcsEnabled) {

            // check max holder amount limit
            if (_isBuy(from)) {
                require(amount + balanceOf(to) <= _maxHolderAmount, "TCS-HOLDER-LIMIT");
            } else if(!_isSell(to)) {
                require(amount + balanceOf(to) <= _maxHolderAmount, "TCS-HOLDER-LIMIT");
            }

            // buy/sell limit
            if (_isSell(to)) {
                require( (_previousSale[from] + (TCS_TIME_INTERVAL * 1 seconds)) < block.timestamp, "TCS-TIME");
            } else if (_isBuy(from)) {
                require( (_previousBuy[to] + (TCS_TIME_INTERVAL * 1 seconds)) < block.timestamp, "TCS-TIME");
            } else {
                // token sharing 
                require( (_previousSale[from] + (TCS_TIME_INTERVAL * 1 seconds)) < block.timestamp, "TCS-TIME");
                require( (_previousBuy[to] + (TCS_TIME_INTERVAL * 1 seconds)) < block.timestamp, "TCS-TIME");
            }
        }
    }
    
    /**
    * APS codes:
    *   - APS-BALANCE -> cannot sell more than 20% of current balance if holds more than apsThresh tokens
    *   - APS-TIME -> must wait until _apsInterval passes before another sell
    */
    function _apsCheck(address from, address to, uint256 amount) view private {
        //
		// APS (Anti Pajeet System):
		// 1. can sell at most 20% of tokens in possession at once if holder has more than _apsThresh tokens
		// 2. can sell once every _apsInterval (60) minutes
		//
		
        if (apsEnabled) {
            
            // Sell in progress
            if(_isSell(to)) {

                uint256 fromBalance = balanceOf(from);	// how many tokens does account own

                // if total number of tokens is above threshold, only 20% of tokens can be sold at once!
                if(fromBalance >= _apsThresh) {
                    require(amount < (fromBalance / (5)), "APS-BALANCE");
                }

                // at most 1 sell every _apsInterval minutes (60 by default)
                require( (_previousSale[from] + (_apsInterval * 1 minutes)) < block.timestamp, "APS-TIME");
            }
			
        }
    }
	
	function _swapAndLiquifyAllFees() private {
        uint256 contractBalance = balanceOf(address(this));

        uint256 tTotal = tPendingLiquidity + tPendingMarketing;
        
        if(contractBalance == 0 || tTotal == 0 || tTotal < _swapThresh) {return;}
        
		uint256 tLiqHalf = tPendingLiquidity > 0 ? contractBalance.mul(tPendingLiquidity).div(tTotal).div(2) : 0;
        uint256 amountToSwapForETH = contractBalance.sub(tLiqHalf);
        
        // starting contract's ETH balance
        uint256 initialBalance = address(this).balance;

		// swap tokens for ETH
        _swapTokensForEth(amountToSwapForETH, address(this));
		
		// how much ETH did we just swap into?
        uint256 swappedBalance = address(this).balance.sub(initialBalance);
		
		// calculate ETH shares
		uint256 cMarketing = swappedBalance.mul(tPendingMarketing).div(tTotal);
        uint256 cLiq = swappedBalance - cMarketing;

		// liquify
		if(tPendingLiquidity > 0 && cLiq > 0){
		
			//
			// DLP (Delayed Liquidity Provision):
			// - adding to liquidity only after some threshold has been met to avoid LP provision on every transaction
			//  * NOTE: liquidity provision MUST be enabled first
			//  * NOTE: don't enrich liquidity if sender is swap pair
			//
		
			// add liquidity to LP
			_addLiquidity(tLiqHalf, cLiq);
        
			emit SwapAndLiquify(tLiqHalf, cLiq, tPendingLiquidity.sub(tLiqHalf));
		}
        
		// transfer to marketing
        (bool sent,) = address(marketingWalletAddress).call{value: cMarketing}("");
        emit MarketingSwap(tPendingMarketing, cMarketing, sent);

         // reset token count
        tPendingLiquidity = 0;
        tPendingMarketing = 0;
    }
    
    function _delayedProvision(address from, address to) private {

        if (
            !_inSwapAndLiquify &&
            !_isBuy(from) &&
            _swapAndLiquifyEnabled &&
            !_isExcludedFromFee[from] &&
            !_isExcludedFromFee[to]
        ) {
            _inSwapAndLiquify = true;
			_swapAndLiquifyAllFees();
            _inSwapAndLiquify = false;
		}
    }

    function _swapTokensForEth(uint256 tokenAmount, address account) private {
        // generate the uniswap pair path of token -> weth
		address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _swapV2Router.WETH();

        _approve(address(this), address(_swapV2Router), tokenAmount);

        // make the swap
        _swapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            account,
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_swapV2Router), tokenAmount);

        // add the liquidity
        _swapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            deadAddress,
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        bool isBuy = _isBuy(sender);

        uint256 fees = 0;
        if (takeFee) {
            TaxedValues memory totalValues = _getValues(amount, isBuy);

            fees = totalValues.tMarketing + totalValues.tLiquidity;

            if(fees > 0) {

                tPendingMarketing += totalValues.tMarketing;
                tPendingLiquidity += totalValues.tLiquidity;

                _totalTakenFees.marketingFee += totalValues.tMarketing;
                _totalTakenFees.liquidityFee += totalValues.tLiquidity;

                super._transfer(sender, address(this), fees);

                amount -= fees;
            }
        }

        if (isBuy) {
            _previousBuy[recipient] = block.timestamp;
        } else if(_isSell(recipient)) {
            _previousSale[sender] = block.timestamp;
        } else {
            // token sharing
            _previousBuy[recipient] = block.timestamp;
            _previousSale[sender] = block.timestamp;
        }

        super._transfer(sender, recipient, amount);

    }
    
}