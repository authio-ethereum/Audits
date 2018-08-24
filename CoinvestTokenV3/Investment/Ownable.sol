contract Ownable {

  // @audit - The owner of the contract
  address public owner;
  // @audit - The coinvest wallet of this contract
  address public coinvest;

  // @audit - Event: Emitted when ownership is transferred
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  // @audit - Set's the owner to the sender's address and the coinvest wallet to the sender's address
  constructor() public {
    owner = msg.sender;
    coinvest = msg.sender;
  }

  // @audit - Ensure that the sender is the owner
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  // @audit - Ensure that the sender is the coinvest wallet 
  modifier onlyCoinvest() {
      require(msg.sender == coinvest);
      _;
  }

  // @audit - Transfers ownership from the current owner to a new owner address 
  // @param - newOwner: The new owner address
  // @audit - MODIFIER onlyOwner: Restricts access to the owner of the contract
  function transferOwnership(address newOwner) onlyOwner public {
    // @audit - Ensure that the new owner address is not address zero
    require(newOwner != address(0));
    // @audit - Emit an OwnershipTransferred event
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
  
  // @audit - Updates the coinvest wallet address
  // @param - _newCoinvest: The Address of the new coinvest wallet
  // @audit - MODIFIER onlyCoinvest: Restricts access to the coinvest wallet of this contract
  function transferCoinvest(address _newCoinvest) 
    onlyCoinvest
    external
  {
      // @audit - Ensure that the new coinvest address is address zero
      require(_newCoinvest != address(0));
      coinvest = _newCoinvest;
  }

}
