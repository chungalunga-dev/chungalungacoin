main(deployer->msg.sender->owner):0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
special:0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
liquidity:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
marketing:0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB

balance (owner): 10 000 000 000 000 000 000 000 000 000

TESTING:

buyer 1: 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
buyer 2: 0x17F6AD8Ef982297579C203069C1DbfFE4348c372
cool guy: 0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC

blacklist: 0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678
whitelist: 0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7

fake AMM: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C

presale helper(router): 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c
presale : 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C


PRESTEPS:
1. transfer (simulate LP creation)
	from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
	to: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C
	amount: 100000000000000000000 (10 TKN with 18 decimals) 
	
2. whitelisting/blacklisting:
	a) whitelist cool guys:
		0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC
		0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7
	b) blacklist bad guys:
		0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678
3.  Presale helper addresses:
	setHelperSaleAddress
		helper: 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c
		presale: 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c
		
PRESALE:
	conditions: 
		- liquidity added
		- trading closed
		- whitelisted addresses
		
	test_1_1_presale_owner
		* This is manual presale. We should disable all fees here first. Then, tokens need to be transferred between owner account to beneficiary
		- defineLiquidityAdded (OPTIONAL)
		- setPreSale
			true
		- transfer
			from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to: 0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC  (cool guy)
			amount: 10000000000000000000 (1 TKN with 18 decimals) 
		- setPreSale
			false
			
	test_1_2_presale_helper
		* This is automated presale. We should disable all fees here first. Then, tokens need to be transferred between presale account via router (which needs to have tokens first) to beneficiary
		- defineLiquidityAdded (OPTIONAL)
		- setPreSale
			true
		- transfer
			from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to: 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c  (presale)
			amount: 100000000000000000000 (10 TKN with 18 decimals) 
		- transferFrom
			msg.sender: 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c(presale helper router)
			from: 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c  (presale)
			to: 0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC  (cool guy)
			amount: 10000000000000000000 (1 TKN with 18 decimals) 
		- setPreSale
			false
		
TRANSFER:
	conditions:
		- liquidity added
		- trading opened
	
	test_2_1_transfer_defineliquidity
		- defineLiquidityAdded
		
	test_2_2_transfer_open_trading_noliquidity
		* shoudld fail as there's not liquidity
		- openTrading
	
	test_2_3_transfer_open_trading_ok
		- defineLiquidityAdded
		- openTrading

	test_2_4_transfer_check_tcs_whitelisted
		* whitelisted address should complete transfer even though trading is still not open
		- defineLiquidityAdded
		- transfer
			from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to 0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7
			amount: 10000000000000000000 (1 TKN with 18 decimals)
	
	test_2_5_transfer_tcs_owner
		* owner should complete transfer even though trading is still not open
		- defineLiquidityAdded
		- transfer 
			from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to: 0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7
			amount: 10000000000000000000 (1 TKN with 18 decimals) 
			
	test_2_6_transfer_tcs_buyer_notopened
		* buyer address should not complete transfer if trading is not open
		- defineLiquidityAdded
		- transfer 
			from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to: 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
			amount: 10000000000000000000 (1 TKN with 18 decimals) 
			
	test_2_7_transfer_blacklisted
		* should not transfer(buy/sell) if address is blacklisted
		- defineLiquidityAdded
		- openTrading
		- transfer
			from 0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7
			to 0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678
			amount: 1000000000000000000 (1 TKN with 18 decimals)
 
	test_2_8_transfer_buyer
		* buyer should complete transaction once trade is open
		- defineLiquidityAdded
		- openTrading
		- transfer
			from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
			amount: 10000000000000000000 (1 TKN with 18 decimals)
	
	test_2_9_transfer_overmaxtx
		* buyer should not be able to make transfer larger than maxtx
		- defineLiquidityAdded
		- openTrading
		- setMaxTxAmount
			amount: 5000000000000000000 (0.5 TKN with 18 decimals)
		- transfer
			from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
			amount: 10000000000000000000 (1 TKN with 18 decimals)
			
	test_2_9_transfer_overmaxtx_excluded
		* buyer that is excluded from maxtx check should be able to make transfer larger than maxtx
		- defineLiquidityAdded
		- openTrading
		- setMaxTxAmount
			amount: 5000000000000000000 (0.5 TKN with 18 decimals)
		- transfer
			from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
			amount: 10000000000000000000 (1 TKN with 18 decimals)
			
	test_2_10_transfer_blocked
		* transfer between accounts is blocked
		- defineLiquidityAdded
		- openTrading
		- setMaxTxAmount
			amount: 10000000000000000000 (1 TKN with 18 decimals)
		- transfer
			from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
			amount: 10000000000000000000 (1 TKN with 18 decimals)
		- blockSharing
		- transfer
			from: 0x617F2E2fD72FD9D5503197092aC168c91465E7f2 (buyer 1)
			to 0x17F6AD8Ef982297579C203069C1DbfFE4348c372 (buyer 2)
			amount: 5000000000000000000 (0.5 TKN with 18 decimals)
			
	test_2_11_transfer_blocked_whitelisted
		* transfer between accounts is blocked but account is whitelisted
		- defineLiquidityAdded
		- openTrading
		- setMaxTxAmount
			amount: 10000000000000000000 (1 TKN with 18 decimals)
		- whitelist
			account: 0x17F6AD8Ef982297579C203069C1DbfFE4348c372 (buyer 2)
		- transfer
			from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
			amount: 10000000000000000000 (1 TKN with 18 decimals)
		- blockSharing
		- transfer
			from: 0x617F2E2fD72FD9D5503197092aC168c91465E7f2 (buyer 1)
			to 0x17F6AD8Ef982297579C203069C1DbfFE4348c372 (buyer 2)
			amount: 5000000000000000000 (0.5 TKN with 18 decimals)
		
