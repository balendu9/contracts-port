# Liquidity Pool Smart Contract Project

## Project Overview
This project implements a secure, modular, and gas-optimized Automated Market Maker (AMM) liquidity pool smart contract, designed for decentralized finance (DeFi) applications. The contract supports liquidity provision, token swaps, and reserve management, with a focus on mitigating common attack vectors such as reentrancy, sandwich attacks, and flash loans. The architecture leverages OpenZeppelin's upgradeable proxy pattern, ensuring flexibility for future enhancements.

### Objectives
- **Security**: Mitigate known vulnerabilities (e.g., reentrancy, sandwich attacks, flash loans).
- **Modularity**: Use interfaces and upgradeable patterns for extensibility.
- **Gas Optimization**: Minimize storage writes, pack variables, and batch updates.
- **Comprehensive Testing**: Achieve >90% test coverage with unit and integration tests.
- **Real-World Readiness**: Optimize for mainnet deployment with robust error handling and slippage protection.

## Features

### Core Functionality
- **Add Liquidity**: Users can deposit token pairs (Token A and Token B) to provide liquidity, receiving LP tokens proportional to their contribution.
- **Remove Liquidity**: Users can burn LP tokens to withdraw their share of the pool's reserves.
- **Swap**: Users can swap Token A for Token B (or vice versa) using a constant product formula, with a 0.3% fee.
- **Reserve Management**: Tracks pool reserves with gas-efficient storage (using `uint128` in a packed `struct`).

### Security Features
- **Reentrancy Protection**: Utilizes OpenZeppelin's `ReentrancyGuardUpgradeable` to prevent reentrant calls in critical functions (`addLiquidity`, `removeLiquidity`, `swap`).
- **Sandwich Attack Mitigation**: Limits trade volume per block to 10% of reserves, tracked via `blockTradeVolume` and `lastTradeBlock`.
- **Slippage Protection**: Enforces minimum output amounts (`minA`, `minB`, `minAmountOut`) to protect against unexpected price movements.
- **Flash Loan Resistance**: Uses atomic reserve updates and constant product formula to prevent manipulation via flash loans.
- **Emergency Pause**: Implements `PausableUpgradeable` for owner-controlled pausing in emergencies.
- **Ratio Checks**: Ensures proper token ratios during liquidity addition to prevent reserve manipulation.
- **Minimum Liquidity Lock**: Locks 1000 LP tokens (`MINIMUM_LIQUIDITY`) on initial deposit to avoid pool initialization attacks.

### Gas Optimization
- **Storage Packing**: Uses a `Reserves` struct with `uint128` fields to fit within a single storage slot, reducing `SSTORE` costs.
- **Efficient Math**: Implements gas-optimized `sqrt` and `min` functions for calculations.
- **Batched Updates**: Consolidates reserve updates in a single function (`updateReserves`) to minimize storage writes.
- **SafeMath**: Uses `SafeMathUpgradeable` for arithmetic safety without excessive gas overhead.

### Modularity and Upgradeability
- **Interface-Based Design**: Defines `ILiquidityPool` interface for clear contract interactions and future extensions.
- **Upgradeable Architecture**: Leverages OpenZeppelin's `Initializable`, `OwnableUpgradeable`, and proxy patterns for safe upgrades.
- **Modular Functions**: Separates concerns (liquidity, swaps, reserves) to allow independent feature additions.

## Architecture

### Contract Structure
- **LiquidityPool.sol**: Main contract implementing the AMM logic.
  - Inherits `Initializable`, `OwnableUpgradeable`, `ReentrancyGuardUpgradeable`, `PausableUpgradeable`.
  - Uses `SafeMathUpgradeable` for arithmetic operations.
  - Implements `ILiquidityPool` interface for modularity.
- **Dependencies**:
  - OpenZeppelin Contracts (v4.9.0): `IERC20Upgradeable`, `OwnableUpgradeable`, `ReentrancyGuardUpgradeable`, `PausableUpgradeable`, `SafeMathUpgradeable`.
  - Deployed with `TransparentUpgradeableProxy` for upgradeability.

### Storage Layout
- **Reserves**: Packed into a `struct Reserves { uint128 reserveA; uint128 reserveB; }` to optimize storage slots.
- **LP Tokens**: Stored in `mapping(address => uint256) lpBalance` and `totalSupply` for tracking.
- **Sandwich Mitigation**: Uses `lastTradeBlock` and `blockTradeVolume` mapping to limit per-block trade volume.
- **Tokens**: References `tokenA` and `tokenB` as `IERC20Upgradeable` for token interactions.

### Workflow
1. **Deployment**:
   - Deploy `LiquidityPool` implementation contract.
   - Deploy `TransparentUpgradeableProxy` pointing to the implementation.
   - Call `initialize(address _tokenA, address _tokenB)` to set token pairs and initialize ownership.
2. **Liquidity Provision**:
   - Users approve `tokenA` and `tokenB` for the pool.
   - Call `addLiquidity` with desired amounts and minimum thresholds to receive LP tokens.
