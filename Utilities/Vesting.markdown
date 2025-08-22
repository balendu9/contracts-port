# Vesting Contract

## Overview

The Vesting Contract is a secure, gas-optimized, and production-ready Solidity smart contract designed for managing token vesting schedules on Ethereum-compatible blockchains. It enables the creation of customizable vesting schedules for multiple beneficiaries, supporting linear vesting, cliff periods, and revocable grants. Built with best practices and leveraging audited OpenZeppelin libraries, the contract prioritizes security, scalability, and efficiency, making it suitable for projects requiring robust token vesting mechanisms, such as token distribution for team members, advisors, or investors.

## Properties and Capabilities

The Vesting Contract offers the following properties and functionalities, designed for flexibility, security, and efficiency:

### Properties
1. **Token Compatibility**:
   - Compatible with any ERC20-compliant token, specified during deployment via the constructor.
   - Uses an `immutable` `token` variable to tie the contract to a single token address, reducing storage costs.

2. **Vesting Schedules**:
   - Supports multiple vesting schedules per beneficiary, stored in a `mapping(address => VestingSchedule[])` for efficient access.
   - Each schedule includes:
     - `beneficiary`: Address receiving the tokens.
     - `startTime`: Timestamp when vesting begins.
     - `cliffDuration`: Initial period during which no tokens can be released.
     - `vestingDuration`: Total period over which tokens vest linearly.
     - `totalAmount`: Total tokens allocated for the schedule.
     - `releasedAmount`: Tokens already claimed by the beneficiary.
     - `revocable`: Boolean indicating if the schedule can be revoked.
     - `revoked`: Boolean indicating if the schedule has been revoked.
   - Tracks the number of schedules per beneficiary (`vestingScheduleCount`) for efficient iteration.
   - Maintains `totalTokensLocked` to ensure sufficient tokens for all vesting schedules.

3. **Security Features**:
   - Uses `SafeMath` for safe arithmetic to prevent overflows/underflows.
   - Implements `ReentrancyGuard` to protect against reentrancy attacks during token releases.
   - Follows the checks-effects-interactions pattern to minimize vulnerabilities.
   - Validates inputs (e.g., non-zero addresses, valid durations, sufficient token balance).
   - Restricts sensitive operations (e.g., schedule creation, revocation) to the contract owner via `Ownable`.
   - Includes `Pausable` for emergency pause/unpause functionality.

4. **Gas Optimization**:
   - Uses `uint256` for efficient storage and arithmetic.
   - Minimizes storage writes by updating state only when necessary.
   - Uses `immutable` for the token address to reduce gas costs.
   - Avoids unnecessary loops and complex computations in critical functions.

5. **Event Emission**:
   - Emits events for transparency and auditability:
     - `VestingScheduleCreated`: Triggered when a new schedule is created.
     - `TokensReleased`: Triggered when tokens are released to a beneficiary.
     - `VestingRevoked`: Triggered when a schedule is revoked.
     - `TokensWithdrawn`: Triggered when excess tokens are withdrawn by the owner.

### Capabilities
1. **Create Vesting Schedules**:
   - Function: `createVestingSchedule(address _beneficiary, uint256 _totalAmount, uint256 _startTime, uint256 _cliffDuration, uint256 _vestingDuration, bool _revocable)`
   - Allows the owner to create vesting schedules with customizable parameters.
   - Validates beneficiary address, token amount, start time, cliff, and vesting duration.
   - Ensures the contract has sufficient tokens before creating a schedule.
   - Emits `VestingScheduleCreated` event.

2. **Release Vested Tokens**:
   - Function: `release(uint256 _scheduleId)`
   - Allows beneficiaries to claim vested tokens based on linear vesting after the cliff period.
   - Calculates vested amount using: `totalAmount * (currentTime - startTime) / vestingDuration`.
   - Returns 0 if before the cliff or if the schedule is revoked; returns full amount if vesting is complete.
   - Updates `releasedAmount` and `totalTokensLocked`, then transfers tokens.
   - Protected by `nonReentrant` modifier.
   - Emits `TokensReleased` event.

3. **Revoke Vesting Schedules**:
   - Function: `revoke(address _beneficiary, uint256 _scheduleId)`
   - Allows the owner to revoke revocable schedules, affecting only unvested tokens.
   - Updates `totalTokensLocked` to reflect unvested tokens.
   - Emits `VestingRevoked` event.

4. **Withdraw Excess Tokens**:
   - Function: `withdrawExcessTokens(uint256 _amount)`
   - Allows the owner to withdraw unallocated tokens (not tied to vesting schedules).
   - Validates available token balance.
   - Emits `TokensWithdrawn` event.

5. **Pause/Unpause Contract**:
   - Functions: `pause()` and `unpause()`
   - Allows the owner to halt/resume state-changing operations in emergencies.
   - Uses OpenZeppelin’s `Pausable` for reliable implementation.

6. **Query Vesting Information**:
   - View Functions:
     - `getReleasableAmount(address _beneficiary, uint256 _scheduleId)`: Returns the number of tokens currently releasable.
     - `getVestingSchedule(address _beneficiary, uint256 _scheduleId)`: Returns full schedule details (beneficiary, start time, cliff, vesting duration, total amount, released amount, revocable, revoked).
   - Enables off-chain monitoring of vesting progress.

