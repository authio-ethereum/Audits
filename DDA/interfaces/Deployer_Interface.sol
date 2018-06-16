pragma solidity ^0.4.21;
// @audit - Interface for a Deployer contract
interface Deployer_Interface {
  // @audit - Allows anyone to deploy and initialize a new swap contract (normally called by factory)
  // @param - _party: The "creator" of the new swap contract 
  // @param - _user: The UserContract of the new swap contract 
  // @param - _start: The start date of the new swap contract 
  // @returns - address: The address of the newly created swap contract 
  function newContract(address _party, address user_contract, uint _start_date) external payable returns (address);
}
