//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol import
import "../ownership/Ownable.sol";

//@audit - Extends the Ownable contract to allow privileged access to halting functions
contract Pausable is Ownable {
  //@audit - Events
  event Pause();
  event Unpause();

  //@audit - Whether the contract is currently paused
  bool public paused = false;

  //@audit - modifier: Only passes if the contract is not paused
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  //@audit - modifier: Only passes if the contract is paused
  modifier whenPaused() {
    require(paused);
    _;
  }

  //@audit - Allows the owner to pause the contract
  //@audit - MODIFIER onlyOwner(): Only the contract owner can call this function
  //@audit - MODIFIER whenNotPaused(): This function can only be called when the contract is not paused
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    Pause();
  }

  //@audit - Allows the owner to unpause a paused contract
  //@audit - MODIFIER onlyOwner(): Only the contract owner can call this function
  //@audit - MODIFIER whenPaused(): This function can only be called when the contract is paused
  function unpause() onlyOwner whenPaused public {
    paused = false;
    Unpause();
  }
}
