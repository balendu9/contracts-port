# TimelockMultisig Contract

## Overview

The `TimelockMultisig` contract is a secure, gas-optimized, and production-ready multisignature (multisig) wallet with a timelock feature, implemented in Solidity (`^0.8.24`). It allows a group of owners to propose, confirm, and execute transactions (ETH transfers or contract calls) after a specified timelock delay, ensuring a threshold of owner confirmations is met. The contract is designed for high scalability, battle-tested security patterns, and gas efficiency, making it suitable for decentralized governance, treasury management, or other use cases requiring secure multi-party approval.

### Key Features
- **Multisig Approval**: Transactions require a predefined number of owner confirmations (threshold).
- **Timelock Delay**: Confirmed transactions are locked until the timelock period expires, enhancing security.
- **Security**: Includes reentrancy protection, no self-destruct or delegatecall, and immutable threshold/delay.
- **Gas Optimization**: Uses `EnumerableSet` for O(1) operations, `calldata` for inputs, and minimal storage writes.
- **Scalability**: Supports up to hundreds of owners efficiently.
- **Transparency**: Emits events for all actions and provides getter functions for transaction details.

## How It Works

### Core Components
- **Owners**: A set of addresses (managed via `EnumerableSet.AddressSet`) authorized to propose and confirm transactions.
- **Threshold**: The minimum number of confirmations required to approve a transaction (set at deployment).
- **Timelock Delay**: A delay (in seconds) before a confirmed transaction can be executed.
- **Transactions**: Stored in a mapping, each transaction includes:
  - Target address (`to`)
  - ETH value (`value`)
  - Call data (`data`)
  - Earliest execution timestamp (`eta`)
  - Execution status (`executed`)
  - Set of confirmers (`confirmers`)

### Workflow
1. **Propose Transaction**: An owner calls `proposeTransaction(to, value, data)` to propose a transaction. The proposer auto-confirms it.
2. **Confirm Transaction**: Other owners call `confirmTransaction(txId)` to add their confirmation. Once the threshold is reached, the transaction's `eta` is set to `block.timestamp + delay`.
3. **Execute Transaction**: After the timelock expires (`block.timestamp >= eta`), any owner can call `executeTransaction(txId)` to execute the transaction.
4. **Querying**: Use `getTransaction(txId)`, `getTransactionConfirmers(txId)`, `getConfirmationCount(txId)`, and `getOwners()` to view transaction and owner details.

### Security Features
- **Immutable Parameters**: `threshold` and `delay` are immutable to prevent runtime changes.
- **Reentrancy Protection**: State updates (e.g., `executed = true`) occur before external calls.
- **No Dangerous Operations**: Avoids `selfdestruct` and `delegatecall` to prevent exploits.
- **Access Control**: Only owners can propose, confirm, or execute transactions.
- **Event Emission**: All state changes emit events for off-chain tracking.

### Gas Optimizations
- Uses `EnumerableSet` for efficient owner and confirmer management.
- Employs `calldata` for input data to reduce gas costs.
- Minimizes storage writes by updating only necessary fields.
- Avoids loops in favor of set-based operations.

## Using the Contract in Remix

