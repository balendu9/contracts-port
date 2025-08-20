# Flash Loan Arbitrage Simulator

## Overview
The Flash Loan Arbitrage Simulator is a professional, efficient, and fully functional system designed to simulate arbitrage opportunities using flash loans on decentralized exchanges (DEXes). It combines a Solidity smart contract deployed on the Ethereum Sepolia testnet with Python scripts to simulate price differences, execute trades, and analyze performance across multiple cycles. The system demonstrates flash loan mechanics, gas optimization, risk handling (e.g., slippage), and performance tracking (success rate, profits, gas usage).

### Core Features
- **Solidity Smart Contract**: Executes flash loans and arbitrage trades between two mock DEXes (Uniswap V2 clones) on Sepolia testnet.
- **Python Simulation**: Simulates price differences across DEXes, triggers arbitrage, and tracks metrics over hundreds of cycles.
- **Profit/Loss Calculations**: Computes profits, gas costs, and slippage for each trade.
- **Gas Optimization**: Uses immutable variables and minimal operations in Solidity for efficiency.
- **Risk Scenarios**: Handles failures due to insufficient profits or high slippage.
- **Performance Tracking**: Monitors success rate, cumulative profits, and generates a performance graph.

### Advanced Features
- Simulates 100+ arbitrage cycles with dynamic liquidity changes.
- Tracks metrics: success rate, profits, gas usage, and slippage.
- Visualizes cumulative profits using Matplotlib.

## Prerequisites
- **Node.js**: v18+ LTS for Hardhat (Solidity development).
- **Python**: 3.12+ for simulation scripts.
- **MetaMask**: Wallet for Sepolia testnet (funded with ~0.1 Sepolia ETH from [sepoliafaucet.com](https://sepoliafaucet.com) or [Alchemy](https://alchemy.com)).
- **Alchemy API Key**: For Sepolia testnet access ([get one free](https://alchemy.com)).

## Installation
1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd flash-loan-arbitrage
   ```

2. **Set Up Hardhat (Solidity)**:
   ```bash
   npm install -g hardhat
   npm install @openzeppelin/contracts @uniswap/v2-core @uniswap/v2-periphery dotenv ethers
   ```
   - Create `.env` file in root:
     ```plaintext
     ALCHEMY_SEPOLIA_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
     PRIVATE_KEY=your_wallet_private_key
     ```

3. **Set Up Python**:
   ```bash
   pip install web3 numpy pandas matplotlib
   ```

4. **Get Sepolia ETH**:
   - Fund your MetaMask wallet via [sepoliafaucet.com](https://sepoliafaucet.com) or Alchemy.

## Project Structure
- **contracts/**: Solidity contracts (`TokenA.sol`, `TokenB.sol`, `FlashLoanProvider.sol`, `ArbitrageContract.sol`).
- **scripts/**: Deployment (`deploy.js`) and liquidity setup (`add_liquidity.js`).
- **simulator.py**: Python script for simulating arbitrage cycles and analyzing results.
- **addresses.json**: Generated file with deployed contract addresses.
- **performance.png**: Output graph of cumulative profits.

## Usage
### Step 1: Deploy Contracts
1. Compile contracts:
   ```bash
   npx hardhat compile
   ```
2. Deploy to Sepolia testnet:
   ```bash
   npx hardhat run scripts/deploy.js --network sepolia
   ```
   - Outputs contract addresses to console and `addresses.json`.
3. Add initial liquidity to DEXes:
   ```bash
   npx hardhat run scripts/add_liquidity.js --network sepolia
   ```
   - Sets up price differences (e.g., 1000 TokenA : 1100 TokenB on DEX1, 1000 TokenA : 900 TokenB on DEX2).

### Step 2: Run Simulation
1. Update `simulator.py` with:
   - Your Alchemy API key and private key.
   - Full contract ABIs (copy from `artifacts/contracts/*.json` after compilation).
2. Run the simulation (100 cycles by default):
   ```bash
   python simulator.py
   ```

### Expected Outputs
- **Console**:
  - Summary: Success rate (e.g., 82%), total profit (e.g., 156.789 TokenA), average gas (e.g., 247,123 units).
  - Sample DataFrame: Shows cycle details (success, profit, gas, slippage, risk notes).
    ```
    Success Rate: 82.0%
    Total Profit: 156.789 TokenA
    Avg Gas: 247123.5
       cycle  success   profit  gas_used  slippage      risk_note
    0      0     True   1.2345   245000    0.0123           None
    1      1    False   0.0000        0   -0.0500  Slippage failure
    ...
    Performance graph saved as performance.png
    ```
- **Performance Graph**: `performance.png` plots cumulative profit over cycles.
- **On-Chain**: Transactions on Sepolia (viewable on Etherscan) with `ArbitrageExecuted` events (borrowed amount, profit, gas used).

### Step 3: Verify Results
- Check contract balances:
  ```python
  from web3 import Web3
  w3 = Web3(Web3.HTTPProvider('https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY'))
  token_a = w3.eth.contract(address='TOKEN_A_ADDRESS', abi=ERC20_ABI)
  balance = token_a.caller.balanceOf('ARBITRAGE_CONTRACT_ADDRESS') / 10**18
  print(f"Contract balance: {balance} TokenA")
  ```
- Withdraw profits:
  ```bash
  npx hardhat console --network sepolia
  > const arb = await ethers.getContractAt("ArbitrageContract", "ARBITRAGE_CONTRACT_ADDRESS");
  > await arb.withdraw();
  ```
- View txs on [Sepolia Etherscan](https://sepolia.etherscan.io).

## Gas Optimization
- **Solidity**: Uses immutable variables, SafeERC20 for transfers, and minimal external calls.
- **Python**: Limits gas usage with fixed `gas` (2M) and `gasPrice` (5 gwei).
- **Average Gas**: ~200,000–300,000 per arbitrage tx.

## Risk Handling
- **Slippage**: Python estimates slippage; contract reverts if profit < minimum.
- **Failures**: Captured as `False` in results with negative slippage (e.g., -5%).
- **Test Risks**: `test_risks()` function simulates high-slippage scenarios by removing liquidity.

## Troubleshooting
- **Tx Reverts**: Check Etherscan for revert reasons (e.g., “Insufficient profit”). Ensure sufficient liquidity and price differences.
- **Low Success Rate**: Adjust liquidity range in `simulator.py` (e.g., 800–1200 TokenB) for larger price spreads.
- **Network Issues**: Verify Alchemy API key and Sepolia ETH balance.
- **ABI Errors**: Ensure ABIs in `simulator.py` match `artifacts/contracts/*.json`.

## Extending the Project
- **Real DEXes**: Replace mock DEXes with Uniswap V2 on Sepolia (update `ArbitrageContract` with real router addresses).
- **Larger Scale**: Increase cycles to 1000+ using Python multiprocessing.
- **Security**: Add slippage checks in `ArbitrageContract` (e.g., `minAmountOut` in swaps).
- **Mainnet**: Adapt for Ethereum mainnet with real DEXes and flash loan providers (e.g., Aave).

## License
MIT License. See `LICENSE` file for details.