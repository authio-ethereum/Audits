//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
import '../token/MintableToken.sol';
import '../math/SafeMath.sol';

//@audit - Basic Crowdsale contract
contract Crowdsale {
  //@audit - Using ... for attaches SafeMath functions to uint types
  using SafeMath for uint256;

  //@audit - The address of the token being sold, cast to MintableToken
  MintableToken public token;

  //@audit - The uint start and end time of the crowdsale
  uint256 public startTime;
  uint256 public endTime;

  //@audit - The address of the wallet to forward raised funds to
  address public wallet;

  //@audit - The rate of tokens per wei spent
  uint256 public rate;

  //@audit - Keeps track of amount of wei raised
  uint256 public weiRaised;

  //@audit - TokenPurchase event
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  //@audit - Constructor: Sets start and end time, as well as token purcahase rate and wallet
  function Crowdsale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet) public {
    //@audit - Ensure the crowdsale start time is in the future
    require(_startTime >= now);
    //@audit - Ensure the crowdsale end time is after the start time
    require(_endTime >= _startTime);
    //@audit - Ensure the amount of tokens received per wei spent is nonzero
    require(_rate > 0);
    //@audit - Ensure the forwarding wallet is valid
    require(_wallet != address(0));

    //@audit - Deploy the crowdsale's token
    token = createTokenContract();
    //@audit - Set start time, end time, rate, and forwarding wallet
    startTime = _startTime;
    endTime = _endTime;
    rate = _rate;
    wallet = _wallet;
  }

  //@audit - Deploys a MintableToken contract
  //@returns - "MintableToken": The address of the deployed MintableToken contract
  //@audit - VISIBILITY internal: This function can only be called from within this contract
  function createTokenContract() internal returns (MintableToken) {
    return new MintableToken();
  }

  //@audit - Fallback function - allows the sender to purchase tokens
  //@audit - VISIBILITY external: This function can only be called from outside the contract
  //@audit - MODIFIER payable: This function can be sent Ether
  function () external payable {
    buyTokens(msg.sender);
  }

  //@audit - Token purchase function
  //@param - "beneficiary": The address of the person to buy tokens for
  //@audit - MODIFIER payable: This function can be sent Ether
  function buyTokens(address beneficiary) public payable {
    //@audit - Ensure the address to purchase for is nonzero
    require(beneficiary != address(0));
    //@audit - Ensure the token purchase is valid
    require(validPurchase());

    //@audit - Get the wei being spent
    uint256 weiAmount = msg.value;

    //@audit - Get the number of tokens to purchase using the rate
    uint256 tokens = weiAmount.mul(rate);

    //@audit - Incremen weiRaised by the amount spent
    weiRaised = weiRaised.add(weiAmount);

    //@audit - Mint the purchased tokens for the beneficiary
    token.mint(beneficiary, tokens);
    //@audit - TokenPurchase event
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    //@audit - Forward funds to forwarding wallet
    forwardFunds();
  }

  //@audit - Forwards funds to the forwarding wallet
  //@audit - VISIBILITY internal: This function can only be called from within this contract
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  //@audit - Returns whether or not a token purchase can be made
  //@returns - "bool": Whether or not a purchase can be made
  //@audit - VISIBILITY internal: This function can only be called from within this contract
  //@audit - NOTE: Function should be marked constant or view
  function validPurchase() internal  returns (bool) {
    //@audit - withinPeriod is true if crowdsale start time is in the past, and end time is in the future
    bool withinPeriod = now >= startTime && now <= endTime;
    //@audit - nonZeroPurchase is true if a nonzero amount of Ether was sent
    bool nonZeroPurchase = msg.value != 0;
    //@audit - Returns true if withinPeriod and nonZeroPurchase are true
    return withinPeriod && nonZeroPurchase;
  }

  //@audit - Returns whether the crowdsale has started
  //@returns - "bool": Whether the crowdsale has started
  function hasStarted() public constant returns (bool) {
    return now >= startTime;
  }

  //@audit - Returns whether the crowdsale has ended
  //@returns - "bool": Whether the crowdsale has ended
  function hasEnded() public view returns (bool) {
    return now > endTime;
  }

  //@audit - Returns block.timestamp
  //@returns - "uint": The current block's timestamp
  function currentTime() public constant returns(uint256) {
    return now;
  }
}
