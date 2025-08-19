// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * Professional ERC-20 token with:
 *  - Minting (role-gated) with hard cap
 *  - Burning (self / allowance)
 *  - Pausing (role-gated)
 *  - AccessControl roles
 *  - EIP-2612 Permit (gasless approvals)
 *  - Address blocklist (send/receive) with role-gated management
 *  - Rescue functions for stuck assets
 *
 * Built on OpenZeppelin v5.x
 */ 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ProfessionalToken is ERC20, ERC20Burnable, ERC20Pausable, ERC20Permit, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BLOCKLIST_MANAGER_ROLE = keccak256("BLOCKLIST_MANAGER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");

    uint256 public constant HARD_CAP = 1_000_000_000 * 10**18; // 1 billion tokens with 18 decimals
    mapping(address => bool) private _blocklist;

    event AddressBlocked(address indexed account);
    event AddressUnblocked(address indexed account);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);
    event ETHRescued(address indexed to, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        address defaultAdmin
    ) ERC20(name, symbol) ERC20Permit(name) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(BLOCKLIST_MANAGER_ROLE, defaultAdmin);
        _grantRole(RESCUER_ROLE, defaultAdmin);
    }

    // Minting function with hard cap
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(totalSupply() + amount <= HARD_CAP, "ProfessionalToken: Exceeds hard cap");
        _mint(to, amount);
    }

    // Pausing functions
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Blocklist management
    function blockAddress(address account) external onlyRole(BLOCKLIST_MANAGER_ROLE) {
        require(account != address(0), "ProfessionalToken: Cannot block zero address");
        require(!_blocklist[account], "ProfessionalToken: Address already blocked");
        _blocklist[account] = true;
        emit AddressBlocked(account);
    }

    function unblockAddress(address account) external onlyRole(BLOCKLIST_MANAGER_ROLE) {
        require(_blocklist[account], "ProfessionalToken: Address not blocked");
        _blocklist[account] = false;
        emit AddressUnblocked(account);
    }

    function isBlocked(address account) public view returns (bool) {
        return _blocklist[account];
    }

    // Override transfer functions to enforce blocklist
    function _update(address from, address to, uint256 amount) 
        internal 
        override(ERC20, ERC20Pausable) 
        whenNotPaused 
    {
        require(!_blocklist[from], "ProfessionalToken: Sender is blocked");
        require(!_blocklist[to], "ProfessionalToken: Recipient is blocked");
        super._update(from, to, amount);
    }

    // Rescue functions for stuck assets
    function rescueTokens(address token, address to, uint256 amount) 
        external 
        onlyRole(RESCUER_ROLE) 
        nonReentrant 
    {
        require(token != address(this), "ProfessionalToken: Cannot rescue this token");
        require(to != address(0), "ProfessionalToken: Cannot rescue to zero address");
        IERC20(token).safeTransfer(to, amount);
        emit TokensRescued(token, to, amount);
    }

    function rescueETH(address payable to) 
        external 
        onlyRole(RESCUER_ROLE) 
        nonReentrant 
    {
        require(to != address(0), "ProfessionalToken: Cannot rescue to zero address");
        uint256 balance = address(this).balance;
        to.transfer(balance);
        emit ETHRescued(to, balance);
    }

    // Fallback function to prevent accidental ETH transfers
    receive() external payable {
        revert("ProfessionalToken: Direct ETH transfers not allowed");
    }

    // Optional: Override decimals if needed (default is 18)
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
