// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CTokenStorage {
    bool internal _notEntered; // Reentrancy flag

    string public name;
    string public symbol;
    uint8 public decimals = 8;

    uint internal constant borrowRateMaxMantissa = 0.0005e16; // 0.05% per block
    uint internal constant reserveFactorMaxMantissa = 1e18;

    address public admin;
    address public pendingAdmin;

    InterestRateModel public interestRateModel;
    uint public reserveFactorMantissa;
    uint public accrualBlockTimestamp;

    uint public borrowIndex = 1e18;
    uint public totalBorrows;
    uint public totalReserves;
    uint public totalSupply;

    mapping (address => uint) public accountTokens;
    mapping (address => mapping (address => uint)) public transferAllowances;

    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    mapping(address => BorrowSnapshot) public accountBorrows;
}