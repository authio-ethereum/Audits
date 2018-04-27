pragma solidity ^0.4.15;


contract MultiOwnable {
    mapping (address => bool) public ownerRegistry;
    address[] owners;
    address multiOwnableCreator = 0x0;

    function MultiOwnable() {
        multiOwnableCreator = msg.sender;
    }

    //@audit - allows the creator of the contract to set the owners[], if it has not been set yet
    function setupOwners(address[] _owners) {
        // Owners are allowed to be set up only one time
        require(multiOwnableCreator == msg.sender);
        require(owners.length == 0);
        //@audit - for every owner in _owners
        for(uint256 idx=0; idx < _owners.length; idx++) {
            //@audit - ensure they are not already an owner, that the owner is not 0x0, and that the owner is not this contract
            require(
                !ownerRegistry[_owners[idx]] &&
                _owners[idx] != 0x0 &&
                _owners[idx] != address(this)
            );
            //@audit - mark the passed in owner as an owner in ownerRegistry
            ownerRegistry[_owners[idx]] = true;
        }
        //@audit - set the owners array to the passed in _owners array
        owners = _owners;
    }

    modifier onlyOwner() {
        require(ownerRegistry[msg.sender] == true);
        _;
    }

    //@audit - NOTE: mark function as constant
    function getOwners() public returns (address[]) {
        return owners;
    }
}
