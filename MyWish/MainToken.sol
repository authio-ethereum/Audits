pragma solidity ^0.4.23;

// Partial ERC20 interface
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

// SafeMath Library
library SafeMath {

  // Multiply a and b, return c. Assert-style failure on overflow
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  // Divide a and b, return the result
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return a / b;
  }

  // Subtract b from a and return the result. Assert-style failure on underflow
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  // Add a and b, return the result. Assert-style failure on overflow
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

// Basic ERC20 implementation, extended from partial ERC20 interface
contract BasicToken is ERC20Basic {
  // Using SafeMath library to extend uint256
  using SafeMath for uint256;

  // Token balance mapping
  mapping(address => uint256) balances;

  // Total token supply
  uint256 totalSupply_;

  // Implements totalSupply function from ERC20Basic interface, returning totalSupply_
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  // Allows the sender to transfer tokens to another address. Returns true
  function transfer(address _to, uint256 _value) public returns (bool) {
    // Ensure sender is not burning tokens -- no transfers to address(0x0) allowed
    require(_to != address(0));
    // Ensure sender has sufficient balance to send _value tokens
    require(_value <= balances[msg.sender]);

    // Set new sender token balance - previous minus _value
    balances[msg.sender] = balances[msg.sender].sub(_value);
    // Add sent tokens to recipient's balance
    balances[_to] = balances[_to].add(_value);
    // Emit Transfer event
    emit Transfer(msg.sender, _to, _value);
    // Return true
    return true;
  }

  // Implements ERC20Basic interface "balanceOf" function.
  // Queries the balance of the passed-in owner and returns it
  function balanceOf(address _owner) public view returns (uint256) {
    return balances[_owner];
  }
}

// Extends ERC20Basic interface
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender)
    public view returns (uint256);

  function transferFrom(address from, address to, uint256 value)
    public returns (bool);

  function approve(address spender, uint256 value) public returns (bool);
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}

// Implements ERC20 interface
contract StandardToken is ERC20, BasicToken {

  // Token allowances mapping
  mapping (address => mapping (address => uint256)) internal allowed;

  // Implements transferFrom function from ERC20 interface
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    returns (bool)
  {
    // Ensure the recipient is not address(0x0)
    require(_to != address(0));
    // Require that the owner account has sufficient tokens to send _value
    require(_value <= balances[_from]);
    // Require that the sender has been allowed at least _value tokens by the owner
    require(_value <= allowed[_from][msg.sender]);

    // Update owner token balance - prev minus _value
    // NOTE: Because SafeMath is being used, the check above is not needed
    balances[_from] = balances[_from].sub(_value);
    // Update recipient token balance - prev + _value
    balances[_to] = balances[_to].add(_value);
    // Remove transferred tokens from sender's allowance
    // NOTE: Because SafeMath is being used, the check above is not needed
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    // Emit Transfer event
    emit Transfer(_from, _to, _value);
    // Return true
    return true;
  }

  // Approves a spender address to _value of the sender's tokens
  function approve(address _spender, uint256 _value) public returns (bool) {
    // Set the sender's approval amount for _spender to _value
    allowed[msg.sender][_spender] = _value;
    // Emit Approval event
    emit Approval(msg.sender, _spender, _value);
    // Return true
    return true;
  }

  // Getter for token allowances mapping
  function allowance(
    address _owner,
    address _spender
   )
    public
    view
    returns (uint256)
  {
    return allowed[_owner][_spender];
  }

  // Increase token approval by a set amount
  function increaseApproval(
    address _spender,
    uint _addedValue
  )
    public
    returns (bool)
  {
    // Increase sender's approved amount for _spender by _addedValue
    allowed[msg.sender][_spender] = (
      allowed[msg.sender][_spender].add(_addedValue));
    // Emit Approval event
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    // Return true
    return true;
  }

  // Decrease token approval by a set amount
  function decreaseApproval(
    address _spender,
    uint _subtractedValue
  )
    public
    returns (bool)
  {
    // Get previous approved amount
    uint oldValue = allowed[msg.sender][_spender];
    // Instead of throwing on underflow, we set the allowance to 0
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      // No underflow - decrease _spender's approval by _subtractedValue
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    // Emit Approval event
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    // Return true
    return true;
  }
}

