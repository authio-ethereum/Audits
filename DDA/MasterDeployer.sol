pragma solidity ^0.4.23;

import "./libraries/SafeMath.sol";
import './Factory.sol';
import "./CloneFactory.sol";

// @audit - Contract used to deploy factories
contract MasterDeployer is CloneFactory{
  // @audit - Attaches SafeMath to uint256
  using SafeMath for uint256;
  // @audit - The factories that this deployer has created
  address[] factory_contracts;
  // @audit - The base factory from which to clone the other factories 
  address private factory;
  // @audit - The index of a given address
  mapping(address => uint) public factory_index;
  // @audit - Emitted when a new factory is created
  event NewFactory(address _factory);

  // @audit - Constructor: Adds address 0 to the array of factories and makes the sender the owner 
  constructor() public {
    factory_contracts.push(address(0));
  }
	
  // @audit - Allows the owner to update the factory of this deployer
  // @param - _factory: The new factory
  // @audit - MODIFIER onlyOwner: Only accessible to the owner
  function setFactory(address _factory) public onlyOwner(){
    factory = _factory;
  }

  // @audit - Allows the ownder to deploy a new factory
  // @audit - MODIFIER onlyOwner: Only accessible to the owner
  // @audit - NOTE: This function does not explicitly return a value.
  function deployFactory() public onlyOwner() returns(address){
    // @audit - Create a clone of this contracts current factory
    address _new_fac = createClone(factory);
    // @audit - Set the index of the new factory to be the number of factories this contract had previously deployed
    factory_index[_new_fac] = factory_contracts.length;
    // @audit - Add the clone factory to the array of factories
    factory_contracts.push(_new_fac);
    // @audit - Initialize the new factory an make the sender (the owner of this contract) the owner
    Factory(_new_fac).init(msg.sender);
    // @audit - Emit a new factory event
    emit NewFactory(_new_fac);
  }

  // @audit - Allows the owner to remove a factory
  // @param - _factory: The address of the factory to be removed
  // @audit - MODIFIER onlyOwner: Only accessible to the owner
  function removeFactory(address _factory) public onlyOwner(){
    // @audit - Get the index of this factory -- this will be nonzero because address(0) was pushed to the array
    uint256 fIndex = factory_index[_factory];
    // @audit - Get the index of the last factory deployed by this contract
    uint256 lastFactoryIndex = factory_contracts.length.sub(1);
    // @audit - Get the last factory deployed 
    address lastFactory = factory_contracts[lastFactoryIndex];
    // @audit - Replace _factory be the last factory deployed
    factory_contracts[fIndex] = lastFactory;
    // @audit - Update the index of the last factory deployed
    factory_index[lastFactory] = fIndex;
    // @audit - Update the length of the factories array
    factory_contracts.length--;
    // @audit - Set the index of _factory to be equal to 0
    factory_index[_factory] = 0;
  }

  // @audit - Allows anyone to get the number of factories deployed by this contract
  // @returns - uint: The number of factories deployed by this contract
  function getFactoryCount() public constant returns(uint){
    return factory_contracts.length - 1;
  }

  // @audit - Allows anyone to get the factory at a specified index of the factories array
  // @param - _index: The index of the factory to get
  // @returns - address: The address of the specified factory 
  function getFactorybyIndex(uint _index) public constant returns(address){
    return factory_contracts[_index];
  }
}
