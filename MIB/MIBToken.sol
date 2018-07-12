pragma solidity ^0.4.24;

contract DMIBLog {
    // @audit - Event: An anonymous event that is emitted to signal the use of a function (ex. "stop" and "start" below) 
    event MIBLog(bytes4 indexed sig, address indexed sender, uint _value) anonymous;

    // @audit - Modifier that emits a MIBLog event and then proceeds with execution
    modifier mlog {
        emit MIBLog(msg.sig, msg.sender, msg.value);
        _;
    }
}


contract Ownable {
    // @audit - The owner of the contract -- has access to admin level functionality
    address public owner;

    // @audit - Event: Emitted when there is a change in ownership 
    event OwnerLog(address indexed previousOwner, address indexed newOwner, bytes4 sig);

    // @audit - Constructor: Sets the sender as the owner
    constructor() public { 
        owner = msg.sender; 
    }

    // @audit - Restricts access to just the owner
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    // @audit - Allows the current owner to transfer ownership to a new address 
    // @param - newOwner: The replacement owner address
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of this contract 
    function transferOwnership(address newOwner) onlyOwner  public {
        // @audit - Ensure that the new owner is not address zero
        require(newOwner != address(0));
        // @audit - Emit an owner log event
        emit OwnerLog(owner, newOwner, msg.sig);
        // @audit - Update the owner
        owner = newOwner;
    }
}

// @audit - This contract is Ownable and DMIBLog
contract MIBStop is Ownable, DMIBLog {

    // @audit - Boolean value representing whether or not the app is stopped
    bool public stopped;

    // @audit - Restricts access to the case when the application is not stopped
    modifier stoppable {
        require (!stopped);
        _;
    }

    // @audit - Allows the owner update the "stopped" variable to true and emits an MIBLog event 
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of this contract 
    // @audit - MODIFIER mlog: Emits an anonymous MIBLog event
    function stop() onlyOwner mlog public {
        stopped = true;
    }

    // @audit - Allows the owner update the "stopped" variable to false and emits an MIBLog event 
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of this contract 
    // @audit - MODIFIER mlog: Emits an anonymous MIBLog event
    function start() onlyOwner mlog public {
        stopped = false;
    }
}

// @audit - A normal SafeMath library
library SafeMath {
    
    // @audit - A safe multiplication function -- fails on overflows
    // @param - a: The first number to multiply 
    // @param - b: The second number to multiply 
    // @returns - The product of "a" and "b"  
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // @audit - If "a" equals 0, return 0
        if (a == 0) {
          return 0;
        }

        // @audit - Set "c" to the product of "a" and "b"
        c = a * b;
        // @audit - Assert that "c" divided by "a" equals "b" -- This will be the case if there was not an overflow
        assert(c / a == b);
        // @audit - Return the product
        return c;
    }

    // @audit - A safe division function -- fails if the dividend is zero 
    // @param - a: The numerator
    // @param - b: The divisor 
    // @returns - The quotient of "a" and "b"
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // @audit - Normal division reverts if the dividend is zero 
        return a / b;
    }

    // @audit - A safe subtraction function -- fails on underflows
    // @param - a: The number being subtracted from 
    // @param - b: The number being subtracted by 
    // @returns - The difference of "a" and "b"
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        // @audit - Ensure that "b" is less than or equal to "a"
        assert(b <= a);
        // @audit - Return the difference
        return a - b;
    }

    // @audit - A safe addition function -- fails on overflows
    // @param - a: The first number to add 
    // @param - b: The second number to add 
    // @returns - The sum of "a" and "b"
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        // @audit - Ensure that the sum is greater than "a"
        assert(c >= a);
        return c;
    }
}

