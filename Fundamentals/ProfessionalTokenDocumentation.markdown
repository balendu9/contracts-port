# ProfessionalToken Smart Contract Documentation

## Overview

The `ProfessionalToken` is a Solidity smart contract implementing a professional-grade ERC-20 token based on OpenZeppelin v5.x. It extends the standard ERC-20 functionality with advanced features such as minting with a hard cap, burning, pausing, role-based access control, EIP-2612 permit for gasless approvals, address blocklisting, and rescue functions for stuck assets. This contract is designed for security, flexibility, and administrative control, making it suitable for enterprise-grade token deployments.

## Features

The `ProfessionalToken` contract includes the following features:

1. **ERC-20 Compliance**: Fully compliant with the ERC-20 standard, supporting `transfer`, `approve`, `transferFrom`, and other standard functions.
2. **Minting with Hard Cap**: Allows authorized minters to create new tokens up to a predefined hard cap (1 billion tokens with 18 decimals).
3. **Burning**: Token holders can burn their own tokens, and approved spenders can burn tokens on behalf of others via allowances.
4. **Pausing**: Authorized pausers can pause and unpause token transfers to handle emergencies or maintenance.
5. **Role-Based Access Control**: Uses OpenZeppelin's `AccessControl` to manage permissions for minting, pausing, blocklist management, and asset rescue.
6. **EIP-2612 Permit**: Supports gasless approvals through off-chain signatures, enabling users to approve token spending without on-chain transactions.
7. **Address Blocklist**: Allows authorized managers to block specific addresses from sending or receiving tokens, useful for compliance or security purposes.
8. **Rescue Functions**: Enables authorized rescuers to recover stuck ERC-20 tokens or ETH accidentally sent to the contract.
9. **Reentrancy Protection**: Incorporates `ReentrancyGuard` to prevent reentrancy attacks during minting and rescue operations.
10. **SafeERC20 Integration**: Uses `SafeERC20` for secure interaction with external ERC-20 tokens during rescue operations, handling non-standard tokens safely.

## Contract Structure

The contract inherits from multiple OpenZeppelin contracts to provide its functionality:

- **ERC20**: Core ERC-20 functionality (e.g., `transfer`, `approve`, `balanceOf`).
- **ERC20Burnable**: Adds `burn` and `burnFrom` functions for token destruction.
- **ERC20Pausable**: Enables pausing/unpausing of token transfers.
- **ERC20Permit**: Implements EIP-2612 for gasless approvals via the `permit` function.
- **AccessControl**: Manages role-based permissions for administrative actions.
- **ReentrancyGuard**: Prevents reentrancy attacks in critical functions.
- **SafeERC20**: Ensures safe handling of external ERC-20 tokens during rescue operations.

### Key Components

- **Roles**:
  - `DEFAULT_ADMIN_ROLE`: Grants full administrative control, including role management.
  - `MINTER_ROLE`: Allows minting new tokens.
  - `PAUSER_ROLE`: Permits pausing and unpausing the contract.
  - `BLOCKLIST_MANAGER_ROLE`: Manages the blocklist for restricting addresses.
  - `RESCUER_ROLE`: Authorizes rescue of stuck assets.

- **Hard Cap**: Set to 1 billion tokens (1,000,000,000 * 10^18), enforced during minting to prevent exceeding the total supply.

- **Blocklist**: A mapping that tracks blocked addresses, preventing them from sending or receiving tokens.

- **Events**:
  - `AddressBlocked(address)`: Emitted when an address is added to the blocklist.
  - `AddressUnblocked(address)`: Emitted when an address is removed polyphenols the blocklist.
  - `TokensRescued(address, address, uint256)`: Emitted when tokens are rescued.
  - `ETHRescued(address, uint256)`: Emitted when ETH is rescued.

## How It Works

