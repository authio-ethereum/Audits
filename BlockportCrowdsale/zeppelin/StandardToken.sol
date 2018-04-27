//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
import './BasicToken.sol';
import './ERC20.sol';

//@audit - StandardToken, extends ERC20 and BasicToken to implement transferFrom and various approval functions
contract StandardToken is ERC20, BasicToken {

  //@audit - Maps the address of a token holder to the address of a spender, to the amount they are allowed to spend
  //@audit - VISIBILITY internal: This field is only directly accessible within this contract
  mapping (address => mapping (address => uint256)) internal allowed;

  //@audit - Extends BasicToken.transfer
  function transfer(address _to, uint256 _value) public returns (bool) {
    return BasicToken.transfer(_to, _value);
  }

  //@audit - Sends tokens from one address to another, provided the sender has enough allowance
  //@param - "_from": The address the tokens will come from
  //@param - "_to": The address the tokens will go to
  //@param - "_value": The uint amount of tokens to send
  //@returns - "bool": Whether the transfer succeeded
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    //@audit - Ensure the recipient is valid
    require(_to != address(0));
    //@audit - Ensure the _from address has enough of a balance
    require(_value <= balances[_from]);
    //@audit - Ensure the sender has enough allowed spending from the _from addresss
    require(_value <= allowed[_from][msg.sender]);

    //@audit - Safe-sub the tokens to send from _from
    balances[_from] = balances[_from].sub(_value);
    //@audit - Safe-add the tokens to be sent to the _to address
    balances[_to] = balances[_to].add(_value);
    //@audit - Safe-sub from the sender's allowance
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    //@audit - Transfer event
    Transfer(_from, _to, _value);
    //@audit - Return true
    return true;
  }

  //@audit - Allows the sender to approve a spender to send their tokens
  //@param - "_spender": The address of the spender which has access to the sender's tokens
  //@param - "_value": The uint amount of tokens to send
  //@returns - "bool": Whether the approval succeeded
  function approve(address _spender, uint256 _value) public returns (bool) {
    //@audit - Set the sender's allowance
    allowed[msg.sender][_spender] = _value;
    //@audit - Approval event
    Approval(msg.sender, _spender, _value);
    //@audit - Return true
    return true;
  }

  //@audit - Returns the number of tokens the _spender can spend of the _owner's tokens
  //@param - "_owner": The owner of the tokens
  //@param - "_spender": The spender of the tokens
  //@returns - "uint": The uint number of tokens the spender can spend
  //@audit - NOTE: Mark function constant or view
  function allowance(address _owner, address _spender) public  returns (uint256) {
    return allowed[_owner][_spender];
  }

  //@audit - Increase the allowance of a spender
  //@param - "_spender": The address of the spender of the token
  //@param - "_addedValue": The uint amount of value to increase the allowance by
  //@returns - "bool": Whether the approval succeeded
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    //@audit - Safe-add _addedValue to the _spender's allowance of the sender's tokens
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    //@audit - Approval event
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    //@audit - Return true
    return true;
  }

  //@audit - Decrease the allowance of a spender
  //@param - "_spender": The address of the spender of the token
  //@param - "_subtractedValue": The uint amount of value to decrease the allowance by
  //@returns - "bool": Whether the approval succeeded
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    //@audit - Get the current allowance from the _spender
    uint oldValue = allowed[msg.sender][_spender];
    //@audit - If the value to subtract is larger than the current value, set the _spender's allowance to 0
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
    //@audit - Otherwise, Safe-sub from the _spender's allowance
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    //@audit - Approval event
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    //@audit - Return true
    return true;
  }

}
