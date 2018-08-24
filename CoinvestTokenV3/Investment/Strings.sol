/*
 * @title String & slice utility library for Solidity contracts.
 * @author Nick Johnson <arachnid@notdot.net>
 *
 * @dev Functionality in this library is largely implemented using an
 *      abstraction called a 'slice'. A slice represents a part of a string -
 *      anything from the entire string to a single character, or even no
 *      characters at all (a 0-length slice). Since a slice only has to specify
 *      an offset and a length, copying and manipulating slices is a lot less
 *      expensive than copying and manipulating the strings they reference.
 *
 *      To further reduce gas costs, most functions on slice that need to return
 *      a slice modify the original one instead of allocating a new one; for
 *      instance, `s.split(".")` will return the text up to the first '.',
 *      modifying s to only contain the remainder of the string after the '.'.
 *      In situations where you do not want to modify the original slice, you
 *      can make a copy first with `.copy()`, for example:
 *      `s.copy().split(".")`. Try and avoid using this idiom in loops; since
 *      Solidity has no memory management, it will result in allocating many
 *      short-lived slices that are later discarded.
 *
 *      Functions that return two slices come in two versions: a non-allocating
 *      version that takes the second slice as an argument, modifying it in
 *      place, and an allocating version that allocates and returns the second
 *      slice; see `nextRune` for example.
 *
 *      Functions that have to copy string data will return strings rather than
 *      slices; these can be cast back to slices for further processing if
 *      required.
 *
 *      For convenience, some functions are provided with non-modifying
 *      variants that create a new slice and return both; for instance,
 *      `s.splitNew('.')` leaves s unmodified, and returns two values
 *      corresponding to the left and right parts of the string.
 */

pragma solidity ^0.4.14;

