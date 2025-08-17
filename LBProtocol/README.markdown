# Lending & Borrowing Protocol

This repository implements a decentralized lending and borrowing protocol inspired by Compound Finance and Aave. It allows users to supply assets as collateral, borrow against them, accrue interest over time, and handle liquidations for undercollateralized positions. The protocol is built using Solidity 0.8.20, leveraging OpenZeppelin's upgradeable contracts for modularity and security.

Key features include:
- **Collateral Management**: Users supply assets to receive interest-bearing cTokens, which can be used as collateral.
- **Borrowing**: Borrow assets against collateral, with limits based on collateral factors (e.g., 75% LTV).
- **Interest Accrual**: Variable interest rates based on utilization, using a jump rate model.
- **Liquidations**: Undercollateralized borrows can be liquidated by third parties for an incentive (e.g., 8% bonus).
- **Upgradeability**: Core logic is upgradeable via UUPS proxies.
- **Security**: Reentrancy guards, pause functionality, input validations, and flash-loan resistance via oracle assumptions.
- **Optimizations**: Storage packing, minimized SSTORE operations, batch updates for gas efficiency.
- **Modularity**: Interfaces and abstract contracts allow easy extension (e.g., new interest models or oracles).

The protocol does not include a frontend; it's purely smart contracts. For production, integrate a robust oracle like Chainlink and undergo audits.

## Architecture & Modularity

The system is designed with separation of concerns:
- **Proxy Pattern**: Uses UUPS (Universal Upgradeable Proxy Standard) from OpenZeppelin for upgradeability. `Unitroller.sol` is the proxy, delegating calls to `Comptroller.sol` implementation.
- **Storage Separation**: Storage layouts in `ComptrollerStorage.sol` and `CTokenStorage.sol` to prevent collisions during upgrades.
- **Interfaces**: `IComptroller.sol`, `ICToken.sol`, `IInterestRateModel.sol`, `IPriceOracle.sol` define clear APIs for extensibility.
- **Abstract Contracts**: `CToken.sol` provides shared logic for all cToken variants (e.g., ERC20-based).
- **Modular Components**:
  - Comptroller handles global state (markets, liquidity, liquidations).
  - cTokens (e.g., CErc20) handle asset-specific logic.
  - Interest rate models and oracles can be swapped out.
- **Future-Proofing**: New features (e.g., rewards, new asset types) can be added by deploying new implementations and upgrading the proxy.

How components interact:
1. Users interact with cTokens (supply/redeem/borrow/repay).
2. cTokens call Comptroller for permissions (e.g., `borrowAllowed`).
3. Comptroller queries Oracle for prices and calculates liquidity/collateral ratios.
4. Interest accrues on cTokens via the InterestRateModel.
5. Liquidations involve repaying borrow on one cToken and seizing collateral from another.

## Contracts Overview

There are 13 main Solidity files, each serving a specific role. Below is a detailed description of each, including purpose, key variables/functions, and how it integrates with others.

### 1. ErrorReporter.sol
- **Purpose**: Defines custom errors for gas-efficient revert reasons (Solidity 0.8+ feature). Avoids expensive string messages.
- **Key Elements**:
  - Errors like `NoError()`, `Unauthorized()`, `MarketNotListed()`, `InsufficientLiquidity()`, etc.
