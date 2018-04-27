//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
import '../math/SafeMath.sol';
import './Crowdsale.sol';

//@audit - CappedCrowdsale, extends Crowdsale to add a maximum cap for wei raised
contract CappedCrowdsale is Crowdsale {
  //@audit - Using ... for attaches SafeMath functions to uint types
  using SafeMath for uint256;

  //@audit - The maximum amount of Ether to raise during the crowdsale, in wei
  uint256 public cap;

  //@audit - Constructor: Sets crowdsale wei cap
  //@param - "_cap": The maximum amount of wei to raise
  function CappedCrowdsale(uint256 _cap) public {
    //@audit - Ensure the maximum amount is nonzero
    require(_cap > 0);
    //@audit - Set the cap
    cap = _cap;
  }

  //@audit - Whether a purchase is valid or not
  //@returns - "bool": Whether a purchase is valid
  //@audit - VISIBILITY internal: This function can only be accessed from within this contract
  //@audit - NOTE: Function should be marked constant or view
  function validPurchase() internal  returns (bool) {
    //@audit - Safe-add wei sent to the amount of wei raised in the crowdsale, and determine if it is within the cap amount
    bool withinCap = weiRaised.add(msg.value) <= cap;
    //@audit - Return whether the wei sent is within the cap, as well as the result of Crowdsale.validPurchase
    return super.validPurchase() && withinCap;
  }

  //@audit - Returns whether the crowdsale has ended or not, determined by the wei raised
  //@returns - "bool": Whether the crowdsale has ended
  function hasEnded() public view returns (bool) {
    //@audit - capReached is true if the wei raised is greater than or equal to the crowdsale cap
    bool capReached = weiRaised >= cap;
    //@audit - Returns whether the cap has been reached, or the result of Crowdsale.hasEnded
    return super.hasEnded() || capReached;
  }

}
