# Escrow Smart Contract

This is a secure, scalable, and gas-optimized Ethereum smart contract for an escrow system, built using Solidity ^0.8.20. It facilitates trustless transactions between a buyer and a seller, with funds held in escrow until conditions are met. The contract includes dispute resolution, timeout mechanisms, and administrative controls, making it suitable for production use.

## Features

- **Secure Escrow Transactions**: Holds funds until both buyer and seller approve, ensuring trustless mediation.
- **Dispute Resolution**: An arbiter can resolve disputes, deciding whether funds go to the buyer or seller.
- **Timeout Mechanism**: Allows refunds if the transaction is not completed within a specified period.
- **Fee System**: Configurable fees (up to 10%) are sent to a designated recipient upon transaction completion.
- **Access Control**: Administrative functions (e.g., updating arbiter, fees) are restricted to the contract owner.
- **Pausable**: Emergency pause/unpause functionality for security.
- **Event Logging**: Comprehensive events for transparency and off-chain tracking.
- **Gas Optimization**: Designed to minimize gas costs through efficient storage and logic.

## Security Features

The contract incorporates industry-standard security practices to ensure robustness:

- **Reentrancy Protection**: Uses OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks during fund transfers.
- **Safe Math**: Employs `SafeMath` for arithmetic operations to avoid overflows and underflows.
- **Access Control**: Leverages OpenZeppelin's `Ownable` to restrict sensitive functions (e.g., updating arbiter or fees) to the contract owner.
- **Pausable Mechanism**: Includes OpenZeppelin's `Pausable` for emergency stops in case of vulnerabilities or attacks.
- **Input Validation**: Checks all inputs (e.g., addresses, amounts, timeouts) to prevent invalid transactions.
- **Restricted ETH Transfers**: Uses a reverting `receive()` function to prevent accidental ETH deposits outside the `createTransaction` function.
- **Timeout Constraints**: Enforces minimum (1 hour) and maximum (30 days) timeouts to balance usability and security.
- **Event Transparency**: Emits detailed events for all critical actions, enabling off-chain monitoring and auditing.

The contract has been designed with reference to battle-tested OpenZeppelin libraries, which are widely used in production Ethereum contracts. However, it is recommended to conduct a professional security audit before mainnet deployment to ensure no edge cases are overlooked.

## Prerequisites

- **Solidity Version**: ^0.8.20
- **Dependencies**: OpenZeppelin Contracts (`@openzeppelin/contracts`)
- **Tools**: Hardhat, Truffle, or Remix for compilation and deployment
- **Network**: Compatible with Ethereum mainnet or testnets (e.g., Sepolia)
- **Node.js**: For installing dependencies (if using Hardhat/Truffle)

## Installation

1. **Install OpenZeppelin Contracts**:
   ```bash
   npm install @openzeppelin/contracts
   ```

2. **Create Project Structure**:
   - Place the `Escrow.sol` file in your project's `contracts` directory.
   - Ensure your development environment (e.g., Hardhat) is set up.

3. **Compile the Contract**:
   Using Hardhat:
   ```bash
   npx hardhat compile
   ```

## Deployment

1. **Configure Deployment Parameters**:
   - `arbiter`: Address of the trusted dispute resolver.
   - `feeBps`: Fee in basis points (e.g., 100 for 1%, max 1000 for 10%).
   - `feeRecipient`: Address to receive fees.

2. **Deploy the Contract**:
   Example using Hardhat:
   ```javascript
   const Escrow = await ethers.getContractFactory("Escrow");
   const escrow = await Escrow.deploy(
       "0xArbiterAddress",
       100, // 1% fee
       "0xFeeRecipientAddress"
   );
   await escrow.deployed();
   console.log("Escrow deployed to:", escrow.address);
   ```

3. **Test on a Testnet**:
   - Deploy to a testnet like Sepolia to verify functionality.
   - Use tools like MetaMask or Hardhat for interaction.

## Usage

### Creating a Transaction
- **Function**: `createTransaction(address payable _seller, uint256 _timeoutSeconds)`
- **Caller**: Buyer
- **Parameters**:
  - `_seller`: Seller's address.
  - `_timeoutSeconds`: Timeout period (1 hour to 30 days).