### Prerequisites
- **Remix IDE**: Access Remix at [remix.ethereum.org](https://remix.ethereum.org).
- **MetaMask**: Install MetaMask and connect it to a testnet (e.g., Sepolia) with test ETH.
- **OpenZeppelin Dependency**: The contract uses OpenZeppelin's `EnumerableSet` library.

### Step-by-Step Guide

1. **Set Up Remix Environment**
   - Open Remix IDE in your browser.
   - In the **File Explorer**, create a new file named `TimelockMultisig.sol`.
   - Copy and paste the contract code into this file.

2. **Import OpenZeppelin Dependency**
   - The contract requires `@openzeppelin/contracts/utils/structs/EnumerableSet.sol`.
   - In Remix, go to the **File Explorer**, create a new folder (e.g., `openzeppelin`), and import the `EnumerableSet.sol` file using:
     ```solidity
     import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v5.0/contracts/utils/structs/EnumerableSet.sol";
     ```
     Alternatively, Remix will automatically resolve the import if you enable the **Auto-import** feature.

3. **Compile the Contract**
   - Go to the **Solidity Compiler** tab.
   - Select compiler version `0.8.24` (or compatible `^0.8.24`).
   - Enable **Auto-compile** or click **Compile TimelockMultisig.sol**.
   - Ensure no compilation errors appear.

4. **Deploy the Contract**
   - Go to the **Deploy & Run Transactions** tab.
   - Select **Injected Provider - MetaMask** as the environment and connect MetaMask.
   - In the **Deploy** section, enter constructor parameters:
     - `initialOwners`: An array of owner addresses (e.g., `["0xOwner1", "0xOwner2", "0xOwner3"]`).
     - `requiredThreshold`: Number of required confirmations (e.g., `2` for 2-of-3 multisig).
     - `timelockDelay`: Delay in seconds (e.g., `86400` for 1 day).
   - Click **Deploy** and confirm the transaction in MetaMask.

5. **Interact with the Contract**
   - **Propose a Transaction**:
     - Call `proposeTransaction(to, value, data)` with:
       - `to`: Target address (e.g., a recipient or contract).
       - `value`: ETH amount in wei (e.g., `1000000000000000000` for 1 ETH).
       - `data`: Call data (e.g., `0x` for simple ETH transfer, or encoded function call for contract interaction).
       - Example: Propose sending 1 ETH to `0xRecipient` with `proposeTransaction("0xRecipient", 1000000000000000000, "0x")`.
     - Note the returned `txId` from the transaction logs.
   - **Confirm a Transaction**:
     - Other owners call `confirmTransaction(txId)` using the `txId` from the proposal.
     - Once `threshold` confirmations are reached, the `eta` is set.
   - **Execute a Transaction**:
     - After the timelock expires (check `eta` via `getTransaction(txId)`), call `executeTransaction(txId)`.
   - **Query Details**:
     - Use `getTransaction(txId)` to view transaction details.
     - Use `getTransactionConfirmers(txId)` to see who confirmed.
     - Use `getOwners()` to list all owners.

6. **Test the Contract**
   - Use multiple MetaMask accounts to simulate different owners.
   - Test edge cases:
     - Propose with invalid `to` (should revert).
     - Confirm twice by the same owner (should revert).
     - Execute before timelock expires (should revert).
     - Execute with insufficient confirmations (should revert).
   - Send ETH to the contract (via `payable` receive function) to test ETH transfers.

7. **Verify and Deploy to Mainnet**
   - For testnets or mainnet, deploy using Remix and verify the contract on Etherscan:
     - Copy the deployed contract address.
     - Use Etherscan's **Verify and Publish** feature, pasting the contract code and constructor arguments.
   - Recommended: Conduct a professional audit before mainnet deployment.

### Example Usage
- Deploy with 3 owners, threshold of 2, and 1-day timelock:
  ```solidity
  constructor(["0xOwner1", "0xOwner2", "0xOwner3"], 2, 86400)
  ```
- Propose sending 1 ETH:
  - Owner1 calls `proposeTransaction("0xRecipient", 1000000000000000000, "0x")` → `txId = 1`.
- Confirm:
  - Owner2 calls `confirmTransaction(1)` → `eta` set to `block.timestamp + 86400`.
- Execute:
  - After 1 day, Owner1 calls `executeTransaction(1)` → 1 ETH sent to `0xRecipient`.

## Notes
- **Security**: Never deploy without testing and auditing. Use Remix's **Solidity Unit Testing** plugin for automated tests.
- **Gas Costs**: Gas usage scales with the number of confirmers. Suitable for small to medium owner groups (<100).
- **Extensions**: Add owner management (e.g., `addOwner`, `removeOwner`) via multisig-executed transactions if needed.
- **Dependencies**: Ensure OpenZeppelin contracts are accessible (Remix handles this automatically for GitHub imports).

## License
This contract is licensed under the MIT License, as specified in the SPDX header.