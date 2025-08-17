// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint);
    function exitMarket(address cToken) external returns (uint);
    function mintAllowed(address cToken, address minter, uint mintAmount) external returns (uint);
    function redeemAllowed(address cToken, address redeemer, uint redeemTokens) external returns (uint);
    function borrowAllowed(address cToken, address borrower, uint borrowAmount) external returns (uint);
    function repayBorrowAllowed(address cToken, address payer, address borrower, uint repayAmount) external returns (uint);
    function liquidateBorrowAllowed(address cTokenBorrowed, address cTokenCollateral, address liquidator, address borrower, uint repayAmount) external returns (uint);
    function seizeAllowed(address cTokenCollateral, address cTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external returns (uint);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function getHypotheticalAccountLiquidity(address account, address cTokenModify, uint redeemTokens, uint borrowAmount) external view returns (uint, uint, uint);
    // Admin functions
    function _setPriceOracle(address newOracle) external returns (uint);
    function _supportMarket(CToken cToken) external returns (uint);
    function _setCollateralFactor(CToken cToken, uint newCollateralFactorMantissa) external returns (uint);
}