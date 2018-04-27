import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/token/StandardToken.sol';

contract LockableToken is StandardToken, Ownable {
    bool public isLocked = true;
    mapping (address => uint256) public lastMovement;
    event Burn(address _owner, uint256 _amount);

    //@audit - NOTE: Recommend a "notLocked" modifier, as 'require(!isLocked)' is used 3 times
    /*

    modifier notLocked() {
      require(!isLocked);
      _;
    }

    */

    //@audit - LOW: Crowdsale can start with an unlocked token, because creator of the ERT token can call unlock, then hand ownership over to the crowdsale
    //ISSUE FIXED IN COMMIT: 3e1765a
    function unlock() public onlyOwner {
        isLocked = false;
    }

    //@audit - CRITICAL: transferFrom should set the lastMovement of _from instead of msg.sender, because lastMovement is meant to keep tokens from being used to vote multiple times after transfers. This could allow
    //                   a user to approve tokens for another address, use that address to send tokens to a third address using transferFrom, and then use the third address to vote again because lastMovement was never set.
    //                   Both transfer and transferFrom should also set lastMovement for the _to address, or the _to address can be used to vote with the freshly transferred tokens
    //ISSUE FIXED IN COMMIT: 7c2c2f4
    //@audit - allows a user to send tokens to another address
    function transfer(address _to, uint256 _amount) public returns (bool) {
        require(!isLocked);
        lastMovement[msg.sender] = getTime(); //@audit - lastMovement[msg.sender] = now;
        return super.transfer(_to, _amount); //@audit - refers to StandardToken
    }

    //@audit - standard ERC20 transferFrom function, but sets the sender's lastMovement to now
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(!isLocked);
        lastMovement[msg.sender] = getTime(); //@audit - lastMovement[msg.sender] = now;
        super.transferFrom(_from, _to, _value); //@audit - refers to StandardToken
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(!isLocked);
        super.approve(_spender, _value); //@audit - refers to StandardToken
    }

    //@audit - LOW: The treasury calls this function when refunds are enabled, but the treasury is never 'allowed' by the _from address explicity. If a refund is enabled, this would require
    //              all users that want a refund to manually approve the treasury to refund the user.
    //              Suggested fix: Remove the 'allowed' check, and only allow this function to be accessed by the treasury contract
    //@audit - allows a user to burn tokens on behalf of another user, provided they are allowed to do so
    function burnFrom(address _from, uint256 _value) public  returns (bool) {
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        totalSupply = totalSupply.sub(_value);
        Burn(_from, _value);
        return true;
    }

    function getTime() internal returns (uint256) {
        // Just returns `now` value
        // This function is redefined in EthearnalRepTokenCrowdsaleMock contract
        // to allow testing contract behaviour at different time moments
        return now;
    }

}
