pragma solidity ^0.8.3;

// SPDX-License-Identifier: Unlicensed

/**
 * Some blacklisting/whitelisting functionalities:
 *  - adding account to list of blacklisted/whitelisted accounts
 *  - removing account from list of blacklisted/whitelisted accounts
 *  - check whether account is blacklisted/whitelisted accounts (against internal list)
 */
interface IBlacklisting {

    /**
     * Define account status in blacklist
	 *
	 * @param account   Account to be added or removed to/from blacklist
	 * @param add       Should account be added or removed from blacklist
     */
    function setBlacklist(address account, bool add) external;

    /**
     * Define account status in whitelist
	 *
	 * @param account   Account to be added or removed to/from whitelist
	 * @param add       Should account be added or removed from whitelist
     */
    function setWhitelist(address account, bool add) external;
    /**
     * Checks whether account is blacklisted
     */
    function isBlacklisted(address account) external view returns(bool);
	/**
     * Checks whether account is whitelisted
     */
    function isWhitelisted(address account) external view returns(bool);

    /**
    *  Define fee charged to blacklist. Fee supports singe decimal place, i.e it should be multiplied by 10 to get unsigned int: 100 means 10%, 10 means 1% and 1 means 0.1%
    */
    function setBlacklistFee(uint256 blacklistFee) external;
    
}