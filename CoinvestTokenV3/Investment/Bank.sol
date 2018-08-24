pragma solidity ^0.4.23;
import './Ownable.sol';
import './ERC20Interface.sol';

// @audit - Inherits from the Ownable contract
contract Bank is Ownable {

    // @audit - The investment contract address of this bank 
    address public investmentAddr;      
    // @audit - The Coinvest token contract of this bank
    address public coinToken;           
    // @audit - The Cash token contract of this bank
    address public cashToken;          

    // @audit - Constructor: Sets the coinToken, cashToken, owner, and coinvest wallet addresses 
    // @param - _coinToken: The coinvest token address    
    // @param - _cashToken:  The cash token address
    function Bank(address _coinToken, address _cashToken)
      public
    {
        coinToken = _coinToken;
        cashToken = _cashToken;
    }

/** ****************************** Only Investment ****************************** **/
    
    // @audit - Transfers either CASH tokens or Coinvest tokens to a specified address 
    // @param - _to: The recipient of the transfer 
    // @param - _value: The amount of tokens to transfer
    // @param - _isCoin: A boolean representing whether the tokens to transfer are Coinvest Tokens
    // @returns - success: Returns true if the transaction succeeds
    function transfer(address _to, uint256 _value, bool _isCoin)
      external
    returns (bool success)
    {
        // @audit - Ensure that the sender is the Investment contract address
        require(msg.sender == investmentAddr);

        // @audit - Initialize a token contract with the coinToken address or the cashToken address, depending on the _isCoin value
        ERC20Interface token;
        if (_isCoin) token = ERC20Interface(coinToken);
        else token = ERC20Interface(cashToken);

        // @audit - Call the token's transfer function and ensure that the call succeeds
        require(token.transfer(_to, _value));
        return true;
    }
    
/** ******************************* Only Owner ********************************** **/
    
    // @audit - Changes the investment address to a new address
    // @param - _newInvestment:
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of this contract
    function changeInvestment(address _newInvestment)
      external
      onlyOwner
    {
        // @audit - Ensure that the new investment address is not address zero
        require(_newInvestment != address(0));
        investmentAddr = _newInvestment;
    }
    
/** ****************************** Only Coinvest ******************************* **/

    // @audit - Transfers stuck tokens to the coinvest wallet
    // @param - _tokenContract: The token contract with stuck tokens
    // @audit - MODIFIER onlyCoinvest: Restricts access to the coinvest wallet of this contract
    function tokenEscape(address _tokenContract)
      external
      onlyCoinvest
    {
        // @audit - Ensure that the token contract is not coinToken or cashToken 
        require(_tokenContract != coinToken && _tokenContract != cashToken);
        // @audit - If the token contract is address zero, transfer this contract's balance to the coinvest wallet 
        if (_tokenContract == address(0)) coinvest.transfer(address(this).balance);
        else {
            // @audit - Initialize an ERC20 instance with the token contract address
            ERC20Interface lostToken = ERC20Interface(_tokenContract);
            // @audit - Retrieve the amount of stuck tokens 
            uint256 stuckTokens = lostToken.balanceOf(address(this));
            // @audit - Transfer the stuck tokens to the coinvest wallet
            lostToken.transfer(coinvest, stuckTokens);
        }    
    }

}