3. **Swaps**:
   - Users approve input token and call `swap` with input amount, token address, and minimum output.
   - Contract enforces slippage and volume limits, updates reserves, and transfers tokens.
4. **Liquidity Removal**:
   - Users call `removeLiquidity` with LP tokens and minimum thresholds to withdraw their share.
5. **Emergency Actions**:
   - Owner can call `pause` or `unpause` to control contract state.
6. **Upgrades**:
   - Deploy new implementation contract.
   - Update proxy to point to new implementation via owner controls.

## Security Mitigations
The contract addresses the following attack vectors:
- **Reentrancy**: Prevented by `nonReentrant` modifier on state-changing functions.
- **Sandwich Attacks**: Mitigated by per-block trade volume limits (10% of reserves).
- **Flash Loans**: Countered by atomic reserve updates and constant product formula.
- **Price Manipulation**: Protected by ratio checks and slippage enforcement.
- **Overflow/Underflow**: Mitigated by `SafeMathUpgradeable`.
- **Unauthorized Access**: Restricted by `OwnableUpgradeable` for sensitive functions.
- **Initial Pool Attacks**: Prevented by `MINIMUM_LIQUIDITY` lock.

## Testing

### Test Suite
- **File**: `LiquidityPoolTest.t.sol`
- **Framework**: Foundry (Forge)
- **Coverage**: >90% (verified with `forge coverage`)

### Test Cases
- **Unit Tests**:
  - `testAddLiquidity`: Verifies liquidity addition and LP token minting.
  - `testRemoveLiquidity`: Ensures correct reserve withdrawals and LP token burning.
  - `testSwap`: Tests token swaps with fee and reserve updates.
- **Integration Tests**:
  - Simulates mainnet-forked state with `MockToken` for realistic interactions.
  - Tests multi-user scenarios (e.g., multiple liquidity providers).
- **Security Tests**:
  - `testReentrancyAttack`: Attempts reentrant calls and verifies reversion.
  - `testSandwichAttackMitigation`: Tests large trades to trigger volume limits.
  - `testSlippageProtection`: Ensures swaps revert on excessive slippage.
- **Edge Cases**:
  - `testZeroLiquidityEdgeCase`: Verifies reversion on zero-amount inputs.
  - Tests undercollateralization, malicious inputs, and high-volume trades.

### Testing Workflow
1. Run `forge test` to execute all tests.
2. Use `forge coverage` to verify >90% coverage.
3. Profile gas usage with `forge test --gas-report`.
4. Simulate mainnet conditions using `forge --fork-url <mainnet-rpc-url>`.

## Gas Optimization Details
- **Storage Packing**: `reserveA` and `reserveB` use `uint128` to fit in one storage slot.
- **Batched Updates**: `updateReserves` consolidates state changes to minimize `SSTORE`.
- **Efficient Math**: Custom `sqrt` and `min` functions reduce gas compared to external libraries.
- **Fee Calculation**: Uses constant 0.3% fee (30 basis points) to avoid complex computations.
- **Gas Report**: Run `forge test --gas-report` to identify bottlenecks.

## Deployment Instructions
1. **Install Dependencies**:
   - Install Foundry: `curl -L https://foundry.paradigm.xyz | bash`.
   - Install OpenZeppelin: `npm install @openzeppelin/contracts-upgradeable`.
2. **Compile Contracts**:
   - Run `forge build` to compile `LiquidityPool.sol` and tests.
3. **Deploy Implementation**:
   - Deploy `LiquidityPool` using `forge create`.
4. **Deploy Proxy**:
   - Deploy `TransparentUpgradeableProxy` pointing to the implementation.
   - Call `initialize` with token addresses.
5. **Verify Contracts**:
   - Use `forge verify-contract` for Etherscan verification.
6. **Test on Mainnet Fork**:
   - Run `forge test --fork-url <mainnet-rpc-url>` to simulate real-world conditions.

## Future Enhancements
- **Additional Pools**: Add support for multiple token pairs via a factory contract.
- **Fee Tiers**: Implement configurable fee structures (e.g., 0.05%, 0.3%, 1%).
- **Oracles**: Integrate price oracles (e.g., Chainlink) for external price validation.
- **Governance**: Add decentralized governance for parameter updates.
- **Flash Swaps**: Support flash swaps with additional security checks.

## Known Limitations
- **Single Pair**: Currently supports one token pair per pool.
- **Block-Based Mitigation**: Sandwich protection relies on block number, which may need tuning for different networks.
- **Upgrade Risks**: Upgrades require careful storage layout management to avoid slot collisions.

## Audit Recommendations
- Verify storage layout compatibility for upgrades.
- Audit sandwich mitigation logic for edge cases (e.g., multi-block attacks).
- Test with real token contracts (e.g., USDC, WETH) on mainnet fork.
- Review gas usage under high load (e.g., multiple swaps per block).