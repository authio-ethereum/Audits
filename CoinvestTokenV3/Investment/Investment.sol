pragma solidity ^0.4.23;

import './SafeMathLib.sol';
import './Ownable.sol';
import './Strings.sol';
import './UserData.sol';
import './Bank.sol';
import './ERC20Interface.sol';
// @audit - This may be the wrong URL: This file is not a solidity contract 
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

// @audit - Inherits from Ownable and usingOraclize
contract Investment is Ownable, usingOraclize { 

    // @audit - Attaches SafeMathLib to uint256
    using SafeMathLib for uint256;
    // @audit - Attaches strings to all types
    using strings for *;
    
    // @audit - The Bank contract of this contract
    Bank public bank;
    // @audit - The UserData contract of this contract
    UserData public userData;
    // @audit - The coinToken of this contract
    address public coinToken;
    // @audit - The cashToken of this contract
    address public cashToken;
    // @audit - The custom gas price of this contract
    uint256 public customGasPrice;
    
    // @audit - A struct representing trades
    struct TradeInfo {
        uint256[] idsAndAmts;
        address beneficiary;
        bool isBuy;
        bool isCoin;
    }
    
    // @audit - A mapping from oracle query ids to the trade that they initialized 
    mapping(bytes32 => TradeInfo) trades;
    // @audit - A mapping from cryptocurrency ids to their symbols
    mapping(uint256 => string) public cryptoSymbols;
    // @audit - A mapping from cryptocurrency ids to their tied inverse 
    mapping(uint256 => uint256) public tiedInverse;
    // @audit - Mapping from a cryptocurrency id to a boolean reflecting whether or not the currency is an inverse 
    mapping (uint256 => bool) public isInverse;
    // @audit - Mapping from a beneficiary 
    mapping(address => uint256) public freeTrades;

    // @audit - Event: Emitted when the oracle is queried 
    event newOraclizeQuery(string description);
    // @audit - Event: Emitted when a purchase occurs
    event Buy(address indexed buyer, uint256[] cryptoIds, uint256[] amounts, uint256[] prices, bool isCoin);
    // @audit - Event: Emitted when a sale occurs
    event Sell(address indexed seller, uint256[] cryptoIds, uint256[] amounts, uint256[] prices, bool isCoin);

/** ********************************** Defaults ************************************* **/
    
    // @audit - Constructor: Sets many public variables, as well as the owner and coinvest wallet addresses
    // @param - _coinToken: The Coinvest token contract
    // @param - _cashToken: The Cash token contract
    // @param - _bank: The bank contract
    // @param - _userData: The user data contract
    constructor(address _coinToken, address _cashToken, address _bank, address _userData)
      public
      payable
    {
        coinToken = _coinToken;
        cashToken = _cashToken;
        bank = Bank(_bank);
        userData = UserData(_userData);

        // @audit - Set the Oracalize proof type 
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        

        // @audit - Add all of the supported currencies twice -- once as there own inverse and once normally
        addCrypto(1, "BTC,", 11, false);
        addCrypto(2, "ETH,", 12, false);
        addCrypto(3, "XRP,", 13, false);
        addCrypto(4, "LTC,", 14, false);
        addCrypto(5, "DASH,", 15, false);
        addCrypto(6, "BCH,", 16, false);
        addCrypto(7, "XMR,", 17, false);
        addCrypto(8, "XEM,", 18, false);
        addCrypto(9, "EOS,", 19, false);
        addCrypto(10, "COIN,", 20, false);
        addCrypto(11, "BTC,", 1, true);
        addCrypto(12, "ETH,", 2, true);
        addCrypto(13, "XRP,", 3, true);
        addCrypto(14, "LTC,", 4, true);
        addCrypto(15, "DASH,", 5, true);
        addCrypto(16, "BCH,", 6, true);
        addCrypto(17, "XMR,", 7, true);
        addCrypto(18, "XEM,", 8, true);
        addCrypto(19, "EOS,", 9, true);
        addCrypto(20, "COIN,", 10, true);
        addCrypto(21, "CASH,", 22, false);
        addCrypto(22, "CASH,", 21, true);

        // @audit - Set the oracle's custom gas price
        customGasPrice = 20000000000;
        oraclize_setCustomGasPrice(customGasPrice);
    }
  
    // @audit - An empty fallback function
    function()
      external
      payable
    {
        
    }
  
/** *************************** ApproveAndCall FallBack **************************** **/
  
  // @audit - The ApproveAndCall endpoint for this contract
  // @param - _from: The address where the approval is coming from 
  // @param - _amount: The amount of value to be approved
  // @param - _token: The token address 
  // @param - _data: The provided calldata
    function receiveApproval(address _from, uint256 _amount, address _token, bytes _data) 
      public
    {
        // @audit - Ensure that the sender is either the coinToken or cashToken contract
        require(msg.sender == coinToken || msg.sender == cashToken);
        
        address beneficiary;
        // @audit - Load the beneficiary's address from the first slot of _data (right after the function selector)
        assembly {
            beneficiary := mload(add(_data,36))
        }
        // @audit - Ensure that the _from address is the beneficiary -- since the caller is cashToken or coinToken, _from is the address that called the token
        require(_from == beneficiary);
        
        // @audit - DelegateCall this contract with the provided calldata. 
        require(address(this).delegatecall(_data));
    }
  
/** ********************************** External ************************************* **/
    
    // @audit - _beneficiary: The buyer or seller of the transaction
    // @param - _cryptoIds: An array of cryptocurrency ids
    // @param - _amounts: An array of amounts of cryptocurrencies
    // @param - _isCoin: A boolean reflecting whether or not the payment coin is the Cash Token or the Coinvest Token
    // @returns - success: Returns true if the transaction succeeds
    // @audit - MODIFIER onlySenderOrToken: Restricts access to the beneficiary specified or a coin token
    function buy(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool _isCoin)
      public
      onlySenderOrToken(_beneficiary)
    returns (bool success)
    {
        // @audit - Ensure that the _cryptoIds and the _amounts arrays have equal length
        require(_cryptoIds.length == _amounts.length);
        // @audit - Get the current prices of the specified cryptos
        require(getPrices(_beneficiary, _cryptoIds, _amounts, _isCoin, true));
        return true;
    }

    // @audit - _beneficiary: The buyer or seller of the transaction
    // @param - _cryptoIds: An array of cryptocurrency ids
    // @param - _amounts: An array of amounts of cryptocurrencies
    // @param - _isCoin: A boolean reflecting whether or not the payment coin is the Cash Token or the Coinvest Token
    // @returns - success: Returns true if the transaction succeeds
    // @audit - MODIFIER onlySenderOrToken: Restricts access to the beneficiary specified or a coin token
    function sell(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool _isCoin)
      public
      onlySenderOrToken(_beneficiary)
    returns (bool success)
    {
        // @audit - Ensure that the _cryptoIds and _amounts arrays have equal lengths
        require(_cryptoIds.length == _amounts.length);
        // @audit - Ensure that the getPrices call succeeds and initialize the trade info and call the API
        require(getPrices(_beneficiary, _cryptoIds, _amounts, _isCoin, false));
        return true;
    }
    
/** ********************************** Internal ************************************ **/

    // @audit - Finalizes a purchase after the oracle responds
    // @param - _beneficiary: The beneficiary of the transaction
    // @param - _cryptoIds: An array of ids for the cryptocurrencies registered in this contract
    // @param - _amounts: An array of amounts of cryptocurrencies
    // @param - _prices: An array of prices of cryptocurrencies 
    // @param - _coinValue: The value of the coin 
    // @param - _isCoin: A boolean reflecting whether or not the coin is the Coinvest Token 
    // @returns - success: Returns true if the transaction succeeds
    function finalizeBuy(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, uint256[] _prices, uint256 _coinValue, bool _isCoin)
      internal
    returns (bool success)
    {
        ERC20Interface token;
        // @audit - If the coin is the Coinvest Token, get an instance of the CoinVest Token
        if (_isCoin) token = ERC20Interface(coinToken);
        // @audit - Otherwise, get an instance of the Cash Token
        else token = ERC20Interface(cashToken);
        
        // @audit - Calculate the base fee 
        uint256 fee = 4990000000000000000 * (10 ** 18) / _prices[0];
        // @audit - If the beneficiary has free trades, deduct a free trade from the beneficiary
        if (freeTrades[_beneficiary] >  0) freeTrades[_beneficiary] = freeTrades[_beneficiary].sub(1);
        // @audit - Otherwise, transfer the fee from the beneficiary to the coinvest wallet
        else require(token.transferFrom(_beneficiary, coinvest, fee));
        
        // @audit - Transfer the coinValue from the beneficiary to the bank 
        require(token.transferFrom(_beneficiary, bank, _coinValue));

        // @audit - If the first cryptoIds equals [ 10 ] (hence the coin being bought is Coinvest Token), 
        if (_cryptoIds[0] == 10 && _cryptoIds.length == 1) {
            // @audit - Transfer the specified amount of Coinvest tokens to the _beneficiary
            require(bank.transfer(_beneficiary, _amounts[0], true));
        // @audit - Otherwise if cryptoIds equals [ 21 ],
        } else if (_cryptoIds[0] == 21 && _cryptoIds.length == 1) {
            // @audit - Transfer the specified amount of Cash tokens to the _beneficiary
            require(bank.transfer(_beneficiary, _amounts[0], false));
        // @audit - Otherwise, 
        } else {
            // @audit - Use the userData contract to modify the holdings of the beneficiary
            require(userData.modifyHoldings(_beneficiary, _cryptoIds, _amounts, true));
        }
        // @audit - Emit a Buy event
        emit Buy(_beneficiary, _cryptoIds, _amounts, _prices, _isCoin);
        return true;
    }
    
    // @audit - Finalizes a sale after the oracle responds
    // @param - _beneficiary: The beneficiary of the transaction
    // @param - _cryptoIds: An array of ids for the cryptocurrencies registered in this contract
    // @param - _amounts: An array of amounts of cryptocurrencies
    // @param - _prices: An array of prices of cryptocurrencies
    // @param - _coinValue: The value of the coin 
    // @param - _isCoin: A boolean reflecting whether or not the coin is the Coinvest Token 
    // @returns - success: Returns true if the transaction succeeds
    function finalizeSell(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, uint256[] _prices, uint256 _coinValue, bool _isCoin)
      internal
    returns (bool success)
    {   
        // @audit - Calculate the fee for the sale
        uint256 fee = 4990000000000000000 * (10 ** 18) / _prices[0];
        // @audit - If the beneficiary has free trades, deduct a free trade from the beneficiary
        if (freeTrades[_beneficiary] > 0) freeTrades[_beneficiary] = freeTrades[_beneficiary].sub(1);
        // @audit - Otherwise,
        else {
            // @audit - Ensure that the coinValue is sufficient to pay the fee
            require(_coinValue > fee);
            // @audit - Ensure that a transfer from the coinvest wallet of the fee succeeds
            require(bank.transfer(coinvest, fee, _isCoin));
            // @audit - Subtract the fee from the coin value
            _coinValue = _coinValue.sub(fee);
        }
        // @audit - Transfer the modified coinValue to the _beneficiary
        require(bank.transfer(_beneficiary, _coinValue, _isCoin));
        // @audit -  Modify the holdings of the beneficiary as a sale
        require(userData.modifyHoldings(_beneficiary, _cryptoIds, _amounts, false));
        // @audit - Emit a Sell event 
        emit Sell(_beneficiary, _cryptoIds, _amounts, _prices, _isCoin);
        return true;
    }
    
/** ******************************** Only Owner ************************************* **/
    
    // @audit - Add a cryptocurrency to the investment contract
    // @param - _id: The crypto's ids
    // @param - _symbol: The crypto's symbol
    // @param - _inverse: The tokens inverse
    // @param - _isInverse: A boolean reflecting whether or not this token is an inverse
    // @returns - success: Returns true if the transaction succeeds
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of the contract
    function addCrypto(uint256 _id, string _symbol, uint256 _inverse, bool _isInverse)
      public
      onlyOwner
    returns (bool success)
    {
        // @audit - Update the appropriate mappings at the crypto's index
        cryptoSymbols[_id] = _symbol;
        tiedInverse[_id] = _inverse;
        isInverse[_id] = _isInverse;
        return true;
    }
    
    // @audit - Allows the Coinvest wallet to grant users more free trades on the platform
    // @param - _users: An array of users
    // @param - _trades: An array of numbers to add to the free trade mapping
    // @audit - MODIFIER onlyCoinvest: Ensure that the sender is the coinvest wallet 
    function addTrades(address[] _users, uint256[] _trades)
      external
      onlyCoinvest
    {
        // @audit - Ensure that the lengths of the _users and _trades arrays are equal
        require(_users.length == _trades.length);
        
        // @audit - Loop over the _users array
        for (uint256 i = 0; i < _users.length; i++) {
            // @audit - Update the free trade list of _users[i] with the value of _trades[i] 
            freeTrades[_users[i]] = freeTrades[_users[i]].add(_trades[i]);
        }     
    }

    // @audit - Updates the Coinvest token, Cash token, bank, and userData contract addresses
    // @param - _coinToken: The new coinToken address
    // @param - _cashToken: the new cashToken address
    // @param - _bank: The new bank address
    // @param - _userData: The new userData address
    // @returns - success: Returns true if the transaction succeeds
    // @audit - MODIFIER onlyOwner: Restricts access to the owner of the contract
    function changeContracts(address _coinToken, address _cashToken, address _bank, address _userData)
      external
      onlyOwner
    returns (bool success)
    {
        coinToken = _coinToken;
        cashToken = _cashToken;
        bank = Bank(_bank);
        userData = UserData(_userData);
        return true;
    }
    
/** ********************************* Modifiers ************************************* **/
    
    // @audit - Ensure that the sender is either the beneficiary of the transaction or that the sender is a token (useful when ApproveAndCall is used)
    modifier onlySenderOrToken(address _beneficiary)
    {
        require(msg.sender == _beneficiary || msg.sender == coinToken || msg.sender == cashToken);
        _;
    }
    
/** ******************************************************************************** **/
/** ******************************* Oracle Logic *********************************** **/
/** ******************************************************************************** **/

    // @audit - Get the prices of the provided cryptocurrencies and initialize the trade
    // @param - _beneficiary: The beneficiary of the transaction 
    // @param - _cryptoIds: An array of ids for the cryptocurrencies registered in this contract
    // @param - _amounts: An array of amounts of the cryptocurrencies
    // @param - _isCoin: A boolean reflecting which type of token this is 
    // @param - _buy: A boolean reflecting whether or not this is a buy transaction
    // @returns - Returns true
    function getPrices(address _beneficiary, uint256[] _cryptos, uint256[] _amounts, bool _isCoin, bool _buy) 
      internal
    returns (bool success)
    {
        // @audit - If the price of querying the URL is greater than this contract balance, 
        if (oraclize_getPrice("URL") > this.balance) {
            // @audit - Emit a newOraclizeQuery that signals that this contract needs more ether to query the oracle
            emit newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            // @audit - Emit a newOraclizeQuery that signals that there is enough ether for the API request
            emit newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            // @audit - Get the full URL of the API request
            string memory fullUrl = craftUrl(_cryptos, _isCoin);
            // @audit - Query the oracle with a gas limit of 150000 gas plus 50000 gas per cryptocurrency being queried 
            bytes32 queryId = oraclize_query("URL", fullUrl, 150000 + 50000 * _cryptos.length);
            // @audit - Create the new trade under the id queryId. 
            trades[queryId] = TradeInfo(bitConv(_cryptos, _amounts), _beneficiary, _buy, _isCoin);
        }
        return true;
    }
    
    // @audit - An endpoint for the oracle to call once the API responds
    // @param - myid: The query id that the oracle is responding to
    // @param - result: The string returned by the API 
    // @param - proof: Unused bytes
    function __callback(bytes32 myid, string result, bytes proof)
      public
    {
        // @audit - Ensure that the sender is the oracalize_cbAddress
        if (msg.sender != oraclize_cbAddress()) throw;
    
        // @audit - Get the trade info stuct corresponding to myid
        TradeInfo memory tradeInfo = trades[myid];
        // @audit - Get a cryptos and an amounts array
        var (a,b) = bitRec(tradeInfo.idsAndAmts);
        uint256[] memory cryptos = a;
        uint256[] memory amounts = b;

        // @audit - Get local variables from the tradeInfo struct 
        address beneficiary = tradeInfo.beneficiary;
        bool isBuy = tradeInfo.isBuy;
        bool isCoin = tradeInfo.isCoin;
    
        // @audit - Get the values of the cryptocurrencies specified
        uint256[] memory cryptoValues = decodePrices(cryptos, result, isCoin);
        // @audit - Calculate the total value of the currencies 
        uint256 value = calculateValue(amounts, cryptoValues);
        
        // @audit - If the transaction was a buy, finalize the payment process and exchange of the tokens
        if (isBuy) require(finalizeBuy(beneficiary, cryptos, amounts, cryptoValues, value, isCoin));
        // @audit - If the transaction was a sell, finalize the payment process and exchange of the tokens
        else require(finalizeSell(beneficiary, cryptos, amounts, cryptoValues, value, isCoin));
    }
    
/** ******************************* Constants ************************************ **/
    
    // @audit - Crafts the correct API URL to get the prices of given cryptocurrencies
    // @param - _cryptoIds: An array of ids for the cryptocurrencies registered in this contract
    // @param - _isCoin: A boolean value reflecting whether or not the coin is the Coinvest Token
    // @returns - string: The crafter URL to query the appropriate API
    function craftUrl(uint256[] _cryptos, bool _isCoin)
      public
      view
    returns (string)
    {
        if (_isCoin) var url = "https://min-api.cryptocompare.com/data/pricemulti?fsyms=COIN,";
        else url = "https://min-api.cryptocompare.com/data/pricemulti?fsyms=CASH,";

        // @audit - Loop over the cryptos array  
        for (uint256 i = 0; i < _cryptos.length; i++) {
            // @audit - Get the id of the cryptocurrency 
            uint256 id = _cryptos[i];
            // @audit - Ensure that the crypto symbol representing this currency is not empty 
            require(bytes(cryptoSymbols[id]).length > 0);
            // @audit - Concatenate the crypt symbol to the partially finished url
            url = url.toSlice().concat(cryptoSymbols[id].toSlice());
        }
        // @audit - Concatenate the USD symbol to the url
        url = url.toSlice().concat("&tsyms=USD".toSlice());
        return url;
    }

    // @audit - Decode the prices of the cryptos given by the array of ids
    // @param - _cryptos: An array of crypto ids
    // @param - _result: The string returned by the API 
    // @param - _isCoin: A boolean reflecting whether or not the price should be given in Coinvest tokens
    // @returns - uint256[]: An array of prices
    function decodePrices(uint256[] _cryptos, string _result, bool _isCoin) 
      public
      view
    returns (uint256[])
    {
        // @audit - Get a slice of the result string
        var s = _result.toSlice();
        // @audit - Get a slice of 'USD' 
        var delim = 'USD'.toSlice();
        // @audit - Get the part of s before the first instance of 'USD'
        var breakPart = s.split(delim).toString();
        // @audit - Initialize an array of prices
        uint256[] memory prices = new uint256[](_cryptos.length + 1);
        // @audit - Get the part of s after the first instance and before the second instance of 'USD'
        var coinPart = s.split(delim).toString();
        // @audit - Set the beginning element of the prices array with the coinpart of the crypto with precision of 10 ** 18
        prices[0] = parseInt(coinPart,18);
        
        // @audit - Loop over the crypto ids
        for(uint256 i = 0; i < _cryptos.length; i++) {
            // @audit - Get the inverse of the given crypto
            uint256 inverse = tiedInverse[i];
            // @audit - Loop over the cryptos ids
            for (uint256 j = 0; j < _cryptos.length; j++) {
                // @audit - If j equals i, break out of the array. Is this desired
                if (j == i) break;
                // @audit - If the jth crypto is the inverse, 
                if (_cryptos[j] == inverse) {
                    // @audit - Calculate the prices[i + 1] as (10 ** 18) ** 2 divided by prices[j + 1] (the inverse price)
                    prices[i+1] = (10 ** 36) / prices[j+1];
                    break;
                }
            }

            // @audit - If the prices element in question is zero and _isCoin and the crypto is a Coinvest token or inverse,
            if (prices[i + 1] == 0 && _isCoin && (_cryptos[i] == 10 || _cryptos[i] == 20)) {
                // @audit - If the crypto is not an inverse, then set prices[i + 1] equal to the price of a Coinvest Token 
                if (!isInverse[_cryptos[i]]) prices[i+1] = prices[0];
                // @audit - If the crypto is an inverse, calculate its inverse price from the price of a Coinvest Token 
                else prices[i+1] = (10 ** 36) / prices[0];
            // @audit - If the prices element in question is zero and _isCoin and the crypto is a Cash token,
            } else if (prices[i + 1] == 0 && !_isCoin && (_cryptos[i] == 20 || _cryptos[i] == 21)) 
                // @audit - If the crypto is not an inverse, then set prices[i + 1] equal to the price of a Coinvest Token 
                if (!isInverse[_cryptos[i]]) prices[i+1] = prices[0];
                // @audit - If the crypto is an inverse, calculate its inverse price from the price of a Coinvest Token 
                else prices[i+1] = (10 ** 36) / prices[0];
            // @audit - Otherwise, if the price in question is zero,
            } else if (prices[i+1] == 0) {
                // @audit - Split the string at the deliminator
                var part = s.split(delim).toString();
                // @audit -  Parse the int from the string
                uint256 price = parseInt(part,18);
                // @audit - If the price is nonzero and not an inverse, 
                if (price > 0 && !isInverse[_cryptos[i]]) prices[i+1] = price;
                // @audit - If the price is nonzero and an inverse, calculate the inverse price
                else if (price > 0) prices[i+1] = (10 ** 36) / price;
                // @audit - What should the price of an inverse be if the price is zero?
            }
        }
        return prices;
    }

    // @audit - Calculates the total value of specified cryptos
    // @param - _amounts: An array of amounts for given cryptos 
    // @param - _cryptoValues: An array of the values for specific cryptos
    // @returns - The total value of the cryptos
    function calculateValue(uint256[] _amounts, uint256[] _cryptoValues)
      public
      pure
    returns (uint256 value)
    {
        // @audit - There should be a check for properly sized arrays 
        // @audit - Loop over the _amounts array
        for (uint256 i = 0; i < _amounts.length; i++) {
            // @audit - Add value to the crypto value at index i + 1 multiplied by amount at index i divided by crypto values at index 0
            // @audit - Why is this how this works? What is cryptoValues[0] supposed to be
            value = value.add(_cryptoValues[i+1].mul(_amounts[i]).div(_cryptoValues[0]));
        }
    }
    
    // @audit - Convert the two given arrays to a single array that encodes the information from both
    // @param - _cryptoIds: An array of ids for the cryptocurrencies registered in this contract
    // @param - _amounts: An array of amounts for the cryptocurrencies
    // @returns - uint256[]: The combined information array 
    function bitConv(uint256[] _cryptos, uint256[] _amounts)
      public
      pure
    returns (uint256[])
    {
        // @audit - Initialize a new uint256 array with the same length as the _cryptos array
        uint256[] memory combined = new uint256[](_cryptos.length); 
        // @audit - Loop over the _cryptos array
        for (uint256 i = 0; i < _cryptos.length; i++) {
            // @audit - Or 0 with the value of _cryptos at index i 
            combined[i] |= _cryptos[i];
            // @audit - Or the value of combined at index i with _amounts at index i multiplied by 256
            combined[i] |= _amounts[i] << 8;
        }
        return combined;
    }
    
    // @audit - Recovers an array of crypto ids and an array of amounts from the provided array
    // @param - _idsAndAmts: An array that encodes cryptocurrency ids and amounts 
    // @returns - uint256[]: Returns a cryptos array
    // @returns - uint256[]: Returns an amounts array
    function bitRec(uint256[] _idsAndAmts) 
      public
      pure
    returns (uint256[], uint256[]) 
    {
        // @audit - Initialize the two arrays
        uint256[] memory cryptos = new uint256[](_idsAndAmts.length);
        uint256[] memory amounts = new uint256[](_idsAndAmts.length);

        // @audit - Loop over the original array
        for (uint256 i = 0; i < _idsAndAmts.length; i++) {
            // @audit - Cast the original array at index i to a uint8
            cryptos[i] = uint256(uint8(_idsAndAmts[i]));
            // @audit - Cast the original array at index i to a uint248 after shifting the number right by 8 bits
            amounts[i] = uint256(uint248(_idsAndAmts[i] >> 8));
        }
        // @audit - Return the arrays
        return (cryptos, amounts);
    }
    
