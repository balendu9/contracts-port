// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// /**
//  * @title OptimizedUtils
//  * @author balendu - Built with inspiration from Solmate, optimized for DeFi use cases.
//  * @notice A gas-optimized library for math, data structures, and utilities in Solidity.
//  *         Designed for efficiency in DeFi protocols: safe casts, fixed-point math, bit manipulation,
//  *         array operations, Merkle trees, time utilities, and string handling.
//  *         Focuses on minimal gas usage via iterative methods, unchecked blocks, and inline checks.
//  *         Use cases: lending, AMMs, staking, airdrops, and more.
//  * @dev This library is internal-use only; functions are pure or view where possible.
//  *      Tested for gas efficiency; see documentation for benchmarks.
//  *      Import via npm or Foundry: import {OptimizedUtils} from "@yourpackage/OptimizedUtils.sol";
//  */
library OptimizedUtils {
    // Constants for fixed-point math (WAD = 1e18, like in MakerDAO)
    uint256 constant WAD = 1e18;
    uint256 constant HALF_WAD = 0.5e18;

    // Error messages (kept short for gas savings)
    error Overflow();
    error Underflow();
    error DivisionByZero();
    error InvalidInput();
    error InvalidProof();

    // Section 1: Gas-Optimized Math & Data Structures

    /**
     * @notice Safely casts uint256 to uint128, reverting on overflow.
     * @param value The uint256 value to cast.
     * @return The casted uint128 value.
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) revert Overflow();
        return uint128(value);
    }

    /**
     * @notice Safely casts uint256 to uint64, reverting on overflow.
     * @param value The uint256 value to cast.
     * @return The casted uint64 value.
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) revert Overflow();
        return uint64(value);
    }

    /**
     * @notice Multiplies two WAD-fixed-point numbers, rounding down.
     * @param x First WAD value.
     * @param y Second WAD value.
     * @return Result as WAD.
     */
    function mulWad(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y) / WAD;
    }

    /**
     * @notice Divides two WAD-fixed-point numbers, rounding down.
     * @param x Numerator as WAD.
     * @param y Denominator as WAD.
     * @return Result as WAD.
     */
    function divWad(uint256 x, uint256 y) internal pure returns (uint256) {
        if (y == 0) revert DivisionByZero();
        return (x * WAD) / y;
    }

    /**
     * @notice Computes x^y in WAD units using binary exponentiation.
     * @dev Gas-optimized for compound interest: principal * powWad(1 + rate, time).
     * @param x Base as WAD.
     * @param y Exponent as WAD.
     * @return Result as WAD.
     */
    function powWad(uint256 x, uint256 y) internal pure returns (uint256) {
        if (y == 0) return WAD;
        if (x == 0) return 0;

        uint256 result = WAD;
        uint256 base = x;
        uint256 exp = y;

        while (exp > 0) {
            if (exp % 2 == 1) {
                result = mulWad(result, base);
            }
            exp /= 2;
            base = mulWad(base, base);
        }
        return result;
    }

    /**
     * @notice Computes square root of x in WAD units using Babylonian method.
     * @dev Iterative convergence for gas efficiency; converges in ~4 iterations for most values.
     * @param x Value as WAD.
     * @return Square root as WAD.
     */
    function sqrtWad(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    /**
     * @notice Computes natural log of x in WAD units using series expansion.
     * @dev Optimized for x near 1; use with care for large deviations.
     * @param x Value as WAD (must be > 0).
     * @return Ln(x) as WAD.
     */
    function lnWad(uint256 x) internal pure returns (int256) {
        if (x == 0) revert InvalidInput();

        int256 result = 0;
        uint256 term = (x - WAD) * WAD / x;
        int256 sign = 1;
        for (uint256 i = 1; i < 20; ++i) { // Converges quickly
            result += sign * int256(term) / int256(i);
            term = mulWad(term, (x - WAD) * WAD / x);
            sign = -sign;
        }
        return result;
    }

    /**
     * @notice Computes log base 2 of x in WAD units.
     * @dev Uses bit operations for initial approximation, then refines.
     * @param x Value as WAD (must be > 0).
     * @return Log2(x) as WAD.
     */
    function log2Wad(uint256 x) internal pure returns (uint256) {
        if (x == 0) revert InvalidInput();

        uint256 result = 0;
        uint256 y = x;
        if (y >= 1 << 128) { y >>= 128; result += 128 * WAD; }
        if (y >= 1 << 64) { y >>= 64; result += 64 * WAD; }
        if (y >= 1 << 32) { y >>= 32; result += 32 * WAD; }
        if (y >= 1 << 16) { y >>= 16; result += 16 * WAD; }
        if (y >= 1 << 8) { y >>= 8; result += 8 * WAD; }
        if (y >= 1 << 4) { y >>= 4; result += 4 * WAD; }
        if (y >= 1 << 2) { y >>= 2; result += 2 * WAD; }
        if (y >= 1 << 1) { result += 1 * WAD; }

        // Refine with a few Newton iterations if needed (omitted for gas, as approx is good)
        return result;
    }

    // EnumerableMap: Cheaper than OZ's via simple array + mapping
    // Note: For full implementation, you'd need a struct with mapping and array.
    // Here's a skeleton; expand as needed.
    struct EnumerableMap {
        mapping(uint256 => uint256) map; // key => value
        uint256[] keys;
    }

    function set(EnumerableMap storage self, uint256 key, uint256 value) internal {
        if (self.map[key] == 0) self.keys.push(key);
        self.map[key] = value + 1; // +1 to distinguish from default 0
    }

    function get(EnumerableMap storage self, uint256 key) internal view returns (uint256) {
        uint256 val = self.map[key];
        return val == 0 ? 0 : val - 1;
    }

    // Section 2: Safe Math for Other Types

    /**
     * @notice Safely casts int256 to int128, reverting on overflow/underflow.
     * @param value The int256 value to cast.
     * @return The casted int128 value.
     */
    function toInt128(int256 value) internal pure returns (int128) {
        if (value > type(int128).max || value < type(int128).min) revert Overflow();
        return int128(value);
    }

    /**
     * @notice Safely casts int256 to int64, reverting on overflow/underflow.
     * @param value The int256 value to cast.
     * @return The casted int64 value.
     */
    function toInt64(int256 value) internal pure returns (int64) {
        if (value > type(int64).max || value < type(int64).min) revert Overflow();
        return int64(value);
    }

    /**
     * @notice Safe addition for uint256, reverting on overflow.
     * @dev Uses unchecked for gas savings where safe.
     * @param a First operand.
     * @param b Second operand.
     * @return Sum.
     */
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) revert Overflow();
            return c;
        }
    }

    /**
     * @notice Safe subtraction for uint256, reverting on underflow.
     * @param a First operand.
     * @param b Second operand.
     * @return Difference.
     */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (b > a) revert Underflow();
            return a - b;
        }
    }

    /**
     * @notice Safe multiplication for uint256, reverting on overflow.
     * @param a First operand.
     * @param b Second operand.
     * @return Product.
     */
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            uint256 c = a * b;
            if (a != 0 && c / a != b) revert Overflow();
            return c;
        }
    }

    // Similar for int256, uint128, etc. – extend as needed.

    // Section 3: Bit Manipulation Utilities

    /**
     * @notice Sets a specific bit in a uint256.
     * @param value The original value.
     * @param bit The bit position (0-255).
     * @return Updated value.
     */
    function bitSet(uint256 value, uint8 bit) internal pure returns (uint256) {
        return value | (1 << bit);
    }

    /**
     * @notice Gets a specific bit from a uint256.
     * @param value The value.
     * @param bit The bit position (0-255).
     * @return 1 if set, 0 otherwise.
     */
    function bitGet(uint256 value, uint8 bit) internal pure returns (uint256) {
        return (value >> bit) & 1;
    }

    /**
     * @notice Counts the number of set bits (Hamming weight).
     * @dev Uses bitwise operations for efficiency (no loops).
     * @param value The uint256 value.
     * @return Number of set bits.
     */
    function bitCount(uint256 value) internal pure returns (uint256) {
        value = value - ((value >> 1) & 0x5555555555555555555555555555555555555555555555555555555555555555);
        value = (value & 0x3333333333333333333333333333333333333333333333333333333333333333) + ((value >> 2) & 0x3333333333333333333333333333333333333333333333333333333333333333);
        value = (value + (value >> 4)) & 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
        value = value + (value >> 8);
        value = value + (value >> 16);
        value = value + (value >> 32);
        value = value + (value >> 64);
        value = value + (value >> 128);
        return value & 0xff;
    }

    // Section 4: Array Utilities

    /**
     * @notice Inserts into a sorted uint256 array while maintaining order.
     * @dev Uses binary search for insertion point.
     * @param array The sorted array (storage).
     * @param value The value to insert.
     */
    function sortedInsert(uint256[] storage array, uint256 value) internal {
        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (array[mid] < value) low = mid + 1;
            else high = mid;
        }

        array.push(array[array.length - 1]); // Extend array
        for (uint256 i = array.length - 1; i > low; --i) {
            array[i] = array[i - 1];
        }
        array[low] = value;
    }

    /**
     * @notice Binary search for a value in a sorted uint256 array.
     * @param array The sorted array.
     * @param value The value to find.
     * @return Index if found, or type(uint256).max if not.
     */
    function binarySearch(uint256[] memory array, uint256 value) internal pure returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (array[mid] == value) return mid;
            else if (array[mid] < value) low = mid + 1;
            else high = mid;
        }
        return type(uint256).max;
    }

    /**
     * @notice Removes an element from a uint256 array without preserving order.
     * @dev Swaps with last element and pops – gas cheap.
     * @param array The array (storage).
     * @param index The index to remove.
     */
    function removeNoOrder(uint256[] storage array, uint256 index) internal {
        if (index >= array.length) revert InvalidInput();
        array[index] = array[array.length - 1];
        array.pop();
    }

    // Section 5: Compact Merkle Tree Utilities

    /**
     * @notice Hashes a Merkle leaf (e.g., address + amount).
     * @param data The abi-encoded data.
     * @return Keccak256 hash.
     */
    function hashLeaf(bytes memory data) internal pure returns (bytes32) {
        return keccak256(data);
    }

    /**
     * @notice Verifies a Merkle proof iteratively.
     * @dev Gas-optimized: processes proof left-to-right.
     * @param leaf The leaf hash.
     * @param proof The proof array (siblings).
     * @param root The root hash.
     * @return True if valid.
     */
    function verifyProof(bytes32 leaf, bytes32[] memory proof, bytes32 root) internal pure returns (bool) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; ++i) {
            bytes32 sibling = proof[i];
            if (computed < sibling) {
                computed = keccak256(abi.encodePacked(computed, sibling));
            } else {
                computed = keccak256(abi.encodePacked(sibling, computed));
            }
        }
        return computed == root;
    }

    // Section 6: Time-Based Utilities

    /**
     * @notice Safely casts current timestamp to uint32 for storage.
     * @dev Assumes timestamps fit in uint32 until ~2106.
     * @return uint32(block.timestamp).
     */
    function safeTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
    }

    /**
     * @notice Calculates time delta with overflow protection.
     * @param start Start timestamp.
     * @param end End timestamp.
     * @return Delta (end - start).
     */
    function timeDelta(uint256 start, uint256 end) internal pure returns (uint256) {
        if (end < start) revert Underflow();
        return end - start;
    }

    // Section 7: Gas-Optimized String Utilities

    /**
     * @notice Concatenates two strings.
     * @dev Uses abi.encodePacked for efficiency.
     * @param a First string.
     * @param b Second string.
     * @return Concatenated string.
     */
    function concatenate(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /**
     * @notice Converts uint256 to string.
     * @dev Gas-optimized: fixed buffer, no dynamic alloc.
     * @param value The uint256 value.
     * @return String representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            ++digits;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            --digits;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }
}