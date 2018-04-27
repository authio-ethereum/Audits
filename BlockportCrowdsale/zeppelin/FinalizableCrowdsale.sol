//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
import '../math/SafeMath.sol';
import '../ownership/Ownable.sol';
import './Crowdsale.sol';

//@audit - Extends basic Crowdsale to add function once a crowdsale is fnialized
contract FinalizableCrowdsale is Crowdsale, Ownable {
  //@audit - Using ... for attaches SafeMath functions to uint types
  using SafeMath for uint256;

  //@audit - Whether the crowdsale is finalized
  bool public isFinalized = false;

  //@audit - Finalized event
  event Finalized();

  //@audit - Called once the crowdsale is complete
  //@audit - MODIFIER onlyOwner(): Only the owner address can call this fucntion (uses Ownable)
  function finalize() onlyOwner public {
    //@audit - Require that finalization has not already occurred. This function can only be called once
    require(!isFinalized);

    //@audit - Call the finalization method. Meant to be overridden by a child contract
    finalization();
    //@audit - Finalized event
    Finalized();

    //@audit - Set isFinalized, so this function cannot be called again
    isFinalized = true;
  }

  //@audit - Finalization method, to be overridden by child contracts
  //@audit - VISIBILITY internal: This function can only be called from within this contract
  function finalization() internal {
  }
}
