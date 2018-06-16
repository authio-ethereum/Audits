pragma solidity ^0.4.21;

import "./SafeMath.sol";
import "../interfaces/Factory_Interface.sol";

library DRCTLibrary{

    using SafeMath for uint256;

    //@audit - Struct holding owner's balance 
    struct Balance {
        address owner;
        uint amount;
        }

    //@audit - struct holding all pertinent information about a token 
    struct TokenStorage {
        //@audit - address for the swap contract that this struct is holding token information for 
        address master_contract;
        //@audit - total supply of token
        uint total_supply;
        //@audit - Maps swap_contract address to balances struct for each user in the swap 
        mapping(address => Balance[]) swap_balances;
        //@audit - Mapping swap address to mapping of addresses that are participating in the swap to their index in the swap_balances Balance[] array 
        mapping(address => mapping(address => uint)) swap_balances_index;
        //@audit - Maps user to all swaps that user is participating in
        mapping(address => address[]) user_swaps;
        //@audit - Mapping of user to mapping of swap address to index that the swap is in the user_swaps address[] array
        mapping(address => mapping(address => uint)) user_swaps_index;
        //@audit - mapping of user to total balance in token 
        mapping(address => uint) user_total_balances;
        //@audit - mapping of token allowances for users 
        mapping(address => mapping(address => uint)) allowed;
    }   

    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
    event CreateToken(address _from, uint _value);
    
    //@param - self: TokenStorage struct holding all the information regarding the swap and all involved parties
    //@param - _factory: address of master contract holding all swaps for a certain derivative 
    //@audit - function sets the master swap contract for the TokenStorage struct 
    function startToken(TokenStorage storage self, address _factory) public {
        //@audit - Sets master contract
        self.master_contract = _factory;
    }
    //@param - self: TokenStorage struct holding all the information regarding the swap and all involved parties
    //@param - _member: The user/contract who's whitelist status is to be checked 
    //@return - Boolean value representing whether or not _member is whitelisted 
    //@audit - Checks if the _member address is whitelisted in the master swap contract of the TokenStorage instance 
    function isWhitelisted(TokenStorage storage self,address _member) internal view returns(bool){ 
        //@audit - Creates factory interface instance for factory contract at master swap contract address
        Factory_Interface _factory = Factory_Interface(self.master_contract);
        //@audit - calls isWhitelisted function within the created _factory instance and returns result 
        return _factory.isWhitelisted(_member);

    }

    //@param - self: TokenStorage struct holding all the information regarding the swap and all involved parties
    //@param - _supply: total supply of token to be created 
    //@param - _owner: owner of token to be created 
    //@param - _swap: address of swap to be associated with the token 
    //@audit - Creates a token and sets all the initial variables in self to represent that Token creation 
    function createToken(TokenStorage storage self, uint _supply, address _owner, address _swap) public{
    require(msg.sender == self.master_contract);
        //@audit - Safe-add supply to existing total supply field of self/ pretty much sets total_suppy to supply just using Safe-add in order to check for valid suppy 
        self.total_supply = self.total_supply.add(_supply);
        //@audit -  Set owners balance to total supply- give owner all the tokens
        self.user_total_balances[_owner] = self.user_total_balances[_owner].add(_supply);
        //@audit - Checks to see if the owner is involved in any swaps within self 
        if (self.user_swaps[_owner].length == 0)
            //@audit - If the owner is not involved in any other swaps then set the first swap-address in the owner's list to be the zero address
            //@audit - This is so the following line of code works as written
            self.user_swaps[_owner].push(address(0x0));
        //@audit - Tracks the index of the swap in user_swaps- which is the current length of user_swaps- in user_swaps_index 
        self.user_swaps_index[_owner][_swap] = self.user_swaps[_owner].length;
        //@audit - Adds the _swap address to the end of the address[] in the user_swaps mapping
        self.user_swaps[_owner].push(_swap);
        //@audit - Push 0-Balances struct in order for the following line of code to function properly
        self.swap_balances[_swap].push(Balance({
            owner: 0,
            amount: 0
        }));
        //@audit - Tracks index of _owner in _swap's entry of swap_balances mapping  
        self.swap_balances_index[_swap][_owner] = 1;
        //@audit - Pushes balance struct of owner- _owner with the total supply of the token onto the swap_balances Balances[] for the _swap entry
        self.swap_balances[_swap].push(Balance({
            owner: _owner,
            amount: _supply
        }));
        //@audit - Emits a Create_Token event 
        emit CreateToken(_owner,_supply);
    }
    
    //@param - self: TokenStorage struct holding all the information regarding the swap and all involved parties
    //@param - _party: The address of the user/contract attempting to cash out 
    //@param - _swap: The swap from which the user/contract is attempting to cash out from 
    //@audit - Pay's out the _party for their token holdings in the contract at address _swap 
    function pay(TokenStorage storage self,address _party, address _swap) public {
        require(msg.sender == self.master_contract);
        //@audit - Get the index of the party in the _swap's Balances[] in the swap_balances mapping 
        uint party_balance_index = self.swap_balances_index[_swap][_party];
        //@audit - Use the index obtained in the previous step and obtain the amount from the balance struct at that index 
        uint party_swap_balance = self.swap_balances[_swap][party_balance_index].amount;
        //@audit - Use safemath to subtract the balance obtained in the previous step from the _party's mapped total balance value 
        self.user_total_balances[_party] = self.user_total_balances[_party].sub(party_swap_balance);
        //@audit - Use safemath to subtract party_swap_balance from the total token supply held in self 
        self.total_supply = self.total_supply.sub(party_swap_balance);
        //@audit - Set _party's balance in swap to 0
        self.swap_balances[_swap][party_balance_index].amount = 0;
    }

    //@audit - Returns the total balance of _owner in self 
    function balanceOf(TokenStorage storage self,address _owner) public constant returns (uint balance) {
       return self.user_total_balances[_owner]; 
     }

     //@audit -  returns the total supply of self 
    function totalSupply(TokenStorage storage self) public constant returns (uint _total_supply) {
       return self.total_supply;
    }

    //@param - self: TokenStorage struct holding all the information regarding the swap and all involved parties
    //@param - _remove: address of token owner to remove 
    //@param - _swap: the swap in which to remove the owner's balance 
    //@audit - removes the struct belonging to a certain address from the balances[] in the swap_balances mapping 
    function removeFromSwapBalances(TokenStorage storage self,address _remove, address _swap) internal {
        //@audit - check for valid inputs 
        //@audit - Obtain index of last element of Balances[] in swap_balances entry for _swap 
        uint last_address_index = self.swap_balances[_swap].length.sub(1);
        //@audit - Use this index to get the address of the last user added to the Balances[] entry for _swap in swap_balances 
        address last_address = self.swap_balances[_swap][last_address_index].owner;
        //@audit -  Check to see if this address is not the _remove address 
        if (last_address != _remove) {
            //@audit - if not ^, get the index of the address to remove 
            uint remove_index = self.swap_balances_index[_swap][_remove];
            //@audit - assign this index to the address of the last user added to the Balances[] entry for _swap in swap_balances 
            self.swap_balances_index[_swap][last_address] = remove_index;
            //@audit - replace the balance struct for the address to be removed by the balance struct for the last element 
            self.swap_balances[_swap][remove_index] = self.swap_balances[_swap][last_address_index];
        }
        //@audit - remove the _remove's index entry from the swap_balances_index double mapping 
        delete self.swap_balances_index[_swap][_remove];
        //@audit - reduce the length of the array by 1
        self.swap_balances[_swap].length = self.swap_balances[_swap].length.sub(1);
    }

    //@param - self: TokenStorage struct holding all the information regarding the swap and all involved parties
    //@param - _from: The address that is sending money in the "transfer" transaction 
    //@param - _to: The address that is recieving money in the "transfer" transaction 
    //@param - _amount: The amount that is being transferred from _from to _to 
    //@audit - Executes a transfer of _amount from _from to _to 
    function transferHelper(TokenStorage storage self,address _from, address _to, uint _amount) internal {
        //@audit - obtain a list of all the swap contracts that the _from user is involved in within this token 
        address[] memory from_swaps = self.user_swaps[_from];

        //@audit - set up for loop to cycle through from_swaps- list of all swap contracts that _from user is inolved in
        for (uint i = from_swaps.length.sub(1); i > 0; i--) {
            //@audit - get index of _from in from_swaps[i] swap_balances, balances[] array 
            uint from_swap_user_index = self.swap_balances_index[from_swaps[i]][_from];
            //@audit - get balance struct of _from with regards to swap contract- from_swaps[i]
            Balance memory from_user_bal = self.swap_balances[from_swaps[i]][from_swap_user_index];
            
            //@audit -  if the _amount to transfer is greater than or equal to the user's balance in the swap contract from_swap[i]
            if (_amount >= from_user_bal.amount) {
                //@audit - decrement _amount by the user's balance in this swap contract (presumably use all of this balance to use for a portion of this transfer)
                _amount -= from_user_bal.amount;
                
                //@audit - decrement the length of the _from address' list that holds all the swap contracts that 
                //@audit - _from is involved in by 1, since reading the list from back 
                self.user_swaps[_from].length = self.user_swaps[_from].length.sub(1);
                
                //@audit - Delete the double mapping entry that holds the index of from_swap[i] in user_swaps[_from]
                delete self.user_swaps_index[_from][from_swaps[i]];
                
                //@audit - check if _to already is involved in the swap contract from_swaps[i]
                if (self.user_swaps_index[_to][from_swaps[i]] != 0) {
                    
                    //@audit - get the index of _to's Balance struct for from_swap[i] in swap_balances mapping 
                    uint to_balance_index = self.swap_balances_index[from_swaps[i]][_to];
                    assert(to_balance_index != 0);
                    
                    //@audit - safe-add the _from user's balance in from_swap[i] to the _to user's balance in from_swap[i]
                    self.swap_balances[from_swaps[i]][to_balance_index].amount = self.swap_balances[from_swaps[i]][to_balance_index].amount.add(from_user_bal.amount);
                    
                    //@audit - remove the Balance struct with the that belongs to _from from the swap_balances entry for from_swaps[i]
                    removeFromSwapBalances(self,_from, from_swaps[i]);
                //@audit - if _to is not involved with from_swaps[i] already 
                } else {
                    
                    //@audit - if this is the first swap that the _to is involved w then initialize the entry for their user_swaps mapping correctly 
                    if (self.user_swaps[_to].length == 0){
                        self.user_swaps[_to].push(address(0x0));
                    }
                    //@audit - set the index that from_swaps[i] will be in _to's entry in user_swaps_index 
                    self.user_swaps_index[_to][from_swaps[i]] = self.user_swaps[_to].length;
                    
                    //@audit - add from_swaps[i] to user_swaps[_to] list 
                    self.user_swaps[_to].push(from_swaps[i]);
                
                    //@audit - replace the the address of _from's Balance struct in from_swaps[i]'s swap_balance's entry with _to
                    self.swap_balances[from_swaps[i]][from_swap_user_index].owner = _to;
                
                    //@audit - assign _from's index in from_swaps[i]'s swap_balance's entry to _to's index 
                    self.swap_balances_index[from_swaps[i]][_to] = self.swap_balances_index[from_swaps[i]][_from];
                
                    //@audit - remove _from's entry in the swap_balances_index double mapping that holds each user address's index in each swap contract's swap_balances entry 
                    delete self.swap_balances_index[from_swaps[i]][_from];
                }
                
                //@audit- if the amount has been fully paid, then break out of the for loop
                if (_amount == 0)
                    break;

            //@audit - the case that _amount is less than the amount that _from has in from_swap[i]
            } else {
                
                //@audit - index of _to in from_swaps[i] entry in swap_balances
                uint to_swap_balance_index = self.swap_balances_index[from_swaps[i]][_to];
                
                //@audit - check if the user _to is involved in the swap contract from_swap[i]
                if (self.user_swaps_index[_to][from_swaps[i]] != 0) {
                    
                    //@audit - safe-add _amount to _to's balance in from_swap[i]
                    self.swap_balances[from_swaps[i]][to_swap_balance_index].amount = self.swap_balances[from_swaps[i]][to_swap_balance_index].amount.add(_amount);
                
                //@audit - in the case that _to is not yet involved in swap contract from_swap[i]
                } else {
                    
                    //@audit - if _to is not involved in any swap contracts, initiate his user_swap mapping entry 
                    if (self.user_swaps[_to].length == 0){
                        self.user_swaps[_to].push(address(0x0));
                    }

                    //@audit - set the index of from_swaps[i] in _to's user_swap's entry to the entry's current length
                    self.user_swaps_index[_to][from_swaps[i]] = self.user_swaps[_to].length;
                    
                    //@audit - add from_swaps[i] to the list of swap_contracts that _to is involved with 
                    self.user_swaps[_to].push(from_swaps[i]);
                    
                    //@audit - set the index of _to in from_swaps[i] swap_balances's entry to the entry's current length 
                    self.swap_balances_index[from_swaps[i]][_to] = self.swap_balances[from_swaps[i]].length;
                    
                    //@audit - push a Balance struct with owner _to and amount _amount to the swap_balances entry of from_swaps[i] 
                    self.swap_balances[from_swaps[i]].push(Balance({
                        owner: _to,
                        amount: _amount
                    }));
                }
                
                //@audit - safe-subtract _amount from _from's balance in from_swaps[i]
                self.swap_balances[from_swaps[i]][from_swap_user_index].amount = self.swap_balances[from_swaps[i]][from_swap_user_index].amount.sub(_amount);
                
                //@audit - break from the for loop since the full _amount has been transfered from _from to _to
                break;
            }
        }
    }

    //@audit - Transfer's _amount from msg.sender to _to 
    function transfer(TokenStorage storage self, address _to, uint _amount) public returns (bool) {
        require(isWhitelisted(self,_to));
        //@audit - assign the user's total balance to balance_owner
        uint balance_owner = self.user_total_balances[msg.sender];
        //@audit - checks for valid inputs 
        if (
            _to == msg.sender ||
            _to == address(0) ||
            _amount == 0 ||
            balance_owner < _amount
        ) return false;
        //@audit - execute transfer with transfer helper 
        transferHelper(self,msg.sender, _to, _amount);
        //@audit - safe-sub and safe-add _amount to msg.sender and _to's total balance in self 
        self.user_total_balances[msg.sender] = self.user_total_balances[msg.sender].sub(_amount);
        self.user_total_balances[_to] = self.user_total_balances[_to].add(_amount);
        //@audit - emit Transfer event 
        emit Transfer(msg.sender, _to, _amount);
        //@audit - return true upon successful completion of transfer 
        return true;
    }

    //@audit - msg.sender sends _amount to _to on _from's behalf 
    function transferFrom(TokenStorage storage self, address _from, address _to, uint _amount) public returns (bool) {
        //@audit - requires reciever of transfer to be whitelisted in this token 
        require(isWhitelisted(self,_to));
        //@audit - returns total balance of _from in self 
        uint balance_owner = self.user_total_balances[_from];
        //@audit - returns total amount tokens that msg.sender is allowed to send on _from's behalf 
        uint sender_allowed = self.allowed[_from][msg.sender];
        //@audit - checks for valid inputs 
        if (
            _to == _from ||
            _to == address(0) ||
            _amount == 0 ||
            balance_owner < _amount ||
            sender_allowed < _amount
        ) return false;
        //@audit - execute transfer with transfer 
        transferHelper(self,_from, _to, _amount);
        //@audit - safe-add and safe-sub _amount from the _from and _to accounts total balances 
        self.user_total_balances[_from] = self.user_total_balances[_from].sub(_amount);
        self.user_total_balances[_to] = self.user_total_balances[_to].add(_amount);
        //@audit - safe-sub _amount from the amount of tokens that msg.sender can spend on _from's behalf 
        self.allowed[_from][msg.sender] = self.allowed[_from][msg.sender].sub(_amount);
        //@audit - emit Transfer event 
        emit Transfer(_from, _to, _amount);
        //@audit - return true upon successful completion of transfer 
        return true;
    }


    //@audit - msg.sender's approve's _spender to spend _amount on his/her behalf 
    function approve(TokenStorage storage self, address _spender, uint _amount) public returns (bool) {
        //@audit - sets the amount that _spender can spend on msg.sender's behalf to _amount 
        self.allowed[msg.sender][_spender] = _amount;
        //@audit - emit Approval event 
        emit Approval(msg.sender, _spender, _amount);
        //@audit - return true upon successful completion of approval 
        return true;
    }

    //@audit - returns length of number of accounts holding tokens in _swap contract
    function addressCount(TokenStorage storage self, address _swap) public constant returns (uint) {  
        return self.swap_balances[_swap].length; 
    }

    //@audit - returns amount and owner held in Balance struct in the _ind index of _swap's entry in swap_balances 
    function getBalanceAndHolderByIndex(TokenStorage storage self, uint _ind, address _swap) public constant returns (uint, address) { 
        return (self.swap_balances[_swap][_ind].amount, self.swap_balances[_swap][_ind].owner);
    }

    //@audit - returns the index of _owner in the Balances[] corresponding to _swap in swap_balances 
    function getIndexByAddress(TokenStorage storage self, address _owner, address _swap) public constant returns (uint) {
        return self.swap_balances_index[_swap][_owner]; 
    }

    //@audit - returns the amount that _spender can spend on _owner's behalf
    function allowance(TokenStorage storage self, address _owner, address _spender) public constant returns (uint) { 
        return self.allowed[_owner][_spender]; 
    }
}
