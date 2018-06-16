pragma solidity ^0.4.21;

import "./interfaces/Deployer_Interface.sol";
import "./DRCT_Token.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/Wrapped_Ether_Interface.sol";
import "./interfaces/MemberCoin_Interface.sol";

/* @audit - Factory contract contains functions accessible by the owner for setting standardized 
            variables for swap contracts as well as deployment functions for DRCT token contracts 
            and TokenToTokenSwap contracts. */
contract Factory {
    // @audit - Attaches SafeMath library to uint256
    using SafeMath for uint256;
    // @audit - The owner of this contract -- has access to admin level functions 
    address public owner;
    // @audit - The oracle of this contract -- used by the swaps deployed by this factory
    address public oracle_address;
    // @audit - The UserContract of this factory -- used by users to create and register base tokens for swaps 
    address public user_contract;
    // @audit - The Deployer of this factory -- used to deploy new swap contracts
    address internal deployer_address;
    // @audit - An instance of the Deployer_Interface -- used internally
    Deployer_Interface internal deployer;
    // @audit - The base token contract (must meet the ERC20 specification) of this factory -- used for payouts
    address public token;
    // @audit - The fee of creating a new swap contract through factory
    uint public fee;
    // @audit - The duration of the swap contracts deployed by this factory 
    uint public duration;
    // @audit - The multiplier of this contract
    uint public multiplier;
    // @audit - The token ratio of this contract -- used to determine the amount of DRCT tokens to create for a given amount of ether
    uint public token_ratio;
    // @audit - The swap contracts deployed by this factory
    address[] public contracts;
    // @audit - The start dates of the long and short token contracts deployed by this factory
    uint[] public startDates;
    // @audit - The member contract of this factory -- used to determine membership and whitelist statuses 
    address public memberContract;
    // @audit - A mapping from a memberType (from the Membership contract) that tells us whether or not that memberType is whitelisted 
    mapping(uint => bool) whitelistedTypes;
    // @audit - Mapping from the addresses of swap contracts to the start date of the contract 
    mapping(address => uint) public created_contracts;
    // @audit - A mapping from a DRCT_Token address to a uint representing the token contract's start_date 
    mapping(address => uint) public token_dates;
    // @audit - A mapping from a uint representing a start date to an address representing a DRCT_Token contract 
    mapping(uint => address) public long_tokens;
    // @audit - A mapping from a uint representing a start date to an address representing a DRCT_Token contract 
    mapping(uint => address) public short_tokens;

    // @audit - Event: emitted when a new swap is created
    event ContractCreation(address _sender, address _created);

    // @audit - modifier: Only allows access to the owner of this factory
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // @audit - Constructor: Sets the sender as the owner address
    constructor() public {
        owner = msg.sender;
    }

    // @audit - Allows anyone to set the owner's address provided that the past owner set the owner address to address(0)
    // @param - _owner: The new address to be given ownership permissions
    function init(address _owner) public{
        require(owner == address(0));
        owner = _owner;
    }

    // @audit - Allows the existing owner to update the member contract address
    // @param - _memberContract: The address to be made the new member contract
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setMemberContract(address _memberContract) public onlyOwner() {
        memberContract = _memberContract;
    }

    // @audit - Allows the existing owner to set the memberTypes that are whitelisted. Since a memberType of 0 indicates a non-member, whitelistedTypes[0] is set to false
    // @param - _memberTypes: A uint array that represents the start dates of several member contracts
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setWhitelistedMemberTypes(uint[] _memberTypes) public onlyOwner(){
        whitelistedTypes[0] = false;
        for(uint i = 0; i<_memberTypes.length;i++){
            whitelistedTypes[_memberTypes[i]] = true;
        }
    }

    // @audit - Allows anyone to get the whitelist status of a member contract 
    // @param - _member: The address of a member contract 
    // @return - bool: A bool representing the whitelist status of the member contract
    function isWhitelisted(address _member) public view returns (bool){
        // @audit - Initialize a member interface
        MemberCoin_Interface Member = MemberCoin_Interface(memberContract);
        // @audit - Return the whitelist status of this member, determined by their membershipType in the membership contract 
        return whitelistedTypes[Member.getMemberType(_member)];
    }
    

    // @audit - Allows anyone to get the addresses of the long tokens contract and the short tokens contract on a particular date
    // @param - _date: The start date of a swap contract
    // @returns - address: The address of the short tokens contract of the swap that starts on _date
    // @returns - address: The address of the long tokens contract of the swap that starts on _date
    function getTokens(uint _date) public view returns(address, address){
        return(long_tokens[_date],short_tokens[_date]);
    }

    // @audit - Allows the existing owner to update the fee of this factory's swap creation process 
    // @param - _fee: The new fee of creating a swap contract from this factory
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setFee(uint _fee) public onlyOwner() {
        fee = _fee;
    }

    // @audit - Allows the existing owner to update the deployer address to a new address and makes updates deployer to accomodate this change 
    // @param - _deployer: The address of the new Deployer contract to be used  
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setDeployer(address _deployer) public onlyOwner() {
        deployer_address = _deployer;
        deployer = Deployer_Interface(_deployer);
    }

    // @audit - Allows the existing owner to update the address of the UserContract
    // @param - _userContract: The address to use to update the UserContract
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setUserContract(address _userContract) public onlyOwner() {
        user_contract = _userContract;
    }

    // @audit - Allows the existing owner to update the token_ratio, duration, and multiplier
    // @param - _token_ratio: The new token ratio of this factory  
    // @param - _duration: The new duration of swap contracts in this factory 
    // @param - _multiplier: The new multiplier of this factory 
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setVariables(uint _token_ratio, uint _duration, uint _multiplier) public onlyOwner() {
        token_ratio = _token_ratio;
        duration = _duration;
        multiplier = _multiplier;
    }

    // @audit - Allows the existing owner to update the base token of this factory
    // @param - _token: The new base token address
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setBaseToken(address _token) public onlyOwner() {
        token = _token;
    }

    // @audit - Allows anyone that is whitelisted to deploy a new swap contract that starts on _start_date
    // @param - _start_date: The date to start the new swap
    // @returns - address: The address of the new swap contract
    function deployContract(uint _start_date) public payable returns (address) {
        // @audit - Require that the value sent is enough to pay the fee and that the sender is whitelisted 
        require(msg.value >= fee && isWhitelisted(msg.sender));
        // @audit - Make sure that the start date is an even day
        require(_start_date % 86400 == 0);
        // @audit - Deploy the new contract through the existing deployer interface
        address new_contract = deployer.newContract(msg.sender, user_contract, _start_date);
        // @audit - Add the new swap contract to the contracts array
        contracts.push(new_contract);
        // @audit - Add the start date of the new swap to the created_contracts mapping 
        created_contracts[new_contract] = _start_date;
        // @audit - emit a contract creation event with the sender and the new_contract as topics
        emit ContractCreation(msg.sender,new_contract);
        return new_contract;
    }

    // @audit - Allows anyone to deploy a token contract for a particular start date provided that the token contracts have not been defined
    // @param - _start_date: The start date of the swap for these token contracts
    function deployTokenContract(uint _start_date) public{
        address _token;
        // @audit - Make sure that _start_date is a valid start date
        require(_start_date % 86400 == 0);
        // @audit - Require that the long and short token contracts for this start date have not already been defined
        require(long_tokens[_start_date] == address(0) && short_tokens[_start_date] == address(0));
        // @audit - Create a new DRCT_Token contract
        _token = new DRCT_Token(address(this));
        // @audit - Set the start date of _token to _start_date
        token_dates[_token] = _start_date;
        // @audit - Update the long_tokens mapping at _start_date to equal _token
        long_tokens[_start_date] = _token;
        // @audit - Create a new DRCT_Token contract
        _token = new DRCT_Token(address(this));
        // @audit - Update the short_tokens mapping at _start_date to equal _token
        short_tokens[_start_date] = _token;
        // @audit - Set the start date of _token to _start_date
        token_dates[_token] = _start_date;
        // @audit - Update the startDates array to include the new start_date
        startDates.push(_start_date);
    }

    // @audit - Allows a swap contract that begins on the start date to create long and short tokens 
    //          using the existing long and short tokens contracts for this start_date 
    // @param - _supply: The amount of wrapped ether to designate for the short tokens and the long tokens 
    // @param - _party: The address that will start with the created long and short tokens 
    // @param - _start_date: The start_date of the swap, long tokens, and short tokens contracts 
    // @returns - ltoken: Returns address of the long tokens contract 
    // @returns - stoken: Returns address of the short tokens contract 
    // @returns - token_ratio: Returns the token_ratio used to create these DRCT tokens
    function createToken(uint _supply, address _party, uint _start_date) public returns (address, address, uint) {
        // @audit - Ensure that the sender's deployed swap contract starts on _start_date
        require(created_contracts[msg.sender] == _start_date);
        // @audit - Get the token addresses of the swap starting on start_date
        address ltoken = long_tokens[_start_date];
        address stoken = short_tokens[_start_date];
        // @audit - Maked sure that the long and short token addresses of this start date are defined
        require(ltoken != address(0) && stoken != address(0));
            // @audit - Create the correct amount of long_tokens using the token ratio and safe division
            DRCT_Token drct_interface = DRCT_Token(ltoken);
            drct_interface.createToken(_supply.div(token_ratio), _party,msg.sender);
            // @audit - Create the correct amount of short_tokens using the token ratio and safe division
            drct_interface = DRCT_Token(stoken);
            drct_interface.createToken(_supply.div(token_ratio), _party,msg.sender);
        return (ltoken, stoken, token_ratio);
    }
  
    // @audit - Allows the existing owner to update the Oracle
    // @param - _new_oracle_address: The new Oracle's address
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setOracleAddress(address _new_oracle_address) public onlyOwner() {
        oracle_address = _new_oracle_address; 
    }

    // @audit - Allows the existing owner to transfer ownership to another address. 
    // @audit - If _new_owner == address(0), then anyone can make any address the owner using the init function
    // @param - _new_owner: The address of the new owner
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setOwner(address _new_owner) public onlyOwner() { 
        owner = _new_owner; 
    }

    // @audit - Allows the existing owner to withdraw fees
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function withdrawFees() public onlyOwner(){
        // @audit - Used the Wrapped_Ether_Interface to get the balance of this factory in the WrappedEther contract 
        Wrapped_Ether_Interface token_interface = Wrapped_Ether_Interface(token);
        uint _val = token_interface.balanceOf(address(this));
        // @audit - If the balance of this factory is greater that 0, withdraw the balance from the WrappedEther contract
        if(_val > 0){
            token_interface.withdraw(_val);
        }
        // @audit - Transfer this factory's balance to the owner
        owner.transfer(address(this).balance);
     }

    // @audit - An empty fallback function 
    function() public payable {
    }

    // @audit - Allows users to get the Oracle address, duration, multiplier, and base token address of this factory
    function getVariables() public view returns (address, uint, uint, address){
        return (oracle_address,duration, multiplier, token);
    }

    // @audit - Used by a TokenToTokenSwap contract to update the party's balance in the DRCT Token contract after a payout 
    // @param - _party: The party to be paid 
    // @param - _token_add: The address of the DRCT_Token contract that holds the payment drct tokens
    function payToken(address _party, address _token_add) public {
        // @audit - Require that the sender has created a swap with a start date > 0. 
        require(created_contracts[msg.sender] > 0);
        DRCT_Token drct_interface = DRCT_Token(_token_add);
        // @audit - Pay _party using the DRCT Token contract at address _token_add
        drct_interface.pay(_party, msg.sender);
    }

    // @audit - Allows anyone to get the number of swap contracts created by this factory
    // @returns - uint: Returns the number of contracts deployed by this factory. 
    function getCount() public constant returns(uint) {
        return contracts.length;
    }

    // @audit - Allows anyone to get the number of starting dates for swap contracts
    // @returns - uint: Returns the number of start dates that have been created in this factory
    function getDateCount() public constant returns(uint) {
        return startDates.length;
    }
}
