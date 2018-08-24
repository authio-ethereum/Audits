pragma solidity ^0.4.23;
import './Ownable.sol'; //@ Audit - Imports ownable
import './ERC20Interface.sol'; //@ Audit - Imports an ERC20 interface
import './SafeMathLib.sol'; //@ Audit - Imports safe math

contract UserData is Ownable { //@ Audit - This contract is ownable so its constructor will set an owner
    using SafeMathLib for uint256; //@ Audit - We use SafeMath for uints

    address public investmentAddress; //@ Audit - State varible for the invement contract attached to this user

    // Address => crypto Id => amount of crypto wei held
    mapping (address => mapping (uint256 => uint256)) public userHoldings; //@ Audit - Maps address to the  crypto idenfier set in investment to balance of the holder of that cryptocurency

    constructor(address _investmentAddress)
      public
    {
        investmentAddress = _investmentAddress; //@ Audit -This constructor sets the investment address to the provided address
    }

    //@ Audit - The investment contract spesified can call this to modify the holdings of a user
    //@ Params - _beneficiary the address that has its holdings modified, _cryptoIds the ids of the cryptos bought or sold,
    //@ Params - _amounts the amounts of crypto to buy or sell, _buy true if this is a buy or false if it is a sell
    //@ Return - Returns whether the call succeded
    function modifyHoldings(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool _buy)
      external
    returns (bool success)
    {
        require(msg.sender == investmentAddress); //@ Audit -If someone who is not the investment contract calls this we revert
        require(_cryptoIds.length == _amounts.length); //@ Audit -If the submited data is malformed revert

        for (uint256 i = 0; i < _cryptoIds.length; i++) { //@ Audit -For each of the traded cryptos
            if (_buy) { //@ Audit - Checks if we are buying crypto
                userHoldings[_beneficiary][_cryptoIds[i]] = userHoldings[_beneficiary][_cryptoIds[i]].add(_amounts[i]);
                //@ Audit - If we are buying crypto we increase the _beneficiary address's holdings of the crypto by the amount given
            } else { //@ Audit - or selling
                userHoldings[_beneficiary][_cryptoIds[i]] = userHoldings[_beneficiary][_cryptoIds[i]].sub(_amounts[i]);
                //@ Audit - If we are selling crypto we reduce the holdings of the beneficiary address for the crypto id by the amount provided
            }
        }

        return true; //@ Audit - We return that the call has succeded
    }

/** ************************** Constants *********************************** **/

    //@ Audit - Checks the balance of the a provided address for all cryptos between ids _start and _end
    //@ Params - _beneficiary the holder to check, _start the first crypto id to check, _end the last crypto id to check
    //@ Return - returns a dynamic array of crypto balances starting at crypto id _start ending at _end
    function returnHoldings(address _beneficiary, uint256 _start, uint256 _end)
      external
      view
    returns (uint256[])
    {
        uint256[] memory holdings = new uint256[](_end.sub(_start)+1); //@ Audit - Declares a new memory array of size end-start + 1
        for (uint256 i = _start; i <= _end; i++) { //@ Audit - This loop is broken since i = start it will access data outside the array in some cases
            holdings[i] = userHoldings[_beneficiary][i]; //@ Audit - Say that we wanted to know the value of crypto ids 5-7 this would set holdings[5] but holdings is only length 3
        } //@ Audit - Fix this by subtracting start from i holdings[i-start] = ... or start i at zero and go till end-start
        return holdings; //@ Audit - Returns the created array
    }

/** ************************** Only Owner ********************************** **/

    //@ Audit - Changes the investment contract address state varible
    //@ Param - _newAddress The address to change too
    //@ Return - returns whether this succeded
    //@ Modifer - onlyOwner inherited from ownable reverts if msg.sender != owner
    function changeInvestment(address _newAddress)
      external
      onlyOwner
    returns (bool success)
    {
        investmentAddress = _newAddress; //@ Audit - Resets the state varible
        return true; //@ Audit - Returns that this succeded
    }


/** ************************** Only Coinvest ******************************* **/

    //@ Audit - A function allowing coinvest to take tokens or ether from this address
    //@ Param - _tokenContract the token that coinvest wants to take, set to zero to take ether
    //@ Modifer - onlyCoinvest modifer inherited from ownable which reverts if msg.sender != coinvest
    function tokenEscape(address _tokenContract)
      external
      onlyCoinvest
    {
        if (_tokenContract == address(0)) coinvest.transfer(address(this).balance); //@ Audit - If the token address is zero we send the coinvest address the balance of this contract
        else { //@ Audit - Otherwise we need to move tokens
            ERC20Interface lostToken = ERC20Interface(_tokenContract);
            //@ Audit - Labels the _tokenContract address as a ERC20 contract

            uint256 stuckTokens = lostToken.balanceOf(address(this));
            //@ Audit - Calculates the tokens held by this contract by calling balanceOf for the token contract on the address of this contract
            lostToken.transfer(coinvest, stuckTokens);
            //@ Audit - Calls transfer to move the tokens from this address to coinvest's address
        }
    }
}
