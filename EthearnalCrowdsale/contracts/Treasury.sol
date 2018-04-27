pragma solidity ^0.4.15;

import './MultiOwnable.sol';
import './EthearnalRepTokenCrowdsale.sol';
import './EthearnalRepToken.sol';
import './VotingProxy.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract Treasury is MultiOwnable {
    using SafeMath for uint256;

    // Total amount of ether withdrawed
    uint256 public weiWithdrawed = 0;

    // Total amount of ther unlocked
    uint256 public weiUnlocked = 0;

    // Wallet withdraw is locked till end of crowdsale
    bool public isCrowdsaleFinished = false;

    // Withdrawed team funds go to this wallet
    address teamWallet = 0x0;

    // Crowdsale contract address
    EthearnalRepTokenCrowdsale public crowdsaleContract;
    EthearnalRepToken public tokenContract;
    bool public isRefundsEnabled = false;

    // Amount of ether that could be withdrawed each withdraw iteration
    uint256 public withdrawChunk = 0;
    VotingProxy public votingProxyContract;


    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);
    event UnlockWei(uint256 amount);
    event RefundedInvestor(address investor, uint256 amountRefunded, uint256 tokensBurn);

    //@audit - NOTE: A validAddress modifier would be helpful:
    /*
      modifier validAddress(address _isValid) {
        require(_isValid != address(0x0));
        _;
      }
    */

    //@audit - LOW: Because the constructor does not set the owners of the treasury contract in the constructor, they can be set at any point by the person who deployed the contract. This will not change where withdrawn
    //              funds go, as the teamWallet is separate, but the onlyOwner functions cannot be used until the owners are set.
    //@audit - TXIDs: (Ropsten)
    // 1. Creating Treasury and finishing crowdsale without initializing owners:
    //    TXID: 0x8774634eab809c0dbe3f93d0d475186d71f4dbf5cea58033ee2adbe488f6f937
    //@audit - Constructor: sets the teamWallet address
    function Treasury(address _teamWallet) public {
        require(_teamWallet != 0x0);
        // TODO: check address integrity
        teamWallet = _teamWallet;
    }

    //@audit - fallback: disallows payment from non-crowdsale addresses
    // TESTED
    function() public payable {
        require(msg.sender == address(crowdsaleContract));
        Deposit(msg.value);
    }

    //@audit - sets the contract for voting, cannot be set twice
    function setVotingProxy(address _votingProxyContract) public onlyOwner {
        require(votingProxyContract == address(0x0));
        votingProxyContract = VotingProxy(_votingProxyContract);
    }

    //@audit - sets the crowdsale contract address, cannot be set twice
    // TESTED
    function setCrowdsaleContract(address _address) public onlyOwner {
        // Could be set only once
        require(crowdsaleContract == address(0x0));
        require(_address != 0x0);
        crowdsaleContract = EthearnalRepTokenCrowdsale(_address);
    }

    //@audit - sets token contract address, cannot be set twice
    function setTokenContract(address _address) public onlyOwner {
        // Could be set only once
        require(tokenContract == address(0x0));
        require(_address != 0x0);
        tokenContract = EthearnalRepToken(_address);
    }

    //@audit - HIGH:   This function should not work if the voting proxy, crowdsale contract, and token contract are not yet set. If they are not set by the time this function is called, any owner can set a fradulent
    //                 contract in their place - such as a contract that bypasses the voting mechanism and allows for a full withdrawal of funds.
    //                 Proposed fix: Set all of these addresses in the constructor, and set up owners then as well so they cannot be changed or set at a later date.
    //@audit - TXIDs: (Ropsten)
    // 1. Function called without setting a voting proxy:
    //    TXID: 0x8774634eab809c0dbe3f93d0d475186d71f4dbf5cea58033ee2adbe488f6f937
    // 2. Setting a voting proxy after the crowdsale is finished:
    //    TXID: 0xcecfcffd230b0457cce6447d05cb26d6e88829727223290733efdc4e40d8a3a1
    // 3. Creating a malicious VotingProxy contract that does not allow for refunds and allows the team to withdraw Ether whenever they want:
    //    ADDR: 0xbfb21a96e917333dd55ef0ea2e8b1250fc5023ae
    // 4. Setting the above malicious VotingProxy contract in the Treasury contract AFTER the crowdsale is complete:
    //    TXID: 0x9a785fd3c714988e44a8dc93c653d7396709f6d586abae34982b614c18bfd101
    //ISSUE FIXED IN COMMIT: d60e2fc
    //@audit - sets the amount of wei allowed to be withdrawn - 10% of the wei raised
    // TESTED
    function setCrowdsaleFinished() public {
        //@audit - NOTE: This require is superfluous, because if the sender is the crowdsaleContract, the crowdsaleContract will not be 0x0
        require(crowdsaleContract != address(0x0));
        require(msg.sender == address(crowdsaleContract));
        //@audit - gets the amount of wei to be withdrawn - 10% of the wei raised by the crowdsale contract
        withdrawChunk = getWeiRaised().div(10);
        //@audit - sets the amount of wei unlocked so far
        weiUnlocked = withdrawChunk;
        isCrowdsaleFinished = true;
    }

    //@audit - If the crowdsale is finished, transfers the current allowed withdrawal amount to the team wallet
    // TESTED
    function withdrawTeamFunds() public onlyOwner {
        //@audit - Ensure the crowdsale is finished (only set in setCrowdsaleFinished, which can only be called by the crowdsale contract)
        require(isCrowdsaleFinished);
        //@audit - Ensure the amount already withdrawn is less than the amount allowed to be withdrawn
        require(weiUnlocked > weiWithdrawed);
        //@audit - calculate the amount allowed to be withdrawn
        uint256 toWithdraw = weiUnlocked.sub(weiWithdrawed);
        //@audit - increment weiWithdrawed
        weiWithdrawed = weiUnlocked;
        //@audit - transfer funds to the team wallet
        teamWallet.transfer(toWithdraw);
        //@audit - NOTE: This will always be 0 -> weiUnlocked = weiWithdrawed
        //@audit - Release Withdraw event
        Withdraw(weiUnlocked.sub(weiWithdrawed));
    }

    //@audit - returns the wei raised from the crowdsale contract
    function getWeiRaised() public constant returns(uint256) {
       return crowdsaleContract.weiRaised();
    }

    //@audit - allows the voting contract to increase the amount able to be withdrawn by the team
    function increaseWithdrawalChunk() {
        //@audit - ensure the crowdsale is finished
        require(isCrowdsaleFinished);
        //@audit - require that the sender is the voting contract
        require(msg.sender == address(votingProxyContract));
        //@audit - increment the wei unlocked to the team
        weiUnlocked = weiUnlocked.add(withdrawChunk);
        //@audit - release event
        UnlockWei(weiUnlocked);
    }

    //@audit - returns now, for testing purposes
    function getTime() internal returns (uint256) {
        // Just returns `now` value
        // This function is redefined in EthearnalRepTokenCrowdsaleMock contract
        // to allow testing contract behaviour at different time moments
        return now;
    }

    //@audit - enables refunds, sent only by the voting contract
    function enableRefunds() public {
        require(msg.sender == address(votingProxyContract));
        isRefundsEnabled = true;
    }

    //@audit - Refunds the sender an amount of tokens
    function refundInvestor(uint256 _tokensToBurn) public {
        //@audit - requires that refunds have been enabled by the voting contract
        require(isRefundsEnabled);
        //@audit - require that the tokenContract address has been set
        require(address(tokenContract) != address(0x0));
        //@audit - get the token rate in ETH from the crowdsale contract
        uint256 tokenRate = crowdsaleContract.getTokenRateEther();
        //@audit - calculate the amount to refund - (tokenRate * _tokensToBurn) / (1 ETH)
        uint256 toRefund = tokenRate.mul(_tokensToBurn).div(1 ether);
        //@audit - calculates the percent left from the raised funds
        uint256 percentLeft = percentLeftFromTotalRaised().mul(100*1000).div(1 ether);
        //@audit - calculates the amount to refund based on the percent left in the contract
        toRefund = toRefund.mul(percentLeft).div(100*1000);
        //@audit - ensure that there is a nonzero amount to refund
        require(toRefund > 0);
        //@audit - burns tokens from the sender
        tokenContract.burnFrom(msg.sender, _tokensToBurn);
        //@audit - transfers the refund amount to the sender and releases an event
        msg.sender.transfer(toRefund);
        RefundedInvestor(msg.sender, toRefund, _tokensToBurn);
    }

    //@audit - returns the percent left from the balance of the treasury and the total wei raised in the crowdsale, with a precision of 18
    function percentLeftFromTotalRaised() public constant returns(uint256) {
        return percent(this.balance, getWeiRaised(), 18);
    }

    //@audit - NOTE: mark function as pure
    //@audit - LOW: Use SafeMath library
    //@audit - calculates the percent given by the numerator and denominator to a certain precision, and rounds the last digit
    function percent(uint numerator, uint denominator, uint precision) internal constant returns(uint quotient) {
        // caution, check safe-to-multiply here
        uint _numerator  = numerator * 10 ** (precision+1);
        // with rounding of last digit
        uint _quotient =  ((_numerator / denominator) + 5) / 10;
        return ( _quotient);
    }
}