library strings {
    struct slice {
        uint _len;
        uint _ptr;
    }

    //@ Audit - Helper function to do memory management
    //@ Params - dest is the memory location to copy to, src is the memory source location and len is the amount to copy
    function memcpy(uint dest, uint src, uint len) private pure {
        for(; len >= 32; len -= 32) { //@ Audit - Each mload and mstore takes 32 byte chunks (words) so we iterate over all of these possible
            assembly {
                mstore(dest, mload(src)) //@ Audit - Stores the 32 bytes of memory from source to dest
            }
            dest += 32; //@ Audit - Adds 32 to dest to move to the next word
            src += 32; //@ Audit - Adds 32 to src to move the copyed info forward one word
        }

        //@ Audit - Anything left over gets copied
        uint mask = 256 ** (32 - len) - 1; //@ Audit - Gets a uint thats 0 for the first len bytes
        assembly {
            let srcpart := and(mload(src), not(mask)) //@ Audit - gets the first len bytes of the 32 bytes at src and leaves the rest zero
            let destpart := and(mload(dest), mask) //@ Audit - Gets the current values of the last 32-len bytes
            mstore(dest, or(destpart, srcpart)) //@ Audit - Stores the 32 bytes (len bytes from src) then (32 - len bytes from dest)
        }
    }

    //@ Audit - Turns a string into a slice
    //@ Params - self the string
    //@ Return - returns the slice struct
    function toSlice(string self) internal pure returns (slice) {
        uint ptr; //@ Audit - Declares ptr so we can set in the assembly block
        assembly {
            ptr := add(self, 0x20) //@ Audit - The first 32 bytes are a string length so we set the ptr to the start of the data
        }
        return slice(bytes(self).length, ptr); //@ Audit - returns the struct which is the length of the string and the data pointer
    }

    //@ Audit - Gets the length of a bytes 32 value ending in zeros
    //@ Params - self the bytes32 to Check
    //@ Return - Returns the unit length
    function len(bytes32 self) internal pure returns (uint) {
        uint ret; //@ Audit - Declares a holder value
        if (self == 0) //@ Audit - If its zero its length is zero
            return 0; //@ Audit -  So return 0
        if (self & 0xffffffffffffffffffffffffffffffff == 0) { //@ Audit - If the last 16 bytes are zero
            ret += 16; //@ Audit - Add 16 to the ret holder value
            self = bytes32(uint(self) / 0x100000000000000000000000000000000); //@ Audit - Right shift by 16 bytes
        }
        if (self & 0xffffffffffffffff == 0) { //@ Audit - If the last 8 bytes are zero
            ret += 8; //@ Audit - Add 8 to the ret holder
            self = bytes32(uint(self) / 0x10000000000000000); //@ Audit - Right shift by 8 bytes
        }
        if (self & 0xffffffff == 0) { //@ Audit -If the last four bytes are zero
            ret += 4; //@ Audit - Add 4 to the ret holder
            self = bytes32(uint(self) / 0x100000000); //@ Audit -Right shift by 4 bytes
        }
        if (self & 0xffff == 0) { //@ Audit - If the last 2 bytes are zero
            ret += 2; //@ Audit - Add two the ret hold varible
            self = bytes32(uint(self) / 0x10000); //@ Audit - Right shift by 2 bytes
        }
        if (self & 0xff == 0) { //@ Audit - Check if the last byte is zero
            ret += 1; //@ Audit - If it is add one to the ret
        } //@ Audit -We don't need to shift for this final test
        return 32 - ret; //@ Audit - We return 32 minus the number bytes that are zero at the end of self
    }

    //@ Audit - Copies a bytes32 value into a slice and returns it
    //@ Params - self the bytes32 value
    //@ Return - ret is the slice
    function toSliceB32(bytes32 self) internal pure returns (slice ret) {
        assembly {
            let ptr := mload(0x40) //@ Audit - Loads the free memory pointer
            mstore(0x40, add(ptr, 0x20)) //@ Audit - Moves the free memory point 32 bytes forward
            mstore(ptr, self) //@ Audit - Stores the 32 bytes at the allocated memory
            mstore(add(ret, 0x20), ptr) //@ Audit - Stores the the ptr at the 32 bytes past the start of the return
        }
        ret._len = len(self); //@ Audit - Stores the length of the bytes32 in the first 32 bytes of the ret slice
    }

    //@ Audit - Returns a new slide struct with the same values as the old one
    //@ Params - self is the old slide
    //@ Return - returns the new slice
    function copy(slice self) internal pure returns (slice) {
        return slice(self._len, self._ptr); //@ Audit - Returns a new slice with the same values as the old one
    }

    //@ Audit - Copies the info from a slice into a string
    //@ Params - self is the slice to convert
    //@ Return - Returns the new string
    function toString(slice self) internal pure returns (string) {
        string memory ret = new string(self._len); //@ Audit - Declares a new string with the length of the slice
        uint retptr; //@ Audit - Declares retptr so it can be assigned in assembly
        assembly { retptr := add(ret, 32) } //@ Audit - Sets retptr to the string data location

        memcpy(retptr, self._ptr, self._len); //@ Audit - Uses memcpy to copy the info in the string to the retptr location
        return ret; //@ Audit - Returns ret as it is now a string
    }

    //@ Audit - Returns the rune length of a slice
    //@ Params - self the slice to check
    //@ Return - returns the uint length l
    function len(slice self) internal pure returns (uint l) {
        uint ptr = self._ptr - 31; //@ Audit - moves the data pointer back by 31 bytes
        uint end = ptr + self._len; //@ Audit - Sets an end position for our loop
        for (l = 0; ptr < end; l++) { //@ Audit - Runs while ptr< end
            uint8 b; //@ Audit - Declares b to be filled in assembly
            assembly { b := and(mload(ptr), 0xFF) } //@ Audit - Cleans all but the last byte of the 32 bytes loaded from ptr
            if (b < 0x80) { //@ Audit -Preforms the unicode encoding check, if b < 0x80 its a length one rune
                ptr += 1; //@ Audit - So we add one to the pointer
            } else if(b < 0xE0) { //@ Audit - If b>0x80 and b < 0xE0 then the rune is length 2
                ptr += 2; //@ Audit - Add two the pointer
            } else if(b < 0xF0) { //@ Audit - If b>0xE0 and b < 0xF0 then the rune is length 3
                ptr += 3; //@ Audit - So we add 3 to the pointer
            } else if(b < 0xF8) { //@ Audit - If b>0xF0 and b < 0xF8 then the rune is length 4
                ptr += 4; //@ Audit So we add 4 to the pointer
            } else if(b < 0xFC) { //@ Audit - If b>0xF* and b < 0xFC then the rune is length 5
                ptr += 5; //@ Audit So we add 5 to the pointer
            } else { //@ Audit - If b>0xFC then its length six
                ptr += 6; //@ Audit So we add 6 to the pointer
            }
        }//@ Audit - As this system moves through the data it will jump forward by rune length each step and thus l will count the runes
    }

    //@ Audit - Method to test if a slice is empty
    //@ Params - self is the slice in question
    //@ Return - returns a bool of whether or not the slice is empty
    function empty(slice self) internal pure returns (bool) {
        return self._len == 0; //@ Audit - If len = 0 the slice is empty
    }

    //@ Audit - Returns a lexographical comparsion of the slices in question
    //@ Param - self The first slice to compare.
    //@ Param - other The second slice to compare.
    //@ Return - the int symbolizing the comparsion (+ if self > other, 0 if self = other, and - if self < other)
    function compare(slice self, slice other) internal pure returns (int) {
        uint shortest = self._len; //@ Audit - sets shortest to be the length of the first slice
        if (other._len < self._len) //@ Audit - If its not the shortest
            shortest = other._len; //@ Audit -  then we set shortest to the length of the other

        uint selfptr = self._ptr; //@ Audit - Copies the self.ptr
        uint otherptr = other._ptr; //@ Audit -  Copies the other.ptr
        for (uint idx = 0; idx < shortest; idx += 32) { //@ Audit - We parse through each 32 byte word
            uint a; //@ Audit - Declares a and b so they can be assigned in the assembly block
            uint b;
            assembly {
                a := mload(selfptr) //@ Audit - gets the value at the self pointer
                b := mload(otherptr) //@ Audit - gets the value at the other pointer
            }
            if (a != b) { //@ Audit - Checks if the values are the same
                //@ Audit -  It might have been a false postive so we zero out extra bits
                uint256 mask = uint256(-1); // 0xffff...
                if(shortest < 32) { //@ Audit - This should be (shortest - idx), I opened an issue on the github for this (TODO)
                  mask = ~(2 ** (8 * (32 - shortest + idx)) - 1); //@ Audit - prepares a mask of the first idx - shortest as f with rest 0
                }
                uint256 diff = (a & mask) - (b & mask);  //@ Audit - masks out the last shortest - idx chars
                if (diff != 0) //@ Audit - If they are not the same now
                    return int(diff); //@ Audit - Return that diffrence
            }
            selfptr += 32; //@ Audit - Move onto the next word in self's data
            otherptr += 32; //@ Audit - Move onto the next word in other's data
        }
        return int(self._len) - int(other._len); //@ Audit - Subtracts the length as lexographically if one string is a substring of the other this calculates the order
    }

    //@ Audit - This tests if two slices are the same
    //@ Params - self the first slice, other the second slice
    //@ Return - returns a bool of whether they are equal
    function equals(slice self, slice other) internal pure returns (bool) {
        return compare(self, other) == 0; //@ Audit - Calls the compare method and tests if it says they are equal
    }

    //@ Audit - Takes a rune out of the string and returns the string after it
    //@ Params - self the slice to work on, rune the location to put the rune removed
    //@ Return - returns the string data after that rune
    function nextRune(slice self, slice rune) internal pure returns (slice) {
        rune._ptr = self._ptr; //@ Audit - Rune will point to the same data as self

        if (self._len == 0) { //@ Audit - If self is empty
            rune._len = 0; //@ Audit - Set rune to be empty
            return rune; //@ Audit -Return an empty slice
        }

        uint l; //@ Audit - Declares l and b so they can be assigned in assembly
        uint b;

        assembly { b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF) } //@ Audit - Takes the first byte of self
        if (b < 0x80) { //@ Audit - If its less than 0x80 its length 1
            l = 1;
        } else if(b < 0xE0) { //@ Audit - If its less than 0xEO and bigger than 0x80 its length two
            l = 2;
        } else if(b < 0xF0) { //@ Audit - If its less than 0xFO and bigger than 0xE0 its length three
            l = 3;
        } else { //@ Audit - If its less than 0xFO its length four
            l = 4;
        }

        //@ Audit - Checks to make sure we didn't get more data then we were supposed to
        if (l > self._len) { //@ Audit - If l is more than the length of self
            rune._len = self._len; //@ Audit - Rune is self long
            self._ptr += self._len; //@ Audit - Self's pointer needs to be moved to its end
            self._len = 0; //@ Audit - and self's length is 0
            return rune; //@ Audit - We must be done so we return rune
        }

        self._ptr += l; //@ Audit - Moves the self pointer forward by the rune length
        self._len -= l; //@ Audit - Reduces the length of our slice by rune length
        rune._len = l; //@ Audit - Sets the rune slice length to rune length
        return rune; //@ Audit -  Returns the rune
    }

    //@ Audit - A container for the above function with no rune memory management
    //@ Param - self the slice to move forward on
    //@ Return -  returns the rune
    function nextRune(slice self) internal pure returns (slice ret) {
        nextRune(self, ret); //@ Audit - By naming the return we initialize it and give that value to the function above
    }

    //@ Audit - Returns the first codepoint in a slice
    //@ Param - self the slice get the codepoint of
    //@ Return - returns the uint codepoint
    function ord(slice self) internal pure returns (uint ret) {
        if (self._len == 0) { //@ Audit - If its zero length there is no next code point
            return 0; //@ Audit - Return zero
        }

        uint word; //@ Audit - Declares word and length to be assigned in the assembly block
        uint length;
        uint divisor = 2 ** 248; //@ Audit - Divsior is f everywhere execpt for a single byte

        assembly { word:= mload(mload(add(self, 32))) } //@ Audit - Puts the uint glyph into the most sigfigant bit of word
        uint b = word / divisor; //@ Audit - Moves the glyph to the least sigfigant bits of b
        if (b < 0x80) { //@ Audit - We now check how many code points are in out glyph
          //@ Audit - If its less than 0x80 its length 1
            ret = b; //@ Audit - If its one then our return is that code point
            length = 1; //@ Audit - We assign length for use later
        } else if(b < 0xE0) {//@ Audit - If its less than 0xEO and bigger than 0x80 its length two
            ret = b & 0x1F; //@ Audit - If its two then our return is that code point subtracted with some values
            length = 2;//@ Audit - We assign length for use later
        } else if(b < 0xF0) {  //@ Audit - If its less than 0xFO and bigger than 0xE0 its length three
            ret = b & 0x0F; //@ Audit - If its three then our return is that code point subtracted with some values
            length = 3; //@ Audit - We assign length for use later
        } else { //@ Audit - If its greater than 0xF0 then its length four
            ret = b & 0x07; //@ Audit - If its four then our return is that code point subtracted with some values
            length = 4; //@ Audit - We assign length for use later
        }

        //@ Audit - We check that we haven't taken more data than we should
        if (length > self._len) { //@ Audit - If the codepoint length is more than self.len
            return 0; //@ Audit - We return zero
        }

        for (uint i = 1; i < length; i++) { //@ Audit - We extract the code point based on length
            divisor = divisor / 256; //@ Audit - Remove some fs from the mask
            b = (word / divisor) & 0xFF; //@ Audit - Sets b to be the and of the bits of word/divisor
            if (b & 0xC0 != 0x80) { //@ Audit - In UTF-8 this should hold
                return 0; //@ Audit -  Otherwise return zero
            }
            ret = (ret * 64) | (b & 0x3F); //@ Audit - Right shift return by 3 bytes then or it with a cleaned b
        }

        return ret;
    }

    //@ Audit - Returns the hash of the slice
    //@ Params - self the slice we want to hash
    //@ Return - returns bytes32 hash
    function keccak(slice self) internal pure returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
            //@ Audit - Since ret is declared in the return we can assign in in assembly
            //@ Audit - We use keccak256 which hashes from the slice pointer for slice length bytes
        }
    }

    //@ Audit - Checks if one slice starts with another
    //@ Params - self the slice to check, needle the slice to check for
    //@ Return - Returns the bool of whether it starts with that needle
    function startsWith(slice self, slice needle) internal pure returns (bool) {
        if (self._len < needle._len) { //@ Audit - If the self slice is too short to contain needle
            return false; //@ Audit - Return false
        }

        if (self._ptr == needle._ptr) { //@ Audit - If self is long enough and both of the slices point to the same memory location
            return true; //@ Audit - Then slice must start with needle
        }

        bool equal; //@ Audit - Declares equal so it can be assgined in the assembly block
        assembly {
            let length := mload(needle) //@ Audit - Gets the length of the needle
            let selfptr := mload(add(self, 0x20)) //@ Audit - Gets the data pointer of self
            let needleptr := mload(add(needle, 0x20)) //@ Audit - Gets the data pointer of needle
            equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
            //@ Audit - assgins equal to be the equality test of the hash of the first length bytes of self and needle
        }
        return equal; //@ Audit - Returns if the first bytes are equal
    }

    //@ Audit - If self starts with needle this method cuts that off and returns the new slice
    //@ Params - self the slice to be checked and edited, needle the slice to check for
    //@ Return - Returns the new slice
    if (self._ptr != needle._ptr) { //@ Audit - If the ptrs are equal then self contains needle
    function beyond(slice self, slice needle) internal pure returns (slice) {
        if (self._len < needle._len) { //@ Audit - If the needle is longer than self
            return self; //@ Audit - Then it cannot start with needle so we return self
        }

        bool equal = true; //@ Audit - Sets equal to true
            assembly {
                let length := mload(needle) //@ Audit - Gets the length of needle
                let selfptr := mload(add(self, 0x20)) //@ Audit - Gets the data pointer of self
                let needleptr := mload(add(needle, 0x20)) //@ Audit -  Gets the data pointer of needle
                equal := eq(sha3(selfptr, length), sha3(needleptr, length))
                //@ Audit - assigns equal to the equality of the hash of the first length bytes of needle and self
            }
        }

        if (equal) { //@ Audit - If self starts with needle
            self._len -= needle._len; //@ Audit - Reduces the self length by needle length
            self._ptr += needle._len; //@ Audit - Moves the slice data pointer forward by length of the needle
        }

        return self; //@ Audit - Returns the edited slice
    }

    //@ Audit - Checks if a slice ends with another slice
    //@ Params - self the slice to check, needle to check for
    function endsWith(slice self, slice needle) internal pure returns (bool) {
        if (self._len < needle._len) { //@ Audit - If needle is longer than self
            return false; //@ Audit - then it cannot be at the end of self
        }

        uint selfptr = self._ptr + self._len - needle._len; //@ Audit - Sets a pointer to needle length from the end of self

        if (selfptr == needle._ptr) { //@ Audit -  If the needle points to that memory locaiton
            return true; //@ Audit - We know that they are the same
        }

        bool equal; //@ Audit - Declares equal to be assigned in the assembly block
        assembly {
            let length := mload(needle) //@ Audit - Gets the length of the needle
            let needleptr := mload(add(needle, 0x20)) //@ Audit - Gets the data pointer of needle
            equal := eq(keccak256(selfptr, length), keccak256(needleptr, length)) //@ Audit - Compares the hash of the end of self and the hash of needle
        }

        return equal; //@ Audit - Returns the result of that comparsion
    }

    //@ Audit - Checks the end of a slice for a string and if its there removes it
    //@ Params - self the slice to check, needle the slice to check for
    //@ Return - Returns the edited slice
    function until(slice self, slice needle) internal pure returns (slice) {
        if (self._len < needle._len) { //@ Audit - If the length of self is less than needle
            return self; //@ Audit - self cannot contain needle so we return it unedited
        }

        uint selfptr = self._ptr + self._len - needle._len; //@ Audit - Gets a pointer to the memory location the length of needle from the end of self
        bool equal = true; //@ Audit - Declares equal to true
        if (selfptr != needle._ptr) { //@ Audit - If selfptr is equal to needle.ptr they are definitly the same
            assembly {
                let length := mload(needle) //@ Audit - Gets the length of needle
                let needleptr := mload(add(needle, 0x20)) //@ Audit - Gets a pointer to the data of needle
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
                //@ Audit - Checks if the hash of needle and the hash of the end of self are the same
            }
        }

        if (equal) { //@ Audit - If self ends with needle
            self._len -= needle._len; //@ Audit - We just have to reduce the length of self
        }

        return self; //@ Audit - We then return the edited slice
    }

    event log_bytemask(bytes32 mask); //@ Audit - Declares a log_bytemask event, never used in code

    //@ Audit - Gets the pointer to the first instance of needle in self or the byte after the self data
    //@ Params - (selflen, selfptr) the slice to check for needle, (needlelen, needleptr) the slice to check for
    //@ Return - Returns the memory pointer
    function findPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr = selfptr; //@ Audit - assigns ptr to selfptr
        uint idx; //@ Audit - Declares idx

        if (needlelen <= selflen) { //@ Audit - Requires that the needle could fit in self
            if (needlelen <= 32) { //@ Audit - For short needles
                bytes32 mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1)); //@ Audit - We set a mask to zero all but 8*needlelen bytes

                bytes32 needledata; //@ Audit - Declares a needle data holder
                assembly { needledata := and(mload(needleptr), mask) } //@ Audit - Sets needle data to the cleaned mload of 32 bytes at needleptr

                uint end = selfptr + selflen - needlelen; //@ Audit - Sets the last possible start point for needle (needle length from the end of self)
                bytes32 ptrdata; //@ Audit - Declares ptrdata
                assembly { ptrdata := and(mload(ptr), mask) } //@ Audit - sets the first ptr data to be the cleaned 32 bytes from the ptr

                while (ptrdata != needledata) { //@ Audit - Iterates over all possible start positions and checks if the data from self is equal to the data from needle
                    if (ptr >= end) //@ Audit - If we have gone beyond the last possible position
                        return selfptr + selflen; //@ Audit - then we return the byte after the self data
                    ptr++; //@ Audit - Moves our ptr forward
                    assembly { ptrdata := and(mload(ptr), mask) } //@ Audit - Gets the needle length bytes of data after the ptr
                }
                return ptr; //@ Audit - Returns the first pointer found where the needle data matches
            } else { //@ Audit - For long needles we use hashing
                bytes32 hash; //@ Audit - declares a hash varible to be assigned in assembly
                assembly { hash := sha3(needleptr, needlelen) } //@ Audit - sets the hash to the hash of the needle data

                for (idx = 0; idx <= selflen - needlelen; idx++) { //@ Audit - Starts at idx zero then goes to the last possible position (self length - needle length)
                    bytes32 testHash; //@ Audit - Declares a holder for the hash data from self.
                    assembly { testHash := sha3(ptr, needlelen) } //@ Audit - Assigns test hash to the hash of the next needle length bytes of self
                    if (hash == testHash) //@ Audit - If this matches the hash we return that pointer
                        return ptr;
                    ptr += 1; //@ Audit - increases ptr by one
                }
            }
        }
        return selfptr + selflen; //@ Audit - If both loops fail then it does not contain needle so we return the ptr to byte after self data
    }

    //@ Audit - Finds the instance of the pointer in the provided slice
    //@ Params - (selflen, selfptr) the slice to search through, (needlelen, needleptr) the slice to search for
    function rfindPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr; //@ Audit - Declares a uint pointer

        if (needlelen <= selflen) { //@ Audit - The needle must be shorter than self
            if (needlelen <= 32) { //@ Audit - If the needle is short we compare bytes data
                bytes32 mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1)); //@ Audit - Construct a mask which is zero except for needlelen bytes at the start

                bytes32 needledata; //@ Audit - Declares needledata to be assigned in assembly
                assembly { needledata := and(mload(needleptr), mask) } //@ Audit - Loads and cleans the needle data

                ptr = selfptr + selflen - needlelen; //@ Audit - assigns pointer to the last possible position for needle in self
                bytes32 ptrdata; //@ Audit - Declares a bytes32 holder for the data at ptr
                assembly { ptrdata := and(mload(ptr), mask) } //@ Audit - loads and cleans the data at ptr

                while (ptrdata != needledata) { //@ Audit - Iterates through pointer till we find one where ptrdata == needledata
                    if (ptr <= selfptr) //@ Audit - If we have gone beyond selfptr we return selfptr (as it does not contain needle)
                        return selfptr;
                    ptr--; //@ Audit - Reduces the ptr by one
                    assembly { ptrdata := and(mload(ptr), mask) } //@ Audit - Loads and cleans the data from ptr
                }
                return ptr + needlelen; //@ Audit - Returns the ptr to the end of the needle
            } else { //@ Audit - If the needle is not short its easier to use hashing
                bytes32 hash; //@ Audit - Declares a holder for the needle hash
                assembly { hash := sha3(needleptr, needlelen) } //@ Audit - Sets hash to the hash of the needle data
                ptr = selfptr + (selflen - needlelen); //@ Audit - Sets the ptr to the last possible position of the data of needle in self
                while (ptr >= selfptr) { //@ Audit - Until ptr reduces to being equal to selfptr
                    bytes32 testHash; //@ Audit - Declares a holder for the hash of the self data
                    assembly { testHash := sha3(ptr, needlelen) } //@ Audit - Loads the hash of needle length of bytes starting at ptr
                    if (hash == testHash) //@ Audit - If the hash of self data is equal to hash of needle data we have found the last instance of needle
                        return ptr + needlelen; //@ Audit - So we return a pointer to the end of the needle data in self
                    ptr -= 1; //@ Audit - Otherwise we reduce pointer by one
                }
            }
        }
        return selfptr; //@ Audit - If we fail in the loops we return the start of the self data
    }

    //@ Audit - Finds needle in slice then returns it and everything after it in slice
    //@ Params - self the slice to search through and modify, needle to slice to find
    //@ Return - returns the edited slice
    function find(slice self, slice needle) internal pure returns (slice) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        //@ Audit - Calls find ptr to get the ptr to the first instance of needle in slice
        self._len -= ptr - self._ptr;
        //@ Audit - Reduces the length of self by the diffrence between the current self pointer and the pointer at the first instance of needle in self
        self._ptr = ptr; //@ Audit - Moves the data pointer of self foward to the pointer which is the first location of needle in self
        return self; //@ Audit - Returns the resulting slice
    }

    //@ Audit - Searches self for the last instance of needle and cuts everything off after the end of needle
    //@ Params - self is the slice to search and modify, needle is the slice to search for
    //@ Return - returns the new slice
    function rfind(slice self, slice needle) internal pure returns (slice) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr); //@ Audit - Calls rFindPtr to get a pointer to after the last instance of needle in slice
        self._len = ptr - self._ptr; //@ Audit - Sets the length of slice to be the end pointer of the slice minus the start pointer
        return self; //@ Audit - Returns the new slice
    }

    //@ Audit - Sets self to everything after the first instance of needle and token to everything before
    //@ Params - self the slice to search and modify, needle the slice to search for, and token the slice to hold the begining of the slice
    //@ Return - returns the token slice
    function split(slice self, slice needle, slice token) internal pure returns (slice) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        //@ Audit - Calls findPtr to find the pointer to the first instance of needle in slice
        token._ptr = self._ptr; //@ Audit - Sets the token pointer to the pointer of self
        token._len = ptr - self._ptr; //@ Audit -  Sets the length of token to be the length until ptr
        if (ptr == self._ptr + self._len) { //@ Audit - If ptr points to the end of self's data
            self._len = 0; //@ Audit - Then we haven't found it so we just set the length to zero
        } else {
            self._len -= token._len + needle._len;
            //@ Audit - Removes the length of the token and the length of the needle from the length of self
            self._ptr = ptr + needle._len;  //@ Audit - Sets the pointer of self to be the byte after the first instance of needle in self
        }
        return token; //@ Audit - Returns the token slice
    }

    //@ Audit - A wrapper for the function split with less memory management (you don't control where token is)
    //@ Params - self the slice to search, needle the slice to search for
    //@ Return - returns the slice with the begining of the string
    function split(slice self, slice needle) internal pure returns (slice token) {
        split(self, needle, token); //@ Audit - Calls split using self, needle and the location of token insitiated in the return statement
    }

    //@ Audit - Searches a slice for the last instance of needle and sets it to everything before that and sets a token to everything after
    //@ Params - self is the slice we search and modify, needle is the slice to search for, token is the slice to load with the end of the string
    //@ Return - Returns the slice with the end of the string
    function rsplit(slice self, slice needle, slice token) internal pure returns (slice) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        //@ Audit - Calls rFindPtr on self and needle to get the pointer to the end of the last instance of needle
        token._ptr = ptr; //@ Audit - Sets the token ptr to be the pointer to the end of the last instance of needle
        token._len = self._len - (ptr - self._ptr); //@ Audit - Sets the length of token to be the length of self after the last instance of needle
        if (ptr == self._ptr) { //@ Audit - If rFindPtr is the same as self pointer
            self._len = 0; //@ Audit - Then self doesn't contain needle so it is length zero
        } else {
            self._len -= token._len + needle._len; //@ Audit - Reduces self length by the length of token and the length of needle
        }
        return token; //@ Audit - Returns the token slice
    }

    //@ Audit - Wrapper for rsplit with less memory management, this instanciates its own token slice
    //@ Params - self the slice to search, needle the slice to search for
    //@ Retun - The returned slice token
    function rsplit(slice self, slice needle) internal pure returns (slice token) {
        rsplit(self, needle, token); //@ Audit - Calls rsplit on self, needle and the token insitiated in return
    }

    //@ Audit -Counts the number of nonoverlaping needles in self
    //@ Params - self the slice to search, needle the slice to search for
    //@ Return - returns the number of needles
    function count(slice self, slice needle) internal pure returns (uint cnt) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr) + needle._len;
        //@ Audit - Sets ptr to the memory location after the first instance of needle
        while (ptr <= self._ptr + self._len) { //@ Audit - If ptr > self.ptr + self.len we are further than the self data so we stop searching
            cnt++; //@ Audit - Increase the count by one
            ptr = findPtr(self._len - (ptr - self._ptr), ptr, needle._len, needle._ptr) + needle._len;
            //@ Audit - Calls find ptr on a slice of self starting at ptr with needle then moves it past the next needle found
        }
    }

    //@ Audit - Returns true if self contains needle false otherwise.
    //@ Params - self the slice to search, needle the slice to search for
    //@ Return - the bool of whether the slice contains the search term
    function contains(slice self, slice needle) internal pure returns (bool) {
        return rfindPtr(self._len, self._ptr, needle._len, needle._ptr) != self._ptr;
        //@ Audit - Calls rFindPtr on self and needle and checks if it sets the pointer to the start of self
    }

    //@ Audit - Returns the string which is the concat of two slices
    function concat(slice self, slice other) internal pure returns (string) {
        string memory ret = new string(self._len + other._len); //@ Audit - Declares a new memory string with length which is the addition of lengths of the slices
        uint retptr; //@ Audit - Declares retptr to be assigned in assembly
        assembly { retptr := add(ret, 32) } //@ Audit - Sets retptr to the data pointer of ret
        memcpy(retptr, self._ptr, self._len); //@ Audit - Calls memcpy to copy the data of self to the start of the string
        memcpy(retptr + self._len, other._ptr, other._len); //@ Audit - Calls memcpy to copy other to the end of the string
        return ret; //@ Audit - returns the formed string
    }

    //@ Audit - Joins an array of slices placing the slice self between them in the string
    //@ Params - self the delimiter slice, and parts the strings to join
    //@ Return - returns the string formed from joining them
    function join(slice self, slice[] parts) internal pure returns (string) {
        if (parts.length == 0) //@ Audit -If you don't provide any parts
            return ""; //@ Audit - Then the string is just the null string

        uint length = self._len * (parts.length - 1); //@ Audit - Gets the length of the number of delimiters to include
        for(uint i = 0; i < parts.length; i++) //@ Audit - Iterates over the parts array
            length += parts[i]._len; //@ Audit - Adds the length of each part to the total length

        string memory ret = new string(length); //@ Audit - Declares a new memory string with length total length
        uint retptr; //@ Audit - Declares a pointer to be assgined in assembly
        assembly { retptr := add(ret, 32) } //@ Audit - Assigns retptr to be a pointer to data of the string

        for(i = 0; i < parts.length; i++) { //@ Audit - Iterates over the length of parts
            memcpy(retptr, parts[i]._ptr, parts[i]._len); //@ Audit - Copies the current part to memory at retptr
            retptr += parts[i]._len; //@ Audit - Adds the length of the current part to the retptr
            if (i < parts.length - 1) { //@ Audit - Checks that this isn't the last part
                memcpy(retptr, self._ptr, self._len); //@ Audit - Copies the delimiter into memory at retptr
                retptr += self._len; //@ Audit - Moves retptr foward by the size of the delemiter
            }
        }

        return ret; //@ Audit - Returns the formed string
    }
}
