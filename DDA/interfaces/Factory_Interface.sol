pragma solidity ^0.4.21;
// @audit - Interface for a Factory contract
interface Factory_Interface {
  // @audit - Allows a creator of a swap contract on the start_date to create long and short tokens 
  //          for their swap using the existing long and short tokens contracts for this start_date 
  // @param - _supply: The amount of wrapped ether to designate for the short tokens and the long tokens 
  // @param - _party: The address that will start with the created long and short tokens 
  // @param - _start_date: The start_date of the swap, long tokens, and short tokens contracts 
  // @returns - ltoken: Returns address of the long tokens contract 
  // @returns - stoken: Returns address of the short tokens contract 
  // @returns - token_ratio: Returns the token_ratio used to create these DRCT tokens
  function createToken(uint _supply, address _party, uint _start_date) external returns (address,address, uint);
  // @audit - Allows a swap contract to update the balance of the party and the total supply
  // @param - _party: The party to be paid 
  // @param - _token_add: The address of the DRCT_Token contract that holds the payment drct tokens
  function payToken(address _party, address _token_add) external;
  // @audit - Allows anyone that is whitelisted to deploy a new swap contract that starts on _start_date
  // @param - _start_date: The date to start the new swap
  // @returns - address: The address of the new swap contract
  function deployContract(uint _start_date) external payable returns (address);
  // @audit - A getter for the base token contract of this factory
  // @returns - address: The address of the base token contract
  // @audit - NOTE: This getter is not implemented in the current factory contract
  function getBase() external view returns(address);
  // @audit - Allows users to get the Oracle address, duration, multiplier, and base token address of this factory
  function getVariables() external view returns (address, uint, uint, address);
  // @audit - Allows anyone to get the whitelist status of a member contract 
  // @param - _member: The address of a member contract 
  // @return - bool: A bool representing the whitelist status of the member contract
  function isWhitelisted(address _member) external view returns (bool);
}

