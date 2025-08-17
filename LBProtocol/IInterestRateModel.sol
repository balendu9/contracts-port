// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface InterestRateModel {
    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint, uint);
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint, uint);
}