pragma solidity ^0.4.21;
// @audit - An interface for an oracle
interface Oracle_Interface{
  // @audit - Allows anyone to see whether or not the oracle was called on a particular date 
  // @param - _date: The date of the request
  // @returns - bool: True if the oracle was queried on _date, false if not
  function getQuery(uint _date) external view returns(bool);
  // @audit - Allows users to retrieve oracle data from a particular date
  // @param - _date: The date of the requested data  
  // @returns - uint: The oracle's data from the specified date
  function retrieveData(uint _date) external view returns (uint);
  // @audit - Allows users to query the oracle. This is payable since oracle requests cost money 
  function pushData() external payable;
}
