//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - An ownable contract has an owner address, which is allowed privileged access to functions
contract Ownable {
  //@audit - The address of the owner
  address public owner;

  //@audit - OwnershipTransferred event
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  //@audit - Constructor: Sets the contract creator as the owner
  function Ownable() public {
    owner = msg.sender;
  }

  //@audit - modifier: Passes only if the sender is the owner
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  //@audit - Allows the owner to transfer ownership to a new address
  //@param - "newOwner": The address of the new owner
  //@audit - MODIFIER onlyOwner(): only the current owner can access this function
  function transferOwnership(address newOwner) public onlyOwner {
    //@audit - Ensure the new owner is a valid address
    require(newOwner != address(0));
    //@audit - OwnershipTransferred event
    OwnershipTransferred(owner, newOwner);
    //@audit - Set the new owner
    owner = newOwner;
  }

}
