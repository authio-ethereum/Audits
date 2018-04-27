//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
import './StandardToken.sol';
import '../ownership/Ownable.sol';

//@audit - Extends StandardToken to allow for token minting
contract MintableToken is StandardToken, Ownable {
  //@audit - Events
  event Mint(address indexed to, uint256 amount);
  event MintFinished();

  //@audit - Whether minting is finished or not
  bool public mintingFinished = false;

  //@audit - modifier: Only passes if mintingFinished is false
  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  //@audit - The token mint function
  //@param - "_to": The address which will recieve minted tokens
  //@param - "_amount": The amount of tokens to mint
  //@returns - "bool": Whether the function succeeded in minting tokens
  //@audit - MODIFIER onlyOwner(): Only the contract owner can mint tokens (uses Ownable)
  //@audit - MODIFIER canMint(): Function only passes when mintingFinished is false
  function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
    //@audit - Safe-add to the total supply
    totalSupply = totalSupply.add(_amount);
    //@audit - Safe-add to the balance of the recipient
    balances[_to] = balances[_to].add(_amount);
    //@audit - Mint and Transfer events
    Mint(_to, _amount);
    Transfer(address(0), _to, _amount);
    //@audit - Return true
    return true;
  }

  //@audit - Called to finish all minting
  //@returns - "bool": Whether the function succeeded
  //@audit - MODIFIER onlyOwner(): Only the contract owner can mint tokens (uses Ownable)
  //@audit - MODIFIER canMint(): Function only passes when mintingFinished is false
  function finishMinting() onlyOwner canMint public returns (bool) {
    //@audit - Set mintingFinished to true
    mintingFinished = true;
    //@audit - event
    MintFinished();
    //@audit - Return true
    return true;
  }
}