// Standard Ownable interface -- implements permissioned access
contract Ownable {
  // Permissioned owner address. 
  // Accesses certain functions through the onlyOwner modifier
  address public owner;

  // Events
  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  // Constructor -- sets the sender as the permissioned owner
  constructor() public {
    owner = msg.sender;
  }

  // Modifier -- only the owner may access this function
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  // Allows the owner to zero out the owner address, removing themselves and anyone else
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = address(0);
  }

  // Allows the owner to transfer ownership to a new address
  function transferOwnership(address _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }

  // Helper function to handle ownership transfer. Disallows setting owner to 0x0
  function _transferOwnership(address _newOwner) internal {
    require(_newOwner != address(0));
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}

// Extension of StandardToken interface to include token minting function.
// Inherits from Ownable, which is used to restrict access to mint functions
contract MintableToken is StandardToken, Ownable {

  // Events
  event Mint(address indexed to, uint256 amount);
  event MintFinished();

  // Whether minting is finished or not. False by default
  bool public mintingFinished = false;

  // Modifier -- This function can only be accessed if minting is not finished
  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  // Modifier -- Only the owner may access this function
  // NOTE: This modifier is redundant, as onlyOwner has the exact same functionality.
  //       Consider removing and using onlyOwner
  modifier hasMintPermission() {
    require(msg.sender == owner);
    _;
  }

  // Allows the sender to mint an amount of tokens to a specified destination address
  // Returns a boolean.
  // NOTE: Returning a boolean here has no use or value. If the execution does not succeed,
  //       the call should revert; false is never returned. Consider removing and not
  //       following this pattern. (As an aside, the boolean returns from ERC20 functions
  //       must still be included. While they are just as redundant as the return in this
  //       function, the ERC20 standard requires that they be included. However, no such
  //       standard requires that mint returns true.)
  // hasMintPermission requires that minting is not finished (mintingFinished == false)
  // canMint requires that the sender is the owner (msg.sender == owner)
  function mint(
    address _to,
    uint256 _amount
  )
    hasMintPermission
    canMint
    public
    returns (bool)
  {
    // Increase totalSupply by _amount
    totalSupply_ = totalSupply_.add(_amount);
    // Increase balance of recipient
    balances[_to] = balances[_to].add(_amount);
    // Emit Mint and Transfer events
    emit Mint(_to, _amount);
    emit Transfer(address(0), _to, _amount);
    // Return true
    return true;
  }

  // Allows the owner to specify that minting is complete. Returns a boolean.
  // NOTE: Similar to the above function, a boolean return serves no purpose here
  // NOTE: Here, onlyOwner is used. Above, hasMintPermission is used. Both have the same
  //       effect -- consider simply using onlyOwner throughout the codebase
  // onlyOwner requires that the sender be the owner (msg.sender == Ownable.owner)
  // canMint requires that minting is not currently finished (mintingFinished == false)
  function finishMinting() onlyOwner canMint public returns (bool) {
    mintingFinished = true;
    emit MintFinished();
    return true;
  }
}

