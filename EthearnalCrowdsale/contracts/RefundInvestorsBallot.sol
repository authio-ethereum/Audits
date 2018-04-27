pragma solidity ^0.4.15;

import "./EthearnalRepToken.sol";
import "./VotingProxy.sol";
import "./IBallot.sol";

contract RefundInvestorsBallot is IBallot { //@audit - contract to decide if investors want to refund the ICO

    uint256 public initialQuorumPercent = 51;
    uint256 public requiredMajorityPercent = 65;

    //@audit - Constructor: sets the token contract and voting contract
    function RefundInvestorsBallot(address _tokenContract) {
        tokenContract = EthearnalRepToken(_tokenContract);
        proxyVotingContract = VotingProxy(msg.sender); //@audit - casts the owner address to a VotingProxy address
    }

    //@audit - decision function: overrides the function defined in IBallot.sol
    function decide() internal {
        //@audit - get the current quorum percent based on time passed
        uint256 quorumPercent = getQuorumPercent();
        //@audit - quorum = (quorumPercent * EthearnalRepToken.totalSupply) / 100
        uint256 quorum = quorumPercent.mul(tokenContract.totalSupply()).div(100);
        //@audit - calculate the number of votes that have been cast
        uint256 soFarVoted = yesVoteSum.add(noVoteSum);
        //@audit - if the amount of votes is over the required quorum, proceed
        if (soFarVoted >= quorum) {
            //@audit - calculate the percent of YES votes
            uint256 percentYes = (100 * yesVoteSum).div(soFarVoted);
            //@audit - if the percent of YES votes is above 65%, enact a refund through the voting contract. Sets isVotingActive to false regardless
            if (percentYes >= requiredMajorityPercent) {
                // does not matter if it would be greater than weiRaised
                proxyVotingContract.proxyEnableRefunds();
                FinishBallot(now);
                isVotingActive = false;
            } else {
                // do nothing, just deactivate voting
                isVotingActive = false;
            }
        }
    }

    //@audit - gets the quorum percent needed to make a decision based on time. Overrides the getQuorumPercent function in IBallot.sol
    function getQuorumPercent() public constant returns (uint256) {
        //@audit - isMonthPassed = (now - ballotStarted) / 5 weeks --- Check rounding in integer divisison in Solidity
        uint256 isMonthPassed = getTime().sub(ballotStarted).div(5 weeks); //@audit - month is 5 weeks?
        if(isMonthPassed == 1){ //@audit - if a month has passed, quorumPercent is 0
            return 0;
        }
        return initialQuorumPercent; //@audit - we don't decrease quorumPercent for a refund vote
    }

}
