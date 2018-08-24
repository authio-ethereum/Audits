pragma solidity ^0.4.23;

// @audit - A Safe Math library -- used to protect against overflows and underflows
library SafeMathLib{

  // @audit - A safe multiplication function -- reverts on overflows
  // @param - a: The first number to multiply
  // @param - b: The second number to multiply
  // @returns - uint: The product of a and b
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // @audit - Set c to be the product of a and b
    uint256 c = a * b;
    // @audit - Ensure that either a is zero or that the quotient of c and a is b -- ensures that an overflow didn't occur
    assert(a == 0 || c / a == b);
    return c;
  }

  // @audit - A safe division function -- reverts when dividing by zero 
  // @param - a: The numerator 
  // @param - b: The divisor -- the function throws if this is zero
  // @returns - uint: The quotient of a and b
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  // @audit - A safe subtraction function -- reverts on underflows
  // @param - a: The number being subtracted by b
  // @param - b: The number being subtracted from a
  // @returns - uint: The difference of a and b
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    // @audit - Ensure that b is less than or equal to a --> prevents underflows
    assert(b <= a);
    return a - b;
  }
  
  // @audit - A safe addition function -- reverts on overflows
  // @param - a: The first number to add
  // @param - b: The second number to add
  // @returns - uint: The sum of a and b
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    // @audit - Set c equal to the sum of a and b
    uint256 c = a + b;
    // @audit - Ensure that c is greater than a --> prevents overflows
    assert(c >= a);
    return c;
  }
}

// @audit - An ownable contract -- used to give a contract owner permissions
contract Ownable {

  // @audit - The owner of this contract -- has admin level permissions
  address public owner;
  // @audit - Event: Emitted when ownership is transferred from one address to another
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  // @audit - Constructor: Sets the owner to be the sender
  constructor() public {
    owner = msg.sender;
  }

  // @audit - MODIFIER: Ensure that the sender is the owner
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  // @audit - Transfers ownership from the owner to a new address 
  // @param - newOwner: The address to be set as the owner of the contract
  // @audit - MODIFIER onlyOwner: Restricts access to the owner of the contract
  function transferOwnership(address newOwner) onlyOwner public {
    // @audit - Ensure that the new owner is not address zero
    require(newOwner != address(0));
    // @audit - Emit an ownership transferred event
    emit OwnershipTransferred(owner, newOwner);
    // @audit - Update the owner of the contract
    owner = newOwner;
  }

}

// @audit - An abstract contract 
contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

