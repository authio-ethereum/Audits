pragma solidity ^0.4.21;

interface DRCT_Token_Interface {
  function addressCount(address _swap) external constant returns (uint);
  function getBalanceAndHolderByIndex(uint _ind, address _swap) external constant returns (uint, address);
  function getIndexByAddress(address _owner, address _swap) external constant returns (uint);
  function createToken(uint _supply, address _owner, address _swap) external;
  function pay(address _party, address _swap) external;
  function partyCount(address _swap) external constant returns(uint);
}
