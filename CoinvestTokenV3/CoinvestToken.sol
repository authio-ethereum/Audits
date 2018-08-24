pragma solidity ^0.4.23;

library SafeMathLib{ //@Audit - A safe math library

  //@Audit - multiplication of two numbers
  //@Params - a, b are the numbers to multiplied
  //@Returns - returns thier multiple if it doesn't overflow
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b; //@Audit - calculates the multiplication
    assert(a == 0 || c / a == b); //@Audit - If a is non zero c/a == b if non overflow
    return c; //@Audit - Returns the product
  }

  //@Audit - does a safe divsion
  //@Params - a is divided by b
  //@Returns - the rounded down divsion
  function div(uint256 a, uint256 b) internal pure returns (uint256) {

    uint256 c = a / b; //@Audit - if b is zero this throws, otherwise does the rounded down divsion
    return c; //@Audit - returns that divsion
  }

  //@Audit - Does safe subtraction
  //@Params - subtracts a from b
  //@Returns - returns a-b
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a); //@Audit - if b > a this will underflow
    return a - b; //@Audit - returns the subtraction
  }

  //@Audit - Does safe addition
  //@Params - add a, b
  //@Returns - returns a+b
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b; //@Audit - adds a and b
    assert(c >= a); //@Audit - if c < a then there has been an overflow so throw
    return c; //@Audit - returns that value
  }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
**/
contract Ownable { //@Audit - A library implementing the owner
  address public owner; //@Audit - public owner state variable

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner); //@Audit - Even informing people that the owner has changed to newOwner

  constructor() public { //@Audit - Upon construction of anything that is ownable
    owner = msg.sender; //@Audit - Sets the owner to msg.sender
  }

  modifier onlyOwner() { //@Audit - A modifier requiring that the owner calls it
    require(msg.sender == owner); //@Audit - throws if msg.sender is not the owner
    _; //@Audit - then executes the function
  }

  //@Audit - A function allowing you to transfer ownership
  //@Params - Takes a new owner address
  //@Modifiers - throws if not only owner
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0)); //@Audit - We don't allow you to burn ownership (reverts if newOwner is zero)
    emit OwnershipTransferred(owner, newOwner); //@Audit - Emits a event signifying that the ownership transfered
    owner = newOwner; //@Audit - sets the owner state varible to the provided one
  }

}

