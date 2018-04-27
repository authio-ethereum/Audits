pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './EthearnalRepToken.sol';
import './Treasury.sol';
import "./MultiOwnable.sol";

//@audit - LOW: The crowdsale can be started with a token contract that has nonzero funds, because the deployer of the token contract can use its public mint function. This is potentially misleading to those entering
//@audit        the contract, as a nonzero totalSupply can be easily rationalized as incoming purchases.
//ISSUE FIXED IN COMMIT: af6d68e
contract EthearnalRepTokenCrowdsale is MultiOwnable {
    using SafeMath for uint256;

    /* *********************
     * Variables & Constants
     */

    // Token Contract
    EthearnalRepToken public token; //@audit - keeps track of the ERT token

    //@audit - NOTE: Ensure the ETH rate USD is updated before the crowdsale
    // Ethereum rate, how much USD does 1 ether cost
    // The actual value is set by setEtherRateUsd
    uint256 etherRateUsd = 300;

    // Token price in Ether, 1 token is 0.5 USD, 3 decimals
    uint256 public tokenRateUsd = (1 * 1000) / uint256(2);

    // Mainsale Start Date (11 Nov 16:00 UTC)
    uint256 public constant saleStartDate = 1510416000;

    // Mainsale End Date (11 Dec 16:00 UTC)
    uint256 public constant saleEndDate = 1513008000;

    // How many tokens generate for the team, ratio with 3 decimals digits
    uint256 public constant teamTokenRatio = uint256(1 * 1000) / 3;

    // Crowdsale State
    enum State {
        BeforeMainSale, // pre-sale finisehd, before main sale
        MainSale, // main sale is active
        MainSaleDone, // main sale done, ICO is not finalized
        Finalized // the final state till the end of the world
    }

    //@audit - sale cap: 30,000,000 USD
    // Hard cap for total sale
    uint256 public saleCapUsd = 30 * (10**6);

    // Money raised totally
    uint256 public weiRaised = 0;

    // This event means everything is finished and tokens
    // are allowed to be used by their owners
    bool public isFinalized = false;

    // Wallet to send team tokens
    address public teamTokenWallet = 0x0;

    // money received from each customer
    mapping(address => uint256) public raisedByAddress;

    // whitelisted investors
    mapping(address => bool) public whitelist;
    // how many whitelisted investors
    uint256 public whitelistedInvestorCounter;


    //@audit - 1000 USD per hour allowed to be spent
    // Extra money each address can spend each hour
    uint256 hourLimitByAddressUsd = 1000;

    // Wallet to store all raised money
    Treasury public treasuryContract = Treasury(0x0);

    /* *******
     * Events
     */

    event ChangeReturn(address recipient, uint256 amount);
    event TokenPurchase(address buyer, uint256 weiAmount, uint256 tokenAmount);
    /* **************
     * Public methods
     */

    //@audit - constructor:
    //pass in an array of owners, the address of the ERT token, the address of the treasury, and the address of the team multisig
    function EthearnalRepTokenCrowdsale(
        address[] _owners,
        address _token,
        address _treasuryContract,
        address _teamTokenWallet
    ) {
        //@audit - ensure that the passed in owner array has more than just one owner
        require(_owners.length > 1);
        //@audit - ensure that the ERT token address is not 0x0
        require(_token != 0x0);
        //@audit - ensure that the treasury address is not 0x0
        require(_treasuryContract != 0x0);
        //@audit - ensure that the team multisig is not 0x0
        require(_teamTokenWallet != 0x0);
        //@audit - cast the passed in token address to an ERT token
        token = EthearnalRepToken(_token);
        //@audit - cast the passed in treasury address to a Treasury contract
        treasuryContract = Treasury(_treasuryContract);
        //@audit - set the team multisig
        teamTokenWallet = _teamTokenWallet;
        //@audit - set up owners (refers to MultiOwnable.sol)
        setupOwners(_owners);
    }

    //@audit - fallback - if the sender is whitelisted, we call buyForWhitelisted
    //otherwise, we call buyTokens
    function() public payable {
        if (whitelist[msg.sender]) {
            buyForWhitelisted();
        } else {
            buyTokens();
        }
    }

    //@audit - purchase function for whitelisted addresses
    function buyForWhitelisted() public payable {
        //@audit - require that msg.sender is in the whitelist
        address whitelistedInvestor = msg.sender;
        require(whitelist[whitelistedInvestor]);
        //@audit - ensure that the sender did not send 0 ETH
        uint256 weiToBuy = msg.value;
        require(weiToBuy > 0);
        //@audit - ensure that the amount of tokens to be purchased is at least 1
        uint256 tokenAmount = getTokenAmountForEther(weiToBuy);
        require(tokenAmount > 0);
        //@audit - increment weiRaised by the amount the sender sent
        weiRaised = weiRaised.add(weiToBuy);
        //@audit - increment the amount the sender has contributed in raisedByAddress, by the amount sent
        raisedByAddress[whitelistedInvestor] = raisedByAddress[whitelistedInvestor].add(weiToBuy);
        //@audit - mint tokens for the purchaser (refers to the zeppelin-solidity Mintable.sol contract), and ensure that it returns true (that tokens can be minted)
        assert(token.mint(whitelistedInvestor, tokenAmount));
        //@audit - call forwardFunds with the amount sent, which sends msg.value to the treasury contract
        forwardFunds(weiToBuy);
        //@audit - release TokenPurchase event
        TokenPurchase(whitelistedInvestor, weiToBuy, tokenAmount);
    }

    //@audit - purchase function for non-whitelisted addresses
    function buyTokens() public payable {
        address recipient = msg.sender;
        //@audit - get the State enum for the current time
        State state = getCurrentState();
        uint256 weiToBuy = msg.value;
        //@audit - ensure the current state is the State.MainSale, and that the sender sent a nonzero amount to the contract
        require(
            (state == State.MainSale) &&
            (weiToBuy > 0)
        );
        //@audit - take the minimum value of the sent ETH vs the amount allowed to be purchased by the sender
        weiToBuy = min(weiToBuy, getWeiAllowedFromAddress(recipient));
        //@audit - ensure that the sender is in fact allowed to purchase anything
        require(weiToBuy > 0);
        //@audit - take the minimum value of the allowed ETH and the sale cap minus the amount already raised
        weiToBuy = min(weiToBuy, convertUsdToEther(saleCapUsd).sub(weiRaised));
        //@audit - ensure that the sender is allowed to purchase anything, given what they have already purchased, as well as the amount already raised
        require(weiToBuy > 0);
        //@audit - get the amount of tokens that will be created by the amount the sender is allowed to spend
        uint256 tokenAmount = getTokenAmountForEther(weiToBuy);
        //@audit - ensure that the buyer can purchase at least 1 token
        require(tokenAmount > 0);
        //@audit - set the amount of wei to return as the amount sent minus the amount being used to purchase tokens
        uint256 weiToReturn = msg.value.sub(weiToBuy);
        //@audit - increment weiRaised
        weiRaised = weiRaised.add(weiToBuy);
        //@audit - increment the amount raised by this address
        raisedByAddress[recipient] = raisedByAddress[recipient].add(weiToBuy);
        //@audit - if some amount of ETH will be refunded, do that and release a ChangeReturn event
        if (weiToReturn > 0) {
            recipient.transfer(weiToReturn);
            ChangeReturn(recipient, weiToReturn);
        }
        //@audit - ensure the correct amount is minted
        assert(token.mint(recipient, tokenAmount));
        //@audit - send the amount raised to the treasury and release a TokenPurchase event
        forwardFunds(weiToBuy);
        TokenPurchase(recipient, weiToBuy, tokenAmount);
    }

    //@audit - CRITICAL:setEtherRateUsd can be called at any point by an owner, allowing the isReadyToFinalize function to pass at any time, even prior to the end of the sale
    //                  This can also allow both: extra purchases over the intended 30M USD cap, or purchases which use much higher or lower rates than intended. This can also
    //                  allow a team member to stop refunds in the treasury contract by setting a very high rate.
    //                  This has the potenial to effect any function which uses convertUsdToEther: getTokenRateEther, isReadyToFinalize, getWeiAllowedFromAddress, and buyTokens
    //                  Suggested fix: Remove this function entirely
    //@audit - TXIDs: (Ropsten)
    // 1. Investing the maximum amount allowed, then lowering the ETH USD rate to 1 USD/ETH. Now possible to invest much more:
    //    TXID: 0x9aae87ee22383f41a8d5db6be06e86f80a5ef42266efc246d1017a4e66f2e2ce
    // 2. Finalizing crowdsale early by setting ETH/USD rate to a high rate:
    //    TXID: 0x8774634eab809c0dbe3f93d0d475186d71f4dbf5cea58033ee2adbe488f6f937
    // 3. Setting ETH rate per USD so high that getTokenRateEther returns 0
    //    TXID: 0x96869879f2c728d5ac332395f492f397e70844ef16982bd3fa6ece44810dfe72
    // 4. Because the tokenRateEther is now 0, refunds are unable to be processed:
    //    Unable to produce TXID, because the transaction no longer goes through (because require statement in refundInvestor now fails)
    //THIS ISSUE WAS FIXED IN COMMIT: 3477bf1
    function setEtherRateUsd(uint256 _rate) public onlyOwner {
        //@audit - Prevents a rate of 0 from being set
        require(_rate > 0);
        //@audit - sets the rate to the passed in uint
        etherRateUsd = _rate;
    }

    //@audit - allows the owner to finalize the crowdsale
    // TEST
    function finalizeByAdmin() public onlyOwner {
        finalize();
    }

    /* ****************
     * Internal methods
     */

    //@audit - Internal method, forwards an amount of wei to the treasury. Used when ERT is purchased
    function forwardFunds(uint256 _weiToBuy) internal {
        treasuryContract.transfer(_weiToBuy);
    }

    //@audit - converts an input amount of USD and returns the amount as wei
    // TESTED
    function convertUsdToEther(uint256 usdAmount) constant internal returns (uint256) {
        return usdAmount.mul(1 ether).div(etherRateUsd);
    }

    //@audit - returns 0.5 USD converted to wei
    // TESTED
    function getTokenRateEther() public constant returns (uint256) {
        // div(1000) because 3 decimals in tokenRateUsd
        return convertUsdToEther(tokenRateUsd).div(1000);
    }

    //@audit - returns the amount of tokens that can be purchased for a given wei amount
    // TESTED
    function getTokenAmountForEther(uint256 weiAmount) constant internal returns (uint256) {
        //@audit - returns (weiAmount / (0.5 USD, converted to wei)) * (10 ^ 18)
        return weiAmount
            .div(getTokenRateEther())
            .mul(10 ** token.decimals());
    }

    //@audit - if the amount raised is above the sale cap, or the current state is State.MainSaleDone, returns true
    //@audit - NOTE: mark function as constant
    // TESTED
    function isReadyToFinalize() internal returns (bool) {
        return(
            (weiRaised >= convertUsdToEther(saleCapUsd)) ||
            (getCurrentState() == State.MainSaleDone)
        );
    }

    //@audit - NOTE: mark function as pure
    // TESTED
    function min(uint256 a, uint256 b) internal returns (uint256) {
        return (a < b) ? a: b;
    }

    //@audit - NOTE: mark funciton as pure
    //@audit - returns the larger of the two uints
    // TESTED
    function max(uint256 a, uint256 b) internal returns (uint256) {
        return (a > b) ? a: b;
    }

    //@audit - NOTE: mark function as pure
    // TESTED
    function ceil(uint a, uint b) internal returns (uint) {
        return ((a.add(b).sub(1)).div(b)).mul(b);
    }

    //@audit - internal: gets the maximum allowed spending amount for an address
    // TESTED
    function getWeiAllowedFromAddress(address _sender) internal returns (uint256) {
        //@audit - gets the number of seconds elapsed since the saleStartDate
        uint256 secondsElapsed = getTime().sub(saleStartDate);
        //@audit - gets the amount of hours elapsed since the saleStartDate, rounded up to the nearest hour
        uint256 fullHours = ceil(secondsElapsed, 3600).div(3600);
        //@audit - if fullHours is 0, sets fullHours to 1
        fullHours = max(1, fullHours);
        //@audit - calculates the maximum amount of wei allowed to be contributed by the sender at the time
        //@audit - limit = (hours since saleStartDate, rounded up) * (1000 USD in ETH)
        uint256 weiLimit = fullHours.mul(convertUsdToEther(hourLimitByAddressUsd));
        //@audit - returns the wei allowed from a given address:
        //@audit - (hours since saleStartDate, rounded up) * (1000 USD in ETH) - (amount contributed so far)
        return weiLimit.sub(raisedByAddress[_sender]);
    }

    //@audit - returns the current time. Method is a placeholder for testing purposes
    function getTime() internal returns (uint256) {
        // Just returns `now` value
        // This function is redefined in EthearnalRepTokenCrowdsaleMock contract
        // to allow testing contract behaviour at different time moments
        return now;
    }

    //@audit - gets the current State enum for the current time
    // TESTED
    function getCurrentState() internal returns (State) {
        return getStateForTime(getTime());
    }

    //@audit - internal: returns the State enum for a given time
    // TESTED
    function getStateForTime(uint256 unixTime) internal returns (State) {
        //@audit - if the isFinalized bool is true, this will return State.Finalized
        if (isFinalized) {
            // This could be before end date of ICO
            // if hard cap is reached
            return State.Finalized;
        }
        //@audit - if the time passed in is before the saleStartDate, return State.BeforeMainSale
        if (unixTime < saleStartDate) {
            return State.BeforeMainSale;
        }
        //@audit - if the time passed in is before the saleEndDate, but after (or equal to) the saleStartDate, return State.MainSale
        if (unixTime < saleEndDate) {
            return State.MainSale;
        }
        //@audit - if the time passed in is after the saleEndDate, return State.MainSaleDone
        return State.MainSaleDone;
    }

    //@audit - private: called to finalize the crowdsale
    // TESTED
    function finalize() private {
        if (!isFinalized) {
            //@audit - ensure the crowdsale is ready to be finalized
            require(isReadyToFinalize());
            //@audit - set isFinalized to true, ensuring no more can be contributed
            isFinalized = true;
            //@audit - mints tokens for the team - cannot be called in this function twice, because isFinalized is now true
            mintTeamTokens();
            //@audit - unlocks the token for transfer (refers to LockableToken.sol)
            token.unlock();
            //@audit - refers to Treasury.sol - finalizes the crowdsale in the treasury contract and allows for the first 10% to be withdrawn
            treasuryContract.setCrowdsaleFinished();
        }
    }

    //@audit - private: mints tokens for the development team, by an amount determined by the teamTokenRatio
    //@audit - teamTokenRatio is (1 * 1000) / 3 = 333, meaning 0.333 * token.totalSupply will be minted
    // TESTED
    function mintTeamTokens() private {
        // div by 1000 because of 3 decimals digits in teamTokenRatio
        var tokenAmount = token.totalSupply().mul(teamTokenRatio).div(1000);
        //@audit - mints tokenAmount (33% of totalSupply) and sends it to the teamTokenWallet
        token.mint(teamTokenWallet, tokenAmount);
    }


    //@audit - allows an owner to add an address to the whitelist mapping, and increment the number of whitelisted investors
    function whitelistInvestor(address _newInvestor) public onlyOwner {
        if(!whitelist[_newInvestor]) {
            whitelist[_newInvestor] = true;
            whitelistedInvestorCounter++;
        }
    }
    //@audit - allows an owner to add multiple investors as whitelisted, and increments the count for each investor added
    function whitelistInvestors(address[] _investors) external onlyOwner {
        //@audit - require that the passed-in array has less than or equal to 250 members
        require(_investors.length <= 250);
        //@audit - for each address in the array, if the investor does not exist yet, add them to the mapping and increment the count
        //@audit - uint8 is safe here, because of the previous require statement
        for(uint8 i=0; i<_investors.length;i++) {
            address newInvestor = _investors[i];
            if(!whitelist[newInvestor]) {
                whitelist[newInvestor] = true;
                whitelistedInvestorCounter++;
            }
        }
    }
    //@audit - NOTE: Change function name to 'removeWhitelistedInvestor' - a blacklist implies they cannot participate in the crowdsale
    //@audit - if an investor is whitelisted, this funciton removes the investor from the whitelist and decrements the whitelisted investor count if it is safe to do so
    function blacklistInvestor(address _investor) public onlyOwner {
        if(whitelist[_investor]) {
            delete whitelist[_investor];
            if(whitelistedInvestorCounter != 0) {
                whitelistedInvestorCounter--;
            }
        }
    }

}
