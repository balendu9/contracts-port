// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface PriceOracle {
    function getUnderlyingPrice(CToken cToken) external view returns (uint);
}