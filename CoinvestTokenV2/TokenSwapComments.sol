// @audit - Version pragma
pragma solidity ^0.4.23;

// @audit - Import CoinvestToken
import './CoinvestToken.sol';

// @audit - Token swap contract: Implements the logic for users to upgrade their COIN v1 to v2
contract TokenSwap {

    // @audit - COIN v1 token address
    // @audit - NOTE: This should be a constant, and hardcoded in
    address oldToken;

    // @audit - COIN v2 token address
    // @audit - NOTE: Have the new token address deploy the swap contract, and set this as 'msg.sender' in the Constructor
    CoinvestToken newToken;

    // @audit - Constructor: Sets old and new token addresses
    // @param - "_oldToken": The address of the COIN v1 token contract
    // @param - "_newToken": The address of the COIN v2 token contract
    constructor(address _oldToken, address _newToken)
      public
    {
        oldToken = _oldToken;
        newToken = CoinvestToken(_newToken);
    }

    // @audit - Used with ERC223 standard. COIN v1 tokens are ERC223-compliant and will call this function
    //          when transferring tokens to this contract. This function ensures that the calling contract
    //          is the v1 token, and then transfers v2 tokens to the original sender.
    // @param - "_from": The address that called oldToken.transfer
    // @param - "_value": The amount of tokens to send to the new contract
    // @param - "_data": Any additional data sent
    function tokenFallback(address _from, uint _value, bytes _data)
      external
    {
        // @audit - NOTE: Get rid of compiler warnings with the line: `_data;`
        // @audit - Ensure the sender is the old token address
        require(msg.sender == oldToken);
        // @audit - Invoke the new token's transfer method to transfer tokens from the swap to the _from address
        require(newToken.transfer(_from, _value));
    }

}
