//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol import
import './ERC20Basic.sol';

//@audit - Extends ERC20Basic to add allowance, transferfrom, and approve methods
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public  returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
