pragma solidity ^0.8.3;

// SPDX-License-Identifier: Unlicensed

/**
 * Defines control over:
 *  - who will be paying fees
 *  - when will fees be applied
 */
interface IFeeControl {
    event ExcludeFromFees (
        address indexed account,
        bool isExcluded
    );
    
    event TakeFeeOnlyOnSwap (
        bool enabled
    );
	
	event MinTokensBeforeSwapUpdated (
        uint256 minTokensBeforeSwap
    );
    
    /**
     * Exclude or include account in fee system. Excluded accounts don't pay any fee.
     *
     * @param account   Account address
     * @param exclude   If true account will be excluded, otherwise it will be included in fee
     */
    function feeControl(address account, bool exclude) external;

    /**
     * Is account excluded from paying fees?
     *
     * @param account   Account address
     */
    function isExcludedFromFee(address account) external view returns(bool);
    /**
     * Taking fee only on swaps.
     * Emits TakeFeeOnlyOnSwap(true) event.
     * 
     * @param onSwap    Take fee only on swap (true) or always (false)
     */
     function takeFeeOnlyOnSwap(bool onSwap) external;
     
    /**
	* Changes number of tokens collected before swap can be triggered
    * - emits MinTokensBeforeSwapUpdated event
    *
    * @param thresh     New number of tokens that must be collected before swap is triggered
	*/
	function changeSwapThresh(uint256 thresh) external;
}