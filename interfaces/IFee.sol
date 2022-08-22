pragma solidity ^0.8.3;

// SPDX-License-Identifier: Unlicensed

/**
 * Defines Fees:
 *  - marketing
 *  - liquidity
 * All fees are using 1 decimal: 1000 means 100%, 100 means 10%, 10 means 1%, 1 means 0.1%
 */
interface IFee {
    /**
     * Struct of fees.
     */
    struct Fees {
      uint256 marketingFee;
      uint256 liquidityFee;
    }
    
    /**
     * Marketing wallet can be changed
     *
     * @param newWallet     Address of new marketing wallet
     */
    function changeMarketingWallet(address newWallet) external;

    /**
	* Changing fees. Distinguishes between buy and sell fees
    *
    * @param liquidityFee   New liquidity fee in percentage written as integer divisible by 1000. E.g. 5% => 0.05 => 50/1000 => 50
    * @param marketingFee   New marketing fee in percentage written as integer divisible by 1000. E.g. 5% => 0.05 => 50/1000 => 50
    * @param isBuy          Are fees for buy or not(for sale)
	*/
    function setFees(uint256 liquidityFee, uint256 marketingFee, bool isBuy)  external;
    
    /**
     * Control whether tokens collected from fees will be automatically swapped or not
     *
     * @param enable        True if swap should be enabled, otherwise false
     */
    function setSwapOfFeeTokens(bool enable) external;
}