pragma solidity ^0.4.18;
import "./SafeMath.sol";
import "./interfaces/IBallotsStorage.sol";
import "./interfaces/IProxyStorage.sol";
import "./interfaces/IKeysManager.sol";


//@audit - Keeps track of information on each network validator
contract ValidatorMetadata {
    using SafeMath for uint256;

    //@audit - Represents the information kept on a validator
    struct Validator {
        bytes32 firstName;
        bytes32 lastName;
        bytes32 licenseId;
        string fullAddress;
        bytes32 state;
        uint256 zipcode;
        uint256 expirationDate;
        uint256 createdDate;
        uint256 updatedDate;
        uint256 minThreshold;
    }

    //@audit - Interface to the ProxyStorage contract
    IProxyStorage public proxyStorage;
    //@audit - Events
    event MetadataCreated(address indexed miningKey);
    event ChangeRequestInitiated(address indexed miningKey);
    event CancelledRequest(address indexed miningKey);
    event Confirmed(address indexed miningKey, address votingSender);
    event FinalizedChange(address indexed miningKey);
    //@audit - Maps addresses to Validator metadata structs
    mapping(address => Validator) public validators;
    //@audit - Maps addresses to requested changes to Validator metadata structs
    mapping(address => Validator) public pendingChanges;
    //@audit - Maps addresses to the number of confirmations a validator metadata change request has received
    mapping(address => uint256) public confirmations;

    //@audit - Modifier throws if an invalid voting key is passed in
    modifier onlyValidVotingKey(address _votingKey) {
        //@audit - Gets the keysManager address and casts it to the IKeysManager interface
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - throw if the passed-in voting key is not active in the KeysManager contract
        require(keysManager.isVotingActive(_votingKey));
        _;
    }

    //@audit - Modifier ensures a function is only accessed by a validator that has not been initialized fully yet
    modifier onlyFirstTime(address _votingKey) {
        //@audit - Gets the mining key for the sending address
        //@audit - NOTE: This was probably meant to be _votingKey
        address miningKey = getMiningByVotingKey(msg.sender);
        //@audit - Gets the validator struct for the validator with the given mining key
        //@audit - NOTE: Use the keyword "memory" here, as the Validator struct is not being modified
        Validator storage validator = validators[miningKey];
        //@audit - Ensure that the validator's created date is 0, meaning this validator has not been created yet.
        require(validator.createdDate == 0);
        _;
    }

    //@audit - Constructor: casts the ProxyStorage contract to an interface
    function ValidatorMetadata(address _proxyStorage) public {
        proxyStorage = IProxyStorage(_proxyStorage);
    }

    //@audit - Creates and adds a validator struct for the sender.
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    //@audit - MODIFIER: onlyFirstTime(msg.sender): Sender must not already be initialized (checked by testing createdDate == 0)
    function createMetadata(
        bytes32 _firstName,
        bytes32 _lastName,
        bytes32 _licenseId,
        string _fullAddress,
        bytes32 _state,
        uint256 _zipcode,
        uint256 _expirationDate ) public onlyValidVotingKey(msg.sender) onlyFirstTime(msg.sender) {
        //@audit - Creates the validator struct for this validator
        Validator memory validator = Validator({
            firstName: _firstName,
            lastName: _lastName,
            licenseId: _licenseId,
            fullAddress: _fullAddress,
            zipcode: _zipcode,
            state: _state,
            expirationDate: _expirationDate,
            createdDate: getTime(), //@audit - getTime returns now, but can be changed for testing purposes
            updatedDate: 0, //@audit - Sets updatedDate to 0 - will change when a changeRequest is completed
            minThreshold: getMinThreshold() //@audit - gets the minimum threshhold from the BallotsStorage contract
        });
        //@audit - Gets the mining key for the sender by calling the KeysManager contract
        address miningKey = getMiningByVotingKey(msg.sender);
        //@audit - Assign the validator struct to the validators mapping, indexed by their mining Key
        validators[miningKey] = validator;
        //@audit - Emits MetadataCreated event
        MetadataCreated(miningKey);
    }

    //@audit - Initiates a request for a change in validator metadata
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a valid voting key, as set by the KeysManager contract
    //@audit - LOW: Sender can call this function without having called createMetadata. This would allow a validator to, instead of calling createMetadata initially, call changeRequest,
    //              pass a ballot to set their metadata, and then at any point in the future call createMetadata and change their metadata without needing a vote to do so.
    function changeRequest(
        bytes32 _firstName,
        bytes32 _lastName,
        bytes32 _licenseId,
        string _fullAddress,
        bytes32 _state,
        uint256 _zipcode,
        uint256 _expirationDate
        ) public onlyValidVotingKey(msg.sender) returns(bool) {
        //@audit - Gets the mining key for the sender from the KeysManager contract
        address miningKey = getMiningByVotingKey(msg.sender);
        //@audit - Sets the requested updated Validator struct, pulling createdDate and minThreshold from the already-created Validator. Sets updatedDate to now
        Validator memory pendingChange = Validator({
            firstName: _firstName,
            lastName: _lastName,
            licenseId: _licenseId,
            fullAddress:_fullAddress,
            state: _state,
            zipcode: _zipcode,
            expirationDate: _expirationDate,
            createdDate: validators[miningKey].createdDate,
            updatedDate: getTime(),
            minThreshold: validators[miningKey].minThreshold
        });
        //@audit - Stores the requested change in the pendingChanges mapping
        pendingChanges[miningKey] = pendingChange;
        //@audit - Emits a ChangeRequestInitiated event
        ChangeRequestInitiated(miningKey);
        return true;
    }

    //@audit - Allows a validator to cancel a pending metadata request
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    function cancelPendingChange() public onlyValidVotingKey(msg.sender) returns(bool) {
        //@audit - gets the mining key for the sender via the KeysManager contract
        address miningKey = getMiningByVotingKey(msg.sender);
        //@audit - removes the pending validator metadata change
        delete pendingChanges[miningKey];
        //@audit - Emits a CancelledRequest event
        CancelledRequest(miningKey);
        //@audit - returns true
        return true;
    }

    //@audit - Allows a validator to confirm a pending metadata change
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    //@audit - LOW: Voting keys can confirm a metadata change by calling this function repeatedly, because the function does not check to see if a key has already confirmed.
    //              Suggested fix: We recommended a new structure for pending changes and confirmations that allowed for efficient insertion, lookup, and removal of pending requests and sent it to
    //              the Oracles Network team. The new structure got rid of double voting and reduced the amount of spam-requests able to be created.
    //@audit - TXIDs: (Ropsten)
    //  1. Sender confirms metadata change for a validator by calling this function twice:
    //     TXID: 0x1857eef3208d617f9d0d564ba3fbdc201695b92274f1c73ef560758240fcee83
    //ISSUE FIXED IN COMMIT: 8389e69
    function confirmPendingChange(address _miningKey) public onlyValidVotingKey(msg.sender) {
        //@audit - gets the mining key for the sender via the KeysManager contract
        address miningKey = getMiningByVotingKey(msg.sender);
        //@audit - Ensure the validator cannot confirm their own metadata change request
        require(miningKey != _miningKey);
        //@audit - increment confirmations accrued by a mining key
        confirmations[_miningKey] = confirmations[_miningKey].add(1);
        //@audit - Emits a Confirmed event
        Confirmed(_miningKey, msg.sender);
    }

    //@audit - Finalizes a metadata change request, if the confirmations recieved are above the minimum threshold
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    function finalize(address _miningKey) public onlyValidVotingKey(msg.sender) {
        //@audit - Throw if the confirmations recieved for the change are below the minimum threshold
        require(confirmations[_miningKey] >= pendingChanges[_miningKey].minThreshold);
        //@audit - The confirmations are higher than the minimum threshold, so the validator metadata is changed
        validators[_miningKey] = pendingChanges[_miningKey];
        //@audit - the pending change is deleted
        delete pendingChanges[_miningKey];
        //@audit - Emits a FinalizedChange event
        FinalizedChange(_miningKey);
    }

    //@audit - For a passed-in voting key, returns the mining key associated with that address
    function getMiningByVotingKey(address _votingKey) public view returns(address) {
        //@audit - Gets the KeysManager contract address and casts it to an interface
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - Returns the mining key via a passed-in voting key
        return keysManager.getMiningKeyByVoting(_votingKey);
    }

    //@audit - Returns now, but can be changed for testing purposes
    function getTime() public view returns(uint256) {
        return now;
    }

    //@audit - Returns the minimum confimations required to change metadata
    function getMinThreshold() public view returns(uint256) {
        //@audit - Safe, efficient uint8. No danger of under/overflow because it does not change in value
        uint8 thresholdType = 2; //@audit - Threshold for metadata change is represented by the number 2 in BallotsStorage
        //@audit - Gets the BallotsStorage contract and casts it to an interface
        IBallotsStorage ballotsStorage = IBallotsStorage(getBallotsStorage());
        //@audit - returns the BallotsStorage threshold with the given thresholdType (2)
        return ballotsStorage.getBallotThreshold(thresholdType);
    }

    //@audit - Returns the BallotsStorage contract address, stored in the ProxyStorage contract
    function getBallotsStorage() public view returns(address) {
        return proxyStorage.getBallotsStorage();
    }

    //@audit - Returns the address of the keys manager contract from the ProxyStorage contract
    function getKeysManager() public view returns(address) {
        return proxyStorage.getKeysManager();
    }


}
