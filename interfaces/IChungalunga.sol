pragma solidity ^0.8.3;

// SPDX-License-Identifier: Unlicensed

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import './IBlacklisting.sol';
import './IFee.sol';
import './IFeeControl.sol';
import './ISafetyControl.sol';

interface IChungalunga is IERC20, IERC20Metadata, IBlacklisting, ISafetyControl, IFee, IFeeControl {
    
    event UpdateSwapV2Router (
        address indexed newAddress
    );
    
    event SwapAndLiquifyEnabledUpdated (
        bool enabled
    );

    event MarketingSwap (
        uint256 tokensSwapped,
        uint256 ethReceived,
        bool success
    );
    
    event SwapAndLiquify (
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    /**
    * Defines new state of properties TCS uses after some property was changed
    * Properties:
    *   - enabled ->is TCS system enabled
    *   - maxTxLimit -> max number of tokens (in wei) one can sell/buy at once
    *   - holderLimit -> max number of tokens one account can hold
    *   - interval ->interval between two consecutive sales in minutes
    */
    event TCSStateUpdate (
        bool enabled,
        uint256 maxTxLimit,
        uint256 holderLimit,
        uint256 interval
    );


    /**
    * (un)Setting *swapV2Pair address.
    *
    * @param pair       address of AMM pair
    * @param value      true if it's to be treated as AMM pair, otherwise false
    */
    function setLPP(address pair, bool value) external;
    
    /**
     * Max TX can be set either by providing percentage of total supply or exact amount.
     *
     * !MAX TX percentage MUST be between 1 and 10!
     * 
     * emits TCSStateUpdate
     *
     * @param maxTxPercent    new percentage used to calculate max number of tokens that can be transferred at the same time
     */
    function setMaxTxPercent(uint256 maxTxPercent) external;
    /**
     * max TX can be set either by providing percentage of total supply or exact amount.
     *
     * emits TCSStateUpdate
     *
     * @param maxTxAmount    new max number of tokens that can be transferred at the same time
     */
    function setMaxTxAmount(uint256 maxTxAmount) external;

    /**
     * Excluded accounts are not limited by max TX amount.
	 * Included accounts are limited by max TX amount.
     *
     * @param account   account address
     * @param exclude   true if account is to be excluded from max TX control. Otherwise false
     */
    function maxTxControl(address account, bool exclude) external;
    /**
     * Is account excluded from MAX TX limitations?
     *
     * @param account   account address
     * @return          true if account is excluded, otherwise false
     */
    function isExcludedFromMaxTx(address account) external view returns(bool);

    /**
    * Defines new limit to max token amount holder can possess.
    *
    * ! Holder limit MUST be greater than 0.5% total supply
    *
    * emits TCSStateUpdate
    *
    * @param limit      Max number of tokens one holder can possess
    */
    function setHolderLimit(uint256 limit) external;
    
    /**
     * Once set, LP provisioning from liquidity fees will start. 
     * Disabled by default. 
     * Must be called manually
     * - emits SwapAndLiquifyEnabledUpdated event
     *
     * @param enabled   true if swap is enabled, otherwise false
     */
    function setSwapAndLiquifyEnabled(bool enabled) external;
    
    /**
     * It will exclude sale helper router address and presale router address from fee's and rewards
     *
     * @param helperRouter  address of router used by helper 
     * @param presaleRouter address of presale router(contract) used by helper 
     */
    function setHelperSaleAddress(address helperRouter, address presaleRouter) external;
    
    /**
     * Any leftover coin balance on contract can be transferred (withdrawn) to chosen account.
     * Used to clear contract state.
     *
     * @param recipient     address of recipient
     */
    function withdrawLocked(address payable recipient) external;

    /**
     * Function to withdraw collected fees to marketing wallet in case automatic swap is disabled.
     * 
     * ! Will fail it swap is not disabled
     */
    function withdrawFees() external;
    
    /**
     * Updates address of V2 swap router
     * - emits UpdateSwapV2Router event
     *
     * @param newAddress    address of swap router
     */
    function updateSwapV2Router(address newAddress) external;

    /**
     * Starts whitelisted process. 
     * Whitelisted process will is valid for limited time only starting from current time. 
     * It will last for at most provided duration in minutes.
     *
     * @param duration      Duration in minutes. 
     */
    function wlProcess(uint256 duration) external;    
}