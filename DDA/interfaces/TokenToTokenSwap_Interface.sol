pragma solidity ^0.4.21;
// @audit - Interface for a TokenToTokenSwap contract
interface TokenToTokenSwap_Interface {
  // @audit - Allows anyone to initialize a  
  // @param - _amount: The amount of base tokens to create
  // @param - _senderAdd: The address of the sender -- either this address or the msg.sender must be the creator of the swap 
  function createSwap(uint _amount, address _senderAdd) external;
}
