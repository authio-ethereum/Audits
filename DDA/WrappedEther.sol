pragma solidity ^0.4.23;
import "./libraries/SafeMath.sol";

// @audit - Contract that allows users to convert ether to "wrapped ether" tokens that meet the ERC20 specification
contract Wrapped_Ether {
    // @audit - Attaches the SafeMath library to uint256
    using SafeMath for uint256;

    // @audit - A public string of the name of the contract 
    string public name = "Wrapped Ether";
    // @audit - The total supply of wrapped ether tokens in this contract
    uint public total_supply;

    // @audit - A mapping from a users address to their balance -- used internally
    mapping(address => uint) internal balances;
    // @audit - A mapping from a users address to a spenders address to their allowance -- used internally
    mapping(address => mapping (address => uint)) internal allowed;

    // @audit - Event: Emitted whenever a transfer from one account to another occurs
    event Transfer(address indexed _from, address indexed _to, uint _value);
    // @audit - Event: Emitted when a change in the allowed mapping occurs
    event Approval(address indexed _owner, address indexed _spender, uint _value);
    // @audit - Event: Used when the state changes. Not used internally  
    event StateChanged(bool _success, string _message);

    // @audit - Allows anyone to create wrapped ether tokens
    function createToken() public payable {
        // @audit - Ensure that msg.value is enough to pay for any wrapped ether tokens
        require(msg.value > 0);
        // @audit - Safely add msg.value to the sender's balance
        balances[msg.sender] = balances[msg.sender].add(msg.value);
        // @audit - Safely add msg.value to the total supply
        total_supply = total_supply.add(msg.value);
    }

    // @audit - Allows anyone to withdraw funds from their balance. Some wrapped ether tokens are unwrapped in the process
    // @param - _value: The amount of funds to withdraw
    function withdraw(uint _value) public {
        // @audit - Safely subtract the requested amount from the senders balance  
        balances[msg.sender] = balances[msg.sender].sub(_value);
        // @audit - Safely subtract the requested amount from the total supply  
        total_supply = total_supply.sub(_value);
        // @audit - Transfer the requested amount to the sender
        msg.sender.transfer(_value);
    }

    // @audit - Allows anyone to get the balance of an owner
    // @param - _owner: The address being queried
    // @returns - bal: The balance of the owner
    function balanceOf(address _owner) public constant returns (uint bal) { return balances[_owner]; }

    // @audit - Allows anyone to transfer tokens from their balance to another address 
    // @param - _to: The recipient of the transfer 
    // @param - _amount: The amount of tokens to transfer 
    // @returns - bool: The success of the transfer 
    function transfer(address _to, uint _amount) public returns (bool) {
        if ( balances[msg.sender] >= _amount
        && _amount > 0
        && balances[_to] + _amount > balances[_to]) {
            // @audit - Safely subtracts the amount being transferred from the sender's balance
            balances[msg.sender] = balances[msg.sender].sub(_amount);
            // @audit - Safely adds the amount being transferred to the recipient's balance
            balances[_to] = balances[_to].add(_amount);
            // @audit - Emits a Transfer event
            emit Transfer(msg.sender, _to, _amount);
            return true;
        // @audit - Return false to indicate that the transfer was unsuccessful
        } else {
            return false;
        }
    }

    // @audit - Allows anyone to transfer tokens from another address to a recipient. Approval is required for this transaction 
    // @param - _from: The address paying in this transaction 
    // @param - _to: The recipient of the transfer 
    // @param - _amount: The amount to transfer 
    // @returns - bool: The success of this transfer 
    function transferFrom(address _from, address _to, uint _amount) public returns (bool) {
        if (balances[_from] >= _amount
        && allowed[_from][msg.sender] >= _amount
        && _amount > 0
        && balances[_to] + _amount > balances[_to]) {
            // @audit - Safely subtracts the amount being transferred from _from's balance
            balances[_from] = balances[_from].sub(_amount);
            // @audit - Safely subtracts the amount being transferred from the sender's allowance 
            allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
            // @audit - Safely adds the amount being transferred to the recipient's balance
            balances[_to] = balances[_to].add(_amount);
            // @audit - Emit a Transfer event
            emit Transfer(_from, _to, _amount);
            return true;
        } else {
            return false;
        }
    }

    // @audit - Allows anyone to approve a spender to spend a specified amount on their behalf 
    // @param - _spender: The address that is being approved to spend 
    // @param - _amount: The new allowance of the spender 
    // @returns - bool: The success of the approval. Always returns true
    function approve(address _spender, uint _amount) public returns (bool) {
        // @audit - Set the approval of _spender to _amount 
        allowed[msg.sender][_spender] = _amount;
        // @audit - Emit an Approval event
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    // @audit - Allows anyone to view the allowance of a spender on the behalf of an owner
    // @param - _owner: The address giving the allowance 
    // @param - _spender: The address recieving the allowance  
    // @returns - uint: The allowance of the spender approved by the owner 
    function allowance(address _owner, address _spender) public view returns (uint) {
       return allowed[_owner][_spender]; 
    }
}
