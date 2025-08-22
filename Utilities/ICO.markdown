# ICO Smart Contract

This is a professional, secure, and gas-optimized Initial Coin Offering (ICO) smart contract built using Solidity. It is designed to facilitate a token sale with features like whitelisting, soft and hard caps, refund mechanisms, and emergency pause functionality. The contract uses battle-tested OpenZeppelin libraries to ensure security and reliability.

## Features

- **Token Sale**: Sells ERC20 tokens at a fixed rate (1000 tokens per ETH).
- **Hard and Soft Caps**: Hard cap set at 1000 ETH, soft cap at 200 ETH.
- **Contribution Limits**: Minimum contribution of 0.1 ETH, maximum of 10 ETH per address.
- **Whitelisting**: Only whitelisted addresses can participate in the ICO.
- **Time-Bound**: ICO runs between a predefined start and end time.
- **Refund Mechanism**: Refunds available if the soft cap is not reached by the end time.
- **Emergency Pause**: Owner can pause/unpause the contract in emergencies.
- **Token Recovery**: Owner can recover tokens sent to the contract by mistake after the ICO ends.
- **Gas Optimization**: Uses efficient coding practices to minimize gas costs.
- **Security**: Incorporates OpenZeppelin's ReentrancyGuard, Ownable, and Pausable contracts, along with SafeMath for arithmetic operations.

## Prerequisites

- **Solidity Version**: ^0.8.20
- **Dependencies**: OpenZeppelin Contracts v4.x
- **Tools**: 
  - Hardhat, Truffle, or Foundry for compilation and deployment
  - Ethereum wallet (e.g., MetaMask) for deployment and interaction
  - Testnet (e.g., Sepolia, Goerli) for testing
  - Etherscan or similar for contract verification

## Installation

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd ico-contract
   ```

2. **Install Dependencies**:
   Ensure you have Node.js installed, then install OpenZeppelin contracts:
   ```bash
   npm install @openzeppelin/contracts
   ```

3. **Set Up Development Environment**:
   Configure a development framework like Hardhat:
   ```bash
   npm install --save-dev hardhat
   npx hardhat
   ```

4. **Copy the Contract**:
   Save the `ICO.sol` file in your project's `contracts/` directory.

## Contract Details

- **File**: `ICO.sol`
- **Dependencies**:
  - `@openzeppelin/contracts/token/ERC20/IERC20.sol`
  - `@openzeppelin/contracts/access/Ownable.sol`
  - `@openzeppelin/contracts/security/ReentrancyGuard.sol`
  - `@openzeppelin/contracts/security/Pausable.sol`
  - `@openzeppelin/contracts/utils/math/SafeMath.sol`

### Key Parameters
- **Token Address**: Address of the ERC20 token being sold.
- **Start Time**: Unix timestamp for ICO start.
- **End Time**: Unix timestamp for ICO end.
- **Rate**: 1000 tokens per ETH.
- **Hard Cap**: 1000 ETH.
- **Soft Cap**: 200 ETH.
- **Min Contribution**: 0.1 ETH.
- **Max Contribution**: 10 ETH per address.

### Key Functions
- `buyTokens()`: Allows whitelisted users to purchase tokens by sending ETH.
- `claimRefund()`: Enables users to claim refunds if the soft cap is not reached and refunds are enabled.
- `enableRefunds()`: Owner can enable refunds if the soft cap is not met after the ICO ends.
- `withdrawFunds()`: Owner can withdraw ETH if the soft cap is reached.
- `updateWhitelist(address[] users, bool status)`: Owner can add/remove users from the whitelist.
- `pause()` / `unpause()`: Owner can pause/unpause the contract.
- `recoverTokens(address token, uint256 amount)`: Owner can recover tokens sent to the contract by mistake.
- `getRemainingTokens()`: View function to check available tokens in the contract.
- `getIcoStatus()`: View function to check ICO state (total raised, soft cap status, etc.).

## Deployment

1. **Deploy the ERC20 Token**:
   Deploy your ERC20 token contract first. Ensure it has sufficient tokens for the ICO.

2. **Transfer Tokens**:
   Transfer the required amount of tokens to the ICO contract address after deployment.

3. **Deploy the ICO Contract**:
   Use a Hardhat script or similar to deploy the contract. Example (Hardhat):
   ```javascript
   const ICO = await ethers.getContractFactory("ICO");
   const ico = await ICO.deploy(
       tokenAddress, // ERC20 token address
       Math.floor(Date.now() / 1000) + 3600, // Start time (1 hour from now)
       Math.floor(Date.now() / 1000) + 3600 * 24 * 7 // End time (7 days from start)
   );
   await ico.deployed();
   console.log("ICO deployed to:", ico.address);
   ```

4. **Whitelist Users**:
   Call `updateWhitelist(address[] users, bool status)` to add participants:
   ```javascript
   await ico.updateWhitelist([user1, user2], true);
   ```

5. **Verify Contract**:
   Verify the contract on Etherscan or similar for transparency.

## Usage

1. **For Users**:
   - Ensure your address is whitelisted.
   - Send ETH to the `buyTokens()` function (0.1 ETH to 10 ETH).
   - Tokens are automatically transferred to your address.
   - If the soft cap is not reached by the end time and refunds are enabled, call `claimRefund()` to get your ETH back.

2. **For Owner**:
   - Monitor the ICO progress using `getIcoStatus()` and `getRemainingTokens()`.
   - Add/remove users from the whitelist using `updateWhitelist()`.
   - Pause the contract in emergencies using `pause()`.
   - Withdraw funds using `withdrawFunds()` if the soft cap is reached.
   - Enable refunds using `enableRefunds()` if the soft cap is not met after the ICO ends.
   - Recover any mistakenly sent tokens using `recoverTokens()` after the ICO ends.

## Security Considerations

- **Audits**: Conduct a professional security audit before deploying to mainnet.
- **Testing**: Thoroughly test on testnets (e.g., Sepolia) to ensure functionality.
- **Access Control**: Secure the owner private key to prevent unauthorized access.
- **Gas Limits**: Monitor gas usage during testing to avoid out-of-gas errors.
- **Reentrancy**: Protected by `ReentrancyGuard`, but verify during audits.
- **Token Supply**: Ensure the contract has sufficient tokens before starting the ICO.

## Testing

1. **Set Up Tests**:
   Create test scripts using Hardhat/Mocha or similar. Example test cases:
   - Deploy contract and verify initialization.
   - Test token purchases within min/max contribution limits.
   - Test whitelisting functionality.
   - Test refund mechanism when soft cap is not reached.
   - Test fund withdrawal when soft cap is reached.
   - Test pause/unpause functionality.

2. **Run Tests**:
   ```bash
   npx hardhat test
   ```

## Deployment Checklist

- [ ] Deploy ERC20 token contract.
- [ ] Transfer tokens to ICO contract.
- [ ] Deploy ICO contract with correct parameters.
- [ ] Whitelist participants.
- [ ] Test all functions on a testnet.
- [ ] Verify contract on Etherscan.
- [ ] Conduct security audit.
- [ ] Deploy to mainnet.
- [ ] Monitor ICO progress and handle emergencies.

## License

MIT License. See the `LICENSE` file for details.

## Disclaimer

This contract is provided as-is. Ensure thorough testing and auditing before using in production. The developers are not responsible for any loss of funds or issues arising from the use of this contract.