// Extends StandardToken interface to implement capability to send tokens to users that will
// only be available for further transfer and use after a given release date
contract FreezableToken is StandardToken {

    // Maps a record locator for a user's frozen tokens to the next release
    // date in their frozen token history
    mapping (bytes32 => uint64) internal chains;
    
    // Maps a record locator for a user's frozen tokens for some release date
    // to the amount of tokens frozen
    mapping (bytes32 => uint) internal freezings;

    // Maps a user's address to their total amount of tokens frozen
    mapping (address => uint) internal freezingBalance;

    // Events
    event Freezed(address indexed to, uint64 release, uint amount);
    event Released(address indexed owner, uint amount);

    // Implementation of the ERC20 balanceOf function. Returns the user's balance
    // from the 'balances' mapping, and adds to it the user's frozen balance
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return super.balanceOf(_owner) + freezingBalance[_owner];
    }

    // Provides a function to view just the user's token balance, not including frozen
    // tokens. Calls the parent's balanceOf function (in this case, StandardToken)
    function actualBalanceOf(address _owner) public view returns (uint256 balance) {
        return super.balanceOf(_owner);
    }

    // View the frozen token balance of an address
    function freezingBalanceOf(address _owner) public view returns (uint256 balance) {
        return freezingBalance[_owner];
    }

    // Gets the number of release dates at which a user has frozen tokens
    function freezingCount(address _addr) public view returns (uint count) {
        // Get initial release date, using the address's base key (release date 0)
        uint64 release = chains[toKey(_addr, 0)];
        // Loop over each subsequent release date. As long as the release date
        // recorded by each subsequent chain is nonzero, we know there are tokens
        // frozen there.
        while (release != 0) {
            // Increment count for each nonzero release date found
            count++;
            release = chains[toKey(_addr, release)];
        }
    }

    // Get the release date and number of tokens frozen at some index in the address's frozen
    // token chain. The index provided is the number of release dates in the future to look through
    function getFreezing(address _addr, uint _index) public view returns (uint64 _release, uint _balance) {
        // _release is implicitly set to 0 at the beginning of this function call
        for (uint i = 0; i < _index + 1; i++) {
            // Get the release date for the next token bucket in the user's chain
            _release = chains[toKey(_addr, _release)];
            // If no release date is found, the index provided is out of bounds - return
            // (user does not have tokens frozen at that index)
            if (_release == 0) {
                return;
            }
        }
        // We have a nonzero release date, so get the balance associated with the date
        _balance = freezings[toKey(_addr, _release)];
    }

    // Allows a user to send tokens to an account that can only be accessed after
    // a certain date has passed
    function freezeTo(address _to, uint _amount, uint64 _until) public {
        // Require that the destination be nonzero
        require(_to != address(0));
        // Require that the sender have sufficient unfrozen balance to send _amount
        require(_amount <= balances[msg.sender]);

        // Subtract _amount from sender's balance
        // NOTE: Because SafeMath is being used, the check above is not needed
        balances[msg.sender] = balances[msg.sender].sub(_amount);

        // Get a key to which the recipient's frozen balance will be recorded
        bytes32 currentKey = toKey(_to, _until);
        // Increase the user's frozen tokens for this release time by the amount
        freezings[currentKey] = freezings[currentKey].add(_amount);
        // Increase the user's total frozen balance by the amount
        freezingBalance[_to] = freezingBalance[_to].add(_amount);

        // Update recipient's frozen token batch sequence to correctly include the new date
        freeze(_to, _until);
        // Emit events
        emit Transfer(msg.sender, _to, _amount);
        emit Freezed(_to, _until, _amount);
    }

    // Release the sender's first available tokens, if the release date has passed
    function releaseOnce() public {
        // Get the sender's head key (release date = 0)
        bytes32 headKey = toKey(msg.sender, 0);
        // Get the release date associated with the head key
        uint64 head = chains[headKey];
        // If the head is 0, the user does not have any frozen tokens
        require(head != 0);
        // Ensure the release date is in the past
        require(uint64(block.timestamp) > head);
        // Get the storage key for the user's frozen balance for this release date
        bytes32 currentKey = toKey(msg.sender, head);

        // Get the next release date after the first one. After we release these
        // first tokens, we will want to set the user's "first" token bucket to
        // this next bucket.
        uint64 next = chains[currentKey];

        // Get the amount of tokens frozen for the first release date
        uint amount = freezings[currentKey];
        // Zero out the frozen tokens so they cannot be used again
        delete freezings[currentKey];

        // Add the now unfrozen tokens to the sender's balance
        balances[msg.sender] = balances[msg.sender].add(amount);
        // Subtract the unfrozen tokens from the sender's frozen balance
        freezingBalance[msg.sender] = freezingBalance[msg.sender].sub(amount);

        // If the user does not have any more frozen tokens, zero out the 
        // first release date
        if (next == 0) {
            delete chains[headKey];
        } else {
            // Otherwise, if the user has more frozen tokens, set the head reference
            // to point to the next release date found
            chains[headKey] = next;
            // Remove the reference to the next release date from the current release
            // date's chain
            delete chains[currentKey];
        }
        // Emit event
        emit Released(msg.sender, amount);
    }

    // Loop through the user's frozen tokens and release all of them
    // Returns the number of tokens released
    function releaseAll() public returns (uint tokens) {
        // Stack variables for release time and release amount
        uint release;
        uint balance;
        // Get the release date and amount for the user's first frozen batch of tokens
        (release, balance) = getFreezing(msg.sender, 0);
        // As long as the next release date found is nonzero, continue releasing tokens
        // As long as the next release date found is in the past, continue releasing tokens
        // LOW: Failure to revert state changes when no tokens are released.
        //      Similar functions should follow similar procedure. releaseOnce will revert
        //      if the user has no tokens to release. It will be expected (and so should be
        //      implemented) that the same will apply to releaseAll.
        // NOTE: Calling releaseOnce and getFreezing every time in a loop is an inefficient method
        //       of looping through each release amount, especially given that all 3 functions
        //       share significant functionality. Refactoring to allow more efficient iterative
        //       access will save significant gas in the event a user is trying to release multiple records.
        while (release != 0 && block.timestamp > release) {
            // Release the next available tokens
            releaseOnce();
            // Increment returned number of tokens unfrozen
            tokens += balance;
            // Get the next release date and amount for the sender
            (release, balance) = getFreezing(msg.sender, 0);
        }
    }

    // NOTE: 
    //   
    //  Improper input sanitization during key generation, and mixing of user frozen token records.
    //
    //                Using this contract, users are able to transfer tokens to each other
    //                with time-locked releases. This is able to be done as many times as
    //                needed: users are able to send multiple batches of frozen tokens to each
    //                other, each with different frozen amounts and different release dates.
    //                To accomplish this in an efficient manner, the contract maintains a record
    //                of frozen batches of tokens in order of release date. This means that
    //                when a user receives frozen tokens with a release date 5 days in the future,
    //                and frozen tokens with a release date 10 days in the future, the tokens 
    //                released 5 days in the future are stored, sequentially, before the tokens
    //                with a 10-day release period. Because of this, when a user wants to claim/release
    //                frozen tokens after the 5 days have elapsed, the contract will only need to
    //                look through one stored record before finding the 5-day batch, saving gas.
    //
    //                This system is managed by a system of "chained" batches of tokens. Each
    //                time a user receives frozen tokens for some given release date, a key is
    //                generated using their address and the release date. The 'chains' mapping
    //                above maps the aforementioned key to the 'next' release date in the user's
    //                frozen token record list, creating a linked list of release dates. The effect
    //                is that for each distinct date at which a user owns frozen tokens, the 'toKey'
    //                function can calculate the a key for that date (returned as "bytes32 result").
    //                The 'chains' mapping can then be queried using this key to get the next release
    //                date in the sequence. So, for some date D.1 and sender S, we can check to see
    //                if the sender has any more frozen tokens as follows:
    //                
    //                let key_1 = toKey(S, D.1) --> Calculate lookup key key_1 for sender S and date D.1
    //                let D.2 = chains[key_1]   --> Query chains mapping with key_1
    //                if D.2 is not 0:
    //                  --> sender has frozen tokens at D.2
    //                else:
    //                  --> sender does not have additional frozen tokens
    //
    //                The problem with this function is in the key's generation. The returned "result"
    //                from this function is 32 bytes in length. The sender's address (_addr) is 20 bytes.
    //                The release date (_release) is assumed to be 8 bytes. Together, they are 28 bytes.
    //                With the addition of the first statement, an additional arbitrary 4 bytes are added.
    //                
    //                1. The calculation starts with setting the leading 4 bytes of the result to the same
    //                value every time (0x57495348, called a "mask"). This gives us:
    //
    //                result = [0x57495348] + 28 bytes                
    //
    //                2. Then, this result is combined with the address, offset 8 bytes. The offset is accomplished
    //                by multiplying the address by 0x10000000000000000. This gives:
    //                
    //                result = [0x57495348] + [_addr] + 8 bytes
    //
    //                3. Finally, the result is combined again with the release date for the tokens. Remember,
    //                we assumed the release date was 8 bytes. This gives:
    //
    //                result = [0x57495348] + [_addr] + [_release]
    //
    //                Together, the 32-byte key should be unique. Given the explanation above, this should
    //                be the case. The three parts of the key (mask, _addr, _release) are each combined in a way
    //                that should not overlap - because if they could overlap, an attacker could carefully
    //                craft an address and release date for which a generated key would match a key generated
    //                by another user for a different batch of frozen tokens. The effect of this would be that 
    //                the attacker would then be able to take control of the other user's frozen token chain,
    //                as they would be able to generate a key the contract recognized as legitimate, but which
    //                was already in use by someone else.
    //
    //                So far, so good. The contracts reviewed here, when generating a key using toKey
    //                all ensure that the release date passed in is only 8 bytes. As we saw above, this
    //                results in a safe key combination. However, the toKey function does NOT require the
    //                release date to be 8 bytes. Instead, the toKey function allows release dates to be input
    //                as 32-byte values. Given that an attacker can specify a release date when freezing tokens,
    //                allowing an attacker to input a 32-byte release date will allow them to easily create keys
    //                that collide with the keys generated by other users. Again, the contracts reviewed all ensure
    //                that the actual value given to toKey only contains 8 bytes in the release date: but it
    //                is very dangerous to allow toKey to accept 32-byte dates for all the reasons above.
    //
    //                The setup in toKey requires that the developer writing the contracts remember to only pass in
    //                8 bytes for the release date. Given that toKey is invoked a total of 12 times across all the 
    //                reviewed contracts, the developer writing these must remember (12 times!) to alter the size of the
    //                value passed-in to be safe. Given that 32-bytes is the default value, this setup presents a classic
    //                anti-pattern - requiring that input sanitization (validating the input size) be performed external to the
    //                critical funciton, as opposed to just ensuring that the critical funciton (toKey) validate the input
    //                itself. Compounding this risk is the structure of the 'chains' mapping, which only maps from keys to
    //                release dates, meaning that multiple users essentially 'share' the same mapping. As long as keys are unique,
    //                this does not pose a significant risk. However, if an attacker is able to find values for which non-unique
    //                keys are generated, they are able to affect a much larger proportion of frozen token holders because all frozen
    //                token holders share the same 'chains' mapping.
    //
    //                Our recommendation is as follows:
    //
    //                1. Do not rely on simple arithmetic operations to generate a unique key. Instead, keys should be generated
    //                using keccak256, a secure hashing function.
    //
    //                2. Change the 'chains' mapping to reflect these changes, and separate userspace in the mapping. Instead of
    //                a mapping from bytes32 => uint64, the mapping should map address => bytes32 => uint64. The same applies to
    //                the 'freezings' mapping.
    //
    //                3. If a function like toKey is used to generate the key (again, this should be done with a hash), it should
    //                check that the input parameters to key generation match the sizes it expects for safe key generation. If dates
    //                are only 8 bytes in length, the input parameter should read "uint64", not "uint". The latter defaults to "uint256",
    //                which uses 32 bytes.
    function toKey(address _addr, uint _release) internal pure returns (bytes32 result) {
        // Set leading 4 bytes of result
        result = 0x5749534800000000000000000000000000000000000000000000000000000000;
        assembly {
            // Place 20-byte address directly after leading 4 bytes
            result := or(result, mul(_addr, 0x10000000000000000))
            // Place assumed 8-byte release date directly after leading 4 bytes and address
            result := or(result, _release)
        }
    }

    // Update the recipient's freeze chain to include _until in the correct order
    // NOTE: The naming here is not suggestive of the function's purpose. I would recommend
    //       changing this to something akin to "insertDate"
    function freeze(address _to, uint64 _until) internal {
        // The time at which the tokens will be released should be in the future
        require(_until > block.timestamp);
        // Get an access key for the recipient and release time
        bytes32 key = toKey(_to, _until);
        // Get the parent key for the recipient, using a release time of 0
        bytes32 parentKey = toKey(_to, uint64(0));
        // Get the next release date from the parent key
        uint64 next = chains[parentKey];

        // If there is no "next" release date, this is the first set of frozen
        // tokens being added. Set the "next" release date to _until, the date
        // at which this batch of tokens will be released. Then, return.
        if (next == 0) {
            chains[parentKey] = _until;
            return;
        }

        // Continuing - there is a "next" release date, so this is not the first
        // batch of tokens being frozen for this recipient. We now need to loop
        // through the rest of the recipient's frozen token records to see whether
        // we will need to add the date to the end of the sequence, or place it 
        // somewhere in the middle of the sequence.

        // Get the next key in the chain from the recipient and next release date
        bytes32 nextKey = toKey(_to, next);
        uint parent;

        // Loop through each consecutive key, stopping when:
        //   1. The next date is 0 (no more dates exist)
        //   or
        //   2. The next date is beyond the last date checked (insert new frozen tokens here)
        while (next != 0 && _until > next) {
            // Update parent reference. This will be the parent date of the date currently being checked
            parent = next;
            // Update parent key reference. This will be the key of the parent date.
            parentKey = nextKey;

            // Get the next date in the sequence
            next = chains[nextKey];
            // Calculate the key for the new date
            nextKey = toKey(_to, next);
        }

        // The user already has tokens frozen to this release date; we don't need
        // to do insert a new date in the sequence; return.
        if (_until == next) {
            return;
        }

        // The date being added comes sequentially before another date at which tokens
        // will be released. Set the new release date to point to the next date in the sequence
        if (next != 0) {
            chains[key] = next;
        }

        // Set the parent of the last date checked to point to the newly added date, _until
        chains[parentKey] = _until;
    }
}

