pragma solidity ^0.4.21;
// @audit - An interface for a membership contract
interface Membership_Interface {
    // @audit - Allows anyone to get the membership type of a given member 
    // @param - _memberAddress: The member whose information is being queried
    // @returns - uint: The membership type of the specified member
    function getMembershipType(address _member) external constant returns(uint);
}
