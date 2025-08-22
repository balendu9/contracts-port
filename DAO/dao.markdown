# DAO Smart Contract

## About the Project

This DAO (Decentralized Autonomous Organization) smart contract is designed to facilitate decentralized governance for organizations or communities on the Ethereum blockchain. It allows token holders to propose, vote on, and execute proposals in a secure, transparent, and efficient manner. The contract is built with scalability, security, and gas optimization in mind, leveraging OpenZeppelin's battle-tested libraries. It is intended for production use but should be thoroughly tested and audited for specific use cases.

The contract assumes the use of an ERC20 governance token to determine voting power. It supports a wide range of governance actions, such as executing contract calls, transferring funds, or updating DAO parameters.

## Features

- **Proposal Creation**: Token holders with sufficient tokens (above the proposal threshold) can create proposals with customizable voting periods, specifying target contracts, ETH values, and function calls.
- **Voting System**: Token holders can vote for or against proposals, with voting power proportional to their token balance at the time of voting.
- **Quorum and Thresholds**: Configurable minimum quorum (in basis points) ensures sufficient participation, and a proposal threshold ensures only significant stakeholders can propose.
- **Timelock Execution**: Proposals that pass must wait for a configurable delay before execution, allowing time for review and preventing flash attacks.
- **Security Measures**:
  - Reentrancy protection using OpenZeppelin's `ReentrancyGuard`.
  - Pausable functionality for emergency stops.
  - Input validation to prevent invalid proposals or votes.
  - Access control via `Ownable` for administrative functions.
- **Gas Optimization**: Uses `SafeMath` for arithmetic operations, efficient data structures, and minimal state changes to reduce gas costs.
- **Upgradability**: Implements the UUPS (Universal Upgradeable Proxy Standard) pattern, allowing the contract to be upgraded by the owner while preserving state.
- **Event Emission**: Emits events for proposal creation, voting, execution, cancellation, and parameter updates for transparency and off-chain tracking.
- **ETH Handling**: Supports receiving ETH for proposals that involve fund transfers.
- **Configurable Parameters**: The owner can update the minimum quorum, voting period, proposal threshold, and execution delay.

## Prerequisites

- **Solidity Compiler**: Version `^0.8.20`.
- **OpenZeppelin Contracts**: The contract depends on `@openzeppelin/contracts-upgradeable` (version compatible with Solidity `^0.8.20`).
- **Governance Token**: An ERC20 token contract deployed on the Ethereum network for voting power.
- **Ethereum Wallet**: A wallet (e.g., MetaMask) with ETH for deployment and testing.
- **Remix IDE**: For compiling, deploying, and interacting with the contract.

## Using the DAO Contract with Remix

