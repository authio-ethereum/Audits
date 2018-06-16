pragma solidity ^0.4.21;
// @audit - An interface for a MemberCoin contract
interface MemberCoin_Interface {
    // @audit - A getter for a particular member's membership type
    // @param - _member: The member to get the type of
    // @returns - uint: The membership type of the specified member 
    function getMemberType(address _member) external constant returns(uint);
}
