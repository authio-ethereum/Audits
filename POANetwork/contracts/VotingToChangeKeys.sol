pragma solidity ^0.4.18;
import "./SafeMath.sol";
import "./interfaces/IProxyStorage.sol";
import "./interfaces/IBallotsStorage.sol";
import "./interfaces/IKeysManager.sol";

//@audit - This contract defines the voting mechanism required to change validator keys
contract VotingToChangeKeys {
    using SafeMath for uint256;

    //@audit - Enum for different types of ballot
    enum BallotTypes {Invalid, Adding, Removal, Swap}
    //@audit - Enum for different types of key
    enum KeyTypes {Invalid, MiningKey, VotingKey, PayoutKey}
    //@audit - Enum for different levels of quorum
    enum QuorumStates {Invalid, InProgress, Accepted, Rejected}
    //@audit - Enum representing different voting types
    enum ActionChoice { Invalid, Accept, Reject }

    //@audit - Reference to the ProxyStorage contract, cast to the IProxyStorage interface
    IProxyStorage public proxyStorage;
    //@audit - The maximum amount of old mining keys to check for votes on a ballot
    uint8 public maxOldMiningKeysDeepCheck = 25;
    //@audit - uint ID of the next Ballot
    uint256 public nextBallotId;
    //@audit - dynamic array of current active ballots
    uint256[] public activeBallots;
    //@audit - The length of the activeBallots array
    uint256 public activeBallotsLength;
    //@audit - The threshold type for changing keys
    uint8 thresholdForKeysType = 1;

    //@audit - Represents different data for voting
    struct VotingData {
        uint256 startTime;
        uint256 endTime;
        address affectedKey;
        uint256 affectedKeyType;
        address miningKey;
        uint256 totalVoters;
        int progress;
        bool isFinalized;
        uint8 quorumState;
        uint256 ballotType;
        uint256 index;
        uint256 minThresholdOfVoters;
        mapping(address => bool) voters;
    }

    //@audit - Maps a ballot ID to its VotingData struct
    mapping(uint256 => VotingData) public votingState;

    //@audit - Events
    event Vote(uint256 indexed decision, address indexed voter, uint256 time );
    event BallotFinalized(uint256 indexed id, address indexed voter);
    event BallotCreated(uint256 indexed id, uint256 indexed ballotType, address indexed creator);

    //@audit - Modifier throws if a passed-in voting key is invalid. Uses keys stored in the KeysManager
    modifier onlyValidVotingKey(address _votingKey) {
        IKeysManager keysManager = IKeysManager(getKeysManager());
        require(keysManager.isVotingActive(_votingKey));
        _;
    }

    //@audit - Constructor: sets the ProxyStorage contract, and casts it to its defined interface
    function VotingToChangeKeys(address _proxyStorage) public {
        proxyStorage = IProxyStorage(_proxyStorage);
    }

    //@audit - Allows for the creation of a ballot to change a validator's keys
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    function createVotingForKeys(
        uint256 _startTime,
        uint256 _endTime,
        address _affectedKey,
        uint256 _affectedKeyType,
        address _miningKey,
        uint256 _ballotType
    ) public onlyValidVotingKey(msg.sender) {
        //@audit - Ensure the starttime and endtime are not 0
        //@audit - NOTE: This check is unecessary because the following check tests startTime against block.timestamp, which will never be 0
        require(_startTime > 0 && _endTime > 0);
        //@audit - Ensure the endtime is after the starttime, and that the starttime is after the current time
        require(_endTime > _startTime && _startTime > getTime());
        //@audit - Ensure the parameters of the ballot are valid
        //only if ballotType is swap or remove
        require(areBallotParamsValid(_ballotType, _affectedKey, _affectedKeyType, _miningKey));
        //@audit - Initialize VotingData struct
        VotingData memory data = VotingData({
            startTime: _startTime,
            endTime: _endTime,
            affectedKey: _affectedKey, //@audit - The key affected by voting
            affectedKeyType: _affectedKeyType, //@audit - The type of the key affected by voting
            miningKey: _miningKey, //@audit - The mining key associated with the affected key
            totalVoters: 0, //@audit - The number of voters so far
            progress: 0, //@audit - Progress can be negative or positive, depending on yes or no votes
            isFinalized: false, //@audit - Whether a ballot is finalized
            quorumState: uint8(QuorumStates.InProgress), //@audit - The state of the ongoing vote
            ballotType: _ballotType, //@audit - The type of ballot: Add, Remove, or Swap
            index: activeBallots.length, //@audit - the index of the ballot
            minThresholdOfVoters: getGlobalMinThresholdOfVoters() //@audit - Sets the minimum threshold of voters
        });
        //@audit - Set the VotingData struct in the votingState mapping
        votingState[nextBallotId] = data;
        //@audit - Pushes the ballot ID to the active ballots array
        activeBallots.push(nextBallotId);
        //@audit - Set activeBallotsLength to the length of the activeBallots array
        activeBallotsLength = activeBallots.length;
        //@audit - Emit a BallotCreated event
        BallotCreated(nextBallotId, _ballotType, msg.sender);
        //@audit - Increment the ID for the next ballot
        nextBallotId++;
    }

    //@audit - Allows a validator to vote on a ballot
    //@audit - MODIFIER: onlyValidVotingKey(msg.sender): Sender must have a vaild voting key, as set by the KeysManager contract
    function vote(uint256 _id, uint8 _choice) public onlyValidVotingKey(msg.sender) {
        //@audit - Gets a ballot from the votingState mapping, using the input _id as the index
        VotingData storage ballot = votingState[_id];
        //@audit - Gets the mining key for the sender from the KeysManager contract
        // // check for validation;
        address miningKey = getMiningByVotingKey(msg.sender);
        //@audit - Ensure the vote passed in is valid for the sender. Calls isValidVote - see the function below for more explanation
        //@audit - NOTE: Place this first in the function so it fails quickly
        require(isValidVote(_id, msg.sender));
        //@audit - If the passed-in choice is ActionChoice.Accept
        if (_choice == uint(ActionChoice.Accept)) {
            //@audit - increment the ballot's progress
            ballot.progress++;
        //@audit - If the passed-in choice is ActionChoice.Reject
        } else if (_choice == uint(ActionChoice.Reject)) {
            //@audit - decrement the ballot's progress
            ballot.progress--;
        } else {
            //@audit - If the passed-in choice is neither Accept nor Reject, revert the transaction
            revert();
        }
        //@audit - increment the total voters for this ballot
        ballot.totalVoters++;
        //@audit - This mining key has voted, so set it to true
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

    //@audit - Returns the BallotsStorage contract address
    function getBallotsStorage() public view returns(address) {
        return proxyStorage.getBallotsStorage();
    }

    //@audit - Gets the KeysManager address from the ProxyStorage contract
    function getKeysManager() public view returns(address) {
        return proxyStorage.getKeysManager();
    }

    //@audit - Returns the number of voters required for a ballot to continue, via the BallotsStorage contract
    function getGlobalMinThresholdOfVoters() public view returns(uint256) {
        IBallotsStorage ballotsStorage = IBallotsStorage(getBallotsStorage());
        return ballotsStorage.getBallotThreshold(thresholdForKeysType);
    }

    //@audit - Returns the progress made on a ballot. Every vote registered in a given ballot increments this by 1
    function getProgress(uint256 _id) public view returns(int) {
        return votingState[_id].progress;
    }

    //@audit - Returns the number of voters that have voted on a ballot referenced by the passed-in ID
    function getTotalVoters(uint256 _id) public view returns(uint256) {
        return votingState[_id].totalVoters;
    }

    //@audit - Returns the minimum number of voters required to continue
    function getMinThresholdOfVoters(uint256 _id) public view returns(uint256) {
        return votingState[_id].minThresholdOfVoters;
    }

    //@audit - Returns the key type associated with the ballot
    function getAffectedKeyType(uint256 _id) public view returns(uint256) {
        return votingState[_id].affectedKeyType;
    }

    //@audit - Get the affected key associated with a ballot
    function getAffectedKey(uint256 _id) public view returns(address) {
        return votingState[_id].affectedKey;
    }

    //@audit - Gets the mining key associated with a ballot
    function getMiningKey(uint256 _id) public view returns(address) {
        return votingState[_id].miningKey;
    }

    //@audit - Returns the address of the mining key for the sender, using the passed-in voting key
    function getMiningByVotingKey(address _votingKey) public view returns(address) {
        IKeysManager keysManager = IKeysManager(getKeysManager());
        return keysManager.getMiningKeyByVoting(_votingKey);
    }

    //@audit - Returns teh ballot type of the ballot associated with the passed-in id
    function getBallotType(uint256 _id) public view returns(uint256) {
        return votingState[_id].ballotType;
    }

    //@audit - returns the start time of a ballot referenced by a passed-in ID
    function getStartTime(uint256 _id) public view returns(uint256) {
        return votingState[_id].startTime;
    }

    //@audit - returns the end time of a ballot referenced by a passed-in ID
    function getEndTime(uint256 _id) public view returns(uint256) {
        return votingState[_id].endTime;
    }

    //@audit - returns whether or not the ballot referenced by a passed-in ID is finalized
    function getIsFinalized(uint256 _id) public view returns(bool) {
        return votingState[_id].isFinalized;
    }

    //@audit - Returns now, but can be changed for testing purposes
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
        //@audit - NOTE: Should be memory - State is not modified
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
        //@audit - Get the KeysManager address from the ProxyStorage contract
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - Get the ballot referenced by the passed-in id
        //@audit - NOTE: Should be memory - State is not modified
        VotingData storage ballot = votingState[_id];
        //@audit - Iterate over old mining keys to see if they have voted on this ballot
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

    //@audit - Returns true if the ballot parameters are valid
    function areBallotParamsValid(
        uint256 _ballotType,
        address _affectedKey,
        uint256 _affectedKeyType,
        address _miningKey) public view returns(bool)
    {
        //@audit - Ensure the affectedKeyType is not 0, as 0 is KeyTypes.Invalid
        require(_affectedKeyType > 0);
        //@audit - Ensure that the affected key is a valid address
        require(_affectedKey != address(0));
        //@audit - Require that the length of the active ballots array be less than 100
        //@audit - CRITICAL: A sender can repeatedly create ballots that cannot be finalized by setting start times far in the future. This allows the sender to inflate
        //                   the activeBallotsLength count for each ballot created. When there are 101 active ballots, no more can be created, and none of the ballots can be finalized.
        //                   This allows a sender to completely block the creation of any more votes to change addresses.
        //@audit - TXIDs: (Ropsten)
        //  1. Creation of the 100th active ballot - was unable to call this function afterward, because of the check below
        //     TXID: 0xdcf8e68241a980552cb8108d7a17f07c36824caddc44b89087642d54e5c6156e
        //ISSUE FIXED IN COMMIT: ab48864
        require(activeBallotsLength <= 100);
        //@audit - casts the KeysManager contract address to an interface
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - Checks if the mining key is active using the KeysManager contract
        bool isMiningActive = keysManager.isMiningActive(_miningKey);
        //@audit - If the passed-in affected key type is KeyTypes.MiningKey
        if (_affectedKeyType == uint256(KeyTypes.MiningKey)) {
            //@audit - If the passed-in ballot type is BallotTypes.Removal, returns true if mining is active for the passed-in mining key
            if (_ballotType == uint256(BallotTypes.Removal)) {
                return isMiningActive;
            }
            //@audit - If the passed-in ballot type is BallotTypes.Adding, returns true
            if (_ballotType == uint256(BallotTypes.Adding)) {
                return true;
            }
        }
        //@audit - If the affected key is the passed-in mining key, throw
        require(_affectedKey != _miningKey);
        //@audit - If the passed-in ballot type is BallotTypes.Removal or BallotTypes.Swap
        if (_ballotType == uint256(BallotTypes.Removal) || _ballotType == uint256(BallotTypes.Swap)) {
            //@audit - If the affected key type is KeyTypes.MiningKey, return true if mining is active for the passed-in mining key
            if (_affectedKeyType == uint256(KeyTypes.MiningKey)) {
                return isMiningActive;
            }
            //@audit - If the affected key type is KeyTypes.VotingKey
            if (_affectedKeyType == uint256(KeyTypes.VotingKey)) {
                //@audit - Use the KeysManager to get the voting key from the mining key
                address votingKey = keysManager.getVotingByMining(_miningKey);
                //@audit - Return true if: voting is active on the passed-in voting key, the affected key is the voting key, and mining is active on the passed-in mining key
                return keysManager.isVotingActive(votingKey) && _affectedKey == votingKey && isMiningActive;
            }
            //@audit - if the affected key type is KeyTypes.PayoutKey
            if (_affectedKeyType == uint256(KeyTypes.PayoutKey)) {
                //@audit - Get the payout key from the KeysManager
                address payoutKey = keysManager.getPayoutByMining(_miningKey);
                //@audit - Returna true if: payout is active for the passed-in mining key, the affected key is the payout key, and mining is active on the passed-in mining key
                return keysManager.isPayoutActive(_miningKey) && _affectedKey == payoutKey && isMiningActive;
            }
        }
        //@audit - Otherwise, return true
        return true;
    }

    //@audit - finalizes a ballot referenced by the given id
    //@audit - ACCESS: Private - can only be called from inside this contract
    function finalizeBallot(uint256 _id) private {
        //@audit - If at least one vote has been made, and the number of voters for the ballot is above the ballot's minimum threshold
        if (getProgress(_id) > 0 && getTotalVoters(_id) >= getMinThresholdOfVoters(_id)) {
            //@audit - Update the ballot with the QuorumStates.Accepted enum
            updateBallot(_id, uint8(QuorumStates.Accepted));
            //@audit - If the ballot type is BallotTypes.Adding
            if (getBallotType(_id) == uint256(BallotTypes.Adding)) {
                //@audit - Finalize an Adding ballot. See the finalizeAdding function for more detailed notes
                finalizeAdding(_id);
            //@audit - If the ballot type is BallotTypes.Removal
            } else if (getBallotType(_id) == uint256(BallotTypes.Removal)) {
                //@audit - Finalize the removal of a key. See the finalizeRemoval function for more detailed notes
                finalizeRemoval(_id);
            //@audit - If the ballot type is BallotTypes.Swap
            } else if (getBallotType(_id) == uint256(BallotTypes.Swap)) {
                //@audit - Finalize a key swap. See the finalizeSwap function for more detailed notes
                finalizeSwap(_id);
            }
        } else {
            //@audit - No votes have been cast, or the number of voters on the ballot has not passed the minimum threshold
            updateBallot(_id, uint8(QuorumStates.Rejected));
        }
        //@audit - Deactivate the ballot. See the deactiveBallot function for more detailed notes
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

    //@audit - Finalizes an Adding-type ballot
    //@audit - ACCESS: Private - can only be called from inside this contract
    function finalizeAdding(uint256 _id) private {
        //@audit - Ensure that the passed-in ballot type is BallotTypes.Adding
        require(getBallotType(_id) == uint256(BallotTypes.Adding));
        //@audit - Get the KeysManager address and cast it to an interface
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - If the affected key type is KeyTypes.MiningKey
        //@audit - NOTE: The key type must be one of these three, so having 3 if statements wastes gas. Consider an if-else structure instead
        if (getAffectedKeyType(_id) == uint256(KeyTypes.MiningKey)) {
            //@audit - Add a Mining Key to the KeysManager contract
            keysManager.addMiningKey(getAffectedKey(_id));
        }
        //@audit - If the affected key type is KeyTypes.VotingKey
        if (getAffectedKeyType(_id) == uint256(KeyTypes.VotingKey)) {
            //@audit - Add a Voting Key to the KeysManager contract
            keysManager.addVotingKey(getAffectedKey(_id), getMiningKey(_id));
        }
        //@audit - If the affected key type is KeyTypes.PayoutKey
        if (getAffectedKeyType(_id) == uint256(KeyTypes.PayoutKey)) {
            //@audit - Add a PayoutKey to the KeysManager contract
            keysManager.addPayoutKey(getAffectedKey(_id), getMiningKey(_id));
        }
    }

    //@audit - Finalizes a Removal-type ballot
    //@audit - ACCESS: Private - can only be called from inside this contract
    function finalizeRemoval(uint256 _id) private {
        //@audit - Ensure that the ballot type is BallotTypes.Removal
        require(getBallotType(_id) == uint256(BallotTypes.Removal));
        //@audit - Get the KeysManager address and cast it to an interface
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - If the affected key type is KeyTypes.MiningKey
        //@audit - NOTE: The key type must be one of these three, so having 3 if statements wastes gas. Consider an if-else structure instead
        if (getAffectedKeyType(_id) == uint256(KeyTypes.MiningKey)) {
            //@audit - Remove the mining key through the KeysManager contract
            keysManager.removeMiningKey(getAffectedKey(_id));
        }
        //@audit - If the affected key type is KeyTypes.VotingKey
        if (getAffectedKeyType(_id) == uint256(KeyTypes.VotingKey)) {
            //@audit - Remove the voting key via the KeysManager contract
            keysManager.removeVotingKey(getMiningKey(_id));
        }
        //@audit - If the affected key type is KeyTypes.PayoutKey
        if (getAffectedKeyType(_id) == uint256(KeyTypes.PayoutKey)) {
            //@audit - Remove the payout key via the KeysManager contract
            keysManager.removePayoutKey(getMiningKey(_id));
        }
    }

    //@audit - Finalizes a Swap-type ballot
    //@audit - ACCESS: Private - can only be called from inside this contract
    function finalizeSwap(uint256 _id) private {
        //@audit - Ensure that the ballot type is BallotTypes.Removal
        require(getBallotType(_id) == uint256(BallotTypes.Swap));
        //@audit - Get the KeysManager address and cast it to an interface
        IKeysManager keysManager = IKeysManager(getKeysManager());
        //@audit - If the affected key type is KeyTypes.MiningKey
        //@audit - NOTE: The key type must be one of these three, so having 3 if statements wastes gas. Consider an if-else structure instead
        if (getAffectedKeyType(_id) == uint256(KeyTypes.MiningKey)) {
            //@audit - Swap out the mining key with the new key
            keysManager.swapMiningKey(getAffectedKey(_id), getMiningKey(_id));
        }
        //@audit - If the affected key type is KeyTypes.VotingKey
        if (getAffectedKeyType(_id) == uint256(KeyTypes.VotingKey)) {
            //@audit - Swap the voting key with the new key
            keysManager.swapVotingKey(getAffectedKey(_id), getMiningKey(_id));
        }
        //@audit - If the affected key type is KeyTypes.PayoutKey
        if (getAffectedKeyType(_id) == uint256(KeyTypes.PayoutKey)) {
            //@audit - Swap the payout key with the new key
            keysManager.swapPayoutKey(getAffectedKey(_id), getMiningKey(_id));
        }
    }
}
