# Uniswap V2-Style Automated Market Maker (AMM)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-blue.svg)](https://soliditylang.org/)

This repository contains a professional, gas-optimized, and security-hardened implementation of a decentralized exchange (DEX) Automated Market Maker (AMM) inspired by Uniswap V2. It includes core smart contracts for liquidity pools, token swaps, and liquidity provision/removal, with additional features for upgradeability, modularity, and protection against common vulnerabilities like flash loan manipulation and reentrancy attacks.

The implementation emphasizes:
- **Gas Efficiency**: Minimized storage writes, packed variables, and batch updates.
- **Security**: Reentrancy guards, flash-loan resistant oracles (via TWAP), and slippage controls.
- **Modularity**: Interfaces and abstract patterns for easy extensibility.
- **Upgradeability**: UUPS proxy pattern for the Factory contract using OpenZeppelin libraries.
- **LP Mechanics**: Proportional liquidity shares using square-root math, fee-on-transfer support, and minimum liquidity locks.

**Note**: This is a simplified educational and development implementation. It is **not production-ready** without professional audits, extensive testing on testnets, and legal compliance checks. Always conduct thorough security reviews before deploying to mainnet.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Contracts and Interfaces](#contracts-and-interfaces)
- [Key Features](#key-features)
  - [Liquidity Provider (LP) Mechanics](#liquidity-provider-lp-mechanics)
  - [Swap and Slippage Handling](#swap-and-slippage-handling)
  - [Gas Optimizations](#gas-optimizations)
  - [Security Hardening](#security-hardening)
- [Dependencies](#dependencies)
- [Deployment](#deployment)
- [Usage](#usage)
  - [Factory Deployment](#factory-deployment)
  - [Creating Pairs](#creating-pairs)
  - [Adding/Removing Liquidity](#addingremoving-liquidity)
  - [Swapping Tokens](#swapping-tokens)
- [Testing](#testing)
- [Attack Surfaces and Mitigations](#attack-surfaces-and-mitigations)
- [Contributing](#contributing)
- [License](#license)

## Architecture Overview

The system is modular, following real-world DeFi patterns:
- **Factory**: Manages pair creation using CREATE2 for deterministic addresses. Upgradeable via UUPS proxy.
- **Pair**: Core liquidity pool contract handling reserves, swaps, mint/burn LP tokens, and TWAP oracles.
- **Router**: Periphery contract for user-friendly interactions (add/remove liquidity, swaps). Supports ETH handling via WETH.
- **ERC20 LP Token**: Integrated into Pair for liquidity shares.
- **Libraries**: Math (sqrt), SafeMath (overflow protection), UQ112x112 (price encoding for oracles).

Contracts use interfaces (e.g., `IUniswapV2Pair`, `IUniswapV2Factory`, `IUniswapV2Router`) for extensibility. Abstract contracts can be inherited for future features like V3-style concentrated liquidity.

Upgradeability is limited to the Factory for safety, allowing fee adjustments or logic updates without affecting existing pairs.

## Contracts and Interfaces

### Core Contracts
- **UniswapV2Factory.sol**: 
  - Deploys new pairs via CREATE2.
  - Manages protocol fees (feeTo address).
  - Upgradeable with UUPS (OpenZeppelin).
  - Inherits `Initializable`, `UUPSUpgradeable`, `OwnableUpgradeable`.

- **UniswapV2Pair.sol**:
  - Manages liquidity reserves (packed in slots for gas savings).
  - Handles mint/burn LP tokens, swaps, skim/sync.
  - Includes cumulative price oracles for TWAP.
  - Uses reentrancy lock modifier.

- **UniswapV2Router02.sol**:
  - Facilitates liquidity addition/removal and token swaps.
  - Supports multi-hop swaps and ETH integration.
  - Pure periphery; no state changes outside pairs.

- **UniswapV2ERC20.sol**:
  - ERC20 implementation for LP tokens with permit support (EIP-2612).

### Libraries
- **Math.sol**: Babylonian method for square roots (gas-efficient).
- **SafeMath.sol**: Arithmetic operations with overflow checks (integrated from OpenZeppelin for brevity).
- **UQ112x112.sol**: Fixed-point encoding for price cumulatives.

### Interfaces
- **IUniswapV2Factory.sol**: Defines factory methods (e.g., createPair, getPair).
- **IUniswapV2Pair.sol**: Pair interactions (e.g., mint, burn, swap, getReserves).
- **IUniswapV2Router.sol**: Router methods (e.g., addLiquidity, swapExactTokensForTokens).
- **IERC20.sol**: Standard ERC20 interface.
- **IUniswapV2Callee.sol**: Callback for flash swaps.
- **IWETH.sol**: WETH interface for ETH handling.

## Key Features

### Liquidity Provider (LP) Mechanics
- **Mint LP Tokens**: When adding liquidity, shares are calculated as `min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)`. Initial mint uses `sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY` to lock a small amount permanently (prevents division by zero).
- **Burn LP Tokens**: Pro-rata distribution of reserves based on balances (not reserves) for accuracy with fee-on-transfer tokens.
- **Fees**: 0.3% swap fee (997/1000 after fee). Protocol fee (1/6 of growth) minted to `feeTo` if enabled.
- **Sync/Skim**: Handles reserve mismatches (e.g., from fee-on-transfer or airdrops).

### Swap and Slippage Handling
- **Constant Product Formula**: ` (reserve0 + amount0In * 0.997) * (reserve1 + amount1In * 0.997) >= reserve0 * reserve1 * 1000^2 `.
- **Slippage Protection**: Router methods require `amountOutMin` or `amountInMax` parameters. Users specify deadlines to prevent stale quotes.
- **Flash Swaps**: Supported via callback; borrower must repay in the same transaction.
- **Multi-Hop Swaps**: Path array in router for routing through multiple pairs.

### Gas Optimizations
- **Storage Packing**: Reserves (uint112) and timestamp (uint32) in one slot.
- **Immutable Variables**: Factory and WETH in Router.
- **Assembly Usage**: CREATE2 in Factory; avoids unnecessary ops.
- **Batch Updates**: Single `_update` call for reserves and cumulatives.
- **Local Variables**: Gas savings by caching (e.g., `_totalSupply`, `_reserve0`).
- **Profiling**: Use Foundry/Hardhat gas reports (e.g., `forge test --gas-report`).

### Security Hardening
- **Reentrancy Guard**: Non-reentrant lock in Pair for critical functions.
- **Flash Loan Resistance**: TWAP oracles (cumulative prices) prevent single-block manipulation. External integrations should average over blocks.
- **Sandwich Mitigation**: User-specified slippage and deadlines; can't eliminate MEV but empowers users.
- **Overflow Protection**: SafeMath throughout.
- **Checks-Effects-Interactions**: Transfers after state updates.
- **Permit Support**: Gas-efficient approvals via signatures.
- **Minimum Liquidity**: Locks 1000 LP tokens initially to avoid zero-reserve issues.

## Dependencies
- OpenZeppelin Contracts Upgradeable: `npm install @openzeppelin/contracts-upgradeable`
- Solidity ^0.8.20

## Deployment
1. Install dependencies: `npm install`.
2. Compile: `npx hardhat compile` or `forge build`.
3. Deploy Factory:
   - Use a proxy for upgradeability.
   - Call `initialize(feeToSetter)` post-deployment.
4. Deploy Router: Pass Factory address and WETH address.
5. Set `feeTo` via Factory if protocol fees are desired.

Example (Hardhat script):
```javascript
const { ethers, upgrades } = require("hardhat");

async function main() {
  const Factory = await ethers.getContractFactory("UniswapV2Factory");
  const factory = await upgrades.deployProxy(Factory, [feeToSetterAddress], { kind: 'uups' });
  await factory.deployed();

  const Router = await ethers.getContractFactory("UniswapV2Router02");
  const router = await Router.deploy(factory.address, WETHAddress);
  await router.deployed();
}

main();
```

## Usage

### Factory Deployment
- Create pairs: `createPair(tokenA, tokenB)` → Returns pair address.

### Creating Pairs
- Pairs are created deterministically via CREATE2.
- Query: `getPair(tokenA, tokenB)`.

### Adding/Removing Liquidity
- Via Router: `addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline)`.
- ETH variant: `addLiquidityETH(...)`.
- Remove: `removeLiquidity(...)` or with permit for gas savings.

### Swapping Tokens
- Exact input: `swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline)`.
- Exact output: `swapTokensForExactTokens(...)`.
- ETH support: `swapExactETHForTokens(...)`, etc.
- Quotes: `getAmountsOut(amountIn, path)` for off-chain slippage calc.

## Testing
- **Framework**: Use Foundry or Hardhat.
- **Coverage Goal**: >90% with `forge coverage` or `npx hardhat coverage`.
- **Test Types**:
  - **Unit**: Pair mint/burn/swap logic, oracle updates.
  - **Integration**: Router flows, multi-hop swaps.
  - **Forked Mainnet**: Test with real tokens (e.g., USDC/ETH) using `forge test --fork-url <rpc>`.
- **Edge Cases**: Zero liquidity, max inputs, malicious callbacks.
- **Attack Simulations**: Reentrancy (mock reentrant callee), flash loans (manipulate then check TWAP), sandwich (front-run swaps).
- Example Test (Foundry):
  ```solidity
  // test/UniswapV2Pair.t.sol
  contract UniswapV2PairTest is Test {
      // Setup factory, tokens, pair...
      function testMint() public {
          // Add liquidity, assert LP minted correctly
      }
  }
  ```

## Attack Surfaces and Mitigations
- **Reentrancy**: Mitigated by lock modifier; tested with mock reentrants.
- **Flash Loan Manipulation**: TWAP requires multi-block averaging; single-tx attacks fail.
- **Sandwich Attacks**: User params (minOut, deadline) protect; MEV-resistant via private relays.
- **Overflow/Underflow**: SafeMath; Solidity 0.8+ checked arithmetic.
- **Fee-on-Transfer Tokens**: Handled by using balances in burn.
- **Oracle Abuse**: Cumulatives overflow safely (desired behavior).
- **Upgrade Risks**: Only Factory upgradeable; pairs immutable for safety.
- **Documented Vectors**: All critical paths follow CEI; external calls minimized.

For full audits, engage firms like Trail of Bits or OpenZeppelin.

## Contributing
Contributions welcome! Fork, create a branch, add tests, and submit a PR. Follow Solidity style guides (e.g., NatSpec comments).

## License
MIT License. See [LICENSE](LICENSE) for details.