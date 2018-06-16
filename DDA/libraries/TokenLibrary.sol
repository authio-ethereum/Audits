pragma solidity ^0.4.23;

import "../interfaces/Oracle_Interface.sol";
import "../interfaces/DRCT_Token_Interface.sol";
import "../interfaces/Factory_Interface.sol";
import "../interfaces/ERC20_Interface.sol";
import "./SafeMath.sol";


// @audit - A library to simplify token swap contracts
library TokenLibrary{

    // @audit - Attaches the SafeMath library to uint
    using SafeMath for uint256;

    // @audit - An enum type representing the swap state: created - 0; started - 1; ended - 2
    enum SwapState {
            created,
            started,
            ended
    }
    
    // @audit - A struct to store information about the swap contract
    struct SwapStorage{
        // @audit - The address of the oracle to query
        address oracle_address;
        // @audit - The address of this swap's factory
        address factory_address;
        // @audit - An instance of this swap's factory
        Factory_Interface factory;
        // @audit - The creator of this swap
        address creator;
        // @audit - The base token of this swap
        address token_address;
        // @audit - An interface to the base token
        ERC20_Interface token;
        // @audit - Enum representing the state of this swap
        SwapState current_state;
        // @audit - uint array containing information about this swap 
        // @audit - [0 - start date][1 - end date][2 - multiplier][3 - duration][4 - oracle reference value for start date][5 - oracle reference value for end date][6 - fee]  
        uint[7] contract_details;
        // @audit - The amount to pay to holders of one long token -- set by Calculate 
        uint pay_to_long;
        // @audit - The amount to pay to holders of one short token -- set by Calculate 
        uint pay_to_short;
        // @audit - The address of the long token contract of this swap
        address long_token_address;
        // @audit - The address of the short token contract of this swap
        address short_token_address;
        // @audit - The number of drct tokens created for this swap -- equals the amount of long tokens created
        uint num_DRCT_tokens;
        // @audit - The amount of base tokens created
        uint token_amount;
        // @audit - The UserContract of this swap
        address userContract;

    }

    // @audit - Event: emitted when a new swap is created
    event SwapCreation(address _token_address, uint _start_date, uint _end_date, uint _token_amount);
    // @audit - Event: emitted when a swap is paid out
    event PaidOut(uint pay_to_long, uint pay_to_short);


    // @audit - Used internally to set the factory address, the creator, the UserContract's address, the start date, and the state of a swap
    // @param - self: A storage pointer to a SwapStorage struct. 
    // @param - _factory_address: The address of the factory
    // @param - _creator: The address of the creator
    // @param - _userContract: The address of the UserContract
    // @param - _start_date: The start date of this swap contract
    function startSwap (SwapStorage storage self, address _factory_address, address _creator, address _userContract, uint _start_date) internal {
        // @audit - Make sure that the creator is not address 0. 
        require(self.creator == address(0));
        // @audit - Assign the passed-in values to the correct SwapStorage variables
        self.creator = _creator;
        self.factory_address = _factory_address;
        self.userContract = _userContract;
        self.contract_details[0] = _start_date;
        // @audit - Set the swap's current state to "created"
        self.current_state = SwapState.created;
    }

    // @audit - Used internally to return some of the variables from the SwapStorage struct
    // @returns - address[5]: An array of addresses that includes the UserContract, long token address, short token address, oracle address, and the base token address
    // @returns - uint: The number of drct tokens -- this is the amount of long tokens (or short tokens)
    // @returns - uint: The multiplier of this swap 
    // @returns - uint: The duration of this swap 
    // @returns - uint: The start date of the swap
    // @returns - uint: The end date of the swap 
    function showPrivateVars(SwapStorage storage self) internal view returns (address[5],uint, uint, uint, uint, uint){
        return ([self.userContract, self.long_token_address,self.short_token_address, self.oracle_address, self.token_address], self.num_DRCT_tokens, self.contract_details[2], self.contract_details[3], self.contract_details[0], self.contract_details[1]);
    }

    // @audit - Used internally to create a new swap Maybe switch the name with startSwap 
    // @param - self: A storage pointer to a SwapStorage struct
    // @param - _amount: the amount of base tokens for this contract 
    // @param - _senderAdd: The address of the sender
    function createSwap(SwapStorage storage self,uint _amount, address _senderAdd) internal{
        /* @audit - Require that the swap has SwapState of created (i.e. it has not started or ended), that the sender is the creator, and that _amount > 0 or that 
                    the sender is the userContract, the _senderAdd is the creator and _amount > 0 */
        require(self.current_state == SwapState.created && msg.sender == self.creator  && _amount > 0 || (msg.sender == self.userContract && _senderAdd == self.creator) && _amount > 0);
        // @audit - Set the SwapStorage's factory to be the Factory instance at factory_address
        self.factory = Factory_Interface(self.factory_address);
        // @audit - Set the oracle address, duration, multiplier, and the base token address to match the factory's values for those variables
        getVariables(self);
        // @audit - Set the end date of this contract to be the start date plus the number of days the contract will be active
        self.contract_details[1] = self.contract_details[0].add(self.contract_details[3].mul(86400));
        // @audit - Ensure the contract is not active for more than 28 days
        assert(self.contract_details[1]-self.contract_details[0] < 28*86400);
        // @audit - Set the token_amount to _amount
        self.token_amount = _amount;
        // @audit - Get an interface for the base token and store that in SwapStorage
        self.token = ERC20_Interface(self.token_address);
        // @audit - Ensure that the token balance of this swap in the base token contract is equal to twice the token_amount
        assert(self.token.balanceOf(address(this)) == SafeMath.mul(_amount,2));
        // @audit - Initialize the token ratio to be equal to 1
        uint tokenratio = 1;
        // @audit - Update the long token address, short token address, and token ratio and actually create the long and short tokens of this swap 
        (self.long_token_address,self.short_token_address,tokenratio) = self.factory.createToken(self.token_amount,self.creator,self.contract_details[0]);
        // @audit - Update the number of drct tokens to equal token amount divided by the token ratio 
        self.num_DRCT_tokens = self.token_amount.div(tokenratio);
        // @audit - Query the oracle to update some of the swap information 
        oracleQuery(self);
        // @audit - Emit a SwapCreation event 
        emit SwapCreation(self.token_address,self.contract_details[0],self.contract_details[1],self.token_amount);
        // @audit - Update the current state of this swap to started
        self.current_state = SwapState.started;
    }

    // @audit - Used internally to update the oracle, duration, multiplier, and base token address to be consistent with this factory's standardized variables 
    // @param - self: A storage pointer to this swap's swap storage
    function getVariables(SwapStorage storage self) internal{
        (self.oracle_address,self.contract_details[3],self.contract_details[2],self.token_address) = self.factory.getVariables();
    }

    // @audit - Used internally to query this contract's oracle
    // @param - self: A storage pointer to this swap's swap storage
    // @returns - bool: This bool reflects whether or not the oracle's values have been set 
    // @audit - NOTE: Maybe safe addition and multiplication should be used within this function
    function oracleQuery(SwapStorage storage self) internal returns(bool){
        // @audit - Create an interface for this swap's oracle
        Oracle_Interface oracle = Oracle_Interface(self.oracle_address);
        // @audit - Set _today to be equal to the current day -- subtract the extra minutes and seconds from now to make it an even day
        uint _today = now - (now % 86400);
        uint i;
        // @audit - If today is past this swap's start date and the start reference rate is zero, query the oracle again 
        if(_today >= self.contract_details[0] && self.contract_details[4] == 0){
            // @audit - For every day since the start date, run the loop
            for(i=0;i < (_today- self.contract_details[0])/86400;i++){
                // @audit - If the oracle was queried i days past the start date, continue 
                if(oracle.getQuery(self.contract_details[0]+i*86400)){
                    // @audit - Set contract_details[4] to be the oracle's data from i days past the start date and then return true 
                    self.contract_details[4] = oracle.retrieveData(self.contract_details[0]+i*86400);
                    return true;
                }
            }
            // @audit - If contract_details[4] does not contain any nonzero data from the oracle, push data from the oracle and return false 
            if(self.contract_details[4] ==0){
                oracle.pushData();
                return false;
            }
        }
        // @audit - If today is past the swap's end date and the ending reference rate equals 0, run the following code
        if(_today >= self.contract_details[1] && self.contract_details[5] == 0){
            // @audit - For every day that has passed since the end date 
            for(i=0;i < (_today- self.contract_details[1])/86400;i++){
                // @audit - If the oracle was queried i days past the end date, continue 
                if(oracle.getQuery(self.contract_details[1]+i*86400)){
                    // @audit - Set contract_details[5] to be the oracle's data from i days past the end date
                    self.contract_details[5] = oracle.retrieveData(self.contract_details[1]+i*86400);
                    return true;
                }
            }
            // @audit - If contract_details[5] does not contain any nonzero data from the oracle, push data from the oracle and return false 
            if(self.contract_details[5] ==0){
                oracle.pushData();
                return false;
            }
        }
        // @audit - If the oracle has already been queried appropriately or the swap start date has not been reached, return true
        return true;
    }

    
    // @audit - Used internally to calculate the payouts for the short and long tokens 
    // @param - self: A storage pointer to this swap's SwapStorage
    function Calculate(SwapStorage storage self) internal{
        uint ratio;
        // @audit - Safely multiply the token amount by 10000 subtracted by the fee and then safely divide by 10000
        self.token_amount = self.token_amount.mul(10000-self.contract_details[6]).div(10000);
        // @audit - If both oracle reference values have been set to nonzero values, continue calculating
        if (self.contract_details[4] > 0 && self.contract_details[5] > 0)
            // @audit - The ratio is the end reference rate divided by the start reference rate -- this is multiplied by 10000 to add precision to the calculation
            ratio = (self.contract_details[5]).mul(100000).div(self.contract_details[4]);
            // @audit - If the token ratio is greater than 10000, the long tokens are more valuable 
            if (ratio > 100000){
                // @audit - The refined ratio is calculated by multiplying the gains made in the reference value by the multiplier
                ratio = (self.contract_details[2].mul(ratio - 100000)).add(100000);
            }
            else if (ratio < 100000){
                    // @audit - The refined ratio is calculated by taking the minimum of 100000 and the multiplier multiplied by the losses sustained by the reference rate
                    ratio = SafeMath.min(100000,(self.contract_details[2].mul(100000-ratio)));
                    // @audit - Subtract the ratio calculated above from 100000
                    ratio = 100000 - ratio;
            }
        // @audit - If the end rate is nonzero and the start rate is zero, set the ratio value to be 10 to the power of 10 to ensure maximal payouts to long holders and no payouts to short holders 
        else if (self.contract_details[5] > 0)
            ratio = 10e10;
        // @audit - If the start rate is nonzero and the end rate is zero, set the ratio to 0 to ensure maximal payouts to short holders and no payouts to long holders 
        else if (self.contract_details[4] > 0)
            ratio = 0;
        // @audit - If both the starting and ending reference values are 0, then the ratio is 10000 as the short and long tokens have not changed in value
        else
            ratio = 100000;
        // @audit - Ensure that the calculations following will be capped at an upside or downside of 100%
        ratio = SafeMath.min(200000,ratio);
        // @audit - Calculate the payout to long tokens to be the ratio mulitplied by the token amount divided by 10000 * num_DRCT_tokens 
        self.pay_to_long = (ratio.mul(self.token_amount)).div(self.num_DRCT_tokens).div(100000);
        // @audit - Calculate the short token payout to be 20000 minus the ratio multiplied by the token amount divided by 10000 * num_DRCT_tokens 
        self.pay_to_short = (SafeMath.sub(200000,ratio).mul(self.token_amount)).div(self.num_DRCT_tokens).div(100000);
        // @audit - This calculation makes sense because it is essentially multiplying a close approximation of the "true" ratio (obviously capped)
        //          by the number of tokens per drct_token. 
    }

    // @audit - Used internally to manually pay out the holders of the long and short token swap contracts 
    // @param - self: A storage pointer to this swap's SwapStorage
    // @param - _range: A uint array intended to represent the starting and ending dates of this swap 
    // @audit - NOTE: The @param comment matches the current comments in the repository but is not consistent with how 
    //          the function is used in the autopay.js script or the test suite 
    // @returns - bool: Returns whether or not the swap was ready to be paid out 
    // @audit - CRITICAL: This function has a critical issue. 
    function forcePay(SwapStorage storage self, uint[2] _range) internal returns (bool) {
        // @audit - Ensure that the swap contract has been started by calling "createSwap" and that now is greater than or equal to the end date
        require(self.current_state == SwapState.started && now >= self.contract_details[1]);
        // @audit - Query the oracle to ensure that the reference values are set. If the oracle did not successfully update the reference values, set ready to false
        bool ready = oracleQuery(self);
        // @audit - If the reference values have been set correctly, proceed to manually pay out the swap contract 
        if(ready){
            // @audit - Calculate the long and short token payouts
            Calculate(self);
            // @audit - Get an interface to the long token contract
            DRCT_Token_Interface drct = DRCT_Token_Interface(self.long_token_address);
            // @audit -  the number of accounts holding long tokens in a swap contract
            uint count = drct.addressCount(address(this));
            // @audit - Set the loop count to the minimum of the address count and _range[1]
            uint loop_count = count < _range[1] ? count : _range[1];
            // @audit - Loop either the difference between range[1] and range[0] or the difference between count and range[0] number of times
            // @audit - NOTE: If count is less than range[0], this loop will not pay out anyone that holds longs, even if count is nonzero 
            for(uint i = loop_count-1; i >= _range[0] ; i--) {
                address long_owner;
                uint to_pay_long;
                // @audit - Returns the balance struct at the given index 
                (to_pay_long, long_owner) = drct.getBalanceAndHolderByIndex(i, address(this));
                // @audit - Pays the long owner the payout per long (calculated by calculate) multiplied by the number of long tokens the owner possesses 
                paySwap(self,long_owner, to_pay_long, true);
            }
            // @audit - Get an interface to the short token contract
            drct = DRCT_Token_Interface(self.short_token_address);
            // @audit -  the number of accounts holding short tokens in a swap contract
            count = drct.addressCount(address(this));
            // @audit - Set the loop count to the minimum of the address count and _range[1]
            loop_count = count < _range[1] ? count : _range[1];
            // @audit - Loop either the difference between range[1] and range[0] or the difference between count and range[0] number of times
            // @audit - NOTE: If count is less than range[0], this loop will not pay out anyone that holds longs, even if count is nonzero 
            for(uint j = loop_count-1; j >= _range[0] ; j--) {
                address short_owner;
                uint to_pay_short;
                // @audit - Returns the balance struct at the given index 
                (to_pay_short, short_owner) = drct.getBalanceAndHolderByIndex(j, address(this));
                // @audit - Pays the short owner the payout per short (calculated by calculate) multiplied by the number of short tokens the owner possesses 
                paySwap(self,short_owner, to_pay_short, false);
            }
            // @audit - If the loop count equals count, transfer the remaining balance of this contract to the factory, emit a PaidOut event, and update the SwapStatus to ended
            // @audit - NOTE: There should be a check that the long and short token contracts both have an addressCount of 1 when this if statement is entered. Otherwise, 
            //          some of the long and short holders will not be payed if forcePay is called incorrectly --> leading to their tokens being locked in after the Swap is ended
            if (loop_count == count){
                self.token.transfer(self.factory_address, self.token.balanceOf(address(this)));
                emit PaidOut(self.pay_to_long,self.pay_to_short);
                self.current_state = SwapState.ended;
            }
        }
        // @audit - Return whether or not any payouts were performed
        return ready;
    }

    // @audit - Used internally (by ForcePayout) to pay out an owner's share of long or short tokens 
    // @param - self: A storage pointer to this swap's SwapStorage
    // @param - _reciever: The address to be paid out 
    // @param - _amount: The amount of tokens to be paid out 
    // @param - _is_long: Whether this payout is paying out long or short tokens 
    function paySwap(SwapStorage storage self,address _receiver, uint _amount, bool _is_long) internal {
        // @audit - If _is_long, pay out the amount of long tokens
        if (_is_long) {
            // @audit - If the long payout is nonzero, continue
            if (self.pay_to_long > 0){
                // @audit - Call the base token contract to transfer the appropriate funds (_amount times pay_to_long) to the reciever
                self.token.transfer(_receiver, _amount.mul(self.pay_to_long));
                // @audit - Calls the payToken function in factory to correctly recalculate the balance of the reciever and the total supply of the long token contract  
                self.factory.payToken(_receiver,self.long_token_address);
            }
        // @audit - If _is_long is false, pay out the short tokens
        } else {
            // @audit - If the short payout is zero, continue
            if (self.pay_to_short > 0){
                // @audit - Call the base token contract to transfer the appropriate funds (_amount times pay_to_long) to the reciever
                self.token.transfer(_receiver, _amount.mul(self.pay_to_short));
                // @audit - Calls the payToken function in factory to correctly recalculate the balance of the reciever and the total supply of the short token contract  
                self.factory.payToken(_receiver,self.short_token_address);
            }
        }
    }

    // @audit - Used internally to get the current state of this swap
    // @param - self: A storage pointer to this swap's SwapStorage 
    // @returns - uint: The current state of this swap
    function showCurrentState(SwapStorage storage self)  internal view returns(uint) {
        return uint(self.current_state);
    }
    


}