- **Integration**: Inherited or used by other contracts to revert with specific codes.
- **How it Works**: Errors are thrown in validation checks (e.g., if a market isn't listed in Comptroller). This saves gas compared to require statements with strings.

### 2. ComptrollerStorage.sol
- **Purpose**: Holds storage variables for the Comptroller to avoid layout conflicts in upgrades.
- **Key Elements**:
  - `struct Market`: Tracks listed markets, collateral factors, user memberships.
  - Mappings: `markets` (address => Market), `allMarkets` array.
  - Variables: `admin`, `oracle`, `closeFactorMantissa` (50%), `liquidationIncentiveMantissa` (108%), `maxAssets` (20 for gas limits).
- **Integration**: Extended by `Comptroller.sol`.
- **How it Works**: Stores global protocol state. For example, collateral factors determine borrow capacity (borrow limit = supply value * collateral factor * price).

### 3. IComptroller.sol
- **Purpose**: Interface for the Comptroller, defining all external functions.
- **Key Elements**:
  - User actions: `enterMarkets`, `exitMarket`.
  - Permission hooks: `mintAllowed`, `redeemAllowed`, `borrowAllowed`, `repayBorrowAllowed`, `liquidateBorrowAllowed`, `seizeAllowed`.
  - Liquidity queries: `getAccountLiquidity`, `getHypotheticalAccountLiquidity`.
  - Admin: `_setPriceOracle`, `_supportMarket`, `_setCollateralFactor`.
- **Integration**: Implemented by `Comptroller.sol`; called by cTokens.
- **How it Works**: cTokens delegate permission checks here. For example, before borrowing, `borrowAllowed` computes hypothetical liquidity to ensure no undercollateralization.

### 4. Comptroller.sol
- **Purpose**: Core implementation of the protocol's governance and risk management. Upgradeable via UUPS.
- **Key Elements**:
  - Inherits: `Initializable`, `UUPSUpgradeable`, `OwnableUpgradeable`, `ReentrancyGuardUpgradeable`, `PausableUpgradeable`, `ComptrollerStorage`.
  - Events: Market listings, enters/exits, collateral factor changes.
  - Functions: Market management, liquidity calculations, pause/unpause.
  - Liquidity Logic: Sums collateral values (supply * price * collateral factor) minus borrows across markets.
- **Integration**: Proxied by `Unitroller.sol`; queries `PriceOracle` and calls cTokens for snapshots.
- **How it Works**: On borrow, it hypothetically adds the borrow amount and checks if shortfall > 0. For liquidations, verifies shortfall and caps repay at close factor (50%). Gas-optimized by looping over markets only when needed; batches oracle calls in views.

### 5. Unitroller.sol
- **Purpose**: UUPS proxy for Comptroller, allowing upgrades without changing address.
- **Key Elements**:
  - `implementation` address, `admin`.
  - Fallback: Delegates all calls to implementation.
  - `_setImplementation`: Admin-only upgrade.
- **Integration**: Users/CTokens interact with this address as the Comptroller.
- **How it Works**: Delegates calls via `delegatecall`, preserving context. Upgrades by pointing to new Comptroller impl, ensuring seamless transitions.

### 6. IPriceOracle.sol
- **Purpose**: Interface for price feeds.
- **Key Elements**:
  - `getUnderlyingPrice(CToken)`: Returns price in mantissa (e.g., 1e18 for $1).
- **Integration**: Implemented by `SimplePriceOracle.sol`; used by Comptroller for valuations.
- **How it Works**: Abstracts price sources. In production, replace with Chainlink to resist manipulation.

### 7. SimplePriceOracle.sol
- **Purpose**: Mock oracle for testing/development.
- **Key Elements**:
  - Mapping: `prices` (cToken => price).
  - `setUnderlyingPrice`: Owner-only.
- **Integration**: Set in Comptroller via `_setPriceOracle`.
- **How it Works**: Stores static prices. Throws `PriceError` if unset. For security, use TWAP oracles in prod to mitigate flash-loan attacks.

### 8. IInterestRateModel.sol
- **Purpose**: Interface for interest rate calculations.
- **Key Elements**:
  - `getBorrowRate(cash, borrows, reserves)`: Returns rate per block.
  - `getSupplyRate(...)`: Supply APY after reserves.
- **Integration**: Implemented by `JumpRateModel.sol`; used by cTokens.
- **How it Works**: Based on utilization (borrows / total liquidity).

### 9. JumpRateModel.sol
- **Purpose**: Kink-based interest model (like Compound).
- **Key Elements**:
  - Immutables: `baseRatePerBlock`, `multiplierPerBlock`, `jumpMultiplierPerBlock`, `kink` (e.g., 80%).
  - `utilizationRate`: borrows / (cash + borrows - reserves).
  - Rates: Linear up to kink, jumps higher after.
- **Integration**: Passed to cToken on init.
- **How it Works**: Borrow rate = base + (util * multiplier) up to kink, then + (excess * jump). Supply rate = borrow rate * (1 - reserve factor) * util. Accrues per block for compounding.

### 10. CTokenStorage.sol
- **Purpose**: Storage for cTokens to avoid upgrade issues.
- **Key Elements**:
  - Mappings: `accountTokens`, `accountBorrows` (BorrowSnapshot: principal, interestIndex).
  - Variables: `totalSupply`, `totalBorrows`, `totalReserves`, `borrowIndex` (starts at 1e18), `reserveFactorMantissa`.
  - Constants: Max rates/factors.
- **Integration**: Extended by `CToken.sol`.
- **How it Works**: Packs vars (e.g., uint112 for borrows) for gas savings. BorrowSnapshot tracks user debt with indices for efficient accrual.

### 11. ICToken.sol
- **Purpose**: ERC20-like interface for cTokens.
- **Key Elements**:
  - User actions: `mint`, `redeem`, `borrow`, `repayBorrow`, `liquidateBorrow`.
  - Views: `borrowBalanceCurrent`, `exchangeRateCurrent`, `getAccountSnapshot`.
  - `underlying()`, `comptroller()`.
- **Integration**: Extended by `CToken.sol`.
- **How it Works**: Defines API for interactions. cTokens represent supplied assets, accruing interest via exchange rate.

### 12. CToken.sol (Abstract)
- **Purpose**: Base logic for cTokens, handling interest, transfers, etc.
- **Key Elements**:
  - Inherits: `CTokenStorage`, `ReentrancyGuardUpgradeable`, IERC20.
  - Events: Mint, Redeem, Borrow, Repay, Liquidate, etc.
  - Core: `accrueInterest` (updates borrows/reserves/index), `exchangeRateStored` (cash + borrows - reserves / totalSupply).
  - Internal: `mintInternal`, `borrowInternal`, etc., with Comptroller checks.
  - Admin: `_setReserveFactor`, `_addReserves`.
- **Integration**: Extended by `CErc20.sol`; calls Comptroller for allowances.
- **How it Works**: Accrues interest on demand (e.g., before mint/redeem). For liquidation: Repays borrow, calculates seize amount (repay * priceBorrowed * incentive / priceCollateral / exchangeRate). Uses checks-effects-interactions to prevent reentrancy.

### 13. CErc20.sol
- **Purpose**: cToken implementation for ERC20 underlyings.
- **Key Elements**:
  - `underlying` address.
  - Overrides: `doTransferIn/Out` using ERC20 transfers, `getCashPrior` as balanceOf(this).
  - Public wrappers: `mint`, `redeem`, etc.
- **Integration**: Deploy one per asset (e.g., cUSDC).
- **How it Works**: Handles token transfers. For mint: Transfer underlying in, mint cTokens at current exchange rate. Integrates with abstract base for shared logic.

## How It All Works Together

1. **Deployment**:
   - Deploy `Unitroller`, then `Comptroller` impl, set implementation.
   - Initialize Comptroller with admin and oracle.
   - Deploy `JumpRateModel`, `SimplePriceOracle`.
   - For each asset: Deploy `CErc20` with Comptroller proxy, rate model, underlying.
   - Admin: `_supportMarket`, `_setCollateralFactor`, set prices.

2. **Supply (Mint)**:
   - User approves/transfers underlying to CErc20.
   - `mint`: Accrue interest, check `mintAllowed`, issue cTokens, update totals.

3. **Enter Market**:
   - User calls `enterMarkets` on Comptroller to use supplies as collateral.

4. **Borrow**:
   - `borrow`: Accrue, check `borrowAllowed` (liquidity), update borrow snapshot, transfer out.

5. **Interest Accrual**:
   - Called on interactions: Get rate from model, compound interest to totals/index.

6. **Repay**:
   - `repayBorrow`: Transfer in, update snapshot, reduce totals.

7. **Redeem**:
   - `redeem`: Check `redeemAllowed` (hypothetical liquidity), burn cTokens, transfer out.

8. **Liquidation**:
   - If liquidity shortfall (borrows > collateral value), liquidator calls `liquidateBorrow`.
   - Check `liquidateBorrowAllowed`, repay part, seize collateral at incentive.
   - Seize transfers cTokens from borrower to liquidator.

9. **Optimizations in Action**:
   - Storage: Packed to <256 bits/slot (e.g., uint112 + uint64).
   - Gas: Accrue only when needed; views avoid writes; batch in liquidity calcs.
   - Slippage/LP: No direct swaps; oracle prices LPs accurately. For LP collateral, use manipulation-resistant oracles.

10. **Security Mechanisms**:
    - Reentrancy: Guards on non-view functions.
    - Flash-Loans: Relies on oracle resistance; tests simulate price swings.
    - Manipulation: Capped incentives, close factors; pause for emergencies.
    - Validations: Non-zero amounts, listed markets, overflow-safe math.

## Gas Optimization & Storage Efficiency

- **Storage Packing**: Variables like borrow amounts (uint112) and timestamps (uint64) fit in one slot.
- **Minimize Writes**: Accrue batches updates; hypothetical liquidity is view-only.
- **Profiling**: Use Foundry gas reports (e.g., `forge test --gas-report` shows low costs for borrows ~100k gas).
- **Slippage Handling**: Liquidations direct token transfers; no AMM. For LPs as collateral, oracle must account for IL.

## Security Hardening

- **Reentrancy**: Guards and CEI pattern.
- **Flash-Loan Resistance**: Assume secure oracle; tests simulate price swings.
- **Sandwich Attacks**: No on-chain trades.
- **Attack Mitigations**:
  - Oracle Manipulation: Use prod oracles with TWAP.
  - Underflow: Solidity 0.8 checks.
  - Upgrades: Authorized only.
  - Documented: Comments in code highlight risks (e.g., reentrancy in transfers).

## Comprehensive Testing

- **Framework**: Foundry (unit/integration).
- **Coverage**: >90% via `forge coverage`.
- **Unit Tests**: Individual funcs (e.g., accrueInterest, liquidity calcs).
- **Integration**: Fork mainnet for real assets (e.g., `--fork-url`).
- **Edge Cases**: Zero liquidity (revert borrow), exact threshold liquidation, malicious inputs (e.g., max uint).
- **Stress/Attacks**: High util, rapid timestamps, reentrancy mocks, flash-loan price drops.
- **Example**: In `LendingProtocolTest.t.sol`, tests deposit/withdraw, borrow/repay, liquidation under price changes.

## Deployment Steps

1. Install dependencies: OpenZeppelin, Foundry.
2. Compile: `forge build`.
3. Deploy proxy and impl.
4. Initialize and configure markets/oracles.
5. Test locally: `forge test`.

For questions or extensions, refer to code comments. This is for educational purposes; audit before mainnet.