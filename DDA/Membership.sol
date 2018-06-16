pragma solidity ^0.4.23;
import "./libraries/SafeMath.sol";

// @audit - Contract to keep track of members and the type of member they are
contract Membership {
    // @audit - Attaches SafeMath to uint256
    using SafeMath for uint256;
    // @audit - The owner of this contract -- has access to admin level functionality
    address public owner;
    // @audit - The member fee 
    uint public memberFee;

    // @audit - Struct representing a member. Includes their id and type of membership
    struct Member {
        uint memberId;
        uint membershipType;
    }
    
    // @audit - Mapping from addresses to a member struct. Used for determining the membership id and type of addresses
    mapping(address => Member) public members;
    // @audit - An array of addresses containing the addresses of the members of this contract
    address[] public membersAccts;

    // @audit - Event: emitted when a member address is updated
    event UpdateMemberAddress(address _from, address _to);
    // @audit - Event: emitted when a new member joins this contract
    event NewMember(address _address, uint _memberId, uint _membershipType);
    // @audit - Event: emitted when a refund is given
    event Refund(address _address, uint _amount);

    // @audit - modifier that makes a function accessible only by the owner
    modifier onlyOwner() {
        require(msg.sender == owner);
    _;
    }
    
    // @audit - Constructor: Sets the sender as the owner
     constructor() public {
        owner = msg.sender;
    }

    // @audit - Allows the owner to update the contracts member fee
    // @param - _memberFee: The replacement member fee
    // @audit - MODIFIER onlyOwner: Makes this function accessible only to the owner
    function setFee(uint _memberFee) public onlyOwner() {
        memberFee = _memberFee;
    }
    
    // @audit - Allows anyone to request membership to the contract
    function requestMembership() public payable {
        // @audit - Get the member struct represeting the sender 
        Member storage sender = members[msg.sender];
        // @audit - Ensure that the value sent is greater than the member fee
        // @audit - Ensure that the sender's membership type equals 0
        require(msg.value >= memberFee && sender.membershipType == 0 );
        // @audit - Add the sender to the membersAccounts array
        membersAccts.push(msg.sender);
        // @audit - Update the new member's id and membership type 
        sender.memberId = membersAccts.length;
        sender.membershipType = 1;
        // @audit - emit a NewMember event
        emit NewMember(msg.sender, sender.memberId, sender.membershipType);
    }
    
    // @audit - Allows the owner to update a member's address
    // @param - _from: The current address of the member
    // @param - _to: The new address of the member
    // @audit - MODIFIER onlyOwner: Makes this function accessible only to the owner
    function updateMemberAddress(address _from, address _to) public onlyOwner {
        // @audit - Ensure that the new address isn't address zero
        require (_to != address(0));
        // @audit - Retrieve the member structs for both addresses
        Member storage currentAddress = members[_from];
        Member storage newAddress = members[_to];
        // @audit - Adds the current address's member info to the new address's member struct 
        newAddress.memberId = currentAddress.memberId;
        newAddress.membershipType = currentAddress.membershipType;
        // @audit - Update the member accounts list 
		    membersAccts[currentAddress.memberId - 1] = _to;
        // @audit - Zero out the old member struct 
        currentAddress.memberId = 0;
        currentAddress.membershipType = 0; 
        // @audit - emit an UpdateMemberAddress event
        emit UpdateMemberAddress(_from, _to);
    }

    // @audit - Allows the owner to set the membership type of a member
    // @param - _memberAddress: The member whose type is being changed 
    // @param - _membershipType: The type of membership to update the member to 
    // @audit - MODIFIER onlyOwner: Makes this function accessible only to the owner
    function setMembershipType(address _memberAddress,  uint _membershipType) public onlyOwner{
        Member storage memberAddress = members[_memberAddress];
        // @audit - Update the membership type 
        memberAddress.membershipType = _membershipType;
    }

    // @audit - Allows anyone to get the addresses of all of the members
    // @returns - address[]: The addresses of all of the member accounts
    function getMembers() view public returns (address[]){
        return membersAccts;
    }
    
    // @audit - Allows anyone to get the membership information of a given member
    // @param - _memberAddress: The member whose information is being queried
    // @returns - uint: The member id of the specified member
    // @returns - uint: The membership type of the specified member 
    function getMember(address _memberAddress) view public returns(uint, uint) {
        return(members[_memberAddress].memberId, members[_memberAddress].membershipType);
    }

    // @audit - Allows anyone to get the number of members registered in this contract
    // @returns - uint: The length of the member accounts array
    function countMembers() view public returns(uint) {
        return membersAccts.length;
    }

    // @audit - Allows anyone to get the membership type of a given member 
    // @param - _memberAddress: The member whose information is being queried
    // @returns - uint: The membership type of the specified member
    function getMembershipType(address _memberAddress) public constant returns(uint){
        return members[_memberAddress].membershipType;
    }
    
    // @audit - Allows the owner to name a new owner of the contract 
    // @param - _new_owner: The replacement owner
    // @audit - MODIFIER onlyOwner: Makes this function accessible only to the owner
    function setOwner(address _new_owner) public onlyOwner() { 
        owner = _new_owner; 
    }

    // @audit - Allows the owner to grant a member a refund and subsequently remove their membership 
    // @param - _to: The member recieving the refund 
    // @param - _amount: The amount to be refunded. If zero, the refund amount is the current member fee 
    // @audit - MODIFIER onlyOwner: Makes this function accessible only to the owner
    function refund(address _to, uint _amount) public onlyOwner {
        // @audit - Ensure that the member's address is not address zero. 
        require (_to != address(0));
        // @audit - If _amount is zero, update it to equal the member fee
        if (_amount == 0) {_amount = memberFee;}
        Member storage currentAddress = members[_to];
        // @audit - Remove the member from the member list and zero out their membership struct 
        membersAccts[currentAddress.memberId-1] = 0;
        currentAddress.memberId = 0;
        currentAddress.membershipType = 0;
        // @audit - Transfer the refund to the member
        _to.transfer(_amount);
        // @audit - emit a refund event
        emit Refund(_to, _amount);
    }

    // @audit - Allows the owner to withdraw some amount of this contract's balance to a specified address
    // @param - _to: The address to withdraw the funds to 
    // @param - _amount: The amount to be withdrawn 
    // @audit - MODIFIER onlyOwner: Makes this function accessible only to the owner
    function withdraw(address _to, uint _amount) public onlyOwner {
        _to.transfer(_amount);
    }    
}
