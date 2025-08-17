// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IInterestRateModel.sol";
import "./ErrorReporter.sol";

contract JumpRateModel is InterestRateModel, ErrorReporter {
    uint public constant blocksPerYear = 2102400; // ~15s blocks

    uint public immutable multiplierPerBlock;
    uint public immutable baseRatePerBlock;
    uint public immutable jumpMultiplierPerBlock;
    uint public immutable kink;

    constructor(uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_) {
        baseRatePerBlock = baseRatePerYear / blocksPerYear;
        multiplierPerBlock = multiplierPerYear / blocksPerYear;
        jumpMultiplierPerBlock = jumpMultiplierPerYear / blocksPerYear;
        kink = kink_;
    }

    function utilizationRate(uint cash, uint borrows, uint reserves) public pure returns (uint) {
        if (borrows == 0) return 0;
        return borrows * 1e18 / (cash + borrows - reserves);
    }

    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint, uint) {
        uint util = utilizationRate(cash, borrows, reserves);
        if (util <= kink) {
            return (0, ((util * multiplierPerBlock) / 1e18) + baseRatePerBlock);
        } else {
            uint normalRate = ((kink * multiplierPerBlock) / 1e18) + baseRatePerBlock;
            uint excessUtil = util - kink;
            return (0, ((excessUtil * jumpMultiplierPerBlock) / 1e18) + normalRate);
        }
    }

    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint, uint) {
        (uint err, uint borrowRate) = getBorrowRate(cash, borrows, reserves);
        if (err != 0) return (err, 0);
        uint oneMinusReserveFactor = 1e18 - reserveFactorMantissa;
        uint rateToPool = borrowRate * oneMinusReserveFactor / 1e18;
        return (0, utilizationRate(cash, borrows, reserves) * rateToPool / 1e18);
    }
}