# ⚡ Simple DEX (Decentralized Exchange)

This project is a **minimalistic Automated Market Maker (AMM)** inspired by [Uniswap V2](https://uniswap.org/).  
It consists of two core contracts:  

- **`DexFactory`** → Deploys new token pairs (liquidity pools).  
- **`DexPair`** → The liquidity pool contract that holds two ERC20 tokens, allows users to add/remove liquidity, and swap between them.  

---

## 📖 Overview

A Decentralized Exchange (DEX) lets users trade ERC20 tokens directly from their wallets without intermediaries.  
Instead of using order books, this AMM uses the **constant product formula**:
x * y = k



Where:
- `x` = reserve of token0  
- `y` = reserve of token1  
- `k` = constant value  

This ensures that token prices adjust automatically based on supply and demand.

---

## 🔧 Contracts

### 1. `DexFactory`

- Responsible for creating new **pairs** of tokens.  
- Each pair is deployed via `CREATE2`, so its address is deterministic.  
- Keeps a mapping of all pairs for easy lookup.  

**Key function:**
```solidity
function createPair(address tokenA, address tokenB) external returns (address pair)

Deploys a new DexPair for tokenA and tokenB.

Emits PairCreated event.

2. DexPair

A single pair contract (liquidity pool).
Holds two ERC20 tokens (token0 and token1) and allows:

Adding liquidity → Users deposit both tokens in proportion, receive LP tokens (not fully implemented in your current version).

Removing liquidity → Users burn LP tokens, withdraw their share of reserves.

Swapping → Users trade one token for the other, following the constant product formula.

Key components:

📌 State

reserve0 and reserve1 → Track liquidity balances.

MINIMUM_LIQUIDITY → Locks tiny liquidity forever to prevent divide-by-zero issues.

FEE = 0.3% → Swap fee applied (like Uniswap V2).

📌 Core Functions

mint(address to)

Adds liquidity.

Issues LP tokens to to.

burn(address to)

Removes liquidity.

Sends proportional tokens back to to.

swap(uint amount0Out, uint amount1Out, address to)

Executes token swap.

Enforces x * y ≥ k invariant.

⚙️ How It Works

Liquidity Providers (LPs) deposit equal value of two tokens into a pair.

Example: 1 ETH + 2000 USDC.

They receive LP tokens, representing their share of the pool.

Traders swap tokens directly from the pool.

Prices are determined by the ratio of reserves.

Every swap updates reserves and charges a small fee.

LP Tokens (TODO in your contract)

Should follow ERC20 standard (transferable, tradable).

Represent ownership of the pool.

Burned when liquidity is removed.

📊 Example Workflow

Create Pair

DexFactory.createPair(tokenA, tokenB);


Add Liquidity

DexPair(pair).mint(msg.sender);


Swap

DexPair(pair).swap(amount0Out, amount1Out, msg.sender);


Remove Liquidity

DexPair(pair).burn(msg.sender);

✅ Why This Matters

Demonstrates the core mechanics of an AMM without extra complexity.

Good for educational purposes, hackathons, or extending into a full DEX.

Extensible to:

Fee routing (feeTo in factory)

LP token ERC20 logic

Router contract for easier UX

🚀 Next Steps

Implement the ERC20 LP token logic in _mint and _burn.

Add a Router contract for:

addLiquidity()

removeLiquidity()

swapExactTokensForTokens()

Security audits:

Reentrancy

Overflow/underflow

Slippage protection
