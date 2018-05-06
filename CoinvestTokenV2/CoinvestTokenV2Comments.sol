// @audit - Version pragma
// NOTE - Version not compatible with 0.4.20. Consider changing to '0.4.21' or higher
pragma solidity ^0.4.20;

// @audit - SafeMathLib contains functions for arithmetic operations that throw on overflow
library SafeMathLib {

  // @audit - Safely multiplies two numbers, throwing on overflow. Returns the product of a and b
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  // @audit - Divides a and b, and returns the result
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  // @audit - Subtracts b from a, checking for underflow. Returns the result
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  // @audit - Adds a and b, checking for overflow. Returns the result.
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

// @audit - Simple 'Ownable' contract - Defines and implements to protocol for administrator-level access to functions
contract Ownable {

  // @audit - The owner of the contract. Has access to admin-level functions
  address public owner;

  // @audit - Event: emitted when the owner transfers their ownership status to another address
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  // @audit - Constructor: Sets the sender as the owner address
  // @audit - NOTE: Update to latest 'constructor' syntax
  function Ownable() public {
    owner = msg.sender;
  }

  // @audit - modifier: Restricts functions to be only accessible by the owner
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  // @audit - Allows the existing owner to transfer ownership to a new address
  // @param - "newOwner": The new address to be given ownership permissions
  // @audit - MODIFIER onlyOwner: Only the owner address is allowed to transfer ownership rights
  function transferOwnership(address newOwner) onlyOwner public {
    // @audit - Ensure a valid new owner address
    require(newOwner != address(0));
    // @audit - Emit OwnershipTransferred event
    emit OwnershipTransferred(owner, newOwner);
    // @audit - Set the new contract owner
    owner = newOwner;
  }

}

// @audit - Implements an abstract 'receiveApproval' function
contract ApproveAndCallFallBack {
  function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

// @audit - The main Coinvest token contract. Inherits the Ownable interface
contract CoinvestToken is Ownable {

    // @audit - Attaches SafeMathLib functions to uint256
    using SafeMathLib for uint256;

    // @audit - Token symbol string
    string public constant symbol = "COIN";

    // @audit - Token name string
    string public constant name = "Coinvest COIN V2 Token";

    // @audit - Number of token display decimals
    uint8 public constant decimals = 18;

    // @audit - Total supply of coinvest token. Same as the total supply of the old coinvest token
    // @audit - NOTE: Consider marking this constant, as reading from constant variables costs far less than reading from state variables
    uint256 public _totalSupply = 107142857 * (10 ** 18);

    // @audit - User token balances
    // @audit - NOTE: Consider explicitly setting visibility to 'internal'
    mapping(address => uint256) balances;

    // @audit - User transaction nonce. This is incremented each time a user's pre-signed transaction is processed, mitigating the risk of race conditions
    // @audit - NOTE: Consider explicitly setting visibility to 'internal'
    // @audit - LOW: Users may sign and approve a transaction, and then want to cancel this transaction. Consider allowing the user to increment their own nonce
    mapping (address => uint256) nonces;

    // @audit - Maps token owner to allowed spender to amount of tokens able to be spent on the owner's behalf
    // @audit - NOTE: Consider explicitly setting visibility to 'internal'
    mapping(address => mapping (address => uint256)) allowed;

    // @audit - Events
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed from, address indexed spender, uint tokens);

    // @audit - Constructor: sets the balance of the sender to the total supply of the coinvest token
    constructor()
      public
    {
        balances[msg.sender] = _totalSupply;
    }

    // @audit - Makes use of the internal _transfer function to transfer tokens from the sender to a recipient
    // @param - "_to": The address to which tokens will be transferred
    // @param - "_amount": The amount of tokens to transfer
    // @returns - "success": Whether or not the transfer succeeded
    function transfer(address _to, uint256 _amount)
      public
    returns (bool success)
    {
        // @audit - Ensure the transfer is successful by requiring a valid response from _transfer
        require(_transfer(msg.sender, _to, _amount));
        // @audit - Return true
        return true;
    }

    // @audit - Allows a delegated spender to send tokens on another addresses' behalf, provided they have sufficient allowance
    // @param - "_from": The address from which tokens will be transferred
    // @param - "_to": The address to which tokens will be transferred
    // @param - "_amount": The amount of tokens to transfer
    // @returns - "success": Whether or not the transfer succeeded
    function transferFrom(address _from, address _to, uint _amount)
      public
    returns (bool success)
    {
        // @audit - Ensure that the _from address has sufficient balance, and that the sender has sufficient allowance
        // @audit - NOTE: These checks are unnecessary given the use of underflow-protected math
        require(balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount);

        // @audit - Safely subtract the amount sent from the sender's allowance
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        // @audit - Ensure the transfer is successful by requiring a valid response from _transfer
        require(_transfer(_from, _to, _amount));
        // @audit - Return true
        return true;
    }

    // @audit - Allows the sender to approve a spender for delegated spends from their token balance
    // @param - "_spender": The address which will be approved for token transfers
    // @param - "_amount": The amount of tokens to approve for spending
    // @returns - "success": Whether or not the approval succeeded
    function approve(address _spender, uint256 _amount)
      public
    returns (bool success)
    {
        // @audit - Ensure the approval is successful by requiring a valid response from _approve
        require(_approve(msg.sender, _spender, _amount));
        // @audit - Return true
        return true;
    }

    // @audit - Allows the sender to approve a spender for delegated spends from their token balance, and calls receiveApproval on the spender's address
    // @param - "_spender": The address which will be approved for token transfers
    // @param - "_amount": The amount of tokens to approve for spending
    // @param - "_data": An amount of data to send to the _spender
    // @returns - "success": Whether or not the approval succeeded
    function approveAndCall(address _spender, uint256 _amount, bytes _data)
      public
    returns (bool success)
    {
        // @audit - Ensure the approval is successful by requiring a valid response from _approve
        require(_approve(msg.sender, _spender, _amount));
        // @audit - Call receiveApproval at the _spender's address, passing in the sender, amount approved, token address, and additional data
        ApproveAndCallFallBack(_spender).receiveApproval(msg.sender, _amount, address(this), _data);
        // @audit - Return true
        return true;
    }

    // @audit - Transfers tokens from one address to another
    // @param - "_from": The address from which tokens will be transferred
    // @param - "_to": The address to which tokens will be transferred
    // @param - "_amount": The amount of tokens to transfer
    // @returns - "success": Whether or not the transfer succeeded
    // @param - VISIBILITY internal: This function cannot be accessed externally
    // @audit - NOTE: This function should check that the recipient address is nonzero, and that the recipient is not this contract's address
    function _transfer(address _from, address _to, uint256 _amount)
      internal
    returns (bool success)
    {
        // @audit - Ensure the sender has sufficient balance for the transaction
        // @audit - NOTE: Because safe subtraction protects against underflow, this check is not necessary
        require(balances[_from] >= _amount);

        // @audit - Safely subtract the amount sent from the sender's balance
        balances[_from] = balances[_from].sub(_amount);
        // @audit - Safely add the amount to send to the recipient's balance
        balances[_to] = balances[_to].add(_amount);

        // @audit - Emit Transfer event and return true
        emit Transfer(_from, _to, _amount);
        return true;
    }

    // @audit - Approves a spender an allowance for spending
    // @param - "_owner": The owner of the tokens to be spent
    // @param - "_spender": The delegated spender of the owner's tokens
    // @param - "_amount": The amount of tokens to approve for spending
    // @returns - "success": Whether or not the approval succeeded
    // @param - VISIBILITY internal: This function cannot be accessed externally
    // @audit - LOW: Recommend enforcing a pattern where allowances must first be set to 0 before being allowed to
    //               change to nonzero values, to prevent racing conditions
    function _approve(address _owner, address _spender, uint256 _amount)
      internal
    returns (bool success)
    {
        // @audit - Ensure the owner has sufficient allowance to allow for the spender
        // @audit - LOW: The owner's balance does not need to be greater than or equal to the amount to approve, as
        //               the transfer function will check these bounds. Additionally, this is easily circumvented if an
        //               owner approves a spender for their entire balance, and then sends tokens elsewhere
        require(balances[_owner] >= _amount);

        // @audit - Set the allowed spend amount of the spender from the owner's balance to the amount
        allowed[_owner][_spender] = _amount;
        // @audit - Emit Approval event and return
        emit Approval(_owner, _spender, _amount);
        return true;
    }

    // @audit - Allows anyone to transfer a user's tokens on their behalf, provided they were given a signed message authorizing the transfer
    // @param - "_signature": The signature provided to the delegate by the owner of the tokens
    // @param - "_to": The address to which the tokens will be sent
    // @param - "_value": The amount of tokens which will be sent
    // @param - "_gasPrice": The number of tokens the signer has agreed to pay per gas used during the transaction
    // @param - "_nonce": The nonce of the signer's transaction
    // @returns - bool: Whether or not the transfer succeeded
    function transferPreSigned(
        bytes _signature,
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
    returns (bool)
    {
        // @audit - Get the current amount of gas in the transaction
        uint256 gas = gasleft();

        // @audit - Get the address from which the tokens will be sent using the signature provided
        address from = recoverTransferPreSigned(_signature, _to, _value, _gasPrice, _nonce);
        // @audit - Ensure the signing address is valid
        require(from != address(0));

        // @audit - Ensure the signed message references the nonce of the next transaction
        require(_nonce == nonces[from] + 1);
        // @audit - Increment nonce
        nonces[from]++;

        // @audit - Ensure a valid token transfer by requiring a 'true' response from _transfer
        require(_transfer(from, _to, _value));

        // @audit - If the signer's set gas price is nonzero -
        if (_gasPrice > 0) {
            // @audit - Get the difference in gas spent executing the signer's transfer, multiply by the gas price, add 35000, and transfer those tokens to the sender
            gas = 35000 + gas.sub(gasleft());
            // @audit - Ensure a valid transfer from signer to sender by requiring a 'true' response from _transfer
            // @audit - MEDIUM: The signer can set a massively-high gas price for the sender and cause an overflow here, resulting in a lower fee for the sender.
            //                  As it's very likely that senders will be using an automated system to pick pre-signed transfers to execute, using such a high fee
            //                  could very likely go unnoticed by such a program, allowing the sender to transfer tokens on the sender's buck. Checking for overflow will fix this issue
            require(_transfer(from, msg.sender, _gasPrice * gas));
        }
        // @audit - Return true
        return true;
    }

    // @audit - Allows anyone to approve an address for spending from the owner's tokens, provided they were given a signed message authorizing the approval
    // @param - "_signature": The signature provided to the delegate by the owner of the tokens
    // @param - "_to": The address which will be approved tokens to spend
    // @param - "_value": The amount of tokens which will be approved for spending by the spender
    // @param - "_gasPrice": The number of tokens the signer has agreed to pay per gas used during the transaction
    // @param - "_nonce": The nonce of the signer's transaction
    // @returns - bool: Whether or not the approval succeeded
    function approvePreSigned(
        bytes _signature,
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
    returns (bool)
    {
        // @audit - Get the current amount of gas in the transaction
        uint256 gas = gasleft();
        // @audit - Get the address from which the spender will be spending using the signature provided
        address from = recoverApprovePreSigned(_signature, _to, _value, _gasPrice, _nonce);
        // @audit - Ensure the signing address is valid
        require(from != address(0));
        // @audit - Ensure the signed message references the nonce of the next transaction
        require(_nonce == nonces[from] + 1);
        // @audit - Increment nonce
        nonces[from]++;
        // @audit - Ensure a valid approval by requiring a 'true' response from _approve
        require(_approve(from, _to, _value));

        // @audit - If the signer's set gas price is nonzero -
        if (_gasPrice > 0) {
            // @audit - Get the difference in gas spent executing the signer's approval, multiply by the gas price, add 35000, and transfer those tokens to the sender
            gas = 35000 + gas.sub(gasleft());
            // @audit - Ensure a valid token transfer by requiring a 'true' response from _transfer
            // @audit - MEDIUM: See transferPreSigned
            require(_transfer(from, msg.sender, _gasPrice * gas));
        }
        // @audit - Return true
        return true;
    }

    // @audit - Allows anyone to approve an address for spending from the owner's tokens, provided they were given a signed message authorizing the approval
    // @param - "_signature": The signature provided to the delegate by the owner of the tokens
    // @param - "_to": The address which will be approved tokens to spend
    // @param - "_value": The amount of tokens which will be approved for spending by the spender
    // @param - "_extraData": Additional data which will be sent to the recipient
    // @param - "_gasPrice": The number of tokens the signer has agreed to pay per gas used during the transaction
    // @param - "_nonce": The nonce of the signer's transaction
    // @returns - bool: Whether or not the approval succeeded
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
        // @audit - Get the current amount of gas in the transaction
        uint256 gas = gasleft();
        // @audit - Get the address from which the spender will be spending using the signature provided
        address from = recoverApproveAndCallPreSigned(_signature, _to, _value, _extraData, _gasPrice, _nonce);
        // @audit - Ensure the signing address is valid
        require(from != address(0));
        // @audit - Ensure the signed message references the nonce of the next transaction
        require(_nonce == nonces[from] + 1);
        // @audit - Increment nonce
        nonces[from]++;

        // @audit - Ensure a valid approval by requiring a 'true' response from _approve
        require(_approve(from, _to, _value));
        // @audit - Call the recipient address's 'receiveApproval' function and pass in the extra data
        ApproveAndCallFallBack(_to).receiveApproval(from, _value, address(this), _extraData);

        // @audit - If the signer's set gas price is nonzero -
        if (_gasPrice > 0) {
            // @audit - Get the difference in gas spent executing the signer's approval, multiply by the gas price, add 35000, and transfer those tokens to the sender
            gas = 35000 + gas.sub(gasleft());
            // @audit - Ensure a valid token transfer by requiring a 'true' response from _transfer
            // @audit - MEDIUM: See transferPreSigned
            require(_transfer(from, msg.sender, _gasPrice * gas));
        }
        // @audit - Return true
        return true;
    }

    // @audit - Returns a hash used to transfer tokens on a party's behalf
    // @param - "_to": The address which will receive the tokens
    // @param - "_value": The amount of tokens to send
    // @param - "_gasPrice": The number of tokens the user will pay per gas used
    // @param - "_nonce": The nonce of the new transaction
    // @returns - "txHash": A hash representing a token transfer
    function getTransferHash(
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
      view
    returns (bytes32 txHash) {
        return keccak256(address(this), bytes4(0x1296830d), _to, _value, _gasPrice, _nonce);
    }

    // @audit - Returns a hash used to approve tokens for a spender on a party's behalf
    // @param - "_to": The address which will be approved to spend tokens
    // @param - "_value": The amount of tokens to approve for spending
    // @param - "_gasPrice": The number of tokens the user will pay per gas used
    // @param - "_nonce": The nonce of the new transaction
    // @returns - "txHash": A hash representing an approval
    function getApproveHash(
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
      view
    returns (bytes32 txHash) {
        return keccak256(address(this), bytes4(0x617b390b), _to, _value, _gasPrice, _nonce);
    }

    // @audit - Returns a hash used to approve tokens for a contract on a party's behalf
    // @param - "_to": The address which will be approved to spend tokens
    // @param - "_value": The amount of tokens to approve for spending
    // @param - "_extraData": Additional data which will be sent with the approveAndCall to the recieving contract
    // @param - "_gasPrice": The number of tokens the user will pay per gas used
    // @param - "_nonce": The nonce of the new transaction
    // @returns - "txHash": A hash representing an approval
    function getApproveAndCallHash(
        address _to,
        uint256 _value,
        bytes _extraData,
        uint256 _gasPrice,
        uint256 _nonce)
      public
      view
    returns (bytes32 txHash) {
        return keccak256(address(this), bytes4(0xc8d4b389), _to, _value, _extraData, _gasPrice, _nonce);
    }

    // @audit - Recovers the signer of the signature authorizing the token transfer
    // @param - "_sig": The signature provided
    // @param - "_to": The address to which the token will be sent
    // @param - "_value": The amount of tokens which will be sent
    // @param - "_gasPrice": The amount of tokens the sender has agreed to pay per gas used
    // @param - "_nonce": The nonce of the user's transaction
    // @returns - "recovered": The address recovered from the provided signature
    function recoverTransferPreSigned(
        bytes _sig,
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
      view
    returns (address recovered)
    {
        // @audit - Calls getTransferHash using the passed-in data, returning a hash representing a token transfer.
        //          This hash is passed to getSignHash, which returns the hash of a message which can be ecrecovered to retrieve the original signer.
        //          Finally, the message hash and signature are passed to ecrecoverFromSig, which returns the address of the signer
        return ecrecoverFromSig(getSignHash(getTransferHash(_to, _value, _gasPrice, _nonce)), _sig);
    }

    // @audit - Recovers the signer of the signature authorizing the approval
    // @param - "_sig": The signature provided
    // @param - "_to": The address which will be approved to spend tokens from the owner's balance
    // @param - "_value": The amount of tokens to approve for the spender
    // @param - "_gasPrice": The amount of tokens the sender has agreed to pay per gas used
    // @param - "_nonce": The nonce of the user's transaction
    // @returns - "recovered": The address recovered from the provided signature
    function recoverApprovePreSigned(
        bytes _sig,
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _nonce)
      public
      view
    returns (address recovered)
    {
        // @audit - Calls getApproveHash using the passed-in data, returning a hash representing an approval for spending.
        //          This hash is passed to getSignHash, which returns the hash of a message which can be ecrecovered to retrieve the original signer.
        //          Finally, the message hash and signature are passed to ecrecoverFromSig, which returns the address of the signer
        return ecrecoverFromSig(getSignHash(getApproveHash(_to, _value, _gasPrice, _nonce)), _sig);
    }

    // @audit - Recovers the signer of the signature authorizing an approval for a contract which will be sent additional data
    // @param - "_sig": The signature provided
    // @param - "_to": The address which will be approved to spend tokens from the owner's balance
    // @param - "_value": The amount of tokens to approve for the spender
    // @param - "_extraData": Additional data which will be sent to the recipient
    // @param - "_gasPrice": The amount of tokens the sender has agreed to pay per gas used
    // @param - "_nonce": The nonce of the user's transaction
    // @returns - "recovered": The address recovered from the provided signature
    function recoverApproveAndCallPreSigned(
        bytes _sig,
        address _to,
        uint256 _value,
        bytes _extraData,
        uint256 _gasPrice,
        uint256 _nonce)
      public
      view
    returns (address recovered)
    {
        // @audit - Calls getApproveAndCallHash using the passed-in data, returning a hash representing an approval for spending by a contract.
        //          This hash is passed to getSignHash, which returns the hash of a message which can be ecrecovered to retrieve the original signer.
        //            Finally, the message hash and signature are passed to ecrecoverFromSig, which returns the address of the signer
        return ecrecoverFromSig(getSignHash(getApproveAndCallHash(_to, _value, _extraData, _gasPrice, _nonce)), _sig);
    }

    // @audit - Returns a hash which can be signed and then recovered using ecrecover
    // @param - "_hash": The hash which will be signed
    // @returns - "signHash": An 'Ethereum Signed Message' hash from which a signer's address can be extracted via ecrecover
    function getSignHash(bytes32 _hash)
      public
      pure
    returns (bytes32 signHash)
    {
        return keccak256("\x19Ethereum Signed Message:\n32", _hash);
    }

    // @audit - Given a message hash and signature, returns the address which signed the message
    // @param - "hash": The hash of the message which was signed
    // @param - "sig": The signature of a message hash
    // @returns - "recoveredAddress": The address that signed the message hash
    function ecrecoverFromSig(bytes32 hash, bytes sig)
      public
      pure
    returns (address recoveredAddress)
    {
        // @audit - Create variables for signature verification: v, r, and s
        bytes32 r;
        bytes32 s;
        uint8 v;
        // @audit - Ensure the length of the signature is at least 65 bytes. If not, return 0x0
        if (sig.length != 65) return address(0);
        assembly {
            // @audit - Get the r value for the signature - bytes 0-32 of the signature
            r := mload(add(sig, 32))
            // @audit - Get the s value for the signature - bytes 32-64 of the signature
            s := mload(add(sig, 64))
            // @audit - Get the v value for the signature - the final (65th) byte of the signature
            v := byte(0, mload(add(sig, 96)))
        }
        // @audit - If the final byte is less than 27, add 27 to the v value
        if (v < 27) {
          v += 27;
        }
        // @audit - If v is not 27 or 28, return 0x0
        if (v != 27 && v != 28) return address(0);
        // @audit - Otherwise, return the signing address of the hash using the v, r, and s values of the signature
        return ecrecover(hash, v, r, s);
    }

    // @audit - Returns the owner's transaction nonce
    function getNonce(address _owner)
      external
      view
    returns (uint256 nonce)
    {
        return nonces[_owner];
    }

    // @audit - Returns the total number of tokens in existence
    function totalSupply()
      external
      view
     returns (uint256)
    {
        return _totalSupply;
    }

    // @audit - Returns the token balance of the passed-in owner
    function balanceOf(address _owner)
      external
      view
    returns (uint256)
    {
        return balances[_owner];
    }

    // @audit - Returns the number of tokens delegated for spending from the _owner to the _spender
    function allowance(address _owner, address _spender)
      external
      view
    returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    // @audit - Allows the owner address to transfer themselves tokens that were sent to this contract by mistake
    // @param - "_tokenContract": The address of the token whose tokens were sent here
    // @audit - MODIFIER onlyOwner: Only the contract owner can retrieve stuck tokens
    function token_escape(address _tokenContract)
      external
      onlyOwner
    {
        // @audit - Cast the passed-in token contract to CoinvestToken
        CoinvestToken lostToken = CoinvestToken(_tokenContract);

        // @audit - Get the balance of tokens held by this contract
        uint256 stuckTokens = lostToken.balanceOf(address(this));
        // @audit - Transfer stuck tokens to the owner
        // @audit - NOTE: Consider adding a check for '0' balance
        lostToken.transfer(owner, stuckTokens);
    }

}
