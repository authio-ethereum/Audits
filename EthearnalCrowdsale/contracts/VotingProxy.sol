pragma solidity ^0.4.15;

import './Treasury.sol';
import './Ballot.sol';
import './RefundInvestorsBallot.sol';
import "./EthearnalRepToken.sol";
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract VotingProxy is Ownable {
    using SafeMath for uint256;
    Treasury public treasuryContract;
    EthearnalRepToken public tokenContract;
    Ballot public currentIncreaseWithdrawalTeamBallot;
    RefundInvestorsBallot public currentRefundInvestorsBallot;

    //@audit - NOTE: ensure addresses are valid (not 0x0)
    //@audit - Constructor: sets treasuryContract and tokenContract
    function  VotingProxy(address _treasuryContract, address _tokenContract) {
        treasuryContract = Treasury(_treasuryContract);
        tokenContract = EthearnalRepToken(_tokenContract);
    }

    //@audit - allows the owner of the contract to create a withdrawal ballot
    function startincreaseWithdrawalTeam() onlyOwner {
        require(treasuryContract.isCrowdsaleFinished()); //@audit - requires the crowdsale to be finished before this is called
        //@audit - ensure that either the current refund ballot does not exist, or does not have active voting
        require(address(currentRefundInvestorsBallot) == 0x0 || currentRefundInvestorsBallot.isVotingActive() == false);
        //@audit - if there is no current increase withdrawal ballot, create one
        if(address(currentIncreaseWithdrawalTeamBallot) == 0x0) {
            currentIncreaseWithdrawalTeamBallot =  new Ballot(tokenContract);
        } else {
            //@audit - ensure that the previous ballot was more than two days ago
            require(getDaysPassedSinceLastTeamFundsBallot() > 2);
            //@audit - create and deploy new ballot
            currentIncreaseWithdrawalTeamBallot =  new Ballot(tokenContract);
        }
    }

    //@audit - allows anyone to create a refund investor ballot
    function startRefundInvestorsBallot() public {
        //@audit - ensure that the crowdsale is over (set in the treasury contract by the crowdsale contract upon completion)
        require(treasuryContract.isCrowdsaleFinished());
        //@audit - if there is no current withdraw ballot, or the current ballot does not have active voting
        require(address(currentIncreaseWithdrawalTeamBallot) == 0x0 || currentIncreaseWithdrawalTeamBallot.isVotingActive() == false);
        //@audit - if there is no current
        if(address(currentRefundInvestorsBallot) == 0x0) {
            currentRefundInvestorsBallot =  new RefundInvestorsBallot(tokenContract);
        } else {
            require(getDaysPassedSinceLastRefundBallot() > 2);
            currentRefundInvestorsBallot =  new RefundInvestorsBallot(tokenContract);
        }
    }

    //@audit - NOTE: since this is a public function, if the currentRefundInvestorsBallot is 0x0, this will not work. Consider adding a check
    //@audit - gets the number of days since the last refund ballot
    function getDaysPassedSinceLastRefundBallot() public constant returns(uint256) {
        return getTime().sub(currentRefundInvestorsBallot.ballotStarted()).div(1 days);
    }

    //@audit - NOTE: since this is a public function, if the currentRefundInvestorsBallot is 0x0, this will not work. Consider adding a check
    //@audit - gets the number of days since the last team funding ballot
    function getDaysPassedSinceLastTeamFundsBallot() public constant returns(uint256) {
        return getTime().sub(currentIncreaseWithdrawalTeamBallot.ballotStarted()).div(1 days);
    }

    //@audit - allows the withdrawal team ballot to increase the withdrawal amount of the treasury contract (increases by 10% of total wei raised)
    function proxyIncreaseWithdrawalChunk() public {
        require(msg.sender == address(currentIncreaseWithdrawalTeamBallot));
        treasuryContract.increaseWithdrawalChunk();
    }

    //@audit - allows the refund investor ballot to enable refunds in the treasury contract
    function proxyEnableRefunds() public {
        require(msg.sender == address(currentRefundInvestorsBallot));
        treasuryContract.enableRefunds();
    }

    //@audit - rejects payments via fallback
    function() {
        revert();
    }

    //@audit - returns the current time (now) for testing purposes
    function getTime() internal returns (uint256) {
        // Just returns `now` value
        // This function is redefined in EthearnalRepTokenCrowdsaleMock contract
        // to allow testing contract behaviour at different time moments
        return now;
    }


}