// @audit - A base contract for a basic ERC20 -- Is not ERC20 compliant
contract ERC20Basic {
    // @audit - A getter for the total supply of tokens 
    function totalSupply() public view returns (uint256);
    // @audit - A getter for the balance of a specified address
    function balanceOf(address who) public view returns (uint256);
    // @audit - Transfers funds from the sender to the recipient
    // @param - to: The recipient of the transfer 
    // @param - value: The value to be sent to the recipient 
    // @returns - The success of the transaction 
    function transfer(address to, uint256 value) public returns (bool);
    // @audit - Event: Emitted when a transfer occurs
    event Transfer(address indexed from, address indexed to, uint256 value);
}

// @audit - An expanded ERC20Basic contract
contract ERC20 is ERC20Basic {
    // @audit - A getter for the allowance of a spender from an owner 
    function allowance(address owner, address spender) public view returns (uint256);
    // @audit - Approves a spender on behalf of the sender to spend funds of the sender's behalf 
    // @param - spender: The address being granted access to the sender's funds 
    // @param - value: The amount to approve the spender by 
    // @returns - The success of the approval
    function approve(address spender, uint256 value) public returns (bool);
    // @audit - Transfers funds on behalf of an owner address to a recipient 
    // @param - from: The owner address of the funds 
    // @param - to: The recipient address of the transfer 
    // @param - value: The value to be sent to the recipient 
    // @returns - The success of the transaction 
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    // @audit - Event: Emitted when an approve transaction occurs
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract MIBToken is ERC20, MIBStop {
    // @audit - The total supply of tokens in the lowest denomination
    uint256 public _totalsupply;
    // @audit - The name of this token
    string public tokenName = "Mobile Integrated Blockchain";
    // @audit - The symbol of this token
    string public symbol = "MIB";
    // @audit - The decimals of this token
    uint public decimals = 18;
    // @audit - Attaches the SafeMath library to unsigned integers
    using SafeMath for uint256;

    // @audit - A mapping from address to their balance
    mapping(address => uint256) public balances;
    // @audit - A mapping from an owner to a spender to their allowance 
    mapping (address => mapping (address => uint256)) public allowed;    

    // @audit - Event: Emitted when tokens are burned 
    event Burn(address indexed from, uint256 value);  

    // @audit - Constructor: Sets the total supply, increments the sender's balance, and sets the sender as the owner
    // @param - _totsupply: The total supply of tokens to create 
    constructor (uint256 _totsupply) public {
        // @audit - Sets the total supply equal to the safe multiplication of the specified "total supply" by 10^18.
        // @audit - This total supply represents the total supply of the smallest fractions of a MIBToken 
		    _totalsupply = _totsupply.mul(1e18);
        // @audit - Safely add the newly calculated total supply to the sender's balance 
        balances[msg.sender] = balances[msg.sender].add(_totalsupply);
    }
    
    // @audit - A fallback function that reverts when called -- prevents ether from being sent to the fallback function 
    function () external payable {
        revert();
    }
    
    // @audit - Returns the total supply of the smallest denomination of the token 
    function totalSupply() public view returns (uint256) {
        return _totalsupply;
    }
    
    // @audit - Returns the balance of a specified address
    function balanceOf(address who) public view returns (uint256) {
        return balances[who];
    }

    // @audit - Transfers funds from the sender to the recipient
    // @param - to: The recipient of the transfer 
    // @param - value: The value to be sent to the recipient 
    // @returns - The success of the transaction 
    // @audit - MODIFIER stoppable: Only accessible when the application is not stopped
    function transfer(address to, uint256 value) stoppable public returns (bool) {
        // @audit - Ensure that the recipient is not address zero
        require(to != address(0));
        // @audit - Ensure that value is nonzero
        require(0 < value);
        // @audit - Ensure that the recipient's balance will be greater than 0 after adding value
        require(0 < balances[to].add(value));
        // @audit - Ensure that the sender's balance subtracted by value is greater than 0 
        require(0 < balances[msg.sender].sub(value));

        // @audit - Safely add "value" to the recipient's balance
        balances[to] = balances[to].add(value);
        // @audit - Safely subtract "value" from the sender's balance
        balances[msg.sender] = balances[msg.sender].sub(value);
        
        // @audit - Emit a transfer event
        emit Transfer(msg.sender, to, value);

        // @audit - Return true to signal a successful call
        return true;
    }
    
    // @audit - NOTE: This is subject to the ERC20 racing condition
    // @audit - Transfers funds on the behalf an owner to a recipient 
    // @param - from: The owner of the funds 
    // @param - to: The recipient of the transfer 
    // @param - value: The value to be sent 
    // @returns - The success of the transaction
    // @audit - MODIFIER stoppable: Only accessible when the application is not stopped
    function transferFrom(address from, address to, uint256 value) stoppable public returns (bool) {
        // @audit - Ensure that the recipient is not address zero
        require(to != address(0));
        // @audit - Ensure that the value is less than or equal to the owner's balance
        require(value <= balances[from]);
        // @audit - Ensure that the sender's allowance is greater than or equal to the value
        require(value <= allowed[from][msg.sender]);
    
        // @audit - Safely subtract "value" from the owner's balance
        balances[from] = balances[from].sub(value);
        // @audit - Safely add "value" to the recipient's balance
        balances[to] = balances[to].add(value);
        // @audit - Safely subtract "value" from the sender's allowance from the owner
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
        // @audit - Emit a transfer event
        emit Transfer(from, to, value);
        // @audit - Return true
        return true;
    }
      
    // @audit - NOTE: This is subject to an ERC20 racing condition
    // @audit - Approves a spender on behalf of the sender to spend funds of the sender's behalf 
    // @param - spender: The address being granted access to the sender's funds 
    // @param - value: The amount to approve the spender by 
    // @returns - The success of the approval
    // @audit - MODIFIER stoppable: Only accessible when the application is not stopped
    function approve(address spender, uint256 value) stoppable public returns (bool success) {
        // @audit - Set the spender's allowance on behalf of the sender to "value"
        allowed[msg.sender][spender] = value;
        // @audit - Emit an Approval event
        emit Approval(msg.sender, spender, value);
        // @audit - Return true
        return true;        
    }
    
    // @audit - A getter for the allowance of a spender on behalf of an owner 
    // @param - owner: The owner of the funds 
    // @param - spender: The address with access to spend some of the owner's funds 
    // @returns - The allowance of the spender on behalf of the owner
    function allowance(address owner, address spender) public view returns (uint256) {
        return allowed[owner][spender];
    }
    
    // @audit - Allows sender to burn some of their tokens (lower their balance) 
    // @param - value: The amount of token's (in the lowest denomination) to burn
    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }
    
    // @audit - An internal function that burns some of an address's balance
    // @param - who: The owner of the funds to burn  
    // @param - value: The amount of the balance to burn 
    function _burn(address who, uint256 value) internal {
        // @audit - Ensure that the owner's balance is greater than or equal to "value"
        require(value <= balances[who]);
        // @audit - Safely subtract value from the owner's balance
        balances[who] = balances[who].sub(value);
        // @audit - Emit a Burn event
        emit Burn(who, value);
        // @audit - Emit a transfer event
        emit Transfer(who, address(0), value);
    }

    // @audit - Allows the owner of the contract to burn an owner's tokens and transfer them back to the owner
    // @param - who: The owner address of the funds  
    // @param - value: The value of funds to burn 
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of this contract 
    function burnFrom(address who, uint256 value) public onlyOwner payable returns (bool success) {
        // @audit - Ensure that the "who" balance is greater than or equal to "value"
        require(balances[who] >= value);

        // @audit - Safely subtract "value" from the "who" balance
        balances[who] = balances[who].sub(value);
        // @audit - Safely add "value" to the sender's balance
        balances[msg.sender] = balances[msg.sender].add(value);

        // @audit - Emit a burn event 
        emit Burn(who, value);
        return true;
    }

}