// @audit - CashToken -- inherits from the Ownable contract 
contract CashToken is Ownable {

    // @audit - Attaches the Safe Math library to uint256
    using SafeMathLib for uint256;
    
    // @audit - The symbol for this token -- a constant string that will be cheap to access
    string public constant symbol = "CASH";
    // @audit - The name for this token -- a constant string that will be cheap to access
    string public constant name = "Coinvest CASH Token";
    // @audit - The amount of decimal places for this token -- determines how much tokens can be split 
    uint8 public constant decimals = 18;
    // @audit - The total supply of CASH tokens
    // @audit - There will be 107142857 CASH tokens. 
    uint256 private _totalSupply = 107142857 * (10 ** 18);
    
    // @audit - The transfer signature of this contract 
    bytes4 internal constant transferSig = 0xa9059cbb;
    // @audit - The approve signature of this contract
    bytes4 internal constant approveSig = 0x095ea7b3;
    // @audit - The increase approval signature of this contract
    bytes4 internal constant increaseApprovalSig = 0xd73dd623;
    // @audit - The decrease approval signature of this contract
    bytes4 internal constant decreaseApprovalSig = 0x66188463;
    // @audit - The approve and call signature of this contract
    bytes4 internal constant approveAndCallSig = 0xcae9ca51;
    // @audit - The revoke hash signature of this contract
    bytes4 internal constant revokeHashSig = 0x70de43f1;

    // @audit - A mapping from a user to the amount of CASH tokens that are held.
    mapping(address => uint256) balances;
    // @audit - A mapping from an owner to a spender to the amount of CASH tokens 
    // @audit - that the spender is allowed to spend on behalf of the owner.
    mapping(address => mapping (address => uint256)) allowed;
    // @audit - A mapping from a user to their personal nonce 
    mapping(address => uint256) nonces;
    // @audit - A mapping from a user to a hash to a boolean value representing whether or not
    // @audit - the hash is valid for the given user.
    mapping(address => mapping (bytes32 => bool)) invalidHashes;

    // @audit - Event: Emitted when a token transfer occurs.
    event Transfer(address indexed from, address indexed to, uint tokens);
    // @audit - Event: Emitted when a change in approval occurs.
    event Approval(address indexed from, address indexed spender, uint tokens);
    // @audit - Event: Emitted when tokens are minted.
    event Mint(address indexed to, uint256 amount);
    // @audit - Event: Emitted when tokens are burned.
    event Burn(address indexed from, uint256 amount);
    // @audit - Event: Emitted when a hash is redeemed.
    event HashRedeemed(bytes32 indexed txHash, address indexed from);

    // @audit - Constructor: Sets the owner of the contract to be the sender and set's the sender's balance to be the total supply of tokens
    constructor()
      public
    {
        balances[msg.sender] = _totalSupply;
    }

    // @audit - Function that makes this token meet the ApproveAndCallback interface
    // @param - _from: The address that sent the approval call 
    // @param - _amount: The amount to that the account was approved with
    // @param - _token: The token contract 
    // @param - _data: The calldata provided 
    // @audit - NOTE: The _from, _amount, and _token variables are unused in this function
    function receiveApproval(address _from, uint256 _amount, address _token, bytes _data) 
      public
    {
        // @audit - Ensure that the call was successful
        require(address(this).call(_data));
    }

/** ******************************** ERC20 ********************************* **/

    // @audit - Transfers a specified amount of CASH tokens from the sender to a recipient
    // @param - _to: The recipient of the transfer 
    // @param - _amount: The amount of tokens to transfer
    // @returns - bool: Returns true if the transaction succeeds
    function transfer(address _to, uint256 _amount) 
      public
    returns (bool success)
    {
        // @audit - Call the internal _transfer function and ensure that the call succeeds
        require(_transfer(msg.sender, _to, _amount));
        return true;
    }
    
    // @audit - Transfers a specified amount of tokens to a recipient on behalf of the owner of the tokens
    // @param - _from: The owner of the tokens
    // @param - _to: The recipient of the tokens
    // @param - _amount: The amount of tokens to transfer
    // @returns - bool: Returns true if the transaction succeeds
    function transferFrom(address _from, address _to, uint _amount)
      public
    returns (bool success)
    {
        // @audit - Ensure that the balance of the amount is sufficient for the transfer
        // @audit - Ensure that the senders balance on behalf of the sender is greater than the amount
        require(balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount);
        // @audit - Subtract the amount being sent from the sender's allowance on behalf of the token owner
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        // @audit - Call the internal _transfer function and ensure that the call succeeds
        require(_transfer(_from, _to, _amount));
        return true;
    }
    
    // @audit - Approve a spender on behalf of the sender for a specified amount
    // @param - _spender: The address being approved to spend CASH tokens on behalf of the sender
    // @param - _amount: The specified amount to approve the sender 
    // @returns - bool: Returns true if the transaction succeeds
    function approve(address _spender, uint256 _amount) 
      public
    returns (bool success)
    {
        // @audit - Calls the internal approve function and ensures that the call succeeds
        require(_approve(msg.sender, _spender, _amount));
        return true;
    }
    
    // @audit - Increases the approval of a spender on behalf of the sender
    // @param - _spender: The address to be given an increased approval
    // @param - _amount: The amount to increase the spenders approval
    // @returns - bool: Returns true if the transaction succeeds
    function increaseApproval(address _spender, uint256 _amount) 
      public
    returns (bool success)
    {
        // @audit - Calls the internal increase approval function and ensures that the call succeeds
        require(_increaseApproval(msg.sender, _spender, _amount));
        return true;
    }
    
    // @audit - Increases the approval of a spender on behalf of the sender
    // @param - _spender: The address to be given an increased approval
    // @param - _amount: The amount to increase the spenders approval
    // @returns - bool: Returns true if the transaction succeeds
    function decreaseApproval(address _spender, uint256 _amount) 
      public
    returns (bool success)
    {
        // @audit - Calls the internal decrease approval function and ensures that the call succeeds
        require(_decreaseApproval(msg.sender, _spender, _amount));
        return true;
    }
    
    // @audit - Approve a spender to spend tokens on the sender's behalf and then call the spender contract's recieveApproval function
    // @param - _spender: The address to be approved and then called
    // @param - _amount: The amount to approve the _spender
    // @param - _data: The calldata provided for the call after approve
    // @returns - Returns true if the call succeeds 
    function approveAndCall(address _spender, uint256 _amount, bytes _data) 
      public
    returns (bool success) 
    {
        // @audit - Calls the internal approve function and ensures that the call succeeds
        require(_approve(msg.sender, _spender, _amount));
        // @audit - Call the spender's recieveApproval function with the provided data and the sender
        ApproveAndCallFallBack(_spender).receiveApproval(msg.sender, _amount, address(this), _data);
        return true;
    }

/** ****************************** Internal ******************************** **/
    
    // @audit - Transfer a specified amount of tokens from one address to another, if possible
    // @param - _from: The owner of the tokens
    // @param - _to: The recipient of the token transfer
    // @param - _amount: The amount of tokens to transfer
    // @returns - Returns true if the transaction succeeds 
    function _transfer(address _from, address _to, uint256 _amount)
      internal
    returns (bool success)
    {
        // @audit - Ensure that the recipient is not address zero
        require (_to != address(0), "Invalid transfer recipient address.");
        // @audit - Ensure the owner's balance is greater than or equal to amount
        require(balances[_from] >= _amount, "Sender does not have enough balance.");
        // @audit - Safely subtract the specified amount of tokens from the owner's balance 
        balances[_from] = balances[_from].sub(_amount);
        // @audit - Safely add the specified amount of tokens to the recipient's balance 
        balances[_to] = balances[_to].add(_amount);
        // @audit - Emit a transfer event 
        emit Transfer(_from, _to, _amount);
        return true;
    }
    
    // @audit - Approve a spender on behalf of an owner to spend a specified amount of tokens
    // @param - _owner: The owner of the tokens
    // @param - _spender: The address allowed to spend the tokens
    // @param - _amount: The specified amount of tokens to transfer
    // @returns - bool: Return true if the transaction succeeds
    function _approve(address _owner, address _spender, uint256 _amount) 
      internal
    returns (bool success)
    {
        // @audit - Set the spender's allowance on behalf of the owner to the specified amount
        allowed[_owner][_spender] = _amount;
        // @audit - Emit an approval event
        emit Approval(_owner, _spender, _amount);
        return true;
    }

    // @audit - Increase the allowance of a spender on behalf of an owner by a specified amount of tokens
    // @param - _owner: The owner of the tokens
    // @param - _spender: The address allowed to spend the tokens
    // @param - _amount: The specified amount of tokens to transfer
    // @returns - bool: Return true if the transaction succeeds
    function _increaseApproval(address _owner, address _spender, uint256 _amount)
      internal
    returns (bool success)
    {
        // @audit - Safely add the specified amount of tokens to the spender's balance on behalf of the owner
        allowed[_owner][_spender] = allowed[_owner][_spender].add(_amount);
        // @audit - Emit an approval event
        emit Approval(_owner, _spender, allowed[_owner][_spender]);
        return true;
    }
    
    // @audit - Decrease the allowance of a spender on behalf of an owner by a specified amount of tokens
    // @param - _owner: The owner of the tokens
    // @param - _spender: The address allowed to spend the tokens
    // @param - _amount: The specified amount of tokens to transfer
    // @returns - bool: Return true if the transaction succeeds
    function _decreaseApproval(address _owner, address _spender, uint256 _amount)
      internal
    returns (bool success)
    {
        // @audit -  If the alloweance of the spender on behalf of the owner is less than the amount to decrease, 
        if (allowed[_owner][_spender] <= _amount) 
          // @audit - Set the spender's allowance on behalf of the owner to zero
          allowed[_owner][_spender] = 0;
        // @audit - Otherwise, 
        else 
          // @audit - Safely subract the specified amount from the spender's allowance on behalf of the owner 
          allowed[_owner][_spender] = allowed[_owner][_spender].sub(_amount);
        // @audit - Emit an approval event
        emit Approval(_owner, _spender, allowed[_owner][_spender]);
        return true;
    }
    
/** ************************ Delegated Functions *************************** **/

    // @audit - Transfers tokens from the signer of a presigned transaction, paying the gas cost in tokens 
    // @param - _signature: The presigned transaction signature
    // @param - _to: The address to transfer to
    // @param - _value: The value to be transferred
    // @param - _gasPrice: The gas price of the transaction
    // @param - _nonce: The nonce of the transaction
    // @returns - bool: Returns true if the transaction succeeds
    function transferPreSigned(
        bytes _signature,
        address _to, 
        uint256 _value,
        uint256 _gasPrice, 
        uint256 _nonce) 
      public
    returns (bool) 
    {
        // @audit - Get the gas left upon beginning program execution 
        uint256 gas = gasleft();
        // @audit - Recover the signing address of the transaction
        address from = recoverPreSigned(_signature, transferSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the signature provided was valid
        require(from != address(0), "Invalid signature provided.");
        // @audit - Get the hash of the data that goes into the presigned hash 
        bytes32 txHash = getPreSignedHash(transferSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the transaction described by the recovered transaction hash has not already been processed
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        // @audit - Update the invalid hashes mapping 
        invalidHashes[from][txHash] = true;
        // @audit - Increment the nonce
        nonces[from]++;
        // @audit - Transfer tokens from the owner to the recipient and gg 
        require(_transfer(from, _to, _value));
        // @audit - If the gas price is greater than zero,
        if (_gasPrice > 0) {
            // @audit - Add 35000 to the beginning gas's difference with the remaining gsa. 
            gas = 35000 + gas.sub(gasleft());
            // @audit - Transfer the desired amount of tokens to the tx.origin 
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
        }
        // @audit - Emit a hash redeemed event 
        emit HashRedeemed(txHash, from);
        return true;
    }
    
    // @audit - Approves a spender on behalf of the owner  
    // @param - _signature: The presigned transaction signature
    // @param - _to: The address to approve 
    // @param - _value: The value to be approve the _to address 
    // @param - _gasPrice: The gas price of the transaction
    // @param - _nonce: The nonce of the transaction
    // @returns - bool: Returns true if the transaction succeeds
    function approvePreSigned(
        bytes _signature,
        address _to, 
        uint256 _value,
        uint256 _gasPrice, 
        uint256 _nonce) 
      public
    returns (bool) 
    {
        // @audit - Get the gas left upon beginning program execution 
        uint256 gas = gasleft();
        // @audit - Recover the signing address from the signature provided and the reconstructed transaction hash
        address from = recoverPreSigned(_signature, approveSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the recovered address is nonzero
        require(from != address(0), "Invalid signature provided.");
        // @audit - Compute the transaction hash 
        bytes32 txHash = getPreSignedHash(approveSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the transaction hash has not been executed already
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        // @audit - Mark the transaction hash as used
        invalidHashes[from][txHash] = true;
        // @audit - Increment the transaction nonce
        nonces[from]++;
        // @audit - Call the internal approve function and ensure that the call is successful 
        require(_approve(from, _to, _value));
        // @audit - If the gas price is greater than zero,
        if (_gasPrice > 0) {
            // @audit - Set the gas equal to 35000 added to the amount of gas used during execution
            gas = 35000 + gas.sub(gasleft());
            // @audit - Call the internal transfer function to pay the transaction originator in CASH tokens
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
        }
        // @audit - Emit a hash redeemed event
        emit HashRedeemed(txHash, from);
        return true;
    }
    
    // @audit -  Increases a spender approval on behalf of the signer of a presigned transaction, paying the gas cost in tokens 
    // @param - _signature: The presigned transaction signature
    // @param - _to: The address to increase the approval 
    // @param - _value: The value to increase the approval 
    // @param - _gasPrice: The gas price of the transaction
    // @param - _nonce: The nonce of the transaction
    // @returns - bool: Returns true if the transaction succeeds
    function increaseApprovalPreSigned(
        bytes _signature,
        address _to, 
        uint256 _value,
        uint256 _gasPrice, 
        uint256 _nonce)
      public
    returns (bool) 
    {
        // @audit - Get the gas left upon beginning program execution 
        uint256 gas = gasleft();
        // @audit - Recover the signing address from the signature provided and the reconstructed transaction hash
        address from = recoverPreSigned(_signature, approveSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the recovered address is nonzero
        require(from != address(0), "Invalid signature provided.");
        // @audit - Compute the transaction hash 
        bytes32 txHash = getPreSignedHash(approveSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the transaction hash has not been executed already
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        // @audit - Mark the transaction hash as used
        invalidHashes[from][txHash] = true;
        // @audit - Increment the transaction nonce
        nonces[from]++;
        // @audit - Call the internal increase approval and ensure that the call succeeds        
        require(_increaseApproval(from, _to, _value));
        
        // @audit - If the gas price is nonzero,
        if (_gasPrice > 0) {
            // @audit - Set the gas equal to 35000 added to the amount of gas used during execution
            gas = 35000 + gas.sub(gasleft());
            // @audit - Call the internal transfer function to pay the transaction originator in CASH tokens
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
        }
        // @audit - Emit a hash redeemed event
        emit HashRedeemed(txHash, from);
        return true;
    }
    
    // @audit -  Decreases a spender approval on behalf of the signer of a presigned transaction, paying the gas cost in tokens 
    // @param - _signature: The presigned transaction signature
    // @param - _to: The address to decrease the approval 
    // @param - _value: The value to decrease the approval 
    // @param - _gasPrice: The gas price of the transaction
    // @param - _nonce: The nonce of the transaction
    // @returns - bool: Returns true if the transaction succeeds
    function decreaseApprovalPreSigned(
        bytes _signature,
        address _to, 
        uint256 _value, 
        uint256 _gasPrice, 
        uint256 _nonce) 
      public
    returns (bool) 
    {
        // @audit - Get the gas left upon beginning program execution 
        uint256 gas = gasleft();
        // @audit - Recover the signing address from the signature provided and the reconstructed transaction hash
        address from = recoverPreSigned(_signature, approveSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the recovered address is nonzero
        require(from != address(0), "Invalid signature provided.");
        // @audit - Compute the transaction hash 
        bytes32 txHash = getPreSignedHash(approveSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the transaction hash has not been executed already
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        // @audit - Mark the transaction hash as used
        invalidHashes[from][txHash] = true;
        // @audit - Increment the transaction nonce
        nonces[from]++;
        // @audit - Call the internal decrease approval and ensure that the call succeeds        
        require(_decreaseApproval(from, _to, _value));

        // @audit - If the gas price is nonzero,
        if (_gasPrice > 0) {
            // @audit - Set the gas equal to 35000 added to the amount of gas used during execution
            gas = 35000 + gas.sub(gasleft());
            // @audit - Call the internal transfer function to pay the transaction originator in CASH tokens
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
        }
        // @audit - Emit a hash redeemed event
        emit HashRedeemed(txHash, from);
        return true;
    }
    
    // @audit -  Approve and call a sender on behalf of the signer of a presigned transaction, paying the gas cost in tokens 
    // @param - _signature: The presigned transaction signature
    // @param - _to: The address to transfer to
    // @param - _value: The value to be transferred
    // @param - _gasPrice: The gas price of the transaction
    // @param - _nonce: The nonce of the transaction
    // @returns - bool: Returns true if the transaction succeeds
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
        // @audit - Get the gas left upon beginning program execution 
        uint256 gas = gasleft();
        // @audit - Recover the signing address from the signature provided and the reconstructed transaction hash
        address from = recoverPreSigned(_signature, approveSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the recovered address is nonzero
        require(from != address(0), "Invalid signature provided.");
        // @audit - Compute the transaction hash 
        bytes32 txHash = getPreSignedHash(approveSig, _to, _value, "", _gasPrice, _nonce);
        // @audit - Ensure that the transaction hash has not been executed already
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        // @audit - Mark the transaction hash as used
        invalidHashes[from][txHash] = true;
        // @audit - Increment the transaction nonce
        nonces[from]++;
        
        // @audit - If value is nonzero, ensure that an internal approve call succeeds
        if (_value > 0) require(_approve(from, _to, _value));
        // @audit - Call the _to address's recieveApproval function
        ApproveAndCallFallBack(_to).receiveApproval(from, _value, address(this), _extraData);

        // @audit - If the gas price is nonzero,
        if (_gasPrice > 0) {
            // @audit - Set the gas equal to 35000 added to the amount of gas used during execution
            gas = 35000 + gas.sub(gasleft());
            // @audit - Call the internal transfer function to pay the transaction originator in CASH tokens
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
        }
        // @audit - Emit a hash redeemed event
        emit HashRedeemed(txHash, from);
        return true;
    }

/** *************************** Revoke PreSigned ************************** **/
    
    // @audit - Mark a specified hash as executed in the sender's namespace
    // @param - _hashToRevoke
    // @returns - bool: Returns true
    function revokeHash(bytes32 _hashToRevoke)
      public
    returns (bool)
    {
        // @audit - Mark the specified hash as executed
        invalidHashes[msg.sender][_hashToRevoke] = true;
        return true;
    }
    
    // @audit - Marks a hash as already executed and pays the gas cost in CASH tokens
    // @param - _signature: The signature of the presigned transaction
    // @param - _hashToRevoke: The hash to mark as executed
    // @param - _gasPrice: The gas price of the transaction
    // @returns - bool: Returns true if the transaction succeeds
    function revokeHashPreSigned(
        bytes _signature,
        bytes32 _hashToRevoke,
        uint256 _gasPrice)
      public
    returns (bool)
    {
        // @audit - Get the amount of gas left at the beginning of the transaction
        uint256 gas = gasleft();
        // @audit - Recover the signer from the signature
        address from = recoverRevokeHash(_signature, _hashToRevoke, _gasPrice);
        // @audit - Ensure that the signer was not address zero
        require(from != address(0), "Invalid signature provided.");
        // @audit - Calculate the transaction hash of the revoke hash operation 
        bytes32 txHash = getRevokeHash(_hashToRevoke, _gasPrice);
        // @audit - Ensure that the revoke hash transaction has not been executed 
        require(!invalidHashes[from][txHash], "Transaction has already been executed.");
        // @audit - Mark the revoke hash transaction as executed
        invalidHashes[from][txHash] = true;
        // @audit - Mark the transaction represented by the hash to revoke as executed
        invalidHashes[from][_hashToRevoke] = true;
        
        // @audit - If the gas price is greater than zero,
        if (_gasPrice > 0) {
            // @audit - Set the gas equal to 35000 added to the amount of gas used during execution
            gas = 35000 + gas.sub(gasleft());
            // @audit - Call the internal transfer function to pay the transaction originator in CASH tokens
            require(_transfer(from, tx.origin, _gasPrice.mul(gas)), "Gas cost could not be paid.");
        }
        
        // @audit - Emit a HashRedeemed event
        emit HashRedeemed(txHash, from);
        return true;
    }
    
    // @audit - Calculates the transaction hash of the revoke hash operation specified by the arguments
    // @param - _hashToRevoke: The transaction hash to mark as executed
    // @param - _gasPrice: The gas price of the revoke hash transaction
    // @returns - txHash: The revoke hash transaction hash
    function getRevokeHash(bytes32 _hashToRevoke, uint256 _gasPrice)
      public
      view
    returns (bytes32 txHash)
    {
        // @audit - Compute the revoke hash transaction hash 
        return keccak256(address(this), revokeHashSig, _hashToRevoke, _gasPrice);
    }

    // @audit - Recover the signer of a revoke hash transaction 
    // @param - _signature: The transaction signature
    // @param - _hashToRevoke: The hash to mark as executed
    // @param - _gasPrice: The gas price of the transaction
    // @returns - from: The signer of a revoke hash transaction
    function recoverRevokeHash(bytes _signature, bytes32 _hashToRevoke, uint256 _gasPrice)
      public
      view
    returns (address from)
    {
        // @audit - Recover the signer from the signature and hash
        return ecrecoverFromSig(getSignHash(getRevokeHash(_hashToRevoke, _gasPrice)), _signature);
    }
    
/** ************************** PreSigned Constants ************************ **/

    // @audit - Computes the transaction hash of a transaction with the specified attributes
    // @param - _function: The function selector of the transaction
    // @param - _to: The address being affected by the transaction
    // @param - _value: The value to be sent with the transaction 
    // @param - _extraData: The extra data sent with the transaction
    // @param - _gasPrice: The gas price of the transaction
    // @param - _nonce: The nonce of the sender of the transaction at the time of the signature
    // @returns - txHash: The hash generated by the provided parameters
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
        // @audit - Compute the hash of the provided inputs with this contract's address prepended
        return keccak256(address(this), _function, _to, _value, _extraData, _gasPrice, _nonce);
    }
    
    // @audit - Recover the signing address of the transaction specified by the arguments and the provided signature
    // @param - _sig: The signature of the transaction
    // @param - _function: The function selector of the transaction
    // @param - _to: The address being affected by the transaction
    // @param - _value: The value to be sent with the transaction 
    // @param - _extraData: The extra data sent with the transaction
    // @param - _gasPrice: The gas price of the transaction
    // @param - _nonce: The nonce of the sender of the transaction at the time of the signature
    // @returns - recovered: The signing address of the transaction specified by the hash and the signature 
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
        // @audit - Recover the signer's address from the hash generated by the provided arguments and the signature 
        return ecrecoverFromSig(getSignHash(getPreSignedHash(_function, _to, _value, _extraData, _gasPrice, _nonce)), _sig);
    }
    
    // @audit - Prepends the standard string "\x19Ethereum Signed Message:\n32" to the provided hash 
    // @param - _hash: The specified transaction hash
    // @returns - signHash: The hash derived from the original hash and the signed message string
    function getSignHash(bytes32 _hash)
      public
      pure
    returns (bytes32 signHash)
    {
        // @audit - Hash the provided hash with the string "\x19Ethereum Signed Message:\n32"
        return keccak256("\x19Ethereum Signed Message:\n32", _hash);
    }

    // @audit - Recovers the transaction signer of a presigned transaction
    // @param - hash: The hash of a presigned transaction
    // @param - sig: The signature of a presigned transaction
    // @returns - recoveredAddress: The signer of the signature
    function ecrecoverFromSig(bytes32 hash, bytes sig) 
      public 
      pure 
    returns (address recoveredAddress) 
    {
        // @audit - Initialize the r, s, and v values to use for the ecrecover
        bytes32 r;
        bytes32 s;
        uint8 v;
        // @audit - If the signature length is not equal to 65 bytes, return address zero to indicate an invalid signature.
        // @audit - The first 32 bytes give r, the second 32 bytes give s, and the last byte gives v 
        if (sig.length != 65) return address(0);
        assembly {
            // @audit - Set r equal to the first 32 bytes of the signature (after sig's length slot)
            r := mload(add(sig, 32))
            // @audit - Set s equal to the second 32 bytes of the signature
            s := mload(add(sig, 64))
            // @audit - Set v equal to the first byte of the third 32 bytes of the signature
            v := byte(0, mload(add(sig, 96)))
        }
        // @audit - If v is less than 27, add 27 to v 
        if (v < 27) v += 27;
        // @audit - If v is not 27 or 28, return address zero to indicate an invalid signature
        if (v != 27 && v != 28) return address(0);
        // @audit - Use the ecrecover operation on the provided hash and the derived v, r, and s to recover the transaction signer
        return ecrecover(hash, v, r, s);
    }

    // @audit - A getter for an owner's personal nonce
    // @returns - uint: The owner's personal nonce
    function getNonce(address _owner)
      external
      view
    returns (uint256 nonce)
    {
        return nonces[_owner];
    }

/** ****************************** Constants ******************************* **/
    
    // @audit - A getter for the total supply of CASH tokens
    // @returns - uint: The total supply of CASH tokens
    function totalSupply() 
      external
      view 
     returns (uint256)
    {
        return _totalSupply;
    }

    // @audit - A getter for the balance of a token owner
    // @param - _owner: The token owner
    // @returns - uint: The balance of the token owner
    function balanceOf(address _owner)
      external
      view 
    returns (uint256) 
    {
        return balances[_owner];
    }
    
    // @audit - A getter for the allowance of a spender on behalf of an owner
    // @param - _owner: The owner of the tokens
    // @param - _spender: The spender of the tokens --> The address with the allowance
    // @returns - uint: The allowance of the spender on behalf of the owner
    function allowance(address _owner, address _spender) 
      external
      view 
    returns (uint256) 
    {
        return allowed[_owner][_spender];
    }
    
/** ****************************** onlyOwner ******************************* **/
    
    // @audit - Creates new CASH tokens and gives them to a specified address
    // @param - _to: The benefactor of the token minting
    // @param - _amount: The amount of tokens to mint
    // @returns - success: Returns true if the transaction succeeds
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of the contract
    function mint(address _to, uint256 _amount)
      external
      onlyOwner
    returns (bool success)
    {
        // @audit - Ensure that the amount to mint is nonzero
        require(_amount > 0);
        // @audit - Safely add the specified amount to the balance of the benefactor
        balances[_to] = balances[_to].add(_amount);
        // @audit - Safely add the specifed amount to the total supply of tokens
        _totalSupply = _totalSupply.add(_amount);
        // @audit - Emit a Mint event
        emit Mint(_to, _amount);
        return true;
    }
    
    // @audit - Eliminates CASH tokens from a specified address 
    // @param - _from: The address from which tokens will be burned
    // @param - _amount: The amount of tokens to burn
    // @returns - success: Returns true if the transaction succeeds
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of the contract
    function burn(address _from, uint256 _amount)
      external
      onlyOwner
    returns (bool success)
    {
        // @audit - Ensure that the amount to burn is nonzero 
        require(_amount > 0);
        // @audit - Ensure that the specified address to burn has enough tokens to burn 
        require(balances[_from] >= _amount);
        // @audit - Safely subtract the specified amount from the address being burned 
        balances[_from] = balances[_from].sub(_amount);
        // @audit - Safely subtract the specified amount from the total supply of CASH tokens
        _totalSupply = _totalSupply.sub(_amount);
        // @audit - Emit a burn event
        emit Burn(_from, _amount);
        return true;
    }

    // @audit - Transfers tokens that were accidentally stuck in a CASHToken contract to the owner of the contract
    // @param - _tokenContract: The token contract with stuck tokens
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of the contract
    function tokenEscape(address _tokenContract)
      external
      onlyOwner
    {
        // @audit - Get CASHToken instance of the token contract
        CashToken lostToken = CashToken(_tokenContract);
        // @audit - Retrieve the number of stuck tokens in the lost token contract
        uint256 stuckTokens = lostToken.balanceOf(address(this));
        // @audit - Transfer the stuck token to the owner of the contract
        lostToken.transfer(owner, stuckTokens);
    }
    
}
