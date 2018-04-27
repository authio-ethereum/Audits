//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
import './zeppelin/token/CappedToken.sol';
import './zeppelin/token/PausableToken.sol';

//@audit - Blockport token contract - Uses OpenZeppelin's CappedToken and PausableToken
contract BlockportToken is CappedToken, PausableToken {

    //@audit - Token name
    string public constant name                 = "Blockport Token";
    //@audit - Token ticker symbol
    string public constant symbol               = "BPT";
    //@audit - Token decimals
    uint public constant decimals               = 18;

    //@audit - Constructor - Sets totalSupply via CappedToken, and sets paused
    //@param - "_totalSupply": The total supply of BPT tokens
    function BlockportToken(uint256 _totalSupply)
        CappedToken(_totalSupply) public {
            paused = true;
    }
}
