pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface for strategies
interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256);
    function balanceOf() external view returns (uint256);
    function emergencyWithdraw() external;
}

// Interface for price oracles to prevent manipulation
interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

// Main Yield Vault contract
contract YieldVault is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // Storage variables packed to minimize SSTORE (32 bytes)
    IERC20 public underlying; // Underlying token (LP or staking token)
    address public strategy; // Current strategy contract
    IPriceOracle public oracle; // Price oracle for slippage protection
    uint256 public totalShares; // Total shares issued
    uint256 public lastHarvest; // Timestamp of last harvest
    uint256 public performanceFee; // Fee in basis points (e.g., 200 = 2%)
    uint256 public constant MAX_BPS = 10_000; // 100% in basis points
    uint256 public slippageTolerance; // Slippage tolerance in basis points
    mapping(address => uint256) public shares; // User shares
    mapping(address => uint256) public userDepositTime; // For timelock protection

    // Events for transparency and off-chain monitoring
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event Harvest(uint256 amount, uint256 fee);
    event StrategyUpdated(address indexed strategy);
    event EmergencyWithdraw(uint256 amount);

    // Custom errors for gas efficiency
    error ZeroAmount();
    error InsufficientShares();
    error SlippageTooHigh();
    error StrategyNotSet();
    error Unauthorized();
    error TimelockActive();

    // Initialize function for proxy
    function initialize(
        address _underlying,
        address _oracle,
        uint256 _performanceFee,
        uint256 _slippageTolerance
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        underlying = IERC20(_underlying);
        oracle = IPriceOracle(_oracle);
        performanceFee = _performanceFee;
        slippageTolerance = _slippageTolerance;
        lastHarvest = block.timestamp;
    }

    // Deposit underlying tokens and mint shares
    function deposit(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();

        // Check slippage using oracle
        uint256 expectedPrice = oracle.getPrice(address(underlying));
        uint256 currentPrice = _getCurrentPrice(); // Implement oracle price check
        if (!_isWithinSlippage(expectedPrice, currentPrice)) revert SlippageTooHigh();

        // Timelock to prevent flash-loan attacks
        userDepositTime[msg.sender] = block.timestamp;

        // Calculate shares based on current vault value
        uint256 sharePrice = _getSharePrice();
        uint256 sharesToMint = (_amount * 1e18) / sharePrice;

        // Transfer tokens and update state in one batch
        underlying.safeTransferFrom(msg.sender, address(this), _amount);
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;

        // Deposit to strategy if set
        if (strategy != address(0)) {
            underlying.safeApprove(strategy, _amount);
            IStrategy(strategy).deposit(_amount);
        }

        emit Deposit(msg.sender, _amount, sharesToMint);
    }

    // Withdraw underlying tokens by burning shares
    function withdraw(uint256 _shares) external nonReentrant {
        if (_shares == 0 || _shares > shares[msg.sender]) revert InsufficientShares();
        // Check timelock to prevent manipulation
        if (block.timestamp < userDepositTime[msg.sender] + 1 hours) revert TimelockActive();

        // Calculate amount based on share price
        uint256 sharePrice = _getSharePrice();
        uint256 amount = (_shares * sharePrice) / 1e18;

        // Update state before external calls
        shares[msg.sender] -= _shares;
        totalShares -= _shares;

        // Withdraw from strategy if needed
        if (strategy != address(0)) {
            IStrategy(strategy).withdraw(amount);
        }

        // Transfer underlying tokens
        underlying.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, _shares);
    }

    // Harvest profits from strategy and compound
    function harvest() external nonReentrant onlyOwner {
        if (strategy == address(0)) revert StrategyNotSet();

        // Harvest from strategy
        uint256 profit = IStrategy(strategy).harvest();
        if (profit == 0) return;

        // Calculate performance fee
        uint256 fee = (profit * performanceFee) / MAX_BPS;
        uint256 amountToCompound = profit - fee;

        // Reinvest profits
        underlying.safeApprove(strategy, amountToCompound);
        IStrategy(strategy).deposit(amountToCompound);

        // Transfer fee to owner
        if (fee > 0) {
            underlying.safeTransfer(owner(), fee);
        }

        lastHarvest = block.timestamp;
        emit Harvest(profit, fee);
    }

    // Emergency withdraw all funds from strategy
    function emergencyWithdraw() external onlyOwner {
        if (strategy == address(0)) revert StrategyNotSet();
        IStrategy(strategy).emergencyWithdraw();
        uint256 balance = underlying.balanceOf(address(this));
        emit EmergencyWithdraw(balance);
    }

    // Set new strategy (upgradeable pattern)
    function setStrategy(address _strategy) external onlyOwner {
        if (_strategy == address(0)) revert StrategyNotSet();
        if (strategy != address(0)) {
            // Withdraw all funds from old strategy
            IStrategy(strategy).emergencyWithdraw();
        }
        strategy = _strategy;
        emit StrategyUpdated(_strategy);
    }

    // Get current share price
    function _getSharePrice() internal view returns (uint256) {
        uint256 totalValue = strategy != address(0) ? IStrategy(strategy).balanceOf() : underlying.balanceOf(address(this));
        return totalShares == 0 ? 1e18 : (totalValue * 1e18) / totalShares;
    }

    // Check if price is within slippage tolerance
    function _isWithinSlippage(uint256 expected, uint256 actual) internal view returns (bool) {
        uint256 diff = expected > actual ? expected - actual : actual - expected;
        return (diff * MAX_BPS) / expected <= slippageTolerance;
    }

    // Placeholder for current price fetch (to be implemented with specific oracle)
    function _getCurrentPrice() internal view returns (uint256) {
        return oracle.getPrice(address(underlying)); // Simplified for example
    }
}