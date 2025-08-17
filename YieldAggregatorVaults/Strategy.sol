pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./YieldVault.sol";

contract Strategy is IStrategy {
    using SafeERC20 for IERC20;

    YieldVault public vault;
    IERC20 public underlying;
    address public targetProtocol; // Example: Aave, Compound, etc.
    address public owner;

    // Custom errors
    error Unauthorized();
    error ZeroAmount();

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert Unauthorized();
        _;
    }

    constructor(address _vault, address _underlying, address _targetProtocol) {
        vault = YieldVault(_vault);
        underlying = IERC20(_underlying);
        targetProtocol = _targetProtocol;
        owner = msg.sender;
    }

    // Deposit to target protocol
    function deposit(uint256 _amount) external override onlyVault {
        if (_amount == 0) revert ZeroAmount();
        // Example: Deposit to Aave/Compound
        underlying.safeApprove(targetProtocol, _amount);
        // Placeholder: Call target protocol's deposit function
    }

    // Withdraw from target protocol
    function withdraw(uint256 _amount) external override onlyVault {
        if (_amount == 0) revert ZeroAmount();
        // Placeholder: Call target protocol's withdraw function
        underlying.safeTransfer(address(vault), _amount);
    }

    // Harvest profits from target protocol
    function harvest() external override onlyVault returns (uint256) {
        // Placeholder: Harvest rewards from target protocol
        uint256 profit = 0; // Calculate profit
        if (profit > 0) {
            underlying.safeTransfer(address(vault), profit);
        }
        return profit;
    }

    // Get balance in target protocol
    function balanceOf() external view override returns (uint256) {
        // Placeholder: Return balance from target protocol
        return underlying.balanceOf(address(this));
    }

    // Emergency withdraw all funds
    function emergencyWithdraw() external override onlyVault {
        uint256 balance = balanceOf();
        if (balance > 0) {
            underlying.safeTransfer(address(vault), balance);
        }
    }
}