/** *************************** Only Owner *********************************** **/

    // @audit - Change the custom gas price of the oracle
    // @param - _newGasPrice: The updated gas price
    // @returns - success: Returns true if the transaction succeeds
    // @audit - MODIFIER onlyOwner: Restricts access to the owner
    function changeGas(uint256 _newGasPrice)
      external
      onlyOwner
    returns (bool success)
    {
        customGasPrice = _newGasPrice;
        oraclize_setCustomGasPrice(_newGasPrice);
        return true;
    }
    
/** ************************** Only Coinvest ******************************* **/

    // @audit - Transfers tokens that are stuck in a token contract (held by this address) into the coinvest wallet
    // @param - _tokenContract: The address of the token with stuck tokens
    // @param - _amount: The amount of tokens or wei to send 
    // @audit - MODIFIER onlyCoinvest: Restricts access to the coinvest wallet
    function tokenEscape(address _tokenContract, uint256 _amount)
      external
      onlyCoinvest
    {
        // @audit - If the _tokenContract address is zero, transfer ether to the coinvest wallet 
        if (_tokenContract == address(0)) coinvest.transfer(_amount);
        // @audit - Otherwise,
        else {
            // @audit - Get an ERC20Interface instance at address _tokenContract
            ERC20Interface lostToken = ERC20Interface(_tokenContract);
            // @audit - Get the amount of stuckTokens in the lostToken contract 
            uint256 stuckTokens = lostToken.balanceOf(address(this));
            // @audit - Transfer the stuck tokens to the coinvest wallet
            lostToken.transfer(coinvest, stuckTokens);
        }
    }
}
