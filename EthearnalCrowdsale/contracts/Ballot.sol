pragma solidity ^0.4.15;

import "./EthearnalRepToken.sol";
import "./VotingProxy.sol";
import "./IBallot.sol";

contract Ballot is IBallot {

    uint256 public initialQuorumPercent = 51;

    //@audit - Constructor: sets token contract and voting contract. No need to check valid addresses, because the contract is deployed by the voting contract
    function Ballot(address _tokenContract) {
        tokenContract = EthearnalRepToken(_tokenContract);
        proxyVotingContract = VotingProxy(msg.sender);
    }

    //@audit - returns the percent required for quorum
    function getQuorumPercent() public constant returns (uint256) {
        //@audit - ensure voting is active
        require(isVotingActive);
        //@audit - weeksNumber = (now - ballotStarted) / 1 weeks
        // find number of full weeks alapsed since voting started
        uint256 weeksNumber = getTime().sub(ballotStarted).div(1 weeks);
        //@audit - NOTE: the below can be simplified to:
        /*

        return initialQuorumPercent < (weeksNumber * 10) ? 0 : initialQuorumPercent.sub(weeksNumber * 10);

        */
        //@audit - if it has been 0 weeks, return the initial percent (51)
        if(weeksNumber == 0) {
            return initialQuorumPercent;
        }
        if (initialQuorumPercent < weeksNumber * 10) {
            return 0; //@audit - returns 0 after 6 weeks
        } else {
            return initialQuorumPercent.sub(weeksNumber * 10); //@audit - (51 - (weeksNumber * 10))
        }
    }

}
