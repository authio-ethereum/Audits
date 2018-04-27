pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';
import './LockableToken.sol';

//@audit - LOW: Possible to set this in the Crowdsale with finishMinting having already been called. No loss in funds because no one can purchase tokens, but a waste of time.
//ISSUE FIXED IN COMMIT: d60e2fc
contract EthearnalRepToken is MintableToken, LockableToken {
    string public constant name = 'Ethearnal Rep Token';
    string public constant symbol = 'ERT';
    uint256 public constant decimals = 18;
}
