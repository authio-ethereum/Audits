pragma solidity ^0.4.23;
import './Ownable.sol';
import './ERC20Interface.sol';
import './SafeMathLib.sol';

// @audit - Inherits from the Ownable contract
contract UserData is Ownable {
    using SafeMathLib for uint256;

    address public investmentAddress;

    mapping (address => mapping (uint256 => uint256)) public userHoldings;

    constructor(address _investmentAddress) 
      public
    {
        investmentAddress = _investmentAddress;
    }
    
    function modifyHoldings(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool _buy)
      external
    returns (bool success)
    {
        require(msg.sender == investmentAddress);
        require(_cryptoIds.length == _amounts.length);
        
        for (uint256 i = 0; i < _cryptoIds.length; i++) {
            if (_buy) {
                userHoldings[_beneficiary][_cryptoIds[i]] = userHoldings[_beneficiary][_cryptoIds[i]].add(_amounts[i]);
            } else {
                userHoldings[_beneficiary][_cryptoIds[i]] = userHoldings[_beneficiary][_cryptoIds[i]].sub(_amounts[i]);
            }
        }
        
        return true;
    }

/** ************************** Constants *********************************** **/
    
    function returnHoldings(address _beneficiary, uint256 _start, uint256 _end)
      external
      view
    returns (uint256[])
    {
        uint256[] memory holdings = new uint256[](_end.sub(_start)+1); 
        for (uint256 i = _start; i <= _end; i++) {
            holdings[i] = userHoldings[_beneficiary][i];
        }
        return holdings;
    }
    
/** ************************** Only Owner ********************************** **/
    
    function changeInvestment(address _newAddress)
      external
      onlyOwner
    returns (bool success)
    {
        investmentAddress = _newAddress;
        return true;
    }

    
/** ************************** Only Coinvest ******************************* **/
    
    // @audit - 
    // @param - 
    // @audit - MODIFIER onlyCoinvest:
    function tokenEscape(address _tokenContract)
      external
      onlyCoinvest
    {
        if (_tokenContract == address(0)) coinvest.transfer(address(this).balance);
        else {
            ERC20Interface lostToken = ERC20Interface(_tokenContract);
        
            uint256 stuckTokens = lostToken.balanceOf(address(this));
            lostToken.transfer(coinvest, stuckTokens);
        }    
    }
    
}