// Extends BasicToken interface to implement a token burn function
contract BurnableToken is BasicToken {

  // Event
  event Burn(address indexed burner, uint256 value);

  // Allows the sender to burn tokens from their balance
  // NOTE: Helper function is unnecessary here and reduces code clarity
  function burn(uint256 _value) public {
    _burn(msg.sender, _value);
  }

  // Internal helper function for "burn(uint)"
  function _burn(address _who, uint256 _value) internal {
    // Ensure the amount to burn is greater than the balance of the token holder
    require(_value <= balances[_who]);

    // Reduce token holder's balance by the amount being burned
    // NOTE: Because SafeMath is being used, the check above is not needed
    balances[_who] = balances[_who].sub(_value);
    // Reduce total token supply by the amount being burned
    totalSupply_ = totalSupply_.sub(_value);
    // Emit Burn and Transfer events
    emit Burn(_who, _value);
    emit Transfer(_who, address(0), _value);
  }
}

// Extends Ownable interface to implement pausable functions
contract Pausable is Ownable {
  
  // Events
  event Pause();
  event Unpause();

  // Whether a pause is currently in effect. Value at contract creation is False.
  bool public paused = false;

  // Modifier -- This function can only be accessed when the contract is not paused (paused == false)
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  // Modifier -- This function can only be accesssed when the contract is paused (paused == true)
  modifier whenPaused() {
    require(paused);
    _;
  }

  // Allows the owner to execute a pause. Sets paused to true and emits a Pause event
  // onlyOwner requires that the sender be the owner (msg.sender == Ownable.owner)
  // whenNotPaused requires that the contract not be paused (paused == false)
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  // Allows the owner to unpause currently paused functions. Sets paused to false and emits an Unpause event
  // onlyOwner requires that the sender be the owner (msg.sender == Ownable.owner)
  // whenPaused requires that the contract is currently paused (paused == true)
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}

