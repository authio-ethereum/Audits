// @audit - A Safe Math library -- used to protect against overflows and underflows
library SafeMathLib{

  // @audit - A safe multiplication function -- reverts on overflows
  // @param - a: The first number to multiply
  // @param - b: The second number to multiply
  // @returns - uint: The product of a and b
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // @audit - Set c to be the product of a and b
    uint256 c = a * b;
    // @audit - Ensure that either a is zero or that the quotient of c and a is b -- ensures that an overflow didn't occur
    assert(a == 0 || c / a == b);
    return c;
  }

  // @audit - A safe division function -- reverts when dividing by zero 
  // @param - a: The numerator 
  // @param - b: The divisor -- the function throws if this is zero
  // @returns - uint: The quotient of a and b
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  // @audit - A safe subtraction function -- reverts on underflows
  // @param - a: The number being subtracted by b
  // @param - b: The number being subtracted from a
  // @returns - uint: The difference of a and b
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    // @audit - Ensure that b is less than or equal to a --> prevents underflows
    assert(b <= a);
    return a - b;
  }
  
  // @audit - A safe addition function -- reverts on overflows
  // @param - a: The first number to add
  // @param - b: The second number to add
  // @returns - uint: The sum of a and b
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    // @audit - Set c equal to the sum of a and b
    uint256 c = a + b;
    // @audit - Ensure that c is greater than a --> prevents overflows
    assert(c >= a);
    return c;
  }
}
