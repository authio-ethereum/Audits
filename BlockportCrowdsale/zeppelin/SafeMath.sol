//@audit - Version pragma
//@audit - NOTE: Use the latest version of Solidity: 0.4.19
pragma solidity ^0.4.13;

//@audit - SafeMath library, allows for mathematical operations without fear of overflow
//@audit - NOTE: Mark functions as pure
library SafeMath {

  //@audit - mul takes as input uint a and b, and returns their product
  function mul(uint256 a, uint256 b) internal  returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  //@audit - Div takes as input uint a and b, and returns a / b
  function div(uint256 a, uint256 b) internal  returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  //@audit - Div takes as input uint a and b, and returns a - b
  function sub(uint256 a, uint256 b) internal  returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  //@audit - Div takes as input uint a and b, and returns their sum
  function add(uint256 a, uint256 b) internal  returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
