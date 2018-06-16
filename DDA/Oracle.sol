pragma solidity ^0.4.23;

// @audit - Import the oracalize api
import "oraclize-api/usingOraclize.sol";

// @audit - Contract that recieves data from the outside world
contract Oracle is usingOraclize{
    // @audit - This is used to detemine whether or not the API callback returned the correct query -- needed since API's are not instantaneous and may be asynchronous 
    bytes32 private queryID;
    // @audit - The URL of the API to query 
    // @audit - NOTE: If possible, this should be made constant as contant's are much cheaper to call
    string public API;

    // @audit - A mapping from a date to the value recieved by the oracle on that date 
    mapping(uint => uint) public oracle_values;
    // @audit - A mapping from a date to a boolean value representing whether or not the oracle was queried on that date 
    mapping(uint => bool) public queried;

    // @audit - Event: Emitted when a new document is stored
    event DocumentStored(uint _key, uint _value);
    // @audit - Event: Emitted after a new oracalize query
    event newOraclizeQuery(string description);

    // @audit - Constructor: Set the API string to be equal to a gdax url for the BTC-USD ticker
    // @audit - NOTE: API is being set to an incorrect URL 
     constructor() public{
        API = "https://api.gdax.com/products/BTC-USD/ticker).price";
    }

    // @audit - Allows users to retrieve oracle data from a particular date
    // @param - _date: The date of the requested data  
    // @returns - uint: The oracle's data from the specified date
    function retrieveData(uint _date) public constant returns (uint) {
        uint value = oracle_values[_date];
        return value;
    }

    // @audit - Allows users to query the oracle. This is payable since oracle requests cost money 
    function pushData() public payable{
        // @audit - Get the even day that now represents -- today's date
        uint _key = now - (now % 86400);
        // @audit - Ensure that the oracle was not queried on this date
        require(queried[_key] == false);
        // @audit - If this contract's balance is not enough to cover the querying fee, emit a newOracalizeQuery event describing the lack of ether
        if (oraclize_getPrice("URL") > address(this).balance) {
            emit newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        // @audit - If the contract's balance is enough to cover the oracle's fees, continue
        } else {
            // @audit - Emit a newOraclizeQuery event with a message that describes that the query was successful
            emit newOraclizeQuery("Oraclize queries sent");
            // @audit - Query the API and get the price element of the json, then set the queryID to the ID that this call returns
            queryID = oraclize_query("URL", "json(https://api.gdax.com/products/BTC-USD/ticker).price");
            // @audit - Update the query mapping for this date to true
            queried[_key] = true;
        }
    }

    // @audit - Exposes the oracle to the API, so that the API can return the requested query data whenever it gets a chance
    // @param - _oracalizeID: The ID of the query that the API processed
    // @param - _result: The result of the API call
    function __callback(bytes32 _oraclizeID, string _result) public {
        // @audit - Ensure that the sender is the API's address 
        // @audit - Ensure that the API responded to the correct query
        require(msg.sender == oraclize_cbAddress() && _oraclizeID == queryID);
        // @audit - Parse the correct integer from the result with a precision of 3 
        uint _value = parseInt(_result,3);
        // @audit - Get the even day that represents today
        uint _key = now - (now % 86400);
        // @audit - Update the oracle_values mapping to accurately reflect the value recieved from the oracle
        oracle_values[_key] = _value;
        // @audit - Emit a document stored event
        emit DocumentStored(_key, _value);
    }

    // @audit - An empty payable function to be used to add ether to cover the query fees
    function fund() public payable {
      
    }

    // @audit - Allows anyone to see whether or not the oracle was called on a particular date 
    // @param - _date: The date of the request
    // @returns - bool: True if the oracle was queried on _date, false if not
    function getQuery(uint _date) public view returns(bool){
        return queried[_date];
    }
}
