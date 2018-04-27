pragma solidity ^0.4.18;

import "./interfaces/IPoaNetworkConsensus.sol";
import "./interfaces/IKeysManager.sol";
import "./interfaces/IProxyStorage.sol";


//@audit - Manages keys for all validators
contract KeysManager is IKeysManager {
    //@audit - Enum representing the state of a key
    enum InitialKeyState { Invalid, Activated, Deactivated }

    //@audit - Struct representing a set of keys
    struct Keys {
        address votingKey;
        address payoutKey;
        bool isMiningActive;
        bool isVotingActive;
        bool isPayoutActive;
    }

    //@audit - Address of the master of ceremony
    address public masterOfCeremony;
    //@audit - Address of the ProxyStorage contract, cast to an interface
    IProxyStorage public proxyStorage;

    //@audit - Address of the PoaNetworkConsensus contract, cast to an interface
    IPoaNetworkConsensus public poaNetworkConsensus;
    //@audit - Maximum number of initial keys that can be created
    uint256 public maxNumberOfInitialKeys = 12;
    //@audit - Number of keys existing initially
    uint256 public initialKeysCount = 0;
    //@audit - Maximum number of validators
    uint256 public maxLimitValidators = 2000;
    //@audit - Maps an address to a validator's initial key type - invalid, activeated, or deactived
    mapping(address => uint8) public initialKeys;
    //@audit - Maps an address to a validator's keys
    mapping(address => Keys) public validatorKeys;
    //@audit - Maps a voting key address to a mining key address
    mapping(address => address) public getMiningKeyByVoting;
    //@audit - Maps a mining key address to the previous mining key address
    mapping(address => address) public miningKeyHistory;

    //@audit - Events
    event PayoutKeyChanged(address key, address indexed miningKey, string action);
    event VotingKeyChanged(address key, address indexed miningKey, string action);
    event MiningKeyChanged(address key, string action);
    event ValidatorInitialized(address indexed miningKey, address indexed votingKey, address indexed payoutKey);
    event InitialKeyCreated(address indexed initialKey, uint256 time, uint256 initialKeysCount);

    //@audit - Modifier: Sender must be the voting to change keys address, as stored in the ProxyStorage contract
    modifier onlyVotingToChangeKeys() {
        require(msg.sender == getVotingToChangeKeys());
        _;
    }

    //@audit - Modifier: Sender must have an activated initial key
    modifier onlyValidInitialKey() {
        require(initialKeys[msg.sender] == uint8(InitialKeyState.Activated));
        _;
    }

    //@audit - Modifier: Ensures the current number of validators is within the maxLimitValidators limit
    modifier withinTotalLimit() {
        require(poaNetworkConsensus.currentValidatorsLength() <= maxLimitValidators);
        _;
    }

    //@audit - Constructor: Sets the proxyStorage, poaConsensus, and masterOfCeremony addresses
    function KeysManager(address _proxyStorage, address _poaConsensus, address _masterOfCeremony) public {
        //@audit - Ensure the ProxyStorage and poaConsensus addresses are nonzero
        require(_proxyStorage != address(0) && _poaConsensus != address(0));
        //@audit - Ensure the ProxyStorage address is not the poaConsensus address
        require(_proxyStorage != _poaConsensus);
        //@audit - Ensure the masterOfCeremony address is nonzero, and is not the poaConsensus address (which also means the address will not be the proxyStorage address)
        require(_masterOfCeremony != address(0) && _masterOfCeremony != _poaConsensus);
        //@audit - Set masterOfCeremony address
        masterOfCeremony = _masterOfCeremony;
        //@audit - Set ProxyStorage and poaNetworkConsensus addresses, after casting them to interfaces
        proxyStorage = IProxyStorage(_proxyStorage);
        poaNetworkConsensus = IPoaNetworkConsensus(_poaConsensus);
        //@audit - Initialize the master of ceremony's validator keys
        validatorKeys[masterOfCeremony] = Keys({
            votingKey: address(0),
            payoutKey: address(0),
            isMiningActive: true,
            isVotingActive: false,
            isPayoutActive: false
        });
    }

    //@audit - Allows the master of ceremony to initialize keys
    function initiateKeys(address _initialKey) public {
        //@audit - Sender must be masterOfCeremony
        require(msg.sender == masterOfCeremony);
        //@audit - Ensure the key to be set is nonzero
        require(_initialKey != address(0));
        //@audit - Ensure the key being set is not overriding an existing key
        require(initialKeys[_initialKey] == uint8(InitialKeyState.Invalid));
        //@audit - Ensure the key being set is not the masterOfCeremony address
        require(_initialKey != masterOfCeremony);
        //@audit - Ensure the current count of keys is less than the maximum number
        require(initialKeysCount < maxNumberOfInitialKeys);
        //@audit - Set the new key to Activated
        initialKeys[_initialKey] = uint8(InitialKeyState.Activated);
        //@audit - Increment the initialKeysCount
        initialKeysCount++;
        //@audit - Emit the InitialKeyCreated event
        InitialKeyCreated(_initialKey, getTime(), initialKeysCount);
    }

    //@audit - Allows a sender to create mining, voting, and payout keys
    //@audit - MODIFIER: Sender must have an active initial key
    function createKeys(address _miningKey, address _votingKey, address _payoutKey) public onlyValidInitialKey {
        //@audit - Ensure none of the passed-in keys are 0x0
        require(_miningKey != address(0) && _votingKey != address(0) && _payoutKey != address(0));
        //@audit - Ensure none of the keys equal each other
        require(_miningKey != _votingKey && _miningKey != _payoutKey && _votingKey != _payoutKey);
        //@audit - Ensure none of the keys are the sender's address
        require(_miningKey != msg.sender && _votingKey != msg.sender && _payoutKey != msg.sender);
        //@audit - Set the keys for the validator
        validatorKeys[_miningKey] = Keys({
            votingKey: _votingKey,
            payoutKey: _payoutKey,
            isMiningActive: true,
            isVotingActive: true,
            isPayoutActive: true
        });
        //@audit - Set the validator's mining key to be accessible through their voting key
        getMiningKeyByVoting[_votingKey] = _miningKey;
        //@audit - Set the validator's key to Deactivated
        initialKeys[msg.sender] = uint8(InitialKeyState.Deactivated);
        //@audit - Add a validator in the poaNetworkConsensus contract
        poaNetworkConsensus.addValidator(_miningKey);
        //@audit - Emit the ValidatorInitialized event
        ValidatorInitialized(_miningKey, _votingKey, _payoutKey);
    }

    //@audit - Returns now, can be changed pre-launch for testing purposes
    function getTime() public view returns(uint256) {
        return now;
    }

    //@audit - Returns the contract address of the voting to change keys contract, via the ProxyStorage contract
    function getVotingToChangeKeys() public view returns(address) {
        return proxyStorage.getVotingToChangeKeys();
    }

    //@audit - Returns true if mining is active for the passed-in key
    function isMiningActive(address _key) public view returns(bool) {
        return validatorKeys[_key].isMiningActive;
    }

    //@audit - Returns true if voting is active for the passed-in key
    function isVotingActive(address _votingKey) public view returns(bool) {
        address miningKey = getMiningKeyByVoting[_votingKey];
        return validatorKeys[miningKey].isVotingActive;
    }

    //@audit - Returns true if payout is active for the passed-in key
    function isPayoutActive(address _miningKey) public view returns(bool) {
        return validatorKeys[_miningKey].isPayoutActive;
    }

    //@audit - Return the voting key associated with the passed-in mining key
    function getVotingByMining(address _miningKey) public view returns(address) {
        return validatorKeys[_miningKey].votingKey;
    }

    //@audit - Return the payout key associated with the passed-in mining key
    function getPayoutByMining(address _miningKey) public view returns(address) {
        return validatorKeys[_miningKey].payoutKey;
    }

    //@audit - Allows a mining key to be added
    //@audit - MODIFIER: Sender must be the voting to change key contract
    //@audit - MODIFIER: Current number of validators must be within the current total limit
    function addMiningKey(address _key) public onlyVotingToChangeKeys withinTotalLimit {
        _addMiningKey(_key);
    }

    //@audit - Allows a voting key to be added, using a mining key
    //@audit - MODIFIER: Sender must be the voting to change key contract
    function addVotingKey(address _key, address _miningKey) public onlyVotingToChangeKeys {
        _addVotingKey(_key, _miningKey);
    }

    //@audit - Allows a payout key to be added, using a mining key
    //@audit - MODIFIER: Sender must be the voting to change key contract
    function addPayoutKey(address _key, address _miningKey) public onlyVotingToChangeKeys {
        _addPayoutKey(_key, _miningKey);
    }

    //@audit - Allows a mining key to be removed
    //@audit - MODIFIER: Sender must be the voting to change key contract
    function removeMiningKey(address _key) public onlyVotingToChangeKeys {
        _removeMiningKey(_key);
    }

    //@audit - Allows a voting key to be removed, using a mining key
    //@audit - MODIFIER: Sender must be the voting to change key contract
    function removeVotingKey(address _miningKey) public onlyVotingToChangeKeys {
        _removeVotingKey(_miningKey);
    }

    //@audit - Allows a payout key to be removed, using a mining key
    //@audit - MODIFIER: Sender must be the voting to change key contract
    function removePayoutKey(address _miningKey) public onlyVotingToChangeKeys {
        _removePayoutKey(_miningKey);
    }

    //@audit - Allows a mining key to be swapped for a different key
    //@audit - MODIFIER: Sender must be the voting to change key contract
    function swapMiningKey(address _key, address _oldMiningKey) public onlyVotingToChangeKeys {
        miningKeyHistory[_key] = _oldMiningKey;
        _removeMiningKey(_oldMiningKey);
        _addMiningKey(_key);
    }

    //@audit - Allows a voting key to be swapped for a different key, using the current mining key
    //@audit - MODIFIER: Sender must be the voting to change key contract
    function swapVotingKey(address _key, address _miningKey) public onlyVotingToChangeKeys {
        _swapVotingKey(_key, _miningKey);
    }

    //@audit - Allows a payout key to be swapped for a different key, using the current mining key
    //@audit - MODIFIER: Sender must be the voting to change key contract
    function swapPayoutKey(address _key, address _miningKey) public onlyVotingToChangeKeys {
        _swapPayoutKey(_key, _miningKey);
    }

    //@audit - Allows a voting key to be swapped for another key, using the current mining key
    //@audit - ACCESS: Private - can only be called from inside this contract
    function _swapVotingKey(address _key, address _miningKey) private {
        _removeVotingKey(_miningKey);
        _addVotingKey(_key, _miningKey);
    }

    //@audit - Allows a payout key to be swapped for another key, using the current mining key
    //@audit - ACCESS: Private - can only be called from inside this contract
    function _swapPayoutKey(address _key, address _miningKey) private {
        _removePayoutKey(_miningKey);
        _addPayoutKey(_key, _miningKey);
    }

    //@audit - Allows a mining key to be added to the consensus contract
    //@audit - ACCESS: Private - can only be called from inside this contract
    function _addMiningKey(address _key) private {
        //@audit - Set the key for this validator in this contract
        validatorKeys[_key] = Keys({
            votingKey: address(0),
            payoutKey: address(0),
            isVotingActive: false,
            isPayoutActive: false,
            isMiningActive: true
        });
        //@audit - Add the new mining key to the poaNetworkConsensus contract
        poaNetworkConsensus.addValidator(_key);
        //@audit - Emit the MiningKeyChanged event
        MiningKeyChanged(_key, "added");
    }

    //@audit - Allows a voting key to be added using the current mining key
    //@audit - ACCESS: Private - can only be called from inside this contract
    function _addVotingKey(address _key, address _miningKey) private {
        //@audit - Get the current Keys struct associated with the given mining key
        Keys storage validator = validatorKeys[_miningKey];
        //@audit - Ensure that mining is active for the mining key, and that the new voting key is not the current mining key
        require(validator.isMiningActive && _key != _miningKey);
        //@audit - If voting is active for the current validator, swap the voting key for the new one
        if (validator.isVotingActive) {
            _swapVotingKey(_key, _miningKey);
        //@audit - If voting is not active for the validator
        } else {
            //@audit - Set the validator's voting key to the new key
            validator.votingKey = _key;
            //@audit - Set the voting to active
            validator.isVotingActive = true;
            //@audit - Set the new voting key as an index for the current mining key
            getMiningKeyByVoting[_key] = _miningKey;
            //@audit - Emit a VotingKeyChanged event
            VotingKeyChanged(_key, _miningKey, "added");
        }
    }

    //@audit - Allows a payout key to be added using the current mining key
    //@audit - ACCESS: Private - can only be called from inside this contract
    function _addPayoutKey(address _key, address _miningKey) private {
        //@audit - Get the Keys struct for the validator associated with the mining key
        Keys storage validator = validatorKeys[_miningKey];
        //@audit - Ensure the validator has active mining, and that the new key is not their mining key
        require(validator.isMiningActive && _key != _miningKey);
        //@audit - If payout is currently active, and the validator's payout key is nonzero
        if (validator.isPayoutActive && validator.payoutKey != address(0)) {
            //@audit - Swap the payout key, using the current mining key
            _swapPayoutKey(_key, _miningKey);
        //@audit - If payout is not currently active, or the validator's payout key is 0
        } else {
            //@audit - Set the validator's payout key to the new key
            validator.payoutKey = _key;
            //@audit - Set their payout to active
            validator.isPayoutActive = true;
            //@audit - Emit a PayoutKeyChanged event
            PayoutKeyChanged(_key, _miningKey, "added");
        }
    }

    //@audit - Allows a mining key to be removed
    //@audit - ACCESS: Private - can only be called from inside this contract
    function _removeMiningKey(address _key) private {
        //@audit - Ensure that the current key has active mining
        require(validatorKeys[_key].isMiningActive);
        //@audit - Get the validator's key struct
        Keys memory keys = validatorKeys[_key];
        //@audit - Remove the indexed mining key
        getMiningKeyByVoting[keys.votingKey] = address(0);
        //@audit - Set the validator's key set to default values
        validatorKeys[_key] = Keys({
            votingKey: address(0),
            payoutKey: address(0),
            isVotingActive: false,
            isPayoutActive: false,
            isMiningActive: false
        });
        //@audit - Remove the validator from the poaNetworkConsensus contract
        poaNetworkConsensus.removeValidator(_key);
        //@audit - Emit a MiningKeyChanged event
        MiningKeyChanged(_key, "removed");
    }

    //@audit - Allows the removal of a voting key associated with a mining key
    //@audit - ACCESS: Private - can only be called from inside this contract
    function _removeVotingKey(address _miningKey) private {
        //@audit - Get the validator's current key set
        Keys storage validator = validatorKeys[_miningKey];
        //@audit - Require that the validator have active mining
        require(validator.isVotingActive);
        //@audit - Get the validator's old voting key
        address oldVoting = validator.votingKey;
        //@audit - Set the validator's current voting key to 0
        validator.votingKey = address(0);
        //@audit - Set the validator's voting to inactive
        validator.isVotingActive = false;
        //@audit - Remove the mining key indexed by the voting key
        getMiningKeyByVoting[oldVoting] = address(0);
        //@audit - Emit a VotingKeyChanged event
        VotingKeyChanged(oldVoting, _miningKey, "removed");
    }

    //@audit - Allows the removal of a payout key associated with a mining key
    //@audit - ACCESS: Private - can only be called from inside this contract
    function _removePayoutKey(address _miningKey) private {
        //@audit - Get the key set associated with the mining key
        Keys storage validator = validatorKeys[_miningKey];
        //@audit - Ensure that payout is currently active for thi validator
        require(validator.isPayoutActive);
        //@audit - Get the payout key
        address oldPayout = validator.payoutKey;
        //@audit - Set the current payout key to 0
        validator.payoutKey = address(0);
        //@audit - Set the validator's payout to inactive
        validator.isPayoutActive = false;
        //@audit - Emit a PayoutKeyChanged event
        PayoutKeyChanged(oldPayout, _miningKey, "removed");
    }
}
