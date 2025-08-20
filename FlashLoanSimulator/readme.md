Install Node.js and Hardhat (for Solidity Development and Deployment)

Download and install Node.js (v18+ LTS) from nodejs.org.
Open a terminal and install Hardhat globally: npm install -g hardhat.
Create a project directory: mkdir flash-loan-arbitrage && cd flash-loan-arbitrage.
Initialize Hardhat: npx hardhat init (select "Create a JavaScript project").
Install dependencies: npm install @openzeppelin/contracts @uniswap/v2-core @uniswap/v2-periphery dotenv ethers.

@openzeppelin/contracts: For ERC20 tokens.
@uniswap/v2-*: For cloning Uniswap V2 DEXes.


Create a .env file in the root: Add ALCHEMY_SEPOLIA_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY (get free API key from alchemy.com) and PRIVATE_KEY=your_wallet_private_key (create a test wallet with MetaMask, fund with Sepolia ETH).


Install Python and Libraries (for Simulation)

Install Python 3.12+ from python.org.
Install libraries: pip install web3 numpy pandas matplotlib.

web3: For interacting with the blockchain.
numpy/pandas/matplotlib: For simulations, data analysis, and visualizations.


