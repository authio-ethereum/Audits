//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol import
import './zeppelin/ownership/Ownable.sol';

//@audit - Crowdsale Whitelist implementation. Uses OpenZeppelin's Ownable contract
contract CrowdsaleWhitelist is Ownable {

    //@audit - Maps addresses to booleans, which signify whether or not an address is whitelisted
    mapping(address => bool) allowedAddresses;
    //@audit - The number of whitelisted addresses
    uint count = 0;

    //@audit - modifier: Throws if the sender is not whitelisted
    modifier whitelisted() {
        require(allowedAddresses[msg.sender] == true);
        _;
    }

    //@audit - Allows the contract owner to add a collection of addresses to the whitelist
    //@param - "_addresses": An array of addresses to add to the whitelist
    //@audit - MODIFIER onlyOwner(): Only the contract owner can add to the whitelist
    function addToWhitelist(address[] _addresses) public onlyOwner {
        //@audit - Loops over the input address array
        for (uint i = 0; i < _addresses.length; i++) {
            //@audit - If the address at index i is already whitelisted,skip this step
            if (allowedAddresses[_addresses[i]]) {
                continue;
            }

            //@audit - Otherwise, add the address to the whitelist, and increment count
            allowedAddresses[_addresses[i]] = true;
            //@audit - NOTE: Omission of SafeMath is acceptable here, but using it anyway would be more adherant to best practices
            count++;
        }

        //@audit - WhitelistUpdated event
        WhitelistUpdated(block.timestamp, "Added", count);
    }

    //@audit - Allow the contrat owner to remove a collection of addresses from the whitelist
    //@param - "_addresses": The array of addresses to remove from the whitelist
    //@audit - MODIFIER onlyOwner(): Only the contract owner can remove addresses from the whitelist
    function removeFromWhitelist(address[] _addresses) public onlyOwner {
        //@audit - Loops over the input address array
        for (uint i = 0; i < _addresses.length; i++) {
            //@audit - If the address at index i is already not whitelisted,skip this step
            if (!allowedAddresses[_addresses[i]]) {
                continue;
            }
            //@audit - Otherwise, remove the address from the whitelist and decrement count
            allowedAddresses[_addresses[i]] = false;
            //@audit - NOTE: Omission of SafeMath is acceptable here (because count cannot be decreased unless removing addresses, and adding addresses increases count), but using it anyway would be more adherant to best practices
            count--;
        }

        //@audit - WhitelistUpdated event
        WhitelistUpdated(block.timestamp, "Removed", count);
    }

    //@audit - Returns true, but throws if the sender is not whitelisted
    //@returns - "bool": Whether the sender is whitelisted
    //@audit - MODIFIER whitelisted(): Throws if the sender is not whitelisted
    function isWhitelisted() public whitelisted constant returns (bool) {
        return true;
    }

    //@audit - Returns whether the input address is whitelisted or not
    //@param - "_address": The address to check for whitelist status
    //@returns - "bool": Whether the input address is whitelisted or not
    function addressIsWhitelisted(address _address) public constant returns (bool) {
        return allowedAddresses[_address];
    }

    //@audit - Returns the number of whitelisted addresses
    //@returns - "uint": The number of whitelisted addresses
    function getAddressCount() public constant returns (uint) {
        return count;
    }

    //@audit - WhitelistUpdated event
    event WhitelistUpdated(uint timestamp, string operation, uint totalAddresses);
}
