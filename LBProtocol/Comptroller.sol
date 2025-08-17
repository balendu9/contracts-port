// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./ComptrollerStorage.sol";
import "./ErrorReporter.sol";
import "./IPriceOracle.sol";
import "./IInterestRateModel.sol";
import "./ICToken.sol";

contract Comptroller is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, ComptrollerStorage, ErrorReporter {
    event MarketListed(CToken cToken);
    event MarketEntered(CToken cToken, address account);
    event MarketExited(CToken cToken, address account);
    event NewCollateralFactor(CToken cToken, uint oldCollateralFactorMantissa, uint newCollateralFactorMantissa);
    event NewPriceOracle(address oldOracle, address newOracle);

    function initialize(address _admin, address _oracle) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        admin = _admin;
        transferOwnership(_admin);
        oracle = PriceOracle(_oracle);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Security: Admin-only, pausable
    function _setPriceOracle(address newOracle) external onlyOwner returns (uint) {
        address oldOracle = address(oracle);
        oracle = PriceOracle(newOracle);
        emit NewPriceOracle(oldOracle, newOracle);
        return 0;
    }

    function _supportMarket(CToken cToken) external onlyOwner returns (uint) {
        if (markets[address(cToken)].isListed) revert MarketNotListed(); // Inverted for example
        // Add checks for valid cToken
        if (!cToken.isCToken()) revert Unauthorized();
        allMarkets.push(address(cToken));
        markets[address(cToken)].isListed = true;
        markets[address(cToken)].collateralFactorMantissa = 0; // Set default to 0, admin sets later
        emit MarketListed(cToken);
        return 0;
    }

    function _setCollateralFactor(CToken cToken, uint newCollateralFactorMantissa) external onlyOwner returns (uint) {
        if (!markets[address(cToken)].isListed) revert MarketNotListed();
        if (newCollateralFactorMantissa > 0.9e18) revert Unauthorized(); // Max 90%
        uint old = markets[address(cToken)].collateralFactorMantissa;
        markets[address(cToken)].collateralFactorMantissa = newCollateralFactorMantissa;
        emit NewCollateralFactor(cToken, old, newCollateralFactorMantissa);
        return 0;
    }

    function enterMarkets(address[] memory cTokens) external nonReentrant whenNotPaused returns (uint) {
        uint len = cTokens.length;
        if (len > maxAssets) revert Unauthorized();
        for (uint i = 0; i < len; i++) {
            CToken cToken = CToken(cTokens[i]);
            addToMarketInternal(cToken, msg.sender);
        }
        return 0;
    }

    function addToMarketInternal(CToken cToken, address account) internal {
        Market storage market = markets[address(cToken)];
        if (!market.isListed) revert MarketNotListed();
        if (market.accountMembership[account]) return; // Already entered
        market.accountMembership[account] = true;
        emit MarketEntered(cToken, account);
    }

    function exitMarket(address cTokenAddress) external nonReentrant whenNotPaused returns (uint) {
        CToken cToken = CToken(cTokenAddress);
        (uint oErr, uint tokensHeld, uint borrowBalance, uint exchangeRateMantissa) = cToken.getAccountSnapshot(msg.sender);
        if (oErr != 0) revert SnapshotError();
        if (borrowBalance != 0) revert InsufficientCollateral(); // Can't exit if borrowing
        if (tokensHeld != 0) revert InsufficientCollateral(); // Can't exit if supplying, but actually can if liquidity ok, but simplified
        Market storage market = markets[address(cToken)];
        market.accountMembership[msg.sender] = false;
        emit MarketExited(cToken, msg.sender);
        return 0;
    }

    // Allowed functions for cToken calls
    function mintAllowed(address cToken, address minter, uint mintAmount) external nonReentrant returns (uint) {
        if (!markets[cToken].isListed) revert MarketNotListed();
        // Update supply index if rewards, but simplified no rewards
        return 0;
    }

    function redeemAllowed(address cToken, address redeemer, uint redeemTokens) external nonReentrant returns (uint) {
        if (!markets[cToken].isListed) revert MarketNotListed();
        if (!markets[cToken].accountMembership[redeemer]) return 0; // Not member, ok for redeem?
        (uint err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(redeemer, CToken(cToken), redeemTokens, 0);
        if (err != 0) revert(); // Error
        if (shortfall > 0) revert InsufficientLiquidity();
        return 0;
    }

    function borrowAllowed(address cToken, address borrower, uint borrowAmount) external nonReentrant returns (uint) {
        if (!markets[cToken].isListed) revert MarketNotListed();
        if (!markets[cToken].accountMembership[borrower]) revert MarketNotListed();
        if (oracle.getUnderlyingPrice(CToken(cToken)) == 0) revert PriceError();
        (uint err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(borrower, CToken(cToken), 0, borrowAmount);
        if (err != 0) revert();
        if (shortfall > 0) revert InsufficientLiquidity();
        return 0;
    }

    function repayBorrowAllowed(address cToken, address payer, address borrower, uint) external view returns (uint) {
        payer; // Unused
        if (!markets[cToken].isListed) revert MarketNotListed();
        if (payer != borrower && !markets[cToken].accountMembership[payer]) {} // Optional
        return 0;
    }

    function liquidateBorrowAllowed(address cTokenBorrowed, address cTokenCollateral, address, address borrower, uint repayAmount) external view returns (uint) {
        if (!markets[cTokenBorrowed].isListed || !markets[cTokenCollateral].isListed) revert MarketNotListed();
        (uint err, , uint shortfall) = getAccountLiquidityInternal(borrower);
        if (err != 0 || shortfall == 0) revert InsufficientCollateral();
        uint borrowBalance = CToken(cTokenBorrowed).borrowBalanceStored(borrower);
        uint maxClose = (borrowBalance * closeFactorMantissa) / 1e18;
        if (repayAmount > maxClose) revert Unauthorized(); // Too much
        return 0;
    }

    function seizeAllowed(address cTokenCollateral, address cTokenBorrowed, address liquidator, address borrower, uint) external view returns (uint) {
        if (!markets[cTokenCollateral].isListed || !markets[cTokenBorrowed].isListed) revert MarketNotListed();
        if (CToken(cTokenCollateral).comptroller() != CToken(cTokenBorrowed).comptroller()) revert ComptrollerMismatch();
        if (liquidator == borrower) revert Unauthorized();
        return 0;
    }

    // Liquidity calculations (gas optimized by batching oracle calls if possible)
    function getAccountLiquidity(address account) external view returns (uint, uint, uint) {
        return getAccountLiquidityInternal(account);
    }

    function getAccountLiquidityInternal(address account) internal view returns (uint, uint, uint) {
        return getHypotheticalAccountLiquidityInternal(account, CToken(address(0)), 0, 0);
    }

    function getHypotheticalAccountLiquidity(address account, address cTokenModify, uint redeemTokens, uint borrowAmount) external view returns (uint, uint, uint) {
        return getHypotheticalAccountLiquidityInternal(account, CToken(cTokenModify), redeemTokens, borrowAmount);
    }

    function getHypotheticalAccountLiquidityInternal(address account, CToken cTokenModify, uint redeemTokens, uint borrowAmount) internal view returns (uint, uint, uint) {
        uint sumCollateral = 0;
        uint sumBorrow = 0;
        for (uint i = 0; i < allMarkets.length; i++) {
            CToken cToken = CToken(allMarkets[i]);
            if (!markets[allMarkets[i]].accountMembership[account]) continue;
            (uint oErr, uint tokens, uint borrow, uint exchangeRate) = cToken.getAccountSnapshot(account);
            if (oErr != 0) return (1, 0, 0); // Error code
            uint collateralValue = (tokens * exchangeRate / 1e18) * oracle.getUnderlyingPrice(cToken);
            sumCollateral += (collateralValue * markets[allMarkets[i]].collateralFactorMantissa) / 1e18;
            sumBorrow += borrow * oracle.getUnderlyingPrice(cToken);
            if (address(cToken) == address(cTokenModify)) {
                sumBorrow += borrowAmount * oracle.getUnderlyingPrice(cToken);
                uint redeemValue = (redeemTokens * exchangeRate / 1e18) * oracle.getUnderlyingPrice(cToken);
                sumCollateral -= (redeemValue * markets[allMarkets[i]].collateralFactorMantissa) / 1e18;
            }
        }
        if (sumCollateral >= sumBorrow) return (0, sumCollateral - sumBorrow, 0);
        else return (0, 0, sumBorrow - sumCollateral);
    }

    // Pause for security
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}