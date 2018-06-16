pragma solidity ^0.4.21;

import "./libraries/DRCTLibrary.sol";

contract DRCT_Token {

    //@audit - allows TokenStorage struct to use methods from DRCTLibrary
    using DRCTLibrary for DRCTLibrary.TokenStorage;

    //@audit - declares public TokenStorage struct 
    DRCTLibrary.TokenStorage public drct;

    //@audit - basic constructor that sets up token under a specific factory contract 
    constructor(address _factory) public {
        drct.startToken(_factory);
    }

    //@audit - creates a token with the specified supply and owner for the specified swap 
    function createToken(uint _supply, address _owner, address _swap) public{
        drct.createToken(_supply,_owner,_swap);
    }

    //@audit - This function pays out _party for the number of tokens they hold in swap 
    function pay(address _party, address _swap) public{
        drct.pay(_party,_swap);
    }

    //@audit - returns the balance of _owner for a specific token 
    function balanceOf(address _owner) public constant returns (uint balance) {
       return drct.balanceOf(_owner);
     }

     //@audit - returns the total supply for the token 
    function totalSupply() public constant returns (uint _total_supply) {
       return drct.totalSupply();
    }

    //@audit - transfer's _amount from msg.sender to _to
    function transfer(address _to, uint _amount) public returns (bool) {
        return drct.transfer(_to,_amount);
    }

    //@audit - msg.sender transfer's _amount to user _to on user _from's behalf 
    function transferFrom(address _from, address _to, uint _amount) public returns (bool) {
        return drct.transferFrom(_from,_to,_amount);
    }

    //@audit - approve's spender to spend _amount on msg.sender's behalf 
    function approve(address _spender, uint _amount) public returns (bool) {
        return drct.approve(_spender,_amount);
    }

    //@audit - returns the number of addresses involved in _swap 
    function addressCount(address _swap) public constant returns (uint) { 
        return drct.addressCount(_swap); 
    }

    //@audit - returns the balance and holder of a balance struct at index _ind of _swap's entry swap_balances mapping 
    function getBalanceAndHolderByIndex(uint _ind, address _swap) public constant returns (uint, address) {
        return drct.getBalanceAndHolderByIndex(_ind,_swap);
    }

    //@audit - returns the index of _owner in _swap's entry in the swap_balances mapping  
    function getIndexByAddress(address _owner, address _swap) public constant returns (uint) {
        return drct.getIndexByAddress(_owner,_swap); 
    }

    //@audit - returns the amount that _spender can spend on _owner's behalf 
    function allowance(address _owner, address _spender) public constant returns (uint) {
        return drct.allowance(_owner,_spender); 
    }
}
