pragma solidity ^0.4.18;
import "./SafeMath.sol";
import "./interfaces/IProxyStorage.sol";
import "./interfaces/IBallotsStorage.sol";
import "./interfaces/IKeysManager.sol";


//@audit - This contract defines the voting mechanism required to change the minimum threshold for votes required to change keys
contract VotingToChangeMinThreshold {
    using SafeMath for uint256;
    //@audit - Enum representing different states of Quorum
    enum QuorumStates {Invalid, InProgress, Accepted, Rejected}
    //@audit - Enum representing different vote choices
    enum ActionChoice { Invalid, Accept, Reject }

    //@audit - The ProxyStorage contract address, cast to an interface
    IProxyStorage public proxyStorage;
    //@audit - How deep the check is supposed to go for old mining keys having voted on a ballot
    uint8 public maxOldMiningKeysDeepCheck = 25;
    //@audit - The ID of the next ballot
    uint256 public nextBallotId;
    //@audit - A dynamic array of all active ballots
    uint256[] public activeBallots;
    //@audit - The length of the activeBallots array
    uint256 public activeBallotsLength;
    //@audit - The type used in the BallotsStorage contract to represent a change in keys
    uint8 thresholdForKeysType = 1;

    //@audit - A struct representing a Ballot
    struct VotingData {
        uint256 startTime;
        uint256 endTime;
        uint256 totalVoters;
        int progress;
        bool isFinalized;
        uint8 quorumState;
        uint256 index;
        uint256 minThresholdOfVoters;
        uint256 proposedValue;
        mapping(address => bool) voters;
    }

    //@audit - Maps ballot IDs to VotingData structs
    mapping(uint256 => VotingData) public votingState;

    //@audit - Events
    event Vote(uint256 indexed decision, address indexed voter, uint256 time );
    event BallotFinalized(uint256 indexed id, address indexed voter);
    event BallotCreated(uint256 indexed id, uint256 indexed ballotType, address indexed creator);

    //@audit - Modifier: Allows only a valid passed-in voting key to continue
    modifier onlyValidVotingKey(address _votingKey) {
        //@audit - Get the KeysManager contract and cast the address to an interface
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - Ensure the passed-in voting key has active voting
        require(keysManager.isVotingActive(_votingKey));
        _;
    }

    //@audit - Modifier: Ensures thepassed-in value is valid
    modifier isValidProposedValue(uint256 _proposedValue) {
        //@audit - Get the ballotsStorage contract and cast it to an interface
        IBallotsStorage ballotsStorage = IBallotsStorage(getBallotsStorage());
        //@audit - Ensure the proposedValue is >= 3, and that the proposedValue is not the current global minimum threshold of voters
        require(_proposedValue >= 3 && _proposedValue != getGlobalMinThresholdOfVoters());
        //@audit - Ensure the proposedValue is less than or equal the amount of votes it is possible to get (via the number of validators)
        require(_proposedValue <= ballotsStorage.getProxyThreshold());
        _;
    }

    //@audit - Constructor: Sets the ProxyStorage contract and casts it to an interface
    function VotingToChangeMinThreshold(address _proxyStorage) public {
        proxyStorage = IProxyStorage(_proxyStorage);
    }

    //@audit - Allows a validator to create a ballot to change the threshold of voters required to change keys
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    //@audit - MODIFIER: isValidProposedValue(_proposedValue): Sender must input a valid proposed value for the new threshold
    function createBallotToChangeThreshold(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _proposedValue
        ) public onlyValidVotingKey(msg.sender) isValidProposedValue(_proposedValue) {
        //@audit - Ensure the current amount of ballots active is <= 100
        //@audit - CRITICAL: A sender can repeatedly create ballots that cannot be finalized by setting start times far in the future. This allows the sender to inflate
        //                   the activeBallotsLength count for each ballot created. When there are 101 active ballots, no more can be created, and none of the ballots can be finalized.
        //                   This allows a sender to completely block a change to the threshold of signatures required to change a validator's keys
        //@audit - TXIDs: (Ropsten)
        //  1. Creation of the 100th active ballot - was unable to call this function afterward, because of the check below
        //     TXID: 0xdcf8e68241a980552cb8108d7a17f07c36824caddc44b89087642d54e5c6156e
        //ISSUE FIXED IN COMMIT: ab48864
        require(activeBallotsLength <= 100);
        //@audit - Ensure the starttime and endtime are not 0
        //@audit - NOTE: This check is unecessary because the following check tests startTime against block.timestamp, which will never be 0
        require(_startTime > 0 && _endTime > 0);
        //@audit - Ensure the endtime comes after the starttime, and the starttime is after now
        require(_endTime > _startTime && _startTime > getTime());
        //@audit - Create the ballot's VotingData struct
        VotingData memory data = VotingData({
            startTime: _startTime,
            endTime: _endTime,
            totalVoters: 0,
            progress: 0,
            isFinalized: false,
            quorumState: uint8(QuorumStates.InProgress),
            index: activeBallots.length,
            proposedValue: _proposedValue,
            minThresholdOfVoters: getGlobalMinThresholdOfVoters()
        });
        //@audit - Set the voting data struct in the votingState mapping, using the nextBallotId as an index
        votingState[nextBallotId] = data;
        //@audit - Push the nextBallotId to the activeBallots array
        activeBallots.push(nextBallotId);
        //@audit - Set activeBallotsLength to the length of the activeBallots array
        activeBallotsLength = activeBallots.length;
        //@audit - Emit BallotCreated event
        BallotCreated(nextBallotId, 4, msg.sender);
        //@audit - increment nextBallotId
        nextBallotId++;
    }

    //@audit - Allow a validator to vote on a ballot denoted by the passed-in ID
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    function vote(uint256 _id, uint8 _choice) public onlyValidVotingKey(msg.sender) {
        //@audit - Get the ballot referenced by the ID
        VotingData storage ballot = votingState[_id];
        //@audit - Get the mining key of the sender
        address miningKey = getMiningByVotingKey(msg.sender);
        //@audit - Ensure the ballot and sender can vote. See the isValidVote function for more detailed notes.
        //@audit - NOTE: Put this first in the function, so that it fails quickly if the vote is invalid
        require(isValidVote(_id, msg.sender));
        //@audit - If the passed-in choice is ActionChoice.Accept
        if (_choice == uint(ActionChoice.Accept)) {
            //@audit - Increment the ballot's progress
            ballot.progress++;
        //@audit - If the passed-in choice is ActionChoice.Reject
        } else if (_choice == uint(ActionChoice.Reject)) {
            //@audit - Decrement the ballot's progress
            ballot.progress--;
        } else {
            //@audit - If the passed-in choice is invalid, revert
            revert();
        }
        //@audit - Increment the total voters for the ballot
        ballot.totalVoters++;
        //@audit - Set the mining key as having voted on this ballot
        ballot.voters[miningKey] = true;
        //@audit - Emit a Vote event
        Vote(_choice, msg.sender, getTime());
    }

    //@audit - Finalizes the ballot referenced by the passed-in ID
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    //@audit - CRITICAL: Validators can revert changes made through new ballots by calling finalize on old ballots. Because !isActive(_id) will return true
    //                   if a ballot has been finalized, a ballot can be finalized again, overwriting the changes a successive ballot made. Because any voting key can do this,
    //                   this issue completely breaks the ballot functionality of these contracts.
    //ISSUE FIXED IN COMMIT: 7bce83d
    function finalize(uint256 _id) public onlyValidVotingKey(msg.sender) {
        //@audit - Require that the ballot is inactive. See the isActive function for more detailed notes
        require(!isActive(_id));
        //@audit - get the referenced ballot
        VotingData storage ballot = votingState[_id];
        //@audit - Finalize the ballot. See the finalizeBallot function for more detailed notes
        finalizeBallot(_id);
        //@audit - Set isFinalized in the ballot to true
        ballot.isFinalized = true;
        //@audit - Emit a BallotFinalized event
        BallotFinalized(_id, msg.sender);
    }

    //@audit - Returns the BallotsStorage contract address via the ProxyStorage contract
    function getBallotsStorage() public view returns(address) {
        return proxyStorage.getBallotsStorage();
    }

    //@audit - Returns the KeysManager contract address via the ProxyStorage contract
    function getKeysManager() public view returns(address) {
        return proxyStorage.getKeysManager();
    }

    //@audit - Returns the proposed new value for the voting threshold from a ballot
    function getProposedValue(uint256 _id) public view returns(uint256) {
        return votingState[_id].proposedValue;
    }

    //@audit - Get the global minimum threshold of voters required to change a validator's keys
    function getGlobalMinThresholdOfVoters() public view returns(uint256) {
        //@audit - Get the BallotsStorage contract address and cast it to an interface
        IBallotsStorage ballotsStorage = IBallotsStorage(getBallotsStorage());
        //@audit - Return the ballot threshold for the contract variable thresholdForKeysType
        return ballotsStorage.getBallotThreshold(thresholdForKeysType);
    }

    //@audit - Returns the progress made on a ballot
    function getProgress(uint256 _id) public view returns(int) {
        return votingState[_id].progress;
    }

    //@audit - Returns the total number of voters for a ballot
    function getTotalVoters(uint256 _id) public view returns(uint256) {
        return votingState[_id].totalVoters;
    }

    //@audit - Returns the minimum threshold required for finishing a ballot referenced by the passsed-in ID
    function getMinThresholdOfVoters(uint256 _id) public view returns(uint256) {
        return votingState[_id].minThresholdOfVoters;
    }

    //@audit - Gets the mining key associated with the passed-in voting key via the KeysManager contract
    function getMiningByVotingKey(address _votingKey) public view returns(address) {
        //@audit - Get the KeysManager address and cast it to an interface
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - Get the mining key by passing in the voting key
        return keysManager.getMiningKeyByVoting(_votingKey);
    }

    //@audit - Returns the uint startTime of a ballot
    function getStartTime(uint256 _id) public view returns(uint256) {
        return votingState[_id].startTime;
    }

    //@audit - Returns the uint endTime of a ballot
    function getEndTime(uint256 _id) public view returns(uint256) {
        return votingState[_id].endTime;
    }

    //@audit - Returns true if the vote for a ballot is finalized
    function getIsFinalized(uint256 _id) public view returns(bool) {
        return votingState[_id].isFinalized;
    }

    //@audit - Returns now, and can be altered for testing purposes
    function getTime() public view returns(uint256) {
        return now;
    }

    //@audit - Returns true if the ballot referenced by _id is active
    function isActive(uint256 _id) public view returns(bool) {
        //@audit - If the ballot's start time is before now, and the ballot's end time is after now, withinTime is true
        bool withinTime = getStartTime(_id) <= getTime() && getTime() <= getEndTime(_id);
        //@audit - If the ballot is within the start time and end time, and the voting was not finalized, return true
        return withinTime && !getIsFinalized(_id);
    }

    //@audit - Checks if the ballot referenced by the passed-in _id has been voted on by the passed-in voting key
    function hasAlreadyVoted(uint256 _id, address _votingKey) public view returns(bool) {
        //@audit - Get the ballot referenced by the id
        //@audit - NOTE: Should be "memory" - state is not being changed
        VotingData storage ballot = votingState[_id];
        //@audit - get the mining key from the KeysManager
        address miningKey = getMiningByVotingKey(_votingKey);
        //@audit - Return whether or not the mining key has voted on this ballot
        return ballot.voters[miningKey];
    }

    //@audit - Checks to see if the vote id and voting key are valid
    function isValidVote(uint256 _id, address _votingKey) public view returns(bool) {
        //@audit - Gets the mining key for the passed-in voting key
        address miningKey = getMiningByVotingKey(_votingKey);
        //@audit - Checks if the voting key has voted on this _id already
        bool notVoted = !hasAlreadyVoted(_id, _votingKey);
        //@audit - Check KeysManager contract to see if any old mining keys have voted on this ballot
        bool oldKeysNotVoted = !areOldMiningKeysVoted(_id, miningKey);
        //@audit - Return true if: the voting key has not voted on this ballot, old mining keys from this key have not voted on this ballot, and the ballot is active
        return notVoted && isActive(_id) && oldKeysNotVoted;
    }

    //@audit - Uses the KeysManager contract to check if old mining keys have voted on the referenced ballot
    //@audit - MEDIUM: Validators can vote two or more times on a ballot by executing a series of mining key changes. Each time a mining key is changed, the mining key history
    //                 for that key is set to the old key through a simple mapping. When a validator votes on a ballot, their 25 most recent keys are looped through and checked to see
    //                 if they have voted on a ballot already. Consider the following scenario:
    //                 1. Validator with mining key A votes on ballot X, then passes a vote to change their mining key to key B.
    //                 History(B): B => A => 0x0
    //                 2. Validator changes their mining key to key C.
    //                 History(C): C => B => A
    //                 3. Validator changes their mining key to key B, the key they had last time.
    //                 History(B): B => C => B => C => B => ...
    //                 Because the history of C was set to B, A is no longer in either key's history as they simply reference each other. The Validator can now vote again on ballot X.
    //                 Recommended fix: Disallow changing keys to keys that were previously held.
    //ISSUE FIXED IN COMMIT: 6e3fc0a
    function areOldMiningKeysVoted(uint256 _id, address _miningKey) public view returns(bool) {
        //@audit - Get the ballot referenced by the passed-in id
        //@audit - NOTE: Should be memory - state is not being changed
        VotingData storage ballot = votingState[_id];
        //@audit - Get the KeysManager address from the ProxyStorage contract
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - Iterates over old mining keys and checks if they have voted on a ballot. Max value is 255, so this will not overflow
        for (uint8 i = 0; i < maxOldMiningKeysDeepCheck; i++) {
            //@audit - Uses the KeysManager contract to get the mining key history for the passed-in mining key
            address oldMiningKey = keysManager.miningKeyHistory(_miningKey);
            //@audit - Return false if the old mining key is 0
            if (oldMiningKey == address(0)) {
                return false;
            }
            //@audit - Return true if the old mining key has voted on this ballot
            if (ballot.voters[oldMiningKey]) {
                return true;
            } else {
                //@audit - Otherwise, set _miningKey to oldMiningKey, and continue the loop
                _miningKey = oldMiningKey;
            }
        }
        //@audit - Return false if the loop completes: none of the old keys have voted
        return false;
    }

    //@audit - Finalize a ballot referenced by the given ID
    //@audit - ACCESS: Private - can only be called from inside this contract
    function finalizeBallot(uint256 _id) private {
        //@audit - Get the BallotsStorage contract address and cast it to an interface
        IBallotsStorage ballotsStorage = IBallotsStorage(getBallotsStorage());
        //@audit - If the progress of the ballot is nonzero (that is, it has been voted on at least once), and if the total voters are above the minimum threshold required
        if (getProgress(_id) > 0 && getTotalVoters(_id) >= getMinThresholdOfVoters(_id)) {
            //@audit - Update the ballot with an "Accepted" state. See the updateBallot function for more detailed notes.
            updateBallot(_id, uint8(QuorumStates.Accepted));
            //@audit - Set the new threshold in the BallotsStorage contract
            ballotsStorage.setThreshold(getProposedValue(_id), thresholdForKeysType);
        } else {
            //@audit - Otherwise, update the ballot with a "Rejected" state
            updateBallot(_id, uint8(QuorumStates.Rejected));
        }
        //@audit - Finally, deactivate the ballot. See the deactiveBallot function for more detailed notes.
        deactiveBallot(_id);
    }

    //@audit - Update the referenced ballot with a new quorum state
    //@audit - ACCESS: Private - can only be called from inside this contract
    function updateBallot(uint256 _id, uint8 _quorumState) private {
        //@audit - Get the ballot referenced by the id
        VotingData storage ballot = votingState[_id];
        //@audit - set the new quorum state
        ballot.quorumState = _quorumState;
    }

    //@audit - Deactivate the ballot referenced by the passed-in ID
    //@audit - ACCESS: Private - can only be called from inside this contract
    //@audit - MEDIUM: This method of deactivating ballots is very unsafe. Calling delete on the ballot's index in activeBallots simply sets that index to its default values.
    //                 The length of the activeBallots array is then decremented, which will remove the final ballot from active circulation. In certain circumstances, it is possible for
    //                 a validator to have an active ballot with one more required vote to pass - the validator could then wait until a ballot is created that they want to get rid of, and then vote on
    //                 the previous ballot and call the finalize function. The old ballot would become final, and the most recently created ballot would be deleted.
    //                 Suggested fix: A safer ballot delete option would be best - swapping the last active ballot with the deactivated ballot, then decrementing the length.
    //@audit - TXIDs : (Ropsten)
    // 1. Malicious validator calls the finalize function on the aforementioned ballot, deleting the most recently created ballot:
    //    TXID:0x8b46f87cece57f339c8ceedd51297a6a1fd5cc254d344525851575631bf2912c
    //ISSUE FIXED IN COMMIT: 60c1fcf
    function deactiveBallot(uint256 _id) private {
        //@audit - Get the VotingData struct for this ballot
        VotingData memory ballot = votingState[_id];
        //@audit - Remove this ballot from the activeBallots array
        delete activeBallots[ballot.index];
        //@audit - If the length of the activeBallots array is greater than 0, decrement the length
        if (activeBallots.length > 0) {
            activeBallots.length--;
        }
        //@audit - Set activeBallotsLength to the length of the activeBallots array
        activeBallotsLength = activeBallots.length;
    }
}
