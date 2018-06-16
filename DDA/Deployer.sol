pragma solidity ^0.4.23;

import "./TokenToTokenSwap.sol";
import "./CloneFactory.sol";

// @audit - Contract to deploy swaps for the Factory. 
// @audit - is CloneFactory: This contract inherits from the CloneFactory contract
contract Deployer is CloneFactory {
    // @audit - The factory using this deployer -- used internally
    address internal factory;
    // @audit - The address of a TokenToTokenSwap contract -- used to create new swaps
    address public swap;
    
    // @audit - Event: emitted whn a new swap is deployed
    event Deployed(address indexed master, address indexed clone);

    // @audit - Constructor: Sets _factory as this contracts factory and sets swap to be a newly deployed TokenToTokenSwap contract
    // @param - _factory: The factory that will use this deployer
    constructor(address _factory) public {
        factory = _factory;
        // @audit - Creates a new swap contract with this contract as the Factory and the UserContract, and the sender as the creator 
        swap = new TokenToTokenSwap(address(this),msg.sender,address(this),now); 
    }

    // @audit - Allows the existing owner to update this deployer's swap
    // @param - _addr: The address of the replacement swap contract
    // @audit - MODIFIER onlyOwner: Only accessible to the existing owner
    function updateSwap(address _addr) public onlyOwner() {
        swap = _addr;
    }
        
    // @audit - Allows anyone to deploy and initialize a new swap contract (normally called by factory)
    // @param - _party: The "creator" of the new swap contract 
    // @param - _user: The UserContract of the new swap contract 
    // @param - _start: The start date of the new swap contract 
    // @returns - address: The address of the newly created swap contract 
    function newContract(address _party, address _user, uint _start) public returns (address) {
        // @audit - Uses the CloneFactory contract to clone the current swap contract
        address new_swap = createClone(swap);
        // @audit - Initializes the new swap contract with the passed-in parameters
        TokenToTokenSwap(new_swap).init(factory, _party, _user, _start);
        // @audit - Emit a Deployed swap event with swap as master and new_swap as clone
        emit Deployed(swap, new_swap);
        // @audit - Return the address of the new swap
        return new_swap;
    }

    // @audit - Allows the owner to update the _factory and _owner of this contract.
    // @param - _factory: The address for the replacement factory 
    // @param - _owner: The address for the replacement owner  
    function setVars(address _factory, address _owner) public {
        // @audit - Ensure that the sender is the owner. Consider using the onlyOwner modifier for style purposes
        require (msg.sender == owner);
        factory = _factory;
        owner = _owner;
    }
}