### Step 1: Set Up Remix
1. Open [Remix IDE](https://remix.ethereum.org) in your browser.
2. Connect your Ethereum wallet (e.g., MetaMask) to Remix and ensure it has ETH for gas fees.
3. Select the network you want to deploy to (e.g., Sepolia testnet for testing or Ethereum mainnet for production).

### Step 2: Import Dependencies
1. In Remix, create a new folder (e.g., `DAO`).
2. Create a new file named `DAO.sol` and paste the DAO smart contract code.
3. Remix will automatically fetch OpenZeppelin dependencies via the `@openzeppelin` imports from npm. Ensure you have an internet connection.

### Step 3: Compile the Contract
1. In the Remix sidebar, go to the **Solidity Compiler** tab.
2. Select compiler version `0.8.20` (or a compatible version).
3. Enable **Auto-compile** or click **Compile DAO.sol**. Ensure there are no compilation errors.

### Step 4: Deploy the Contract
1. Go to the **Deploy & Run Transactions** tab in Remix.
2. Select **Injected Provider - MetaMask** as the environment to connect to your wallet.
3. Since the contract uses a UUPS proxy, you need to deploy it via a proxy. Follow these steps:
   - In the **Contract** dropdown, select `DAO`.
   - Click **Deploy** with the following constructor parameters (example values):
     - `_governanceToken`: Address of the deployed ERC20 governance token (e.g., `0x...`).
     - `_minQuorum`: Minimum quorum in basis points (e.g., `1000` for 10%).
     - `_minVotingPeriod`: Minimum voting period in seconds (e.g., `86400` for 1 day).
     - `_proposalThreshold`: Minimum tokens to propose (e.g., `1000000000000000000` for 1 token with 18 decimals).
     - `_executionDelay`: Delay before execution in seconds (e.g., `172800` for 2 days).
   - Remix does not natively support UUPS proxy deployment, so deploy the implementation contract first and then use a proxy contract (e.g., OpenZeppelin's `ERC1967Proxy`):
     1. Deploy `DAO.sol` to get the implementation address.
     2. Create a new file for the proxy contract (e.g., `Proxy.sol`):
        ```solidity
        pragma solidity ^0.8.20;
        import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
        ```
     3. Deploy `ERC1967Proxy` with:
        - `logic`: The address of the deployed `DAO` implementation.
        - `data`: The encoded `initialize` function call. Use Remix's **Encode** feature to encode `initialize` with the parameters above.
     4. Send the transaction via MetaMask.
4. After deployment, note the proxy contract address. This is the address you'll interact with.

### Step 5: Interact with the Contract
1. In Remix, select the deployed proxy contract under **Deployed Contracts**.
2. **Create a Proposal**:
   - Call `propose` with:
     - `targets`: Array of target contract addresses (e.g., `["0x..."]`).
     - `values`: Array of ETH values (e.g., `[0]` for no ETH).
     - `calldatas`: Array of encoded function calls (use Remix's **Encode** feature or a tool like `web3.js` to encode).
     - `description`: A string describing the proposal (e.g., `"Increase quorum to 15%"`).
     - `votingPeriod`: Duration in seconds (e.g., `86400` for 1 day).
   - Ensure the caller has enough governance tokens (`proposalThreshold`).
3. **Vote on a Proposal**:
   - Call `vote` with:
     - `proposalId`: The ID returned from `propose`.
     - `support`: `true` for a "for" vote, `false` for an "against" vote.
   - Ensure the caller has governance tokens and hasn't voted yet.
4. **Execute a Proposal**:
   - After the voting period and execution delay, call `execute` with the `proposalId`.
   - Ensure the proposal has passed (use `hasPassed` to check).
5. **Administrative Functions** (only callable by the owner):
   - Update parameters (`setMinQuorum`, `setMinVotingPeriod`, `setProposalThreshold`, `setExecutionDelay`).
   - Pause/unpause the contract (`pause`, `unpause`).
   - Upgrade the contract by deploying a new implementation and calling `_authorizeUpgrade` (via a proxy admin interface).

### Step 6: Test Thoroughly
- Use a testnet (e.g., Sepolia) to test all functions, including edge cases (e.g., voting with zero tokens, executing before delay, or reentrancy attempts).
- Verify events are emitted correctly using Remix's **Logs** or an Ethereum explorer.
- Test with multiple accounts to simulate real-world governance scenarios.

### Step 7: Deploy to Mainnet (Production)
- After testing, deploy to the Ethereum mainnet following the same steps.
- Ensure the governance token contract is audited and secure.
- Conduct a professional security audit of the DAO contract before mainnet deployment.

## Security Considerations
- **Audits**: Always conduct a professional security audit before deploying to mainnet.
- **Testing**: Use tools like Hardhat, Foundry, or Truffle to write comprehensive unit and integration tests.
- **Timelock**: The execution delay prevents immediate execution, giving the community time to react to malicious proposals.
- **Emergency Pause**: The owner can pause the contract in case of vulnerabilities.
- **Upgradability**: The UUPS pattern allows fixes and improvements, but upgrades must be carefully managed by the owner.
- **Reentrancy**: Protected by `ReentrancyGuard`, but ensure external contracts called in proposals are trusted.

## Limitations
- The contract relies on the governance token's security and correctness.
- Complex proposals with many targets or large calldata may incur higher gas costs.
- Upgradability introduces centralization risks (owner-controlled upgrades).
- The owner has significant control over parameters and pausing, which may not suit fully decentralized DAOs.

## Future Improvements
- Add support for delegated voting.
- Implement snapshot-based voting to prevent token transfers during voting.
- Include a treasury management system for more complex fund allocation.
- Add role-based access control for more granular administration.

## License
This project is licensed under the MIT License.