pragma solidity ^0.4.23;
import './CoinvestToken.sol';

contract TokenSwap {
    
    // @audit - The address of the old Coinvest token
    address public constant OLD_TOKEN = 0x0dcd2f752394c41875e259e00bb44fd505297caf;
    // @audit - The new Coinvest token 
    CoinvestToken public newToken;

    // @audit - Constructor: Creates the new Coinvest Token contract
    constructor() 
      public 
    {
        newToken = new CoinvestToken();
    }

    // @audit - Transfers new Coinvest tokens to an address
    // @param - _from: The address being transferred funds 
    // @param - _value: The amount to transfer
    // @param - _data: Unused bytes
    function tokenFallback(address _from, uint _value, bytes _data) 
      external
    {
        // @audit - Ensure that the sender is the old token address
        require(msg.sender == OLD_TOKEN);        
        // @audit - Transfer tokens 
        require(newToken.transfer(_from, _value)); 
    }
    
}
