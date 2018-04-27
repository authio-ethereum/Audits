//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.11;

//@audit - Sol import
import './MintableToken.sol';

//@audit - Implements a token with a maximum cap on total supply, which is checked when minting
contract CappedToken is MintableToken {

  //@audit - The uint maximum number of tokens that should exist
  uint256 public cap;

  //@audit - Constructor: Sets the token cap
  //@param - "_cap": The maximum number of tokens that can exist
  function CappedToken(uint256 _cap) public {
    //@audit - Ensure the cap is valid, then set it
    require(_cap > 0);
    cap = _cap;
  }

  //@audit - Extends MintableToken.mint, to check token cap when minting
  //@param - "_to": The address that will recieve the minted tokens
  //@param - "_amount": The number of tokens to mint
  //@returns - "bool": Whether the function succeeded
  //@audit - MODIFIER onlyOwner(): Only the token contract owner can mint tokens (uses Ownable)
  //@audit - MODIFIER canMint(): Minting can only occur when mintingFinished is false (uses MintableToken)
  function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
    //@audit - Ensure the new minted amount does not exceed the cap
    require(totalSupply.add(_amount) <= cap);

    //@audit - Call MintableToken.mint
    return super.mint(_to, _amount);
  }

}
