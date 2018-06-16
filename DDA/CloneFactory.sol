pragma solidity ^0.4.23;

// @audit - Contract used to cheaply clone an arbitrary contract
contract CloneFactory {
    // @audit - The owner of this contract -- can access Admin level functionality
    address internal owner;
    // @audit - Event: Emitted when a new clone is created
    event CloneCreated(address indexed target, address clone);
    // @audit - Constructor: Set the owner to be the sender
    constructor() public{
        owner = msg.sender;
    }
    // @audit - modifier that only allows access to the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    // @audit - Allows the owner to set a new owner
    // @param - The replacement owner
    // @audit - MODIFIER onlyOwner: Only accessible by the factory's current owner
    function setOwner(address _owner) public onlyOwner(){
        owner = _owner;
    }
    
    // @audit - Used internally to create a clone of the contract at address target
    // @param - target: The contract to copy
    // @returns - result: The address of the clone contract
    function createClone(address target) internal returns (address result) {
        // @audit - Bytecode to take calldata provided to and delegatecall the address (currently bebebebebebe...) and then process any resulting reverts from the call
        bytes memory clone = hex"600034603b57603080600f833981f36000368180378080368173bebebebebebebebebebebebebebebebebebebebe5af43d82803e15602c573d90f35b3d90fd";
        // @audit - Cast the target address to a bytes20 value 
        bytes20 targetBytes = bytes20(target);
        // @audit - Paste targetBytes into the clone bytes
        for (uint i = 0; i < 20; i++) {
            clone[26 + i] = targetBytes[i];
        }
        assembly {
            // @audit - Set len equal to the length of the bytes clone
            let len := mload(clone)
            // @audit - Set data equal to the start of the data in the bytes clone -- after the length
            let data := add(clone, 0x20)
            // @audit - Set result equal to the "contract" created by the data produced from bytes clone
            result := create(0, data, len)
        }
    }
}
