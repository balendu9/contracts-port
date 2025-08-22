# Quadratic Voting Smart Contract

## Overview
This Quadratic Voting smart contract, written in Solidity, enables a democratic voting system where votes have a quadratic cost (votes^2) to ensure fairer representation of preferences. It is designed for Ethereum-based blockchains, focusing on security, gas efficiency, and scalability for production use. The contract allows users to create proposals, distribute voting credits, cast votes, and determine the winning proposal after a voting period.

## Features
- **Quadratic Voting Mechanism**: Voters spend credits quadratically (cost = votes^2) to express preference intensity, balancing influence and fairness.
- **Proposal Management**: Owners can create, deactivate, and manage proposals with descriptive text.
- **Credit System**: Owners distribute voting credits (up to 100 per voter) to eligible participants.
- **Secure Voting**: Includes reentrancy protection, input validation, and safe arithmetic using OpenZeppelin's SafeMath.
- **Access Control**: Utilizes OpenZeppelin's Ownable for restricted administrative functions (e.g., proposal creation, credit distribution).
- **Pausable**: Emergency pause/unpause functionality to halt voting if needed.
- **Time-Bound Voting**: Configurable voting period (default: 7 days) with the ability to extend.
- **Transparency**: Emits events for proposal creation, voting, credit distribution, and voting end for easy tracking.
- **Voter History**: Tracks individual voter credits and votes per proposal for accountability.
- **Gas Optimization**: Efficient storage with structs and mappings, minimal state changes, and view functions for read-only queries.
- **Scalability**: Supports multiple proposals and voters with no hardcoded limits (within gas constraints).

## Prerequisites
- Ethereum wallet (e.g., MetaMask) with testnet/mainnet ETH.
- Access to Remix IDE (https://remix.ethereum.org).
- Basic understanding of Solidity and Ethereum smart contracts.

## How to Use with Remix

### Step 1: Set Up Remix
1. Open [Remix IDE](https://remix.ethereum.org) in your browser.
2. Create a new file named `QuadraticVoting.sol` in the Remix file explorer.
3. Copy and paste the contract code from `QuadraticVoting.sol` into this file.

### Step 2: Install Dependencies
The contract uses OpenZeppelin libraries. Import them in Remix:
1. In the Remix file explorer, create a new folder (e.g., `openzeppelin`).
2. Use Remix's "Import from GitHub" feature to import the following OpenZeppelin contracts (version 5.x or compatible with Solidity ^0.8.24):
   - `@openzeppelin/contracts/access/Ownable.sol`
   - `@openzeppelin/contracts/utils/ReentrancyGuard.sol`
   - `@openzeppelin/contracts/utils/math/SafeMath.sol`
   - `@openzeppelin/contracts/security/Pausable.sol`
   Alternatively, Remix will automatically resolve these dependencies during compilation if connected to the internet.

### Step 3: Compile the Contract
1. Navigate to the **Solidity Compiler** tab in Remix.
2. Select Solidity version `0.8.24` (or compatible version).
3. Click **Compile QuadraticVoting.sol**. Ensure no errors appear.

### Step 4: Deploy the Contract
1. Go to the **Deploy & Run Transactions** tab in Remix.
2. Connect your MetaMask wallet to Remix and select the desired network (e.g., Sepolia testnet for testing).
3. Select `QuadraticVoting` from the contract dropdown.
4. Click **Deploy**. Confirm the transaction in MetaMask.
5. Note the deployed contract address in Remix.

### Step 5: Interact with the Contract
1. **Distribute Credits**:
   - As the contract owner, call `distributeCredits(address _voter, uint256 _credits)` to assign credits to voters (e.g., 100 credits max per voter).
   - Example: `distributeCredits("0xVoterAddress", 50)`.
2. **Create Proposals**:
   - Call `createProposal(string _description)` to add a new proposal.
   - Example: `createProposal("Increase community funding")`.
3. **Vote**:
   - As a voter, call `vote(uint256 _proposalId, uint256 _votes)` to cast votes on a proposal.
   - Example: `vote(0, 5)` (costs 25 credits, as 5^2 = 25).
4. **Check Results**:
   - After the voting period (7 days by default), call `getWinningProposal()` to retrieve the winning proposal's ID, description, and vote count.
5. **Manage Voting**:
   - Use `pause()` or `unpause()` for emergency control.
   - Use `extendVotingPeriod(uint256 _additionalTime)` to extend voting (e.g., `extendVotingPeriod(86400)` for 1 day).
   - Use `deactivateProposal(uint256 _proposalId)` to remove a proposal from voting.

### Step 6: Test and Deploy to Mainnet
- **Testing**: Use Remix's JavaScript VM or a testnet (e.g., Sepolia) to test all functions, including edge cases (e.g., insufficient credits, invalid proposal IDs).
- **Mainnet Deployment**: Once tested, deploy to Ethereum mainnet using sufficient ETH for gas fees. Verify the contract on Etherscan for transparency.

## Security Considerations
- The contract uses OpenZeppelin's battle-tested libraries for security.
- Non-reentrant functions prevent reentrancy attacks.
- Input validations ensure safe operations (e.g., credit limits, valid proposal IDs).
- For production, conduct thorough testing and consider a professional security audit.
- Monitor events for real-time tracking of contract activity.

## Limitations
- Gas costs may increase with many proposals or voters; optimize by limiting active proposals.
- Quadratic voting requires voters to understand the credit system to participate effectively.
- The contract assumes a trusted owner for credit distribution and proposal management.

## License
This project is licensed under the MIT License.