### Initialization
The contract is initialized via the constructor, which takes:
- `name`: The token's name (e.g., "Professional Token").
- `symbol`: The token's symbol (e.g., "PRO").
- `defaultAdmin`: The address granted all roles (`DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, `PAUSER_ROLE`, `BLOCKLIST_MANAGER_ROLE`, `RESCUER_ROLE`).

The constructor initializes the `ERC20` and `ERC20Permit` contracts with the provided name and symbol, and assigns roles to the `defaultAdmin`.

### Minting
- **Function**: `mint(address to, uint256 amount)`
- **Access**: Restricted to `MINTER_ROLE`.
- **Behavior**: Mints `amount` tokens to the specified `to` address, ensuring the total supply does not exceed the `HARD_CAP`. Protected by `nonReentrant` to prevent reentrancy attacks.
- **Condition**: Only works when the contract is not paused.

### Burning
- **Functions**:
  - `burn(uint256 amount)`: Allows a token holder to burn their own tokens.
  - `burnFrom(address account, uint256 amount)`: Allows an approved spender to burn tokens from `account` using their allowance.
- **Behavior**: Reduces the total supply and updates balances accordingly.

### Pausing
- **Functions**:
  - `pause()`: Pauses all token transfers, restricted to `PAUSER_ROLE`.
  - `unpause()`: Resumes token transfers, restricted to `PAUSER_ROLE`.
- **Behavior**: When paused, all transfer-related functions (`transfer`, `transferFrom`, `mint`, etc.) are disabled.

### Blocklist Management
- **Functions**:
  - `blockAddress(address account)`: Adds `account` to the blocklist, restricted to `BLOCKLIST_MANAGER_ROLE`.
  - `unblockAddress(address account)`: Removes `account` from the blocklist, restricted to `BLOCKLIST_MANAGER_ROLE`.
  - `isBlocked(address account)`: View function to check if an address is blocked.
- **Behavior**: Blocked addresses cannot send or receive tokens. The check is enforced in the `_update` function, which overrides the core ERC-20 transfer logic.

### EIP-2612 Permit
- **Function**: `permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)`
- **Behavior**: Allows `owner` to approve `spender` to spend `value` tokens via an off-chain signature, valid until `deadline`. Uses EIP-712 typed data signing for security and includes nonce-based replay protection.
- **Usage**: Users sign a permit message off-chain (e.g., using ethers.js) and submit it to the contract, enabling gasless approvals.

### Rescue Functions
- **Functions**:
  - `rescueTokens(address token, address to, uint256 amount)`: Rescues `amount` of an external ERC-20 `token` to the `to` address, using `SafeERC20.safeTransfer` for safety.
  - `rescueETH(address payable to)`: Rescues all ETH held by the contract to the `to` address.
- **Access**: Restricted to `RESCUER_ROLE`.
- **Behavior**: Prevents rescuing the contract's own tokens and ensures safe transfers. Protected by `nonReentrant`.

### Reentrancy Protection
- **Modifier**: `nonReentrant`
- **Applied To**: `mint`, `rescueTokens`, and `rescueETH` functions to prevent reentrancy attacks.

### ETH Handling
- **Receive Function**: Reverts direct ETH transfers to prevent accidental deposits, ensuring only intentional ETH rescue is possible.

## Usage Example

### Deploying the Contract
```solidity
ProfessionalToken token = new ProfessionalToken("Professional Token", "PRO", msg.sender);
```

### Minting Tokens
```solidity
// Admin (with MINTER_ROLE) mints 1000 tokens to a user
token.mint(userAddress, 1000 * 10**18);
```

### Using Permit for Gasless Approval
```javascript
// JavaScript (ethers.js) example for generating a permit signature
const domain = {
    name: await token.name(),
    version: "1",
    chainId: network.chainId,
    verifyingContract: token.address,
};
const types = {
    Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "value", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
    ],
};
const message = {
    owner: owner.address,
    spender: spender.address,
    value: ethers.utils.parseEther("100"),
    nonce: await token.nonces(owner.address),
    deadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
};
const signature = await owner._signTypedData(domain, types, message);
const { v, r, s } = ethers.utils.splitSignature(signature);
await token.permit(owner.address, spender.address, ethers.utils.parseEther("100"), deadline, v, r, s);
```

### Blocking an Address
```solidity
// Admin (with BLOCKLIST_MANAGER_ROLE) blocks an address
token.blockAddress(maliciousAddress);
```

### Rescuing Stuck Tokens
```solidity
// Admin (with RESCUER_ROLE) rescues 100 USDT stuck in the contract
token.rescueTokens(usdtAddress, adminAddress, 100 * 10**6); // Assuming USDT has 6 decimals
```

## Security Considerations

- **Role Management**: Use `AccessControl` to carefully assign and revoke roles. Avoid granting `DEFAULT_ADMIN_ROLE` to untrusted addresses.
- **Blocklist**: Ensure blocklist management complies with legal and regulatory requirements, as blocking addresses may have compliance implications.
- **Rescue Functions**: Only trusted addresses should have `RESCUER_ROLE` to prevent misuse.
- **Hard Cap**: The 1 billion token cap is immutable; ensure it aligns with your tokenomics.
- **Testing**: Thoroughly test the `permit` function, blocklist enforcement, and rescue functions in a test environment (e.g., Hardhat or Foundry) to ensure correct behavior.

## Dependencies

The contract relies on OpenZeppelin v5.x contracts:
- `@openzeppelin/contracts/token/ERC20/ERC20.sol`
- `@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol`
- `@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol`
- `@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol`
- `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol`
- `@openzeppelin/contracts/access/AccessControl.sol`
- `@openzeppelin/contracts/utils/ReentrancyGuard.sol`

Ensure these are installed via npm:
```bash
npm install @openzeppelin/contracts
```

## Conclusion

The `ProfessionalToken` contract is a robust, secure, and feature-rich ERC-20 token implementation suitable for professional use cases. Its modular design, leveraging OpenZeppelin's audited contracts, ensures reliability, while features like EIP-2612, blocklisting, and rescue functions provide flexibility and administrative control. Deployers should carefully manage roles and test the contract thoroughly before deployment.