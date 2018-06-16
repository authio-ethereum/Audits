pragma solidity ^0.4.21;


import "./interfaces/TokenToTokenSwap_Interface.sol";
import "./Factory.sol";
import "./Wrapped_Ether.sol";
import "./libraries/SafeMath.sol";

// @audit - Contract to simplify the registration process for a new base token for the operator
contract UserContract{
    // @audit - A TokenToTokenSwap instance
    TokenToTokenSwap_Interface internal swap;
    // @audit - The base token of this contract
    Wrapped_Ether internal baseToken;
    // @audit - The factory of this contract
    Factory internal factory;

    // @audit - The address of this contract's factory instance 
    address public factory_address;
    // @audit - The owner of this contract
    address internal owner;

    // @audit - Constructor: Makes the sender the owner of this contract
    constructor() public {
        owner = msg.sender;
    }

    // @audit - Allows anyone to set up the base token contract with an existing swap contract
    // @param - _swapadd: The address of the swap contract to use 
    // @param - _amount: The amount of tokens to create 
    function Initiate(address _swapadd, uint _amount) payable public{
        // @audit - Require that the value sent is equal to twice the amount of tokens to create 
        require(msg.value == _amount * 2);
        // @audit - Initialize an interface to interact with the swap
        swap = TokenToTokenSwap_Interface(_swapadd);
        // @audit - Get the address of the token contract for this factory
        address token_address = factory.token();
        // @audit - Get the WrappedEther instance at token_address
        baseToken = Wrapped_Ether(token_address);
        // @audit - Send msg.value to the baseToken to create the proper amount of base tokens
        baseToken.createToken.value(_amount * 2)();
        // @audit - Transfer the newly created tokens to the swap contract so that it can perform payouts 
        baseToken.transfer(_swapadd,_amount* 2);
        // @audit - Create the swap with the specified amount of long and short tokens 
        swap.createSwap(_amount, msg.sender);
    }
    // @audit - Allows the owner to update the address of the factory 
    // @param - _factory_address: The address of the replacement factory
    function setFactory(address _factory_address) public {
        // @audit - Require that the sender is the owner
        require (msg.sender == owner);
        // @audit - Update factory to the factory at _factory_address
        factory_address = _factory_address;
        factory = Factory(factory_address);
    }
}

