pragma solidity ^0.4.21;
// @audit - An interface for an ERC20 Token contract
interface ERC20_Interface {
  // @audit - A getter for the total supply of an ERC20 token
  function totalSupply() external constant returns (uint);
  // @audit - Allows anyone to get the balance of an owner
  // @param - _owner: The address being queried
  // @returns - bal: The balance of the owner
  function balanceOf(address _owner) external constant returns (uint);
  // @audit - Allows anyone to transfer tokens from their balance to another address 
  // @param - _to: The recipient of the transfer 
  // @param - _amount: The amount of tokens to transfer 
  // @returns - bool: The success of the transfer 
  function transfer(address _to, uint _amount) external returns (bool);
  // @audit - Allows anyone to transfer tokens from another address to a recipient. Approval is required for this transaction 
  // @param - _from: The address paying in this transaction 
  // @param - _to: The recipient of the transfer 
  // @param - _amount: The amount to transfer 
  // @returns - bool: The success of this transfer 
  function transferFrom(address _from, address _to, uint _amount) external returns (bool);
  // @audit - Allows anyone to approve a spender to spend a specified amount on their behalf 
  // @param - _spender: The address that is being approved to spend 
  // @param - _amount: The new allowance of the spender 
  // @returns - bool: The success of the approval. Always returns true
  function approve(address _spender, uint _amount) external returns (bool);
  // @audit - Allows anyone to view the allowance of a spender on the behalf of an owner
  // @param - _owner: The address giving the allowance 
  // @param - _spender: The address recieving the allowance  
  // @returns - uint: The allowance of the spender approved by the owner 
  function allowance(address _owner, address _spender) external constant returns (uint);
}
