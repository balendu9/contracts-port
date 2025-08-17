// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ErrorReporter {
    error NoError();
    error Unauthorized();
    error MarketNotListed();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error PriceError();
    error SnapshotError();
    error ComptrollerMismatch();
    // Add more as needed
}