FEES:
	conditions:
		- liquidity added
		- trading opened
		
	test_3_1_fees_collect_all
		* should collect fees on all trans
		- defineLiquidityAdded
		- openTrading
		- takeFeeOnlyOnSwap
			onSwap: false
		- transfer
			from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
			amount: 10000000000000000000 (1 TKN with 18 decimals)
		* check marketing and liquidity account balances:
			- balance:
				liquidity: 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
				marketing: 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
				
	test_3_2_fees_excluded
		* account excluded from fees should not collect fees
		- defineLiquidityAdded
		- openTrading
		- takeFeeOnlyOnSwap
			onSwap: false
		- feeControl
			account: 0x17F6AD8Ef982297579C203069C1DbfFE4348c372
			exclude: true
		- transfer
			from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to 0x17F6AD8Ef982297579C203069C1DbfFE4348c372
			amount: 10000000000000000000 (1 TKN with 18 decimals)
		* check marketing and liquidity account balances:
			- balance:
				liquidity: 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db (should be unchanged)
				marketing: 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB (should be unchanged)
	
	
SALE:
	conditions:
		- liquidity added
		- trading opened
		
	test_4_1_sale_buy
		- defineLiquidityAdded
		- openTrading
		- transfer (simulate LP creation)
			from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C (AMM)
			amount: 100000000000000000000 (10 TKN with 18 decimals) 
		- transfer:
			from: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C (AMM)
			to: 0x17F6AD8Ef982297579C203069C1DbfFE4348c372 (buyer)
			amount: 2000000000000000000 (0.2 TKN)
	
	test_4_2_sale_sell
		- defineLiquidityAdded
		- openTrading
		- transfer (simulate LP creation)
			from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C (AMM)
			amount: 100000000000000000000 (10 TKN with 18 decimals) 
		- transfer (simulate buy of 0.2TKN):
			from: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C (AMM)
			to: 0x17F6AD8Ef982297579C203069C1DbfFE4348c372 (buyer)
			amount: 2000000000000000000 (0.2 TKN)
		- transfer (sell 0.1 TKN):
			from: 0x17F6AD8Ef982297579C203069C1DbfFE4348c372 (buyer)
			to: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C (AMM)
			amount: 1000000000000000000 (0.1 TKN)
	
	test_4_3_sale_buysell_excluded
		- defineLiquidityAdded
		- openTrading
		- transfer (simulate LP creation)
			from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C (AMM)
			amount: 100000000000000000000 (10 TKN with 18 decimals) 
		- transfer (buy by owner):
			from: 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C (AMM)
			to: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			amount: 2000000000000000000 (0.2 TKN)
		- transfer (sell by owner):
			from: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 (owner)
			to: 0x17F6AD8Ef982297579C203069C1DbfFE4348c372
			amount: 1000000000000000000 (0.1 TKN)

 