// Extends FreezableToken and MintableToken to add a single function
contract FreezableMintableToken is FreezableToken, MintableToken {
    
    // Allows the owner to mint tokens to an account, but keep the tokens frozen until some time has elapsed
    // NOTE: As noted above, returning a boolean here is not necessary and should be avoided.
    // onlyOwner requires that the sender be the owner (msg.sender == Ownable.owner)
    // canMint requires that minting currently be allowed (MintableToken.mintingFinished == false)
    function mintAndFreeze(address _to, uint _amount, uint64 _until) public onlyOwner canMint returns (bool) {
        // Increase total token supply by the amount being minted
        totalSupply_ = totalSupply_.add(_amount);

        // Get a key for the recipient at the given release date
        bytes32 currentKey = toKey(_to, _until);
        // Add the amount to the recipient's current frozen balance at the given time
        freezings[currentKey] = freezings[currentKey].add(_amount);
        // Add the amount to the recipient's total frozen balance
        freezingBalance[_to] = freezingBalance[_to].add(_amount);

        // If necessary, add the release date to the user's frozen token linked list
        freeze(_to, _until);
        // Emit events
        emit Mint(_to, _amount);
        emit Freezed(_to, _until, _amount);
        emit Transfer(msg.sender, _to, _amount);
        // Return true
        return true;
    }
}

