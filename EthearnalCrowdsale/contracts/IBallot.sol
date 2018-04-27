pragma solidity ^0.4.15;

import "./EthearnalRepToken.sol";
import "./VotingProxy.sol";

contract IBallot {
    using SafeMath for uint256;
    EthearnalRepToken public tokenContract;

    // Date when vote has started
    uint256 public ballotStarted;

    // Registry of votes
    mapping(address => bool) public votesByAddress;

    // Sum of weights of YES votes
    uint256 public yesVoteSum = 0;

    // Sum of weights of NO votes
    uint256 public noVoteSum = 0;

    // Length of `voters`
    uint256 public votersLength = 0;

    uint256 public initialQuorumPercent = 51;

    VotingProxy public proxyVotingContract;

    // Tells if voting process is active
    bool public isVotingActive = false;

    event FinishBallot(uint256 _time);

    modifier onlyWhenBallotStarted {
        require(ballotStarted != 0);
        _;
    }

    //@audit - CRITICAL: It is possible for anyone to stop the creation of a refund ballot by repeatedly calling startBallot in the current withdrawal ballot, and it is possible for anyone
    //                   to stop creation of an withdrawal ballot by repeatedly calling the startBallot function in a refund ballot
    //                   Suggested fix: Get rid of checks in both startRefundInvestorsBallot and startincreaseWithdrawalTeam that will stop creation if voting is active in one of the ballots, or remove
    //                   the startBallot function in the Ballot.sol contract and simply set isVotingActive to true upon contract creation.
    //@audit - TXIDs: (Kovan)
    // 1. Calling startBallot is a public function and can be called at any time as long as the ballot exists. This applies to both refund and withdraw increase ballots:
    //    TXID: 0xbb819129d313ea2c051098f12a1d9881edf298759879a69570c8d9ae869b4cec
    //ISSUE FIXED IN COMMIT: 323eb08
    //@audit - allows anyone to start the ballot
    function startBallot() public {
        ballotStarted = getTime();
        isVotingActive = true;
    }

    //@audit - allows a user to vote
    function vote(bytes _vote) public onlyWhenBallotStarted {
        require(_vote.length > 0);
        if (isDataYes(_vote)) {
            processVote(true);
        } else if (isDataNo(_vote)) {
            processVote(false);
        }
    }

    //@audit - NOTE: mark function as pure
    function isDataYes(bytes data) public constant returns (bool) {
        // compare data with "YES" string
        return (
            data.length == 3 &&
            (data[0] == 0x59 || data[0] == 0x79) &&
            (data[1] == 0x45 || data[1] == 0x65) &&
            (data[2] == 0x53 || data[2] == 0x73)
        );
    }

    //@audit - NOTE: mark function as pure
    // TESTED
    function isDataNo(bytes data) public constant returns (bool) {
        // compare data with "NO" string
        return (
            data.length == 2 &&
            (data[0] == 0x4e || data[0] == 0x6e) &&
            (data[1] == 0x4f || data[1] == 0x6f)
        );
    }

    //@audit - CRITICAL: votesByAddress[msg.sender] is never set to true, so a sender can vote multiple times
    //@audit - TXIDs: (Ropsten)
    // 1. User has voted twice:
    //    TXID: 0x7fddd88ff84a9c1a3a1040ec94ad6979c0e081fd6518b52b7bdccc6bdf0cc063
    //ISSUE FIXED IN COMMIT: 7c2c2f4
    //@audit - processes a user's vote. A user must hold tokens for their vote to count
    function processVote(bool isYes) internal {
        //@audit - ensure that voting is active
        require(isVotingActive);
        //@audit - ensure that the sender has not already voted
        require(!votesByAddress[msg.sender]);
        //@audit - increment voterlength
        votersLength = votersLength.add(1);
        //@audit - a voter has a weight equal to their token balance
        uint256 voteWeight = tokenContract.balanceOf(msg.sender); //@audit - refers to EthearnalRepToken balance
        //@audit - if the vote is yes, add the voter's weight to the yes vote
        if (isYes) {
            yesVoteSum = yesVoteSum.add(voteWeight);
        } else { //@audit - otherwise, add the voter's weight to the no vote
            noVoteSum = noVoteSum.add(voteWeight);
        }
        //@audit - require(now - EthearnalRepToken.lastMovement(msg.sender) > 7 days), meaning if someone transfers tokens, those tokens cannot vote for 7 days - CHECK THIS
        require(getTime().sub(tokenContract.lastMovement(msg.sender)) > 7 days);
        uint256 quorumPercent = getQuorumPercent(); //@audit - returns nothing here
        if (quorumPercent == 0) {
            isVotingActive = false;
        } else {
            decide();
        }
    }

    //@audit - this function processes a successful YES vote by increasing the withdrawal chunk in the treasury contract
    function decide() internal {
        //@audit - get the quorum percent. Calls a useless function in this contract, but is overwritten in the child contracts
        uint256 quorumPercent = getQuorumPercent();
        //@audit - quorum = (quorumPercent * EthearnalRepToken.totalSupply()) / 1co00
        uint256 quorum = quorumPercent.mul(tokenContract.totalSupply()).div(100);
        //@audit - calculate the number of votes cast and check if it is over the required quorum
        uint256 soFarVoted = yesVoteSum.add(noVoteSum);
        if (soFarVoted >= quorum) {
            //@audit -
            uint256 percentYes = (100 * yesVoteSum).div(soFarVoted); //@audit - SafeMath
            if (percentYes >= initialQuorumPercent) {
                // does not matter if it would be greater than weiRaised
                proxyVotingContract.proxyIncreaseWithdrawalChunk();
                FinishBallot(now); //@audit - event
                isVotingActive = false;
            } else {
                // do nothing, just deactivate voting
                isVotingActive = false;
            }
        }

    }

    function getQuorumPercent() public constant returns (uint256) {

    }

    function getTime() internal returns (uint256) {
        // Just returns `now` value
        // This function is redefined in EthearnalRepTokenCrowdsaleMock contract
        // to allow testing contract behaviour at different time moments
        return now;
    }

}
