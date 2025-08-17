// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CErc20 is CToken {
    address public underlying;

    event NewUnderlying(address old, address new_);

    function initialize(IComptroller comptroller_, InterestRateModel interestRateModel_, uint initialExchangeRateMantissa, string memory name_, string memory symbol_, uint8 decimals_, address admin_, address underlying_) public initializer {
        super.initialize(comptroller_, interestRateModel_, initialExchangeRateMantissa, name_, symbol_, decimals_, admin_);
        underlying = underlying_;
    }

    function mint(uint mintAmount) external returns (uint) {
        doTransferIn(msg.sender, mintAmount);
        return mintInternal(mintAmount);
    }

    function redeem(uint redeemTokens) external returns (uint) {
        return redeemInternal(redeemTokens);
    }

    function redeemUnderlying(uint redeemAmount) external returns (uint) {
        return redeemUnderlyingInternal(redeemAmount);
    }

    function borrow(uint borrowAmount) external returns (uint) {
        return borrowInternal(borrowAmount);
    }

    function repayBorrow(uint repayAmount) external returns (uint) {
        return repayBorrowInternal(repayAmount);
    }

    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint) {
        return repayBorrowBehalfInternal(borrower, repayAmount);
    }

    function liquidateBorrow(address borrower, uint repayAmount, CToken cTokenCollateral) external returns (uint) {
        return liquidateBorrowInternal(borrower, repayAmount, cTokenCollateral);
    }

    function doTransferIn(address from, uint amount) internal override returns (uint) {
        IERC20 token = IERC20(underlying);
        bool success = token.transferFrom(from, address(this), amount);
        if (!success) revert();
        return amount;
    }

    function doTransferOut(address to, uint amount) internal override {
        IERC20 token = IERC20(underlying);
        bool success = token.transfer(to, amount);
        if (!success) revert();
    }

    function getCashPrior() internal override view returns (uint) {
        IERC20 token = IERC20(underlying);
        return token.balanceOf(address(this));
    }
}