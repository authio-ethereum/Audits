pragma solidity ^0.4.18;

// @audit - An ERC20 Interface 
contract ERC20Interface {
    // @audit - A getter for the total supply of a token contract
    // @returns - The total supply of tokens in the contract
    function totalSupply() public view returns (uint);
    // @audit - A getter for the balance of a token owner
    // @param - tokenOwner: The owner address
    // @returns - balance: The balance of the token owner
    function balanceOf(address tokenOwner) public view returns (uint balance);
    // @audit - A getter for a spender's allowance on behalf of a token owner
    // @param - tokenOwner: The owner address
    // @param - spender: The spender address
    // @returns - remaining: The remaining allowance of the spender on behalf of the owner
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);
    // @audit - Transfers tokens from the sender to a recipient
    // @param - to: The recipient address of the transfer
    // @param - tokens: The amount of tokens to transfer
    // @returns - success: The success of the transfer
    function transfer(address to, uint tokens) public returns (bool success);
    // @audit - Approve a spender on behalf of the sender for a specified amount
    // @param - _spender: The address being approved to spend CASH tokens on behalf of the sender
    // @param - _amount: The specified amount to approve the sender 
    // @returns - bool: Returns true if the transaction succeeds
    function approve(address spender, uint tokens) public returns (bool success);
    // @audit - Transfers a specified amount of tokens to a recipient on behalf of the owner of the tokens
    // @param - _from: The owner of the tokens
    // @param - _to: The recipient of the tokens
    // @param - _amount: The amount of tokens to transfer
    // @returns - bool: Returns true if the transaction succeeds
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    // @audit - Event: Emitted when a token transfer occurs.
    event Transfer(address indexed from, address indexed to, uint tokens);
    // @audit - Event: Emitted when a change in approval occurs.
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract TestApproveAndCallFallBack {
    // @audit - Event: Emitted to log bytes
    event LogBytes(bytes data);

    // @audit - Function that makes this token meet the ApproveAndCallback interface
    // @param - _from: The address that sent the approval call 
    // @param - _amount: The amount to that the account was approved with
    // @param - _token: The token contract 
    // @param - _data: The calldata provided 
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public {
        // @audit - Transfer from with the provided data
        ERC20Interface(token).transferFrom(from, address(this), tokens);
        // @audit - Emit a LogBytes event with the provided data
        LogBytes(data);
    }
}

