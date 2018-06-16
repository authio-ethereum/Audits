pragma solidity ^0.4.23;

import "./libraries/TokenLibrary.sol";

// @audit - A swap contract. Manages the terms and payouts of derivatives contracts
contract TokenToTokenSwap {

    // @audit - Attaches TokenLibrary to TokenLibrary.SwapStorage
    using TokenLibrary for TokenLibrary.SwapStorage;

    // @audit - A public instance of TokenLibrary.SwapStorage -- used for interacting with the TokenLibrary api
    TokenLibrary.SwapStorage public swap;

    // @audit - Constructor: Set the factory address, the creator, the UserContract address, and the start date of SwapStorage in the TokenLibrary 
    // @param - _factory_address: The address of this swap's factory 
    // @param - _creator: The address of this swap's creator 
    // @param - _userContract: The address of this swap's UserContract 
    // @param - _start_date: The start date of this swap contract
    constructor (address _factory_address, address _creator, address _userContract, uint _start_date) public {
        swap.startSwap(_factory_address,_creator,_userContract,_start_date);
    }
    
    // @audit - Allows anyone to update the factory address, creator, UserContract, and start date of this swap and set the swap's state to created
    // @param - _factory_address: The address of this swap's factory 
    // @param - _creator: The address of this swap's creator 
    // @param - _userContract: The address of this swap's UserContract 
    // @param - _start_date: The start date of this swap contract
    function init (address _factory_address, address _creator, address _userContract, uint _start_date) public {
        swap.startSwap(_factory_address,_creator,_userContract,_start_date);
    }

    // @audit - Exposes the private variables of this swap to anyone
    // @returns - address[5]: The address of the UserContract, long token Contract, short token contract, oracle, and base token contract 
    // @returns - uint: The number of DRCT_Tokens of this swap. This number reflects the number of long tokens. 
    // @returns - uint: contract_details[2]: The duration of the swap  
    // @returns - uint: contract_details[3]: The multiplier of the swap 
    // @returns - uint: contract_details[0]: The start date of the swap 
    // @returns - uint: contract_details[1]: The end date of the swap 
    function showPrivateVars() public view returns (address[5],uint, uint, uint, uint, uint){
        return swap.showPrivateVars();
    }

    // @audit - Exposes the current state of this contract to anyone.
    // @audit - NOTE: SwapState can be created, started, or ended. created -> 0, started -> 1, ended -> 2 
    // @returns - uint: The number representing the SwapState
    function currentState() public view returns(uint){
        return swap.showCurrentState();
    }

    // @audit - Allows anyone to initialize a  
    // @param - _amount: The amount of base tokens to create
    // @param - _senderAdd: The address of the sender -- either this address or the msg.sender must be the creator of the swap 
    function createSwap(uint _amount, address _senderAdd) public {
        swap.createSwap(_amount,_senderAdd);
    }

    // @audit - Allows anyone to try manually pay out a swap contract.
    // @param - The beginning of the period to pay out 
    // @param - The ending of the period to pay out 
    // @audit - NOTE: The above @param tags are based on the comments in the repository. These comments should probably be updated.
    // @returns - bool: True if the payout was successful, and false if the contract is not ready to be paid out
    function forcePay(uint _begin, uint _end) public returns (bool) {
       swap.forcePay([_begin,_end]);
    }
}
