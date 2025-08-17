// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./CTokenStorage.sol";
import "./ErrorReporter.sol";
import "./IComptroller.sol";
import "./IInterestRateModel.sol";
import "./IPriceOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol"; // Though 0.8 has, for explicit

abstract contract CToken is CTokenStorage, ReentrancyGuardUpgradeable, ErrorReporter, IERC20, IERC20Metadata {
    using SafeMath for uint;

    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndexNew, uint totalBorrowsNew);
    event Mint(address minter, uint mintAmount, uint mintTokens);
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);
    event Borrow(address borrower, uint borrowAmount, uint accountBorrowsNew, uint totalBorrowsNew);
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrowsNew, uint totalBorrowsNew);
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address cTokenCollateral, uint seizeTokens);
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);
    event ReservesAdded(address benefactor, uint addAmount, uint newTotalReserves);
    event ReservesReduced(address admin, uint reduceAmount, uint newTotalReserves);

    IComptroller public comptroller;

    function initialize(IComptroller comptroller_, InterestRateModel interestRateModel_, uint initialExchangeRateMantissa, string memory name_, string memory symbol_, uint8 decimals_, address admin_) public virtual initializer {
        __ReentrancyGuard_init();
        comptroller = comptroller_;
        interestRateModel = interestRateModel_;
        admin = admin_;
        accrualBlockTimestamp = block.timestamp;
        borrowIndex = 1e18;
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        reserveFactorMantissa = 0.05e18; // Default 5%
        // Set initial exchange rate
        // Actual in child
    }

    function transfer(address dst, uint amount) external nonReentrant returns (bool) {
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    function transferFrom(address src, address dst, uint amount) external nonReentrant returns (bool) {
        _transferTokens(src, dst, amount);
        return true;
    }

    function approve(address spender, uint amount) external returns (bool) {
        transferAllowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint) {
        return transferAllowances[owner][spender];
    }

    function balanceOf(address owner) external view returns (uint) {
        return accountTokens[owner];
    }

    function totalSupply() external view returns (uint) {
        return totalSupply;
    }

    function _transferTokens(address from, address to, uint amount) internal {
        if (from == to) revert Unauthorized();
        if (amount == 0) revert Unauthorized();
        accountTokens[from] = accountTokens[from].sub(amount, "Insufficient balance");
        accountTokens[to] = accountTokens[to].add(amount);
        emit Transfer(from, to, amount);
    }

    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint) {
        uint cTokenBalance = accountTokens[account];
        uint borrowBalance = borrowBalanceStored(account);
        uint exchangeRateMantissa = exchangeRateStored();
        return (0, cTokenBalance, borrowBalance, exchangeRateMantissa);
    }

    function borrowBalanceCurrent(address account) external nonReentrant returns (uint) {
        accrueInterest();
        return borrowBalanceStored(account);
    }

    function borrowBalanceStored(address account) public view returns (uint) {
        BorrowSnapshot storage borrowSnapshot = accountBorrows[account];
        if (borrowSnapshot.principal == 0) return 0;
        uint principalTimesIndex = borrowSnapshot.principal * borrowIndex;
        return principalTimesIndex / borrowSnapshot.interestIndex;
    }

    function exchangeRateCurrent() public nonReentrant returns (uint) {
        accrueInterest();
        return exchangeRateStored();
    }

    function exchangeRateStored() public view returns (uint) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) return 1e18; // Initial
        uint cash = getCashPrior();
        uint total = cash + totalBorrows - totalReserves;
        return total * 1e18 / _totalSupply;
    }

    function accrueInterest() public returns (uint) {
        uint currentBlockTimestamp = block.timestamp;
        uint accrualBlockTimestampPrior = accrualBlockTimestamp;
        if (currentBlockTimestamp == accrualBlockTimestampPrior) return 0;

        uint cashPrior = getCashPrior();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;

        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        uint blockDelta = currentBlockTimestamp - accrualBlockTimestampPrior;

        uint simpleInterestFactor = borrowRateMantissa * blockDelta;
        uint interestAccumulated = simpleInterestFactor * borrowsPrior / 1e18;
        uint totalBorrowsNew = interestAccumulated + borrowsPrior;
        uint totalReservesNew = (interestAccumulated * reserveFactorMantissa / 1e18) + reservesPrior;
        uint borrowIndexNew = (simpleInterestFactor * borrowIndexPrior / 1e18) + borrowIndexPrior;

        accrualBlockTimestamp = currentBlockTimestamp;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;

        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
        return 0;
    }

    function mintInternal(uint mintAmount) internal nonReentrant returns (uint) {
        accrueInterest();
        uint err = IComptroller(address(comptroller)).mintAllowed(address(this), msg.sender, mintAmount);
        if (err != 0) revert();
        uint exchangeRate = exchangeRateStored();
        uint mintTokens = mintAmount * 1e18 / exchangeRate;
        totalSupply += mintTokens;
        accountTokens[msg.sender] += mintTokens;
        emit Mint(msg.sender, mintAmount, mintTokens);
        emit Transfer(address(0), msg.sender, mintTokens);
        return 0;
    }

    function redeemInternal(uint redeemTokens) internal nonReentrant returns (uint) {
        accrueInterest();
        uint err = IComptroller(address(comptroller)).redeemAllowed(address(this), msg.sender, redeemTokens);
        if (err != 0) revert();
        uint exchangeRate = exchangeRateStored();
        uint redeemAmount = redeemTokens * exchangeRate / 1e18;
        totalSupply -= redeemTokens;
        accountTokens[msg.sender] -= redeemTokens;
        doTransferOut(msg.sender, redeemAmount);
        emit Redeem(msg.sender, redeemAmount, redeemTokens);
        emit Transfer(msg.sender, address(0), redeemTokens);
        return 0;
    }

    function redeemUnderlyingInternal(uint redeemAmount) internal nonReentrant returns (uint) {
        accrueInterest();
        uint exchangeRate = exchangeRateStored();
        uint redeemTokens = redeemAmount * 1e18 / exchangeRate;
        uint err = IComptroller(address(comptroller)).redeemAllowed(address(this), msg.sender, redeemTokens);
        if (err != 0) revert();
        totalSupply -= redeemTokens;
        accountTokens[msg.sender] -= redeemTokens;
        doTransferOut(msg.sender, redeemAmount);
        emit Redeem(msg.sender, redeemAmount, redeemTokens);
        emit Transfer(msg.sender, address(0), redeemTokens);
        return 0;
    }

    function borrowInternal(uint borrowAmount) internal nonReentrant returns (uint) {
        accrueInterest();
        uint err = IComptroller(address(comptroller)).borrowAllowed(address(this), msg.sender, borrowAmount);
        if (err != 0) revert();
        if (getCashPrior() < borrowAmount) revert InsufficientLiquidity();
        BorrowSnapshot storage borrowSnapshot = accountBorrows[msg.sender];
        uint accountBorrows = borrowBalanceStored(msg.sender);
        uint accountBorrowsNew = accountBorrows + borrowAmount;
        uint totalBorrowsNew = totalBorrows + borrowAmount;
        borrowSnapshot.principal = accountBorrowsNew;
        borrowSnapshot.interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;
        doTransferOut(msg.sender, borrowAmount);
        emit Borrow(msg.sender, borrowAmount, accountBorrowsNew, totalBorrowsNew);
        return 0;
    }

    function repayBorrowInternal(uint repayAmount) internal nonReentrant returns (uint) {
        accrueInterest();
        uint err = IComptroller(address(comptroller)).repayBorrowAllowed(address(this), msg.sender, msg.sender, repayAmount);
        if (err != 0) revert();
        uint actualRepayAmount = doTransferIn(msg.sender, repayAmount);
        uint accountBorrows = borrowBalanceStored(msg.sender);
        uint accountBorrowsNew = accountBorrows - actualRepayAmount;
        uint totalBorrowsNew = totalBorrows - actualRepayAmount;
        BorrowSnapshot storage borrowSnapshot = accountBorrows[msg.sender];
        borrowSnapshot.principal = accountBorrowsNew;
        borrowSnapshot.interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;
        emit RepayBorrow(msg.sender, msg.sender, actualRepayAmount, accountBorrowsNew, totalBorrowsNew);
        return 0;
    }

    function repayBorrowBehalfInternal(address borrower, uint repayAmount) internal nonReentrant returns (uint) {
        accrueInterest();
        uint err = IComptroller(address(comptroller)).repayBorrowAllowed(address(this), msg.sender, borrower, repayAmount);
        if (err != 0) revert();
        uint actualRepayAmount = doTransferIn(msg.sender, repayAmount);
        uint accountBorrows = borrowBalanceStored(borrower);
        uint accountBorrowsNew = accountBorrows - actualRepayAmount;
        uint totalBorrowsNew = totalBorrows - actualRepayAmount;
        BorrowSnapshot storage borrowSnapshot = accountBorrows[borrower];
        borrowSnapshot.principal = accountBorrowsNew;
        borrowSnapshot.interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;
        emit RepayBorrow(msg.sender, borrower, actualRepayAmount, accountBorrowsNew, totalBorrowsNew);
        return 0;
    }

    function liquidateBorrowInternal(address borrower, uint repayAmount, CToken cTokenCollateral) internal nonReentrant returns (uint) {
        accrueInterest();
        cTokenCollateral.accrueInterest();
        if (borrower == msg.sender) revert Unauthorized();
        uint err = IComptroller(address(comptroller)).liquidateBorrowAllowed(address(this), address(cTokenCollateral), msg.sender, borrower, repayAmount);
        if (err != 0) revert();
        uint actualRepayAmount = doTransferIn(msg.sender, repayAmount);
        uint seizeTokens = calculateSeizeTokens(cTokenCollateral, actualRepayAmount);
        uint accountBorrowsNew = borrowBalanceStored(borrower) - actualRepayAmount;
        uint totalBorrowsNew = totalBorrows - actualRepayAmount;
        BorrowSnapshot storage borrowSnapshot = accountBorrows[borrower];
        borrowSnapshot.principal = accountBorrowsNew;
        borrowSnapshot.interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;
        err = cTokenCollateral.seize(msg.sender, borrower, seizeTokens);
        if (err != 0) revert();
        emit LiquidateBorrow(msg.sender, borrower, actualRepayAmount, address(cTokenCollateral), seizeTokens);
        emit RepayBorrow(msg.sender, borrower, actualRepayAmount, accountBorrowsNew, totalBorrowsNew);
        return 0;
    }

    function seize(address liquidator, address borrower, uint seizeTokens) external nonReentrant returns (uint) {
        uint err = IComptroller(address(comptroller)).seizeAllowed(address(this), msg.sender, liquidator, borrower, seizeTokens);
        if (err != 0) revert();
        accountTokens[borrower] -= seizeTokens;
        accountTokens[liquidator] += seizeTokens;
        emit Transfer(borrower, liquidator, seizeTokens);
        return 0;
    }

    function calculateSeizeTokens(CToken cTokenCollateral, uint actualRepayAmount) internal view returns (uint) {
        uint priceBorrowed = comptroller.oracle().getUnderlyingPrice(CToken(address(this)));
        uint priceCollateral = comptroller.oracle().getUnderlyingPrice(cTokenCollateral);
        uint liquidationIncentive = comptroller.liquidationIncentiveMantissa();
        uint numerator = priceBorrowed * liquidationIncentive * actualRepayAmount;
        uint denominator = priceCollateral * 1e18;
        uint exchangeRate = cTokenCollateral.exchangeRateStored();
        return (numerator / denominator) * 1e18 / exchangeRate;
    }

    function _setReserveFactor(uint newReserveFactorMantissa) external {
        if (msg.sender != admin) revert Unauthorized();
        if (newReserveFactorMantissa > reserveFactorMaxMantissa) revert Unauthorized();
        accrueInterest();
        uint old = reserveFactorMantissa;
        reserveFactorMantissa = newReserveFactorMantissa;
        emit NewReserveFactor(old, newReserveFactorMantissa);
    }

    function _addReserves(uint addAmount) external returns (uint) {
        accrueInterest();
        uint actualAddAmount = doTransferIn(msg.sender, addAmount);
        totalReserves += actualAddAmount;
        emit ReservesAdded(msg.sender, actualAddAmount, totalReserves);
        return 0;
    }

    function _reduceReserves(uint reduceAmount) external nonReentrant returns (uint) {
        if (msg.sender != admin) revert Unauthorized();
        accrueInterest();
        if (reduceAmount > totalReserves) revert Unauthorized();
        totalReserves -= reduceAmount;
        doTransferOut(admin, reduceAmount);
        emit ReservesReduced(admin, reduceAmount, totalReserves);
        return 0;
    }

    function getCash() external view returns (uint) {
        return getCashPrior();
    }

    function isCToken() external pure returns (bool) {
        return true;
    }

    // To be implemented in child
    function doTransferIn(address from, uint amount) internal virtual returns (uint);
    function doTransferOut(address to, uint amount) internal virtual;
    function getCashPrior() internal virtual view returns (uint);

    // ERC20 metadata
    function decimals() external view returns (uint8) {
        return decimals;
    }

    function symbol() external view returns (string memory) {
        return symbol;
    }

    function name() external view returns (string memory) {
        return name;
    }
}