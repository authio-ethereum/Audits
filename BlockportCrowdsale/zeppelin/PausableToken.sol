//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
import './StandardToken.sol';
import '../lifecycle/Pausable.sol';

//@audit - Extends StandardToken and uses the Pausable interface to allow the owner to pause token movement
contract PausableToken is StandardToken, Pausable {

  //@audit - Extends transfer function to use modifier whenNotPaused
  function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transfer(_to, _value);
  }

  //@audit - Extends transferFrom function to use modifier whenNotPaused
  function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  //@audit - Extends approve function to use modifier whenNotPaused
  function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
    return super.approve(_spender, _value);
  }

  //@audit - Extends increaseApproval function to use modifier whenNotPaused
  function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool success) {
    return super.increaseApproval(_spender, _addedValue);
  }

  //@audit - Extends decreaseApproval function to use modifier whenNotPaused
  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool success) {
    return super.decreaseApproval(_spender, _subtractedValue);
  }
}
