//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
import './ERC20Basic.sol';
import '../math/SafeMath.sol';

//@audit - Simple version of StandardToken, extending ERC20Basic
contract BasicToken is ERC20Basic {
  //@audit - Using ... for attaches SafeMath functions to uint types
  using SafeMath for uint256;

  //@audit - Balances mapping: maps addresses to uint token balance
  mapping(address => uint256) balances;

  //@audit - Transfer function: Allows a token holder to move tokens to another address
  //@param - "_to": The address to send tokens to
  //@param - "_value": The uint amount of tokens to send
  //@returns - "bool": Whether the function succeeded
  function transfer(address _to, uint256 _value) public returns (bool) {
    //@audit - Ensure the "to" address is valid
    require(_to != address(0));
    //@audit - Ensure the sender has enough tokens to send
    require(_value <= balances[msg.sender]);

    //@audit - Safe-sub tokens to send from the sender's balance
    balances[msg.sender] = balances[msg.sender].sub(_value);
    //@audit - Safe-add tokens to be sent to the recipient's balance
    balances[_to] = balances[_to].add(_value);
    //@audit - Tranfer event
    Transfer(msg.sender, _to, _value);
    //@audit - Return true
    return true;
  }

  //@audit - Returns the balance of an address
  //@param - "_owner": The address whose balance is being queried
  //@returns - "balance": The uint balance of the owner
  //@audit - NOTE: Function should be marked constant or view
  function balanceOf(address _owner) public  returns (uint256 balance) {
    return balances[_owner];
  }

}
