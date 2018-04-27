pragma solidity ^0.4.18;
import "./interfaces/IProxyStorage.sol";


//@audit - This contract serves as storage for various other contract addresses, which allows them to be upgraded through voting mechanisms in other contracts
contract ProxyStorage is IProxyStorage {
    //@audit - Address of the master of ceremony, who distributes the first keys to validators
    address public masterOfCeremony;
    //@audit - Address of the PoaNetworkConsensus contract
    address poaConsensus;
    //@audit - Address of the KeysManager contract
    address keysManager;
    //@audit - Address of the contract that houses the key change voting mechanism
    address votingToChangeKeys;
    //@audit - Address of the contract that houses the voting mechanism required to change the minimum threshold for voting
    address votingToChangeMinThreshold;
    //@audit - Address of the contract that houses the voting mechanism required to change various contract addresses
    address votingToChangeProxy;
    //@audit - Address of the Ballot Storage contract
    address ballotsStorage;
    //@audit - Has the master of ceremony initialized the contract addresses yet
    bool public mocInitialized;

    //@audit - Enum representing the various types of contracts
    enum ContractTypes {
        Invalid,
        KeysManager,
        VotingToChangeKeys,
        VotingToChangeMinThreshold,
        VotingToChangeProxy,
        BallotsStorage
    }

    //@audit - Events
    event ProxyInitialized(
        address keysManager,
        address votingToChangeKeys,
        address votingToChangeMinThreshold,
        address votingToChangeProxy,
        address ballotsStorage);

    event AddressSet(uint256 contractType, address contractAddress);

    //@audit - Modifier: Sender must be the Proxy change voting contract
    modifier onlyVotingToChangeProxy() {
        require(msg.sender == votingToChangeProxy);
        _;
    }

    //@audit - Constructor: Sets the Poa Consensus contract, as well as the address of the master of ceremony
    function ProxyStorage(address _poaConsensus, address _moc) public {
        poaConsensus = _poaConsensus;
        masterOfCeremony = _moc;
    }

    //@audit - Returns the keysManager contract address
    function getKeysManager() public view returns(address) {
        return keysManager;
    }

    //@audit - Returns the votingToChangeKeys contract address
    function getVotingToChangeKeys() public view returns(address) {
        return votingToChangeKeys;
    }

    //@audit - Returns he votingToChangeMinThreshold contract address
    function getVotingToChangeMinThreshold() public view returns(address) {
        return votingToChangeMinThreshold;
    }

    //@audit - Returns the votingToChangeProxy contract address
    function getVotingToChangeProxy() public view returns(address) {
        return votingToChangeProxy;
    }

    //@audit - Returns the poaConsensus contract address
    function getPoaConsensus() public view returns(address) {
        return poaConsensus;
    }

    //@audit - Returns the BallotsStorage contract address
    function getBallotsStorage() public view returns(address) {
        return ballotsStorage;
    }

    //@audit - Allows the master of ceremony to initialize the various contract addresses
    function initializeAddresses(
        address _keysManager,
        address _votingToChangeKeys,
        address _votingToChangeMinThreshold,
        address _votingToChangeProxy,
        address _ballotsStorage
    ) public
    {
        //@audit - Sender must be master of ceremony
        require(msg.sender == masterOfCeremony);
        //@audit - Ensure that this function has not been called before
        require(!mocInitialized);
        //@audit - Set all passed-in addresses
        keysManager = _keysManager;
        votingToChangeKeys = _votingToChangeKeys;
        votingToChangeMinThreshold = _votingToChangeMinThreshold;
        votingToChangeProxy = _votingToChangeProxy;
        ballotsStorage = _ballotsStorage;
        //@audit - Ensure this function cannot be called again
        mocInitialized = true;
        //@audit - Emit the ProxyInitialized event
        ProxyInitialized(
            keysManager,
            votingToChangeKeys,
            votingToChangeMinThreshold,
            votingToChangeProxy,
            ballotsStorage);
    }

    //@audit - Set a contract address, via the proxy vote address change contract
    //@audit - MODIFIER: Sender must be the Proxy change voting contract
    function setContractAddress(uint256 _contractType, address _contractAddress) public onlyVotingToChangeProxy {
        //@audit - Ensure the contract address is not 0
        require(_contractAddress != address(0));
        //@audit - If the contract type is X, set that contract's new address to _contractAddress
        if (_contractType == uint8(ContractTypes.KeysManager)) {
            keysManager = _contractAddress;
        } else if (_contractType == uint8(ContractTypes.VotingToChangeKeys)) {
            votingToChangeKeys = _contractAddress;
        } else if (_contractType == uint8(ContractTypes.VotingToChangeMinThreshold)) {
            votingToChangeMinThreshold = _contractAddress;
        } else if (_contractType == uint8(ContractTypes.VotingToChangeProxy)) {
            votingToChangeProxy = _contractAddress;
        } else if (_contractType == uint8(ContractTypes.BallotsStorage)) {
            ballotsStorage = _contractAddress;
        }
        //@audit - Emit the AddressSet event
        AddressSet(_contractType, _contractAddress);
    }
}