- **ETH**: Send the transaction amount with the call.
- **Returns**: Transaction ID.
- **Example**:
  ```javascript
  const tx = await escrow.createTransaction(sellerAddress, 86400, { value: ethers.utils.parseEther("1.0") });
  ```

### Approving a Transaction
- **Function**: `approveTransaction(uint256 transactionId)`
- **Caller**: Buyer or Seller
- **Behavior**: Marks approval for the caller. If both approve, funds are released to the seller (minus fees).
- **Example**:
  ```javascript
  await escrow.approveTransaction(1);
  ```

### Refunding a Transaction
- **Function**: `refundTransaction(uint256 transactionId)`
- **Caller**: Buyer, Seller (after timeout), or Arbiter
- **Behavior**: Refunds the buyer if the timeout is reached or arbiter initiates.
- **Example**:
  ```javascript
  await escrow.refundTransaction(1);
  ```

### Disputing a Transaction
- **Function**: `disputeTransaction(uint256 transactionId)`
- **Caller**: Buyer or Seller
- **Behavior**: Marks the transaction as disputed, allowing arbiter intervention.
- **Example**:
  ```javascript
  await escrow.disputeTransaction(1);
  ```

### Resolving a Dispute
- **Function**: `resolveDispute(uint256 transactionId, bool approveSeller)`
- **Caller**: Arbiter
- **Parameters**:
  - `approveSeller`: `true` to release funds to seller, `false` to refund buyer.
- **Example**:
  ```javascript
  await escrow.resolveDispute(1, true); // Release to seller
  ```

### Cancelling a Transaction
- **Function**: `cancelTransaction(uint256 transactionId)`
- **Caller**: Buyer or Seller
- **Behavior**: Cancels and refunds if no approvals have been made.
- **Example**:
  ```javascript
  await escrow.cancelTransaction(1);
  ```

### Administrative Functions
- **Update Arbiter**: `updateArbiter(address _newArbiter)` (Owner only)
- **Update Fee**: `updateFee(uint256 _newFeeBps)` (Owner only)
- **Update Fee Recipient**: `updateFeeRecipient(address payable _newFeeRecipient)` (Owner only)
- **Pause/Unpause**: `pause()` / `unpause()` (Owner only)
- **Emergency Withdraw**: `emergencyWithdraw(address payable recipient, uint256 amount)` (Owner only)

## Gas Optimization

- **Efficient Storage**: Uses `mapping` for transactions, avoiding arrays to minimize gas costs.
- **Minimal State Changes**: Reduces storage operations by using boolean flags and enums.
- **No Loops**: Avoids iterative operations to keep gas usage predictable.
- **Basis Points for Fees**: Simplifies fee calculations without floating-point arithmetic.
- **Early Validation**: Reverts early on invalid inputs to save gas.

## Testing

1. **Write Tests**:
   - Test all functions, including edge cases (e.g., timeouts, disputes, pauses).
   - Use Hardhat or Truffle for test suites.
   - Example test cases:
     - Transaction creation and approval.
     - Dispute and resolution scenarios.
     - Timeout and refund flows.
     - Access control (e.g., unauthorized calls).

2. **Run Tests**:
   ```bash
   npx hardhat test
   ```

3. **Coverage**:
   - Aim for 100% test coverage using tools like `solidity-coverage`.

## Security Recommendations

- **Audit**: Engage a professional auditing firm (e.g., OpenZeppelin, ConsenSys) to review the contract before mainnet deployment.
- **Test Edge Cases**: Simulate failures (e.g., low gas, reentrancy attempts).
- **Monitor Events**: Use off-chain tools to track contract events for suspicious activity.
- **Secure Arbiter**: Ensure the arbiter's private key is stored securely.
- **Mainnet Deployment**: Deploy on a testnet first and verify all functionality.

## Limitations

- **Single Arbiter**: Relies on a single trusted arbiter for dispute resolution. Consider multi-sig arbiters for decentralization.
- **ETH Only**: Supports only ETH transactions. ERC20 support would require additional logic.
- **Gas Costs**: While optimized, high-frequency usage may still incur significant gas costs on mainnet.

## License

MIT License. See the `SPDX-License-Identifier` in the contract.

## Contributing

Contributions are welcome! Please:
1. Fork the repository.
2. Create a feature branch.
3. Submit a pull request with detailed descriptions and tests.

## Contact

For questions or support, contact the contract owner or raise an issue in the repository.