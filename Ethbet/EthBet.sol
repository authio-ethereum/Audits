//@audit - NOTE: Use latest version of solidity
pragma solidity ^0.4.11;

//@audit - Imports EthbetToken
//@audit - NOTE: Define and use an interface, to save on deploy costs
import './EthbetToken.sol';


//TODO: This works if we count on only one bet at a time for a user
//@audit - Main Ethbet contract
contract Ethbet {
  //@audit - SafeMath imported from EthbetToken.sol
  //@audi - NOTE: Use latest version of SafeMath, found here: https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol
  using SafeMath for uint256;

  /*
  * Events
  */

  //@audit - Events
  event Deposit(address indexed user, uint amount, uint balance);

  event Withdraw(address indexed user, uint amount, uint balance);

  event LockedBalance(address indexed user, uint amount);

  event UnlockedBalance(address indexed user, uint amount);

  event ExecutedBet(address indexed winner, address indexed loser, uint amount);


  /*
   * Storage
   */
  //@audit - Ethbet relay address
  address public relay;

  //@audit - EthbetToken address
  //@audit - NOTE: Use interface
  EthbetToken public token;

  //@audit - Mapping of contract balances
  mapping (address => uint256) balances;

  //@audit - Mapping of locked balances being used in current open bets
  mapping (address => uint256) lockedBalances;

  /*
  * Modifiers
  */

  //@audit - modifier: ensures the sender is the Ethbet relay address
  modifier isRelay() {
    require(msg.sender == relay);
    _;
  }

  /*
  * Public functions
  */

  /// @dev Contract constructor
  //@audit - Constructor: sets the Ethbet relay and EthbetToken addresses
  //@audit - LOW: There should probably be a "changeRelay" function
  //@param "_relay": Address of Ethbet relay
  //@param "tokenAddress": Address of Ethbet token contract
  function Ethbet(address _relay, address tokenAddress) public {
    // make sure relay address set
    //@audit - Ensure the _relay address is not 0
    require(_relay != address(0));

    //@audit - Set the relay address
    relay = _relay;
    //@audit - Set the token address, casting it to EthbetToken
    token = EthbetToken(tokenAddress);
  }

  /**
   * @dev deposit EBET tokens into the contract
   * @param _amount Amount to deposit
   */
  //@audit - Deposit Ethbet tokens into the contract
  //@audit - NOTE: Should be marked public
  //@param "_amount": The amount of tokens deposited
  function deposit(uint _amount) {
    //@audit - Ensure the amount is nonzero
    require(_amount > 0);

    // token.approve needs to be called beforehand
    // transfer tokens from the user to the contract
    //@audit - Transfers tokens from the sender to the contract. Token.approve must be called first, so that the token can be transferred
    require(token.transferFrom(msg.sender, this, _amount));

    // add the tokens to the user's balance
    //@audit - increment the sender's balance with the amount transferred
    balances[msg.sender] = balances[msg.sender].add(_amount);

    //@audit - Deposit event
    Deposit(msg.sender, _amount, balances[msg.sender]);
  }

  /**
   * @dev withdraw EBET tokens from the contract
   * @param _amount Amount to withdraw
   */
  //@audit - Allows a user to withdraw Ethbet tokens from the contract
  //@audit - NOTE: Users can "withdraw" 0
  //@param "_amount": Amount to withdraw
  function withdraw(uint _amount) public {
    //@audit - Ensure the sender has the available balance to withdraw
    require(balances[msg.sender] >= _amount);

    // subtract the tokens from the user's balance
    //@audit - decrement the sender's balance with the amount to withdraw
    balances[msg.sender] = balances[msg.sender].sub(_amount);

    // transfer tokens from the contract to the user
    //@audit - Transfer the tokens from the contract to the sender
    require(token.transfer(msg.sender, _amount));

    //@audit - Withdraw event
    Withdraw(msg.sender, _amount, balances[msg.sender]);
  }


  /**
   * @dev Lock user balance to be used for bet
   * @param _userAddress User Address
   * @param _amount Amount to be locked
   */
  //@audit - Allows the relay address to lock a portion of the balance of a user's balance in an open bet
  //@audit - NOTE: Balance locked can be "0"
  //@audit - MODIFIER isRelay(): ensures the sender is the Ethbet relay address
  //@param "_userAddress": The address to lock
  //@param "_amount": The amount of tokens to lock
  function lockBalance(address _userAddress, uint _amount) public isRelay {
    //@audit - Ensure the balance of the _userAddress has enough tokens
    require(balances[_userAddress] >= _amount);

    // subtract the tokens from the user's balance
    //@audit - Decrement the user's balance by _amount
    balances[_userAddress] = balances[_userAddress].sub(_amount);

    // add the tokens to the user's locked balance
    //@audit - Add the user's tokens to their locked balance
    lockedBalances[_userAddress] = lockedBalances[_userAddress].add(_amount);

    //@audit - LockedBalance event
    LockedBalance(_userAddress, _amount);
  }

  /**
   * @dev Unlock user balance
   * @param _userAddress User Address
   * @param _amount Amount to be locked
   */
  //@audit - Allows the relay address to unlock a portion of the balance of a user. Is also called when finalizing a bet
  //@audit - NOTE: Balance unlocked can be "0"
  //@audit - MODIFIER isRelay(): Ensures the sender is the Ethbet relay address
  //@param "_userAddress": The address of the user to unlock
  //@param "_amount": The amount of tokens to unlock
  function unlockBalance(address _userAddress, uint _amount) public isRelay {
    //@audit - Ensure the locked balance of the user is at least equal to the amount to unlock
    require(lockedBalances[_userAddress] >= _amount);

    // subtract the tokens from the user's locked balance
    //@audit - Subtract the amount to unlock from the user's locked balance
    lockedBalances[_userAddress] = lockedBalances[_userAddress].sub(_amount);

    // add the tokens to the user's  balance
    //@audit - Increment the user's balance by the amount unlocked
    balances[_userAddress] = balances[_userAddress].add(_amount);

    //@audit - UnlockedBalance event
    UnlockedBalance(_userAddress, _amount);
  }

  /**
  * @dev Get user balance
  * @param _userAddress User Address
  */
  //@audit - Returns the balance of an address
  function balanceOf(address _userAddress) constant public returns (uint) {
    return balances[_userAddress];
  }

  /**
  * @dev Get user locked balance
  * @param _userAddress User Address
  */
  //@audit - Returns the locked balance of an address
  function lockedBalanceOf(address _userAddress) constant public returns (uint) {
    return lockedBalances[_userAddress];
  }

  /**
   * @dev Execute bet
   * @param _maker Maker Address
   * @param _caller Caller Address
   * @param _makerWon Did the maker win
   * @param _amount amount
   */
  //@audit - Allows the relay address to execute and finalize a bet between two parties
  //@audit - MODIFIER isRelay(): The sender must be the Ethbet relay address
  //@param "_maker": The party that created the bet
  //@param "_caller": The party that entered the bet
  //@param "_makerWon": Whether the _maker won the bet or not
  //@param "_amount": The amount placed on the bet
  function executeBet(address _maker, address _caller, bool _makerWon, uint _amount) isRelay public {
    //The caller must have enough balance
    //@audit - Ensure the _caller has a large enough balance to place a bet
    require(balances[_caller] >= _amount);

    //The maker must have enough locked balance
    //@audit - Ensure the _maker's locked balance is large enough
    require(lockedBalances[_maker] >= _amount);

    // unlock maker balance
    //@audit - Unlock the _amount from the _maker
    unlockBalance(_maker, _amount);

    //@audit - If the maker won, the winner will be the _maker
    var winner = _makerWon ? _maker : _caller;
    //@audit - If the maker lost, the loser will be the _caller
    var loser = _makerWon ? _caller : _maker;

    // add the tokens to the winner's balance
    //@audit - Increase the winner's balance by the bet amount
    balances[winner] = balances[winner].add(_amount);
    // remove the tokens from the loser's  balance
    //@audit - Decrease the loser's balance by the bet amount
    balances[loser] = balances[loser].sub(_amount);

    //Log the event
    //@audit - ExecutedBet event
    ExecutedBet(winner, loser, _amount);
  }

}
