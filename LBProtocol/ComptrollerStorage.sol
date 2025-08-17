// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CToken.sol";

contract ComptrollerStorage {
    struct Market {
        bool isListed;
        uint collateralFactorMantissa; // e.g., 0.75e18
        mapping(address => bool) accountMembership;
        uint blockNumber; // For accrual
    }

    address public admin;
    address public pendingAdmin;
    mapping(address => Market) public markets;
    address[] public allMarkets;
    uint public closeFactorMantissa = 0.5e18; // 50%
    uint public liquidationIncentiveMantissa = 1.08e18; // 8%
    PriceOracle public oracle;
    uint public maxAssets = 20; // Limit assets per account for gas
}