// Several constants to be used in the MainToken contract
// LOW: Each of these constant functions is marked public, which implicitly creates
//      a getter function with the same name. While using constants is more efficient
//      than a state variable, excessive use of "public" fields:
//      1. Makes a contract more expensive to deploy (longer bytecode)
//      2. Makes using a contract more expensive, as each additional function selector
//         created by these implicit getters means more options to traverse at runtime
//      
//      Consider removing the word "public" from each constant unless absolutely necessary.
//      This way, the constants can still be used internally to the contract.
contract Consts {
    uint public constant TOKEN_DECIMALS = 10;
    uint8 public constant TOKEN_DECIMALS_UINT8 = 10;
    uint public constant TOKEN_DECIMAL_MULTIPLIER = 10 ** TOKEN_DECIMALS;

    string public constant TOKEN_NAME = "MyWish Token";
    string public constant TOKEN_SYMBOL = "WISH";
    bool public constant PAUSED = true;
    address public constant TARGET_USER = 0x8ffff2c69f000c790809f6b8f9abfcbaab46b322;
    
    bool public constant CONTINUE_MINTING = true;
}

// Extends Consts, FreezableMintableToken, BurnableToken, and Pausable
contract MainToken is Consts, FreezableMintableToken, BurnableToken, Pausable    
{
    
    // Event
    event Initialized();

    // Whether the contract is intialized
    // NOTE: Making this a public variable has no effect. It is only visible
    //       after construction, but it can only be "true" after construction.
    //
    //       Consider removing "public", as each additional public field increases
    //       cost at runtime.
    bool public initialized = false;

    // Constructor -- Calls an "init" function, and transfers ownership of the token
    //                to TARGET_USER, which is defined before deployment.
    constructor() public {
        init();
        transferOwnership(TARGET_USER);
    }
    
    // Implements ERC20 "name" function, returning a string representing the token's name
    function name() public pure returns (string _name) {
        return TOKEN_NAME;
    }

    // Implements ERC20 "symbol" function, returning a string representing the token's symbol
    function symbol() public pure returns (string _symbol) {
        return TOKEN_SYMBOL;
    }

    // Implements ERC20 "decimals" function, returning a uint8 representing the displayed decimals for the token
    function decimals() public pure returns (uint8 _decimals) {
        return TOKEN_DECIMALS_UINT8;
    }

    // Extends transferFrom functionality to require that execution is not currently paused
    // NOTE: Pausable implements a modifier for this purpose -- consider using the modifier.
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool _success) {
        require(!paused);
        return super.transferFrom(_from, _to, _value);
    }

    // Extends transfer functionality to require that execution is not currently paused
    // NOTE: Pausable implements a modifier for this purpose -- consider using the modifier.
    function transfer(address _to, uint256 _value) public returns (bool _success) {
        require(!paused);
        return super.transfer(_to, _value);
    }

    // Initialization function. Called a single time at contract creation
    function init() private {
        // Require that the contract is not already initialized, then set initialized to true
        require(!initialized);
        initialized = true;

        // If the PAUSED constant is true (in this case, it is), pause the contract
        if (PAUSED) {
            pause();
        }

        // Addresses to which tokens will be minted
        address[3] memory addresses = [address(0x0000001b717aDd3E840343364EC9d971FBa3955C),address(0x0000002b717aDd3E840343364EC9d971FBa3955C),address(0x0000003b717aDd3E840343364EC9d971FBa3955C)];
        // Amounts of tokens to mint
        uint[3] memory amounts = [uint(1000000),uint(2000000),uint(3000000)];
        // If tokens are to be frozen, these are the times at which they will be unfrozen
        uint64[3] memory freezes = [uint64(1539709200),uint64(0),uint64(1539709200)];

        // Loop through each address and mint/freeze tokens for them
        for (uint i = 0; i < addresses.length; i++) {
            // If no freeze is required, simply mint the tokens
            if (freezes[i] == 0) {
                mint(addresses[i], amounts[i]);
            } else {
                // Otherwise, mint and freeze the tokens
                mintAndFreeze(addresses[i], amounts[i], freezes[i]);
            }
        }
        
        // If the CONTINUE_MINTING constant is false (in this case, it is not), finalize minting
        // Clarification - in this contract, minting will continue after construction.
        if (!CONTINUE_MINTING) {
            finishMinting();
        }

        // Emit event
        emit Initialized();
    }
}


