pragma solidity ^0.8.3;

// SPDX-License-Identifier: Unlicensed

/**
 * Enables safety and general transaction restrictions control.
 * 
 * Safety control :
 *  1. enabling/disabling anti pajeet system (APS). Can be called by admins to decide whether additional limitiations to sales should be imposed on not
 *  2. enabling/disabling trade control  system (TCS).
 *  3. enabling/disabling sending of tokens between accounts
 *  
 * General control:
 *  1. presale period. During presale all taxes are disabled
 *  2. trade. Before trade is open, no transactions are allowed
 *  3. LP state control. Before LP has been created, trade cannot be opened.
 * 
 */
interface ISafetyControl {

    /**
    * Defines state of APS after change of some of properties.
    * Properties:
    *   - enabled -> is APS enabled
    *   - thresh -> number of tokens(in wei). If one holds more that this number than he cannot sell more than 20% of his tokens at once
    *   - interval -> number of minutes between two consecutive sales
    */
    event APSStateUpdate (
        bool enabled,
        uint256 thresh,
        uint256 interval
    );
    
    /**
     * Enables/disables Anti pajeet system.
     * If enabled it will impose sale restrictions:
     *   - cannot sell more than 0.2% of total supply at once
	 *   - if owns more than 1% total supply:
	 *	    - can sell at most 20% at once (but not more than 0.2 of total supply)
	 *	    - can sell once every hour
     * 
     * emits APSStateUpdate
	 * 
	 * @param enabled   Defines state of APS. true or false
     */
    function setAPS(bool enabled) external;

    /**
     * Enables/disables Trade Control System.
     * If enabled it will impose sale restrictions:
     *   - max TX will be checked
	 *   - holders will not be able to purchase and hold more than _holderLimit tokens
	 *	 - single account can sell once every 2 mins
	 * 
	 * @param enabled   Defines state of TCS. true or false
     */
    function setTCS(bool enabled) external;

    /**
     * Defines new Anti pajeet system threshold in percentage. Value supports single digit, Meaning 10 means 1%.
     * Examples:
     *    to set 1%: 10
     *    to set 0.1%: 1
     * 
     * emits APSStateUpdate
     *
	 * @param thresh  New threshold in percentage of total supply. Value supports single digit.
     */
    function setAPSThreshPercent(uint256 thresh) external;

    /**
    * Defines new Anti pajeet system threshold in tokens. Minimal amount is 1000 tokens
    * 
    * emits APSStateUpdate
    *
	* @param thresh  New threshold in token amount
    */
    function setAPSThreshAmount(uint256 thresh) external;

    /**
    * Sets new interval user will have to wait in between two consecutive sales, if APS is enabled.
    * Default value is 1 hour
    * 
    * 
    * emits APSStateUpdate
    *
    * @param interval   interval between two consecutive sales, in minutes. E.g. 60 means 1 hour
    */
    function setAPSInterval(uint256 interval) external;
    
    /**
     * Upon start of presale all taxes are disabled
	 * Once presale is stopped, taxes are enabled once more
	 * 
	 * @param start     Defines state of Presale. started or stopped
     */
    function setPreSale(bool start) external;
    
    /**
     * Only once trading is open will transactions be allowed. 
     * Trading is disabled by default.
     * Liquidity MUST be proviided before trading can be opened
     *
     * @param on    true if trade is to be opened, otherwise false
     */
    function tradeCtrl(bool on) external;

    /**
    * Enables/disables sharing of tokens between accounts.
    * If enabled, sending tokens from one account to another is permitted. 
    * If disabled, sending tokens from one account to another will be blocked.
    *
    * @param enabled    True if sending between account is permitter, otherwise false      
    */
    function setAccountShare(bool enabled) external;

}