contract ApproveAndCallFallBack { //@Audit -Contract which details the receiveApproval function
    //@Params - from the person we are calling on behalf of
    //@Params - the number of tokens to approve
    //@Params - token the token contract
    //@Params - bytes extra data for the token contract, if it needs it
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

/**
 * @title Coinvest COIN Token
 * @dev ERC20 contract utilizing ERC865-ish structure (3esmit's implementation with alterations).
 * @dev to allow users to pay Ethereum fees in tokens.
**/
contract CoinvestToken is Ownable { //@Audit - Coinvest token contract has an owner

    using SafeMathLib for uint256; //@Audit - Uses safe math on numbers

    string public constant symbol = "COIN"; //@Audit - Sets the symbol as "COIN", constant for efficency
    string public constant name = "Coinvest COIN V3 Token"; //@Audit - Sets the name as "Coinvest COIN V3 Token", constant for efficency

    uint8 public constant decimals = 18; //@Audit - The number of decimals for the token
    uint256 private _totalSupply = 107142857 * (10 ** 18); //@Audit - Sets _totalSupply to 107142857 tokens with 10^18 decimals

    bytes4 internal constant transferSig = 0xa9059cbb; //@Audit - function selctor for transfer, constant for efficency
    bytes4 internal constant approveSig = 0x095ea7b3; //@Audit - function selctor for approve, constant for efficency
    bytes4 internal constant increaseApprovalSig = 0xd73dd623; //@Audit - function selctor for increaseApproval, constant for efficency
    bytes4 internal constant decreaseApprovalSig = 0x66188463; //@Audit - function selctor for decreaseApproval, constant for efficency
    bytes4 internal constant approveAndCallSig = 0xcae9ca51; //@Audit - function selctor for approveAndCall, constant for efficency
    bytes4 internal constant revokeHashSig = 0x70de43f1; //@Audit - function selctor for revokeHash, constant for efficency

    mapping(address => uint256) balances; //@Audit - sends addresses to token balances

    mapping(address => mapping (address => uint256)) allowed; //@Audit - Maps address to mapping addresses to thier transfer allowance

    mapping(address => uint256) nonces; //@Audit - The nonce of each address

    mapping(address => mapping (bytes32 => bool)) invalidHashes; //@Audit - For an address we map signatures to bools of whether they are invalid

    event Transfer(address indexed from, address indexed to, uint tokens); //@Audit - Declares a transfer event which lists from to and the number of tokens
    event Approval(address indexed from, address indexed spender, uint tokens);
    //@Audit - Declares a aproval event listing which account the tokens come from, who can spend them, and the number of tokens
    event HashRedeemed(bytes32 indexed txHash, address indexed from);
    //@Audit - Declares a HashRedeemed event which lists the txHash and and who sent it

    //@Audit - The constructor
    constructor()
      public
    {
        balances[msg.sender] = _totalSupply; //@Audit -  Sets the balance of the owner to all of the tokens
    }

    //@Audit - Calls this contract from this contract with the data provided
    //@Aduit - This function allows anyone to use any of the functions in this as the contract
    //@Params - from: who the token transfer is from, amount: the number of tokens
    //@Params - token: the token contract which these tokens are in, data: the bytes of call data to give to this contract
    function receiveApproval(address _from, uint256 _amount, address _token, bytes _data)
      public
    {
        require(address(this).call(_data)); //@Audit - requires a successful call to this with the data provided
        //@Audit - I have trouble seeing any usecase for this function, I think it should be removed. It doesn't even use most of the data provided.
    }

/** ******************************** ERC20 ********************************* **/
  //@Audit - The standard ERC20 transfer
  //@Params - to: who will be receiving the token , amount: the amounts of token
  //@Return - returns the success of the call
  function transfer(address _to, uint256 _amount)
    public
  returns (bool success)
  {
      require(_transfer(msg.sender, _to, _amount)); //@Audit - requires the success of the internal transfer call
      return true; //@Audit - returns that this has succeded
  }

  //@Audit - The standard ERC20 transferFrom
  //@Params - from: who the tokens are coming from , to: who will be receiving the token , amount: the amounts of token
  //@Return - returns the success of the call
  function transferFrom(address _from, address _to, uint _amount)
    public
  returns (bool success)
  {
      require(balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount);
      //@Audit - checks that the from address has enough token and that the sender has enough allowance (since they use safe sub not strictly nesscary)
      allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount); //@Audit - reduces the allowance of msg.sender
      require(_transfer(_from, _to, _amount));//@Audit - calls the internal transfer to move the tokens, requires that it succeded
      return true; //@Audit - returns that this succeded
  }

  //@Audit - The standard ERC20 approve (with the standard racing conditions)
  //@Params - spender: whose approval gets increased , amount: the amounts of token
  //@Return - returns the success of the call
  function approve(address _spender, uint256 _amount)
    public
  returns (bool success)
  {
      require(_approve(msg.sender, _spender, _amount)); //@Audit - calls the internal aproval and requires its success
      return true; //@Audit - Returns that the call has succeded
  }

  //@Audit - A public increaseApproval function
  //@Params - spender: whose approval gets increased , amount: the amounts of token
  //@Return - returns the success of the call
  function increaseApproval(address _spender, uint256 _amount)
    public
  returns (bool success)
  {
      require(_increaseApproval(msg.sender, _spender, _amount)); //@Audit - calls the internal increase aproval
      return true; //@Audit - Returns that it succeded
  }

  //@Audit - The standard ERC20 approve (which the standard racing conditions)
  //@Params - spender: whose approval gets increased , amount: the amount of token to reduce by
  //@Return - returns the success of the call
  function decreaseApproval(address _spender, uint256 _amount)
    public
  returns (bool success)
  {
      require(_decreaseApproval(msg.sender, _spender, _amount)); //@Audit - calls the internal decreaseApproval function
      return true; //@Audit - returns that the call succeded
  }

  //@Audit - Aprove and call an address
  //@Params - spender : the address to call and approve, amount : the amount of tokens to aprove , data : the call data
  //@Returns -success : the success of the call
  function approveAndCall(address _spender, uint256 _amount, bytes _data)
    public
  returns (bool success)
  {
      require(_approve(msg.sender, _spender, _amount)); //@Audit - calls the internal aprove function and requires its success
      ApproveAndCallFallBack(_spender).receiveApproval(msg.sender, _amount, address(this), _data);
      //@Audit - labels the _spender address as a contract with a receive approval function and calls it
      return true; //@Audit - returns that this has succeded
  }

/******************************** Internal **********************************/

    //@Audit - Internal transfer function used by all of the transfer functions
    //@Params - _from: the address to move the tokens from , _to : the address to move the token to , _amount the number of tokens to move
    //@Return - returns the success of the call
    function _transfer(address _from, address _to, uint256 _amount)
      internal
    returns (bool success)
    {
        require (_to != address(0), "Invalid transfer recipient address."); //@Audit - To send to zero you must burn tokens
        require(balances[_from] >= _amount, "Sender does not have enough balance."); //@Audit - reverts if the from does not have enough tokens

        balances[_from] = balances[_from].sub(_amount); //@Audit - Removes the amount of tokens from the _from address
        balances[_to] = balances[_to].add(_amount); //@Audit - Adds the amount to the balance of to

        emit Transfer(_from, _to, _amount); //@Audit - emits a Transfer event
        return true; //@Audit - returns true
    }

    //@Audit - Internal approve function called by all aprove methods
    //@Params - owner : whose tokens can be moved , _spender : who can spend the tokens , _amount : the number of tokens
    //@Returns - returns the success of the call
    function _approve(address _owner, address _spender, uint256 _amount)
      internal
    returns (bool success)
    {
        allowed[_owner][_spender] = _amount; //@Audit - Resets the allowance to the provided amount
        emit Approval(_owner, _spender, _amount); //@Audit - Emits the aproval amount
        return true; //@Audit - Returns that this has succeded
    }

    //@Audit - Internal increaseApprove function called by all aprove methods
    //@Params - _owner : whose tokens can be moved , _spender : who can spend the tokens , _amount : the number of tokens
    //@Returns - returns the success of the call
    function _increaseApproval(address _owner, address _spender, uint256 _amount)
      internal
    returns (bool success)
    {
        allowed[_owner][_spender] = allowed[_owner][_spender].add(_amount); //@Audit - safe adds the amount to the allowance of spender for owner
        emit Approval(_owner, _spender, allowed[_owner][_spender]); //@Audit - emits an approval event
        return true; //@Audit -  returns that this has succeded
    }


    //@Audit - Internal decreaseApproval function called by all aprove methods
    //@Params - _owner : whose tokens can be moved , _spender : who can spend the tokens , _amount : the number of tokens
    //@Returns - returns the success of the call
    function _decreaseApproval(address _owner, address _spender, uint256 _amount)
      internal
    returns (bool success)
    {
        if (allowed[_owner][_spender] <= _amount) allowed[_owner][_spender] = 0;
        //@Audit - If the approval for sender with owner is less than the the amount we want to reduce by we set it to zero
        else allowed[_owner][_spender] = allowed[_owner][_spender].sub(_amount);
        //@Audit - if its not then we do the safe subtraction

        emit Approval(_owner, _spender, allowed[_owner][_spender]); //@Audit - Emits a aproval change amount
        return true; //@Audit - returns that this succeded
    }

/** ************************ Delegated Functions *************************** **/
//@ Aduit - All of these are race conditioned, the best solution is a salted commit reveal
//@ Aduit - All of these have been checked for transaction mutiablity, since it marks the tx hash as invalid with no ref to sigs they are not affected

    //@ Aduit - function which allows people to preform transactions in exchange for gas
    //@ Params - _signature is the signed transaction, _to who the transfer goes to, _value the number of tokens
    //@ Params - _value is the number of tokens, _gasPrice the gas price in ether/COIN , _nonce the nonce of the transaction
    //@ Return - returns the success of the transaction
    function transferPreSigned(
        bytes _signature,
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
    returns (bool)
    {
        uint256 gas = gasleft(); //@ Aduit - gets the gas of the call

        //@ Aduit - calls the recover presigned function on provided info
        address from = recoverPreSigned(_signature, transferSig, _to, _value, "", _gasPrice, _nonce);
        //@ Aduit - If that call fails it gives back address zero, revert on that
        require(from != address(0), "Invalid signature provided.");

        bytes32 txHash = getPreSignedHash(transferSig, _to, _value, "", _gasPrice, _nonce);
        //@ Aduit - calls the getPreSignedHash function
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        //@ Aduit - Require that the hash hasn't been marked as invalid
        invalidHashes[from][txHash] = true;
        //@ Aduit - Marks the hash as invalid as it has already been used
        nonces[from]++;
        //@ Aduit - increases the nonce of the transaction account

        require(_transfer(from, _to, _value));
        //@ Aduit - transfers the value and requires that transfer to succed

        if (_gasPrice > 0) { //@ Aduit - If there is a gas price
            gas = 35000 + gas.sub(gasleft());
            //@ Aduit - Around 35000 is spent before it hits this point, and then adds the amount of gas spent up to now
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
            //@ Aduit - tranfers the number of tokens coresponding to gas price times the amount used to the tx.orgin
        }

        emit HashRedeemed(txHash, from); //@ Aduit - emits the HashRedeemed event
        return true; //@ Aduit - returns that the call is successful
    }

    //@ Aduit - The pre signed version of approval
    //@ Params - _signature the signed hash of this transaction , _to the address which will increase aproval
    //@ Params - _value is the number of tokens, _gasPrice the gas price they are paying, _nonce the nonce of the from reaction
    //@ Returns - Returns the success of the transaction
    function approvePreSigned(
        bytes _signature,
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
    returns (bool)
    {
        uint256 gas = gasleft(); //@ Aduit - calculates the gas remaining
        address from = recoverPreSigned(_signature, approveSig, _to, _value, "", _gasPrice, _nonce);
        //@ Aduit - calls recoverPreSigned to get the signature
        require(from != address(0), "Invalid signature provided.");
        //@ Aduit - The function should return zero if the signature is wrong
        bytes32 txHash = getPreSignedHash(approveSig, _to, _value, "", _gasPrice, _nonce);
        //@ Aduit - Calls getPreSignedHash to get the txHash
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        //@ Aduit - Checks that the has hasn't been marked as invalid
        invalidHashes[from][txHash] = true;
        //@ Aduit - Marks the txHash as invalid as its been used

        nonces[from]++;
        //@ Aduit - Increases the nonce of the from

        require(_approve(from, _to, _value)); //@ Aduit - calls the internal aprove function

        if (_gasPrice > 0) { //@ Aduit - If they are paying for gas
            gas = 35000 + gas.sub(gasleft()); //@ Aduit - 35000 for the call before this function plus the gas spent so far
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
            //@ Aduit - transfers the gas spent times the gas price of tokens from from to the tx.orgin
        }

        emit HashRedeemed(txHash, from); //@ Aduit - Emits the HashRedeemed event
        return true; //@ Aduit - returns that this has succeded
    }

    //@ Aduit - The pre signed version of increaseApproval
    //@ Params - _signature the signed hash of this transaction , _to the address which will increase aproval
    //@ Params - _value is the number of tokens, _gasPrice the gas price they are paying, _nonce the nonce of the from reaction
    //@ Returns - Returns the success of the transaction
    function increaseApprovalPreSigned(
        bytes _signature,
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
    returns (bool)
    {
        uint256 gas = gasleft(); //@ Aduit -  gets the gas at the start of the call
        address from = recoverPreSigned(_signature, increaseApprovalSig, _to, _value, "", _gasPrice, _nonce);
        //@ Aduit - calls recoverPreSigned to get the from address
        require(from != address(0), "Invalid signature provided.");
        //@ Aduit - if that function returns zero it failed somewhere

        bytes32 txHash = getPreSignedHash(increaseApprovalSig, _to, _value, "", _gasPrice, _nonce);
        //@ Aduit - calls the getPreSignedHash to get the transaction hash
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        //@ Aduit - checks that the hash hasn't been marked as invalid
        invalidHashes[from][txHash] = true;
        //@ Aduit - marks the hash as invalid because it has been used
        nonces[from]++;
        //@ Aduit - increases the nonce for the next transaction

        require(_increaseApproval(from, _to, _value));
        //@ Aduit - calls the increase aproval internal function and requires it returns true

        if (_gasPrice > 0) { //@ Aduit - if the sender is charging
            gas = 35000 + gas.sub(gasleft()); //@ Aduit - add 35000 for the call before the gas was recorded and then adds the amount left
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
            //@ Aduit - calls internal transfer to pay the sender gasPrice*gas tokens
        }

        emit HashRedeemed(txHash, from); //@ Aduit - Emits a hash HashRedeemed event
        return true; //@ Aduit - returns that the call succeded
        bytes _signature,
    }

    //@ Aduit - The pre signed version of decreaseApproval
    //@ Params - _signature the signed hash of this transaction , _to the address which will increase aproval
    //@ Params - _value is the number of tokens, _gasPrice the gas price they are paying, _nonce the nonce of the from reaction
    //@ Returns - Returns the success of the transaction
    function decreaseApprovalPreSigned(
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
    returns (bool)
    {
        uint256 gas = gasleft(); //@Aduit - gets the gas at the start of the call
        address from = recoverPreSigned(_signature, decreaseApprovalSig, _to, _value, "", _gasPrice, _nonce);
        //@Aduit - calls the recoverPreSigned to get the signing address
        require(from != address(0), "Invalid signature provided.");
        //@Aduit - if the function returned zero the signature is invaild

        bytes32 txHash = getPreSignedHash(decreaseApprovalSig, _to, _value, "", _gasPrice, _nonce);
        //@Aduit - calls getPreSignedHash to calculate the hash of the call
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        //@Aduit - Checks if this hash has been marked as invalid, ie has already been used
        invalidHashes[from][txHash] = true;
        //@Aduit - Marks this hash as used
        nonces[from]++;
        //@Aduit - increases the from nonce

        require(_decreaseApproval(from, _to, _value));
        //@Aduit - calls the internal _decreaseApproval function and requires that it succeded

        if (_gasPrice > 0) { //@Aduit - If there is a gas price
            gas = 35000 + gas.sub(gasleft()); //@Aduit - 35000 from before the function and calculates the gas used for the call
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
            //@Aduit - transfers gasPrice*gasUsed tokens from the from address to the tx.orgin
        }

        emit HashRedeemed(txHash, from); //@Aduit - Emits a hash event
        return true; //@Aduit - returns that the call succeded
    }

    //@ Aduit - The pre signed version of approveAndCall
    //@ Params - _signature the signed hash of this transaction , _to the address which will be aproved
    //@ Params - _value is the amount of aproved tokens, _extraData the data provided to the call
    //@ Params - _gasPrice the gas price they are paying, _nonce the nonce of the from reaction
    //@ Returns - Returns the success of the transaction

    function approveAndCallPreSigned(
        bytes _signature,
        address _to,
        uint256 _value,
        bytes _extraData,
        uint256 _gasPrice,
        uint256 _nonce)
      public
    returns (bool)
    {
        uint256 gas = gasleft(); //@ Aduit - Records the amount of gas at the start of the call
        address from = recoverPreSigned(_signature, approveAndCallSig, _to, _value, _extraData, _gasPrice, _nonce);
        //@ Aduit - Preforms an ERC recover to get the address which signed
        require(from != address(0), "Invalid signature provided.");
        //@ Aduit - recoverPreSigned returns zero if it hits an error, this requires that it doesn't

        bytes32 txHash = getPreSignedHash(approveAndCallSig, _to, _value, _extraData, _gasPrice, _nonce);
        //@ Aduit - calls getPreSignedHash to get the transaction hash
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        //@ Aduit - Requires that this hash has not been marked as invalid
        invalidHashes[from][txHash] = true;
        //@ Aduit - Marks the hash as invalid because it has been already used
        nonces[from]++;
        //@ Aduit - Increases the nonce of the from address

        if (_value > 0) require(_approve(from, _to, _value)); //@ Aduit - Zero so that this can serve as a call
        ApproveAndCallFallBack(_to).receiveApproval(from, _value, address(this), _extraData);
        //@ Aduit - Views the _to address as a contract with the ApproveAndCallFallBack interface and calls receive aproval on it

        if (_gasPrice > 0) { //@ Aduit - Checks if the sender requests payment for thier gas
            gas = 35000 + gas.sub(gasleft()); //@ Aduit - 35000 for call before the function, plus gas - gasCurrent to get the gas used by the call
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
            //@ Aduit - Requires a successful transfer of gasPrice*gasUsed from the signer to the tx.orgin
        }

        emit HashRedeemed(txHash, from); //@ Aduit - Emits a hash redeemed event
        return true; //@ Aduit -Returns that the call is successful
    }

/** *************************** Revoke PreSigned ************************** **/

    //@ Aduit -This should increment the nonce, also has a race condition to redeemed hash before revoked
    //@ Aduit - Function allows a user to cancel a transaction that they already signed.
    //@ Params - _hashToRevoke the hash that will be marked as invalid
    //@ Return - returns that this succeded, but this call will never fail so should it?
    function revokeHash(bytes32 _hashToRevoke)
      public
    returns (bool)
    {
        invalidHashes[msg.sender][_hashToRevoke] = true;
        return true;
    }

    //@ Aduit - Allow someone to transmit a revokeHash through a thrid party
    //@ Aduit - Should also increment the nonce
    //@ Params - _signature signed revoke transaction, _hashToRevoke the hash to revoke, _gasPrice the token gas price
    //@ Return - returns if whether the call succeded
    function revokeHashPreSigned(
        bytes _signature,
        bytes32 _hashToRevoke,
        uint256 _gasPrice)
      public
    returns (bool)
    {
        uint256 gas = gasleft(); //@ Aduit - Gets the amount of gas at the start of the function
        address from = recoverRevokeHash(_signature, _hashToRevoke, _gasPrice);
        //@ Aduit - uses the recoverRevokeHash to recover the address of the signer
        require(from != address(0), "Invalid signature provided.");
        //@ Aduit - If the function returns zero it has failed, should revert

        bytes32 txHash = getRevokeHash(_hashToRevoke, _gasPrice);
        //@ Aduit - calls getRevokeHash to get the tx hash for the revoke command
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        //@ Aduit - Requires that the has has not been marked as invaild
        invalidHashes[from][txHash] = true;
        //@ Aduit - Marks the hash as invaild since it has been used

        invalidHashes[from][_hashToRevoke] = true;
        //@ Aduit - Marks the requested hash as invalid

        if (_gasPrice > 0) { //@ Aduit - Checks if the gas price is non zero
            gas = 35000 + gas.sub(gasleft());
            //@ Aduit - gasUsed = 35000 gas for the call before the function and gas - currentGas for gas used in the call
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
            //@ Aduit - Transfers gasUsed*gasPrice tokens to from the signer to the tx.orgin
        }

        emit HashRedeemed(txHash, from); //@ Aduit - Emits that the revoke hash has been redeemed
        return true; //@ Aduit - returns that the call has succeded
    }

    //@ Aduit - Get the hash for a revocation command
    //@ Params - _hashToRevoke the hash to revoke and _gasPrice the gas price signed
    //@ Aduit - returns the hash revoke command hash
    function getRevokeHash(bytes32 _hashToRevoke, uint256 _gasPrice)
      public
      view
    returns (bytes32 txHash)
    {
        return keccak256(address(this), revokeHashSig, _hashToRevoke, _gasPrice);
        //@ Aduit - returns the packed hash of the address of this contract, the hashRevoke signature, and the provided data
    }

    //@ Aduit - returns the signer of a revoke hash command
    //@ Params - _signature the signature on the command, _hashToRevoke the hash to be revoked, _gasPrice the gas price
    //@ Return - returns the address that signed
    function recoverRevokeHash(bytes _signature, bytes32 _hashToRevoke, uint256 _gasPrice)
      public
      view
    returns (address from)
    {
        return ecrecoverFromSig(getSignHash(getRevokeHash(_hashToRevoke, _gasPrice)), _signature);
        //@ Aduit - returns ecrecoverFromSig on the get signHash of get revokeHash of the imputs and the signature
    }

/** ************************** PreSigned Constants ************************ **/

    //@ Aduit - Gets the hash of all of the transaction information
    //@ Params - _function the four byte function selector, _to the to address, _value the value of the transaction
    //@ Params - _extraData any other data of the transaction, _gasPrice the gas price of the tx, and _nonce the transaction nonce
    //@ Return - Returns the txHash
    function getPreSignedHash(
        bytes4 _function,
        address _to,
        uint256 _value,
        bytes _extraData,
        uint256 _gasPrice,
        uint256 _nonce)
      public
      view
    returns (bytes32 txHash)
    {
        return keccak256(address(this), _function, _to, _value, _extraData, _gasPrice, _nonce);
        //@ Aduit - Hashes together all of the provided data in order and returns it
    }

    //@ Aduit - Formats the imputs and calls ecrecover on them
    //@ Params - _sig the signature, _function the function selector, _to the address too, _value the value of the tx
    //@ Params - _extraData the extra data of the tx, _gasPrice the gas price of the tx, and _nonce the nonce of the tx
    //@ Return - returns the address which signed
    function recoverPreSigned(
        bytes _sig,
        bytes4 _function,
        address _to,
        uint256 _value,
        bytes _extraData,
        uint256 _gasPrice,
        uint256 _nonce)
      public
      view
    returns (address recovered)
    {
        return ecrecoverFromSig(getSignHash(getPreSignedHash(_function, _to, _value, _extraData, _gasPrice, _nonce)), _sig);
        //@ Aduit - calls ecrecoverFromSig on the hash of the sign has and the hash of all of the data
    }

    //@ Aduit - Hashes the provided bytes with the ether standard transaction string
    //@ Params - _hash the data we want to hash with it
    //@ Returns - the hash of the data with the string
    function getSignHash(bytes32 _hash)
      public
      pure
    returns (bytes32 signHash)
    {
        return keccak256("\x19Ethereum Signed Message:\n32", _hash);
        //@ Aduit - Hahses the packed data of the standard transaction string with the provided bytes
    }

    //@ Aduit - Function recovering the address which signed a message
    //@ Params - has is the hash of the message, sig is the signature
    //@ Retun - Returns the address produced
    function ecrecoverFromSig(bytes32 hash, bytes sig)
      public
      pure
    returns (address recoveredAddress)
    {
        bytes32 r; //@ Aduit - Declares r so it can be filled in assembly
        bytes32 s; //@ Aduit - Declares s so it can be filled in assembly
        uint8 v; //@ Aduit - Declares v so it can be filled in assembly
        if (sig.length != 65) return address(0); //@ Aduit - Signatures should be 65 bytes
        assembly {
            r := mload(add(sig, 32)) //@ Aduit - mloads 32 bytes from the start of sig data
            s := mload(add(sig, 64)) //@ Aduit - mloads 32 bytes from 32 bytes from the start of sig data
            v := byte(0, mload(add(sig, 96))) //@ Aduit gets the final needed bytes
        }

        if (v < 27) v += 27; //@ Aduit - Check that the end of the sig is 27 or 28
        if (v != 27 && v != 28) return address(0); //@ Aduit - If this is not true with high probality the signature is invalid
        return ecrecover(hash, v, r, s); //@ Aduit - calls the precompiled ecrecover function
    }

    //@ Aduit - Getter for the external interface to know the nonce
    //@ Params - _owner the address whose nonce we check
    //@ Return - nonce is the uint nonce
    function getNonce(address _owner)
      external
      view
    returns (uint256 nonce)
    {
        return nonces[_owner]; //@ Aduit - gets the nonce value for the address
    }

/** ****************************** Constants ******************************* **/

    //@ Aduit - Returns the total total supply
    //@ Aduit - Why not just make the totalSupply public?
    function totalSupply()
      external
      view
     returns (uint256)
    {
        return _totalSupply; //@ Aduit - Returns the total supply
    }

    //@ Aduit - Gets the balance of an address
    //@ Params - _owner the address to get the balance of
    //@ Return - returns the token balance
    function balanceOf(address _owner)
      external
      view
    returns (uint256)
    {
        return balances[_owner]; //@ Aduit - returns the token balance of owner
    }

    //@ Aduit - Gets the allowance of a spender for an owner
    //@ Params - _owner the address whose tokens will be moved, _spender the address that can move the tokens
    //@ Return - returns the uint token allowance
    function allowance(address _owner, address _spender)
      external
      view
    returns (uint256)
    {
        return allowed[_owner][_spender]; //@ Aduit - returns the token allowance of _spender for _owner
    }

/** ****************************** onlyOwner ******************************* **/

    //@ Aduit - Allows the owner to claim tokens that are owned by this contract
    //@ Params - _tokenContract the token contract where the tokens are held
    function tokenEscape(address _tokenContract)
      external
      onlyOwner //@ Aduit - throws if called by someone who is not owner
    {
        CoinvestToken lostToken = CoinvestToken(_tokenContract); //@ Aduit - Labels the provided address as a token contract

        uint256 stuckTokens = lostToken.balanceOf(address(this)); //@ Aduit - Gets the exact number of tokens stored there
        lostToken.transfer(owner, stuckTokens);
        //@ Aduit - Calls the transfer token function on the the provided address to move stuckTokens tokens to owner
    }

}
