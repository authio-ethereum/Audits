pragma solidity ^0.4.21;

// @audit - A library that reverts on overflows and underflows
library SafeMath {
  // @audit - If there will be an integer overflow, reverts. Otherwise, multiplies numbers normally 
  // @param - a: The first number to multiply
  // @param - b: The second number to multiply
  // @returns - uint: If the multiplication was successful, return the result
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    // @audit - Ensure that either a is zero or that c divided by a equals b. a will never be 0 when c / a is called on account of short circuiting.
    //          If a is 0 then an overflow is impossible. Likewise, if c / a equals b, then an overflow didn't occur since divisions don't experience underflows 
    assert(a == 0 || c / a == b);
    return c;
  }

  // @audit - A normal division operation
  // @param - a: The numerator 
  // @param - b: The dividend 
  // @returns - uint: The result of the division 
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  // @audit - If there will be an integer underflow, reverts. Otherwise, subtracts numbers normally 
  // @param - a: The number to subtract from  
  // @param - b: The number to subtract by 
  // @returns - uint: If the multiplication was successful, return the result
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    // @audit - Reverts if b is greater than a
    assert(b <= a);
    return a - b;
  }

  // @audit - If there will be an integer overflow, reverts. Otherwise, add numbers normally 
  // @param - a: The first number to add 
  // @param - b: The second number to add
  // @returns - uint: If the addition was successful, return the result
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    // @audit - If c is less than a, revert. The addition of two nonzero integers is always greater than or equal to either of the arguments
    assert(c >= a);
    return c;
  }

  // @audit - Calculates the minimum of two numbers 
  // @param - a: The first number 
  // @param - b: The second number
  // @returns - uint: The minimum of the two numbers
  function min(uint a, uint b) internal pure returns (uint256) {
    // @audit - If a is less than b, return a. Otherwise return b
    return a < b ? a : b;
  }
}
