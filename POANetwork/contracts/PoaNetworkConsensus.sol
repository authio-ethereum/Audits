pragma solidity ^0.4.18;

import "./interfaces/IPoaNetworkConsensus.sol";
import "./interfaces/IProxyStorage.sol";


//@audit - This contract keeps track of current and pending validators, and is the contract the master of ceremony uses to distribute keys
contract PoaNetworkConsensus is IPoaNetworkConsensus {
    //@audit - Events
    /// Issue this log event to signal a desired change in validator set.
    /// This will not lead to a change in active validator set until
    /// finalizeChange is called.
    ///
    /// Only the last log event of any block can take effect.
    /// If a signal is issued while another is being finalized it may never
    /// take effect.
    ///
    /// parentHash here should be the parent block hash, or the
    /// signal will not be recognized.
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);
    event ChangeFinalized(address[] newSet);
    event ChangeReference(string nameOfContract, address newAddress);
    event MoCInitializedProxyStorage(address proxyStorage);

    //@audit - Struct representing whether an address is a validator, and their index in the currentValidators array
    struct ValidatorState {
        // Is this a validator.
        bool isValidator;
        // Index in the currentValidators.
        uint256 index;
    }

    //@audit - Whether the current validator changes have been finalized
    bool public finalized = false;
    //@audit - Whether the master of ceremony has initialized the proxyStorage contract
    bool public isMasterOfCeremonyInitialized = false;
    //@audit - The address of the master of ceremony
    address public masterOfCeremony;
    //@audit - The system address, required to finalize changes made to validators
    address public systemAddress = 0xfffffffffffffffffffffffffffffffffffffffe;
    //@audit - A dynamic array of current validators
    address[] public currentValidators;
    //@audit - A dynamic array of validators pending their addition to the active list
    address[] public pendingList;
    //@audit - The length of the currentValidators array
    uint256 public currentValidatorsLength;
    //@audit - A mapping of addresses to their ValidatorState struct
    mapping(address => ValidatorState) public validatorsState;
    //@audit - The address of the ProxyStorage contract, cast to an interface
    IProxyStorage public proxyStorage;

    //@audit - Modifier: Sender must be the system address, and current pending list cannot be finalized
    modifier onlySystemAndNotFinalized() {
        require(msg.sender == systemAddress && !finalized);
        _;
    }

    //@audit - Modifier: Sender must by the voting to change keys contract
    modifier onlyVotingContract() {
        require(msg.sender == getVotingToChangeKeys());
        _;
    }

    //@audit - Modifier: Sender must be the KeysManager contract
    modifier onlyKeysManager() {
        require(msg.sender == getKeysManager());
        _;
    }

    //@audit - Modifier: The passed-in address must not already be a validator
    modifier isNewValidator(address _someone) {
        require(!validatorsState[_someone].isValidator);
        _;
    }

    //@audit - Modifier: The passed-in address must already be a validator
    modifier isNotNewValidator(address _someone) {
        require(validatorsState[_someone].isValidator);
        _;
    }

    //@@audit - Constructor: Sets the masterOfCeremony adddress and provides them with a validation key
    function PoaNetworkConsensus(address _masterOfCeremony) public {
        //@audit - Ensure the masterOfCeremony address is nonzero
        // TODO: When you deploy this contract, make sure you hardcode items below
        // Make sure you have those addresses defined in spec.json
        require(_masterOfCeremony != address(0));
        //@audit - Set the master of ceremony address
        masterOfCeremony = _masterOfCeremony;
        //@audit - Set the current validators array to be the master of ceremony
        currentValidators = [masterOfCeremony];
        //@audit - Iterate over the currentValidators array and set each validator to "true"
        //@audit - NOTE: This for loop is unecessary, as there will only ever be one address in the currentValidators array
        for (uint256 i = 0; i < currentValidators.length; i++) {
            validatorsState[currentValidators[i]] = ValidatorState({
                isValidator: true,
                index: i
            });
        }
        //@audit - Update the currentValidatorsLength to the length of the currentValidators array
        currentValidatorsLength = currentValidators.length;
        //@audit - Set the pending list array to be equal to the current validators array
        pendingList = currentValidators;
    }

    //@audit - Returns the current array of validators
    //@audit - NOTE: This only returns data in web3. Solidity does not recognize dynamic return length
    /// Get current validator set (last enacted or initial if no changes ever made)
    function getValidators() public view returns(address[]) {
        return currentValidators;
    }

    //@audit - Returns the pending validator list array
    //@audit - NOTE: This only returns data in web3. Solidity does not recognize dynamic return length
    function getPendingList() public view returns(address[]) {
        return pendingList;
    }

    //@audit - Finalizes an update to the current validators list
    //@audit - MODIFIER: onlySystemAndNotFinalized(): Sender must be the system address, and the change must not already be finalized
    /// Called when an initiated change reaches finality and is activated.
    /// Only valid when msg.sender == SUPER_USER (EIP96, 2**160 - 2)
    ///
    /// Also called when the contract is first enabled for consensus. In this case,
    /// the "change" finalized is the activation of the initial set.
    function finalizeChange() public onlySystemAndNotFinalized {
        //@audit - Set finalized to true
        finalized = true;
        //@audit - Set the current validators as equal to the pending validators
        currentValidators = pendingList;
        //@audit - Update the currentValidatorsLength
        currentValidatorsLength = currentValidators.length;
        //@audit - Emit a ChangeFinalized event
        ChangeFinalized(getValidators());
    }

    //@audit - Adds a validator
    //@audit - MODIFIER: onlyKeysManager(): Sender must be KeysManager contract
    //@audit - MODIFIER: isNewValidator(_validator): Passed-in validator must not already be a validator
    function addValidator(address _validator) public onlyKeysManager isNewValidator(_validator) {
        //@audit - Ensure the validator to be added is not 0x0
        require(_validator != address(0));
        //@audit - Create te validator's ValidatorState struct and add them to the mapping
        validatorsState[_validator] = ValidatorState({
            isValidator: true,
            index: pendingList.length
        });
        //@audit - Push the new validator to the pending list
        pendingList.push(_validator);
        //@audit - Set isFinalized to false, so the change can be finalized by the system
        finalized = false;
        //@audit - Emit an InitiateChange event
        InitiateChange(block.blockhash(block.number - 1), pendingList);
    }

    //@audit - Remove a validator
    //@audit - MODIFIER: onlyKeysManager(): Sender must be the KeysManager contract
    //@audit - MODIFIER: isNotNewValidator(_validator): Passed-in address must already be a confirmed validator
    function removeValidator(address _validator) public onlyKeysManager isNotNewValidator(_validator) {
        //@audit - The index to remove
        uint256 removedIndex = validatorsState[_validator].index;
        //@audit - The final index in the pending list array
        // Can not remove the last validator.
        uint256 lastIndex = pendingList.length - 1;
        //@audit - The validator at the last spot in the pending list
        address lastValidator = pendingList[lastIndex];
        //@audit - Set the pending list removed index to now point to the last validator
        // Override the removed validator with the last one.
        pendingList[removedIndex] = lastValidator;
        //@audit - Update the last validator's index to be the index of the removed validator
        // Update the index of the last validator.
        validatorsState[lastValidator].index = removedIndex;
        //@audit - Remove the validator at the last index from the pending list (as they are now in the new position)
        delete pendingList[lastIndex];
        //@audit - Ensure the pendingList has a nonzero length
        require(pendingList.length > 0);
        //@audit - Decrement pending list length
        pendingList.length--;
        //@audit - Set the new validator's index to 0, and their isValidator status to false
        validatorsState[_validator].index = 0;
        validatorsState[_validator].isValidator = false;
        //@audit - Set finalized to false so it can be confirmed by the system address
        finalized = false;
        //@audit - Emit an InitiateChange event
        InitiateChange(block.blockhash(block.number - 1), pendingList);
    }

    //@audit - set the ProxyStorage contract address
    function setProxyStorage(address _newAddress) public {
        //@audit - Sender must be master of ceremony
        // Address of Master of Ceremony;
        require(msg.sender == masterOfCeremony);
        //@audit - master of ceremony cannot have already initialized this contract
        require(!isMasterOfCeremonyInitialized);
        //@audit - Ensure the new address is nonzero
        require(_newAddress != address(0));
        //@audit - Set the ProxyStorage address, cast to an interface
        proxyStorage = IProxyStorage(_newAddress);
        //@audit - Set isMasterOfCeremonyInitialized to true, ensuring this address cannot be changed again
        isMasterOfCeremonyInitialized = true;
        //@audit - Emit an MoCInitializedProxyStorage event
        MoCInitializedProxyStorage(proxyStorage);
    }

    //@audit - Returns whether or not the address is a validator
    function isValidator(address _someone) public view returns(bool) {
        return validatorsState[_someone].isValidator;
    }

    //@audit - Returns the KeysManager contract address via the ProxyStorage contract
    function getKeysManager() public view returns(address) {
        return proxyStorage.getKeysManager();
    }

    //@audit - Returns the voting to change keys contract address via the ProxyStorage contract
    function getVotingToChangeKeys() public view returns(address) {
        return proxyStorage.getVotingToChangeKeys();
    }

}