7. **Linear Vesting Calculation**:
   - Internal Function: `_calculateVestedAmount(VestingSchedule memory schedule)`
   - Computes vested tokens linearly, ensuring predictable token release.

### Use Cases
- Token distribution for team members, advisors, or investors with vesting periods.
- Controlled release of tokens in DAOs, DeFi protocols, or other token-based projects.
- Scenarios requiring revocable or non-revocable vesting for flexibility.
- Environments prioritizing security, transparency, and efficiency.

### Limitations
- Tied to a single ERC20 token (set at deployment).
- No built-in upgradability (use a proxy pattern for upgrades).
- Gas costs may increase with many schedules due to storage operations.
- Revocation only affects unvested tokens; vested tokens remain releasable.

## Prerequisites

- **Solidity Version**: `^0.8.20`
- **Dependencies**:
  - OpenZeppelin Contracts (`@openzeppelin/contracts` version 4.x or compatible)
  - An ERC20 token contract for vesting
- **Tools**:
  - Hardhat, Truffle, or Foundry for compilation and deployment
  - Node.js and npm for managing dependencies
  - Ethereum wallet (e.g., MetaMask) with sufficient ETH for gas fees
  - Access to a testnet (e.g., Sepolia) or mainnet for deployment

## Installation

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd vesting-contract
   ```

2. **Install Dependencies**:
   ```bash
   npm install @openzeppelin/contracts
   ```

3. **Set Up Development Environment**:
   Configure Hardhat or another framework. Example `hardhat.config.js`:
   ```javascript
   require("@nomicfoundation/hardhat-toolbox");

   module.exports = {
     solidity: "0.8.20",
     networks: {
       sepolia: {
         url: "YOUR_SEPOLIA_RPC_URL",
         accounts: ["YOUR_PRIVATE_KEY"]
       }
     }
   };
   ```

4. **Place the Contract**:
   Save `VestingContract.sol` in the `contracts/` directory.

## Deployment

1. **Compile the Contract**:
   ```bash
   npx hardhat compile
   ```

2. **Deploy the Contract**:
   Create a deployment script (e.g., `scripts/deploy.js`):
   ```javascript
   const hre = require("hardhat");

   async function main() {
     const tokenAddress = "YOUR_ERC20_TOKEN_ADDRESS";
     const VestingContract = await hre.ethers.getContractFactory("VestingContract");
     const vestingContract = await VestingContract.deploy(tokenAddress);
     await vestingContract.deployed();
     console.log("VestingContract deployed to:", vestingContract.address);
   }

   main().catch((error) => {
     console.error(error);
     process.exitCode = 1;
   });
   ```

   Run the script:
   ```bash
   npx hardhat run scripts/deploy.js --network sepolia
   ```

3. **Fund the Contract**:
   Transfer sufficient ERC20 tokens to the contract address to cover vesting schedules.

## Usage

### 1. Create a Vesting Schedule
**Example** (ethers.js):
```javascript
const vestingContract = await ethers.getContractAt("VestingContract", contractAddress);
await vestingContract.createVestingSchedule(
  beneficiaryAddress,
  ethers.utils.parseUnits("1000", 18), // 1000 tokens
  Math.floor(Date.now() / 1000), // Current timestamp
  31536000, // 1-year cliff
  63072000, // 2-year vesting
  true // Revocable
);
```

### 2. Release Vested Tokens
**Example**:
```javascript
await vestingContract.release(scheduleId);
```

### 3. Revoke a Schedule
**Example**:
```javascript
await vestingContract.revoke(beneficiaryAddress, scheduleId);
```

### 4. Withdraw Excess Tokens
**Example**:
```javascript
await vestingContract.withdrawExcessTokens(ethers.utils.parseUnits("500", 18));
```

### 5. Pause/Unpause Contract
**Example**:
```javascript
await vestingContract.pause(); // Pause
await vestingContract.unpause(); // Unpause
```

### 6. Query Vesting Details
**Example**:
```javascript
const releasable = await vestingContract.getReleasableAmount(beneficiaryAddress, scheduleId);
const schedule = await vestingContract.getVestingSchedule(beneficiaryAddress, scheduleId);
```

## Testing

1. **Write Tests**:
   Test cases should cover:
   - Schedule creation and event emission.
   - Token release after cliff and during vesting.
   - Revocation of revocable schedules.
   - Pause/unpause functionality.
   - Edge cases (e.g., zero amounts, invalid addresses).

2. **Run Tests**:
   ```bash
   npx hardhat test
   ```

3. **Test on Testnet**:
   Deploy to Sepolia or similar for real-world simulation.

## Security Considerations

- **Audits**: Conduct a professional security audit before mainnet deployment.
- **Access Control**: Only the owner can create schedules, revoke, pause, or withdraw tokens.
- **Token Balance**: Ensure sufficient tokens in the contract before creating schedules.
- **Reentrancy**: Protected by `ReentrancyGuard`.
- **Arithmetic Safety**: Uses `SafeMath`.
- **Emergency Pause**: Use pause functionality for vulnerabilities or attacks.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.