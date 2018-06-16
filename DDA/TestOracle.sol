pragma solidity ^0.4.21;

// @audit - Contract to simulate a real oracle with user inputted date -- useful for testing purposes
contract Test_Oracle {
    // @audit - The owner of this contract -- has access to admin level functionality
    address private owner;
    // @audit - The URL of the API of this contract
    string public API;
    // @audit - A mapping from a date to the value recieved by the oracle on that date 
    mapping(uint => uint) internal oracle_values;
    // @audit - A mapping from a date to a boolean value representing whether or not the oracle was queried on that date 
    mapping(uint => bool) public queried;
    // @audit - Event: Emitted when a new document is stored
    event DocumentStored(uint _key, uint _value);
    
    // @audit - modifier that only allows access if the sender is the owner
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    // @audit - Constructor: Sets the sender as the owner and sets the API to be the URL that the normal oracle uses
     constructor() public {
        owner = msg.sender;
        // @audit - NOTE: This is an incorrect API URL. The correct url is: https://api.gdax.com/products/BTC-USD/ticker
        API = "https://api.gdax.com/products/BTC-USD/ticker).price";
    }

    // @audit - Allows the owner to store a value at a particular date in the oracle_values mapping -- used mostly for testing 
    // @param - _key: The location in the oracle_values mapping to store the value given 
    // @param - _value: The value to be stored in the oracle_values mapping 
    // @audit - MODIFIER onlyOwner: Only accessible to the owner
    function StoreDocument(uint _key, uint _value) public onlyOwner() {
        // @audit - Add the value given to the oracle_values mapping at the correct key
        oracle_values[_key] = _value;
        // @audit - Emit a DocumentStored event
        emit DocumentStored(_key, _value);
        // @audit - Update the queried mapping to reflect that there is data stored under this key in the oracle_values mapping
        queried[_key] = true;
    }

    // @audit - An empty pushData() function. Used to meet the Oracle specification
    function pushData() public pure {
    }

    // @audit - Allows anyone to see whether or not the oracle was called on a particular date 
    // @param - _date: The date of the request
    // @returns - bool: True if the oracle was queried on _date, false if not
    function getQuery(uint _date) public view returns(bool){
        return queried[_date];
    }

    // @audit - Allows anyone to retrieve oracle data from a particular date
    // @param - _date: The date of the requested data  
    // @returns - uint: The oracle's data from the specified date
    function retrieveData(uint _date) public constant returns (uint) {
        return oracle_values[_date];
    }

    // @audit - Allows the owner to set a new owner
    // @param - _new_owner: The replacement owner
    // @audit - MODIFIER onlyOwner: Only accessible to the owner
    function setOwner(address _new_owner) public onlyOwner() {
        owner = _new_owner; 
    }
}
