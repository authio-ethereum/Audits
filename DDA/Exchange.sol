pragma solidity ^0.4.23;

 import "./libraries/SafeMath.sol";
 import "./interfaces/ERC20_Interface.sol";

contract Exchange{ 
    
    using SafeMath for uint256;

    //@audit - address of the owner of the exchange 
    address public owner; 
    
    //@audit - struct holding all the information of an owner 
    struct Order {
        address maker;
        uint price;
        uint amount;
        address asset;
    }

    //@audit - maps order_id to its corresponding Order struct 
    mapping(uint256 => Order) public orders;
    
    //@audit - maps token address to all orders corresponding to that order 
    mapping(address =>  uint256[]) public forSale;
    
    //@audit - maps an order_nonce to it's index in it's respective address' entry in forSale 
    mapping(uint256 => uint256) internal forSaleIndex;
    
    //@audit - array of token addresses that have open orders  
    address[] public openBooks;
    
    //@audit - maps token address to its index in openBooks 
    mapping (address => uint) internal openBookIndex;
    
    //@audit - maps user's to a list of their order's 
    mapping(address => uint[]) public userOrders;
    
    //@audit - mapping that keeps track of an order_id's index in its maker's entry in userOrder's
    mapping(uint => uint) internal userOrderIndex;
    
    //@audit - mapping that keeps track of blacketlisted addresses 
    mapping(address => bool) internal blacklist;
    
    //@audit - uint keeping track of nonce of this account 
    uint internal order_nonce;

    //audit - modifier that only allows owner of this exchange to modify state 
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    event OrderPlaced(address _sender,address _token, uint256 _amount, uint256 _price);
    event Sale(address _sender,address _token, uint256 _amount, uint256 _price);
    event OrderRemoved(address _sender,address _token, uint256 _amount, uint256 _price);

    //@audit - Constructor- assigns msg.sender to be the owner, push address(0) to openBooks and set the nonce to one 
    constructor() public{
        owner = msg.sender;
        openBooks.push(address(0));
        order_nonce = 1;
    }

    //@audit - list a new order for a specific token 
    function list(address _tokenadd, uint256 _amount, uint256 _price) external {
        //@audit - require that _tokenadd is a valid address and that _amount > 0
        //@audit - user attempting to list() cannot be on the blacklist 
        require(blacklist[msg.sender] == false);
        //@audit - price must be greater than 0
        require(_price > 0);
        //@audit - create a ERC20_Interface at address _tokenadd 
        ERC20_Interface token = ERC20_Interface(_tokenadd);
        //@audit - Asserrt that this contract has enough allowance in token to spend on msg.sender's behalf
        require(token.allowance(msg.sender,address(this)) >= _amount);
        //@audit - if this token has no other orders that have been listed then set up its forSale entry 
        if(forSale[_tokenadd].length == 0){
            forSale[_tokenadd].push(0);
        }
        //@audit - add the current nonce into forSaleIndex and stores it's index in tokenadd's entry in forSale    
        forSaleIndex[order_nonce] = forSale[_tokenadd].length;
        //@audit - push the current order_nonce onto _tokenadd's entry in forSale 
        forSale[_tokenadd].push(order_nonce);
        //@audit - creates an order instance for this list call and stores it in the order array at index order_nonce 
        orders[order_nonce] = Order({
            maker: msg.sender,
            asset: _tokenadd,
            price: _price,
            amount:_amount
        });
        //@audit - emit the correct event    
        emit OrderPlaced(msg.sender,_tokenadd,_amount,_price);
        //@audit - if this token has not already been placed on the openBooks listing, place it on the openBooks list and store it's index on the list in openBook index 
        if(openBookIndex[_tokenadd] == 0 ){    
            openBookIndex[_tokenadd] = openBooks.length;
            openBooks.push(_tokenadd);
        }
        //@audit - store the index of this current order in the userOrder's mapping for msg.sender 
        userOrderIndex[order_nonce] = userOrders[msg.sender].length;
        //@audit - add this order_nonce to msg.sender's list of orders 
        userOrders[msg.sender].push(order_nonce);
        //@audit - increment nonce 
        order_nonce += 1;
    }


    function unlist(uint256 _orderId) external{
        //@audit - require that _orderId is for a valid order 
        require(forSaleIndex[_orderId] > 0);
        //@audit - retrieve the correct Order struct corresponding to this order_id 
        Order memory _order = orders[_orderId];
        //@audit - require that either the maker of the listing or the owner of the exchange is sending this request 
        require(msg.sender== _order.maker || msg.sender == owner);
        //@audit - call the underlister helper function 
        unLister(_orderId,_order);
        //@audit - emit the correct event 
        emit OrderRemoved(msg.sender,_order.asset,_order.amount,_order.price);
    }

    function buy(uint256 _orderId) external payable {
        //@audit - check for valid inputs 
        //@audit - retrive the order corresponding to _orderID 
        Order memory _order = orders[_orderId];
        //@audit - the amount of wei sent with this function call must be equal to the price of the _orde 
        require(msg.value == _order.price);
        //@audit - caller of buy cannto be blacklisted 
        require(blacklist[msg.sender] == false);
        //@audit - assign the maker of the _order corresping to _orderID to maker 
        address maker = _order.maker;
        //@audit - create a ERC20_Interface instance around the token held in _order 
        ERC20_Interface token = ERC20_Interface(_order.asset);
        //@audit - this exchange contract must be allowed to spend at least _order.amount on the maker;s behalf 
        if(token.allowance(_order.maker,address(this)) >= _order.amount){
            //@audit - transferFrom _order.amount from the maker of the order to the caller of buy
            //@audit - if transferFrom is successful, the program will continue. If not, then the function will revert 
            assert(token.transferFrom(_order.maker,msg.sender, _order.amount));
            //@audit - transfer the maker of the order, the price of the order that was just bough from them 
            maker.transfer(_order.price);
        }
        //@audit - unlist the order that was bought 
        unLister(_orderId,_order);
        //@audit - emit the correct event 
        emit Sale(msg.sender,_order.asset,_order.amount,_order.price);
    }

    //@audit - returns all fields of an Order struct corresponding to a specific _orderID
    function getOrder(uint256 _orderId) external view returns(address,uint,uint,address){
        Order storage _order = orders[_orderId];
        return (_order.maker,_order.price,_order.amount,_order.asset);
    }

    //@audit - allows only the owner of this exchange to change the owner of this exchange 
    function setOwner(address _owner) public onlyOwner() {
        owner = _owner;
    }

    //@audit - allows only the owner of this exchange to change a specific address' blacklist status 
    function blacklistParty(address _address, bool _motion) public onlyOwner() {
        blacklist[_address] = _motion;
    }

    //@audit - returns whether or not _address is blacklisted 
    function isBlacklist(address _address) public view returns(bool) {
        return blacklist[_address];
    }

    //@audit - returns number of orders corresponding to a certain token 
    function getOrderCount(address _token) public constant returns(uint) {
        return forSale[_token].length;
    }

    //@audit - returns count of all tokens with open orders 
    function getBookCount() public constant returns(uint) {
        return openBooks.length;
    }

    //@audit - returns all orders corresponsing to a specific token 
    function getOrders(address _token) public constant returns(uint[]) {
        return forSale[_token];
    }

    //@audit - returns list of order_ids's of all orders that _user is involved in 
    function getUserOrders(address _user) public constant returns(uint[]) {
        return userOrders[_user];
    }

    function unLister(uint256 _orderId, Order _order) internal{
        //@audit - get the index of the order in it's token's forSale entry   
        uint256 tokenIndex = forSaleIndex[_orderId];
        //@audit - get index of last order added to the token's forSale entry 
        uint256 lastTokenIndex = forSale[_order.asset].length.sub(1);
        //@audit - get the order_id for the order that corresponds to lastTokenIndex
        uint256 lastToken = for_Sale[_order.asset][lastTokenIndex];
        //@audit - set the lastToken in the place of the order to unList  
        forSale[_order.asset][tokenIndex] = lastToken;
        //@audit - set lastToken's index to its new index in the forSale entry for the _order.asset token 
        forSaleIndex[lastToken] = tokenIndex;
        //@audit - reduce the length of forSale's order list by 1- thereby deleting the last order
        forSale[_order.asset].length--;
        //@audit - zero out the unlisted entry's entry in forSaleIndex 
        forSaleIndex[_orderId] = 0;
        //@audit - zero out the entry for _orderId in the order's listing 
        orders[_orderId] = Order({
            maker: address(0),
            price: 0,
            amount:0,
            asset: address(0)
        });
        //@audit - if this order is the only order under the _order.asset token, then remove this token from all relevent listing 
        if(forSale[_order.asset].length == 1){
            //@audit - find the addres of the token in the openBooks array 
            tokenIndex = openBookIndex[_order.asset];
            //@audit - find the index of the lastToken added to the openBooks array 
            lastTokenIndex = openBooks.length.sub(1);
            //@audit - obtain the address of this "last token"
            address lastAdd = openBooks[lastTokenIndex];
            //@audit - put the "last added token" into openBooks at the index of the token to be removed 
            openBooks[tokenIndex] = lastAdd;
            //@audit - update the index of lastAdd in the openBookIndex 
            openBookIndex[lastAdd] = tokenIndex;
            //@audit - reduce the length of openBooks by 1, deleting the last entry 
            openBooks.length--;
            //@audit - zero out the entry holding the index of the token that was deleted 
            openBookIndex[_order.asset] = 0;
            //@audit - delete the only entry in the array holding all order's corresponding to the token 
            forSale[_order.asset].length--;
        }

        //@audit - obtain the index for the order in the userOrder 
        tokenIndex = userOrderIndex[_orderId];
        //@audit - obtain the index for the last order in the entry for the order's maker in userOrder 
        lastTokenIndex = userOrders[_order.maker].length.sub(1);
        //@audit - obtain the order_id corresponding to the last order in the order maker's entry in userOrders  
        lastToken = userOrders[_order.maker][lastTokenIndex];
        //@audit - replace the order that was removed by the last order 
        userOrders[_order.maker][tokenIndex] = lastToken;
        //@audit - update lastToken's index in userOrderIndex 
        userOrderIndex[lastToken] = tokenIndex;
        //@audit - reduce the length of the order maker's entry in userOrders by 1, deleting the order 
        userOrders[_order.maker].length--;
        //@audit - zero out the deleted order's index in userOrder index 
        userOrderIndex[_orderId] = 0;
    }
}
