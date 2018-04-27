//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - Sol imports
//@audit - NOTE: Use the latest OpenZeppelin contracts, these are slightly outdated
import './BlockportToken.sol';
import './CrowdsaleWhitelist.sol';
import './zeppelin/lifecycle/Pausable.sol';
import './zeppelin/crowdsale/CappedCrowdsale.sol';
import './zeppelin/crowdsale/FinalizableCrowdsale.sol';

//@audit - Blockport Crowdsale contract - Uses OpenZeppelin's CappedCrowdsale.sol, FinalizableCrowdsale.sol, and Pausable.sol, as well as CrowdsaleWhitelist.sol
contract BlockportCrowdsale is CappedCrowdsale, FinalizableCrowdsale, CrowdsaleWhitelist, Pausable {

    //@audit - Using ... for attaches SafeMath functions to uint types
    using SafeMath for uint256;

    //@audit - Address of BPT token
    address public tokenAddress;
    //@audit - Address of Blockport team wallet
    address public teamVault;
    //@audit - Address of Blockport company wallet
    address public companyVault;
    //@audit - Minimum amount of wei required to enter the crowdsale (ether unit is expressed in wei)
    uint256 public minimalInvestmentInWei = 0.1 ether;
    //@audit - Maximum amount of wei allowed to be contributed to the crowdsale (ether unit is expressed in wei)
    uint256 public maxInvestmentInWei = 50 ether;

    //@audit - Mapping between addresses of investors and amount invested
    mapping (address => uint256) internal invested;

    //@audit - Address of BPT token, cast to BlockportToken
    //@audit - NOTE: Using an interface will decrease deployment cost
    BlockportToken public bpToken;

    //@audit - Events
    event InitialRateChange(uint256 rate, uint256 cap);
    event InitialDateChange(uint256 startTime, uint256 endTime);

    //@audit - Constructor: Initializes crowdsale variables, calls CappedCrowdsale and Crowdsale constructors directly
    //@param - "_cap": Maximum amount of wei to raise
    //@param - "_startTime": The uint start time of the crowdsale
    //@param - "_endTime": The uint end time of the crowdsale
    //@param - "_rate": The uint rate of tokens per wei
    //@param - "_wallet": The wallet to which funds will be forwarded
    //@param - "_tokenAddress": The address of the BPT token
    //@param - "_teamVault": The address of the team's wallet, to which tokens will be minted post crowdsale
    //@param - "_companyVault": The address of the BPT company wallet, to which tokens will be minted post crowdsale
    function BlockportCrowdsale(uint256 _cap, uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet, address _tokenAddress, address _teamVault, address _companyVault)
        CappedCrowdsale(_cap)
        Crowdsale(_startTime, _endTime, _rate, _wallet) public {
            //@audit - NOTE: It is possible to create an un-investable crowdsale by setting the crowdsale cap to below the minimalInvestmentInWei. Recommend checking for this.
            //@audit - Ensure passed-in token address is valid
            require(_tokenAddress != address(0));
            //@audit - Ensure passed-in team wallet address is valid
            require(_teamVault != address(0));
            //@audit - Ensure passed-in company wallet addres is valid
            require(_companyVault != address(0));

            //@audit - Set BPT token address
            tokenAddress = _tokenAddress;
            //@audit - Casts the token address passed-in to BlockportToken
            token = createTokenContract();
            //@audit - Sets the team wallet
            teamVault = _teamVault;
            //@audit - Sets the company wallet
            companyVault = _companyVault;
    }

    //@audit - Casts the contract's tokenAddress to BlockportToken and assigns it to bpToken. Returns BlockportToken as MintableToken
    //@returns - "MintableToken": The address of the BPT token, cast to MintableToken
    //@audit - VISIBILITY internal: This function can only be accessed from within this contract
    function createTokenContract() internal returns (MintableToken) {
        bpToken = BlockportToken(tokenAddress);
        return BlockportToken(tokenAddress);
    }

    //@audit - Token purchase function. Allows the sender to buy tokens for a beneficiary
    //@param - "beneficiary": The address of the person to buy tokens for
    //@audit - MODIFIER payable: This function can be sent Ether
    function buyTokens(address beneficiary) public payable {
        //@audit - Increment the sender's invested mapping with the sent Ether
        //@audit - NOTE: Omission of SafeMath is acceptable here, but using it anyway would be more adherant to best practices
        invested[msg.sender] += msg.value;
        //@audit - Call the buyTokens function in Crowdsale
        super.buyTokens(beneficiary);
    }

    //@audit - Returns whether or not an investment is valid, overriding CappedCrowdsale.validPurchase
    //@returns - "bool": Whether or not an investment is valid
    //@audit - VISIBILITY internal: This function can only be accessed from within this contract
    function validPurchase() internal returns (bool) {
        //@audit - Whether the amount of sent Ether is over the minimum investment in wei
        bool moreThanMinimalInvestment = msg.value >= minimalInvestmentInWei;
        //@audit - Whether the sender is whitelisted (uses CrowdsaleWhitelist)
        bool whitelisted = addressIsWhitelisted(msg.sender);
        //@audit - Whether the sender has invested over the maximum investment in wei
        bool lessThanMaxInvestment = invested[msg.sender] <= maxInvestmentInWei;

        //@audit - Returns:
        //@audit - validPurchase from CappedCrowdsale.sol
        //@audit - Whether the amount of sent Ether is over the minimum investment in wei
        //@audit - Whether the sender has invested over the maximum investment in wei
        //@audit - Whether the contract is paused (refers to Pausable.sol)
        //@audit - Whether the sender is whitelisted to participate
        return super.validPurchase() && moreThanMinimalInvestment && lessThanMaxInvestment && !paused && whitelisted;
    }

    //@audit - Finalizes the crowdsale and allocates additional tokens to the team and company
    //@audit - VISIBILITY internal: This fucntion can only be accesed from within this contract
    function finalization() internal {
        //@audit - Get the token's total supply
        uint256 totalSupply = token.totalSupply();
        //@audit - Get the amount of tokens that make up 20% of all tokens
        uint256 twentyPercentAllocation = totalSupply.div(5);

        //@audit - Mint 20% of all tokens for the Bp team
        token.mint(teamVault, twentyPercentAllocation);
        //@audit - Mint 20% of all tokens for the Bp company
        token.mint(companyVault, twentyPercentAllocation);

        //@audit - Finalize minting in the BPT token
        token.finishMinting();
        //@audit - Unpause the token, allowing for transfers
        bpToken.unpause();
        //@audit - Calls finalization in FinalizableCrowdsale
        super.finalization();

        //@audit - Transfer the BPT token ownership from the crowdsale contract to the owner of the crowdsale
        bpToken.transferOwnership(owner);
    }

    //@audit - Allows the crowdsale owner to set the token purchase rate
    //@param - "_rateInWei": The uint rate of tokens per wei spent
    //@param - "_capInWei": The uint maximum amount of wei that can be spent during the crowdsale
    //@returns - "bool": Returns whether the function succeeded
    //@audit - MODIFIER onlyOwner(): Only the owner can call this function
    //@audit - LOW:  Given that the Blockport pre-sale finished within 3 minutes, it is likely that as soon as the main sale starts, there will be a large
    //@audit -       number of people attempting to purchase immediately. Setting the rate and cap can occur minutes before the crowdsale starts, which could
    //@audit -       be misleading for potential investors (who would likely not double-check these values before sending Ether). I would recommend gating
    //@audit -       this function to a few hours before the mainsale starts, instead of directly before.
    function setRate(uint256 _rateInWei, uint256 _capInWei) public onlyOwner returns (bool) {
        //@audit - Ensure the crowdsale start time has no occured yet
        require(startTime > block.timestamp);
        //@audit - Ensure the set token purchase rate is nonzero
        require(_rateInWei > 0);
        //@audit - Ensure the set maximum tokens is nonzero
        require(_capInWei > 0);

        //@audit - Set token purchase rate and token cap
        rate = _rateInWei;
        cap = _capInWei;

        //@audit - InitialRateChange event
        InitialRateChange(rate, cap);
        //@audit - Return true
        return true;
    }

    //@audit - Allows the crowdsale owner to set the start and end dates for the crowdsale
    //@param - "_startTime": The uint start time of the crowdsale
    //@param - "_endTime": The uint end time of the crowdsale
    //@returns - "bool": Whether the function succeeded
    //@audit - MODIFIER onlyOwner(): Only the crowdsale owner can call this function
    function setCrowdsaleDates(uint256 _startTime, uint256 _endTime) public onlyOwner returns (bool) {
        //@audit - Ensure the current crowdsale start time has not occured yet
        require(startTime > block.timestamp);
        //@audit - Ensure the passed-in start time is in the future
        require(_startTime >= now);
        //@audit - Ensure the passed-in end time is after the start time
        require(_endTime >= _startTime);

        //@audit - Set crowdsale start time and end time
        startTime = _startTime;
        endTime = _endTime;

        //@audit - InitialDateChange event
        InitialDateChange(startTime, endTime);
        //@audit - Return true
        return true;
    }

    //@audit - Sets the bpToken owner as the crowdsale contract owner
    //@audit - MODIFIER onlyOwner(): Only the crowdsale owner can call this function
    //@audit - HIGH:   Having this function makes sense from a safety and upgradability perspective to transfer ownership from the crowdsale to the crowdsale owner, but the fact that this can happen pre-finalization
    //@audit -         means that the crowdsale owner can defraud crowdsale pariticpants by becoming owner, minting tokens, and returning ownership to the crowdsale.
    function resetTokenOwnership() onlyOwner public {
        bpToken.transferOwnership(owner);
    }

}
