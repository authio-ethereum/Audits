//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Abstract ERC20 contract
contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public  returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
