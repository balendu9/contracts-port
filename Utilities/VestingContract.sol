// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title VestingContract
/// @notice A secure, gas-optimized contract for token vesting with customizable schedules
/// @dev Implements linear vesting, cliff periods, revocable grants, and emergency pause
contract VestingContract is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    /// @notice Structure to store vesting schedule details
    struct VestingSchedule {
        address beneficiary;        // Address of the beneficiary
        uint256 startTime;          // Vesting start timestamp
        uint256 cliffDuration;      // Cliff period in seconds
        uint256 vestingDuration;    // Total vesting period in seconds
        uint256 totalAmount;        // Total tokens to vest
        uint256 releasedAmount;     // Tokens already released
        bool revocable;             // Whether the schedule is revocable
        bool revoked;               // Whether the schedule has been revoked
    }

    /// @notice Token to be vested
    IERC20 public immutable token;

    /// @notice Mapping of beneficiary address to their vesting schedules
    mapping(address => VestingSchedule[]) public vestingSchedules;

    /// @notice Tracks the number of schedules per beneficiary for gas-efficient iteration
    mapping(address => uint256) public vestingScheduleCount;

    /// @notice Total tokens locked in the contract
    uint256 public totalTokensLocked;

    // Events for transparency and auditability
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );
    event TokensReleased(address indexed beneficiary, uint256 indexed scheduleId, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 indexed scheduleId, uint256 returnedAmount);
    event TokensWithdrawn(address indexed owner, uint256 amount);

    /// @notice Constructor to initialize the contract with the token address
    /// @param _token Address of the ERC20 token to vest
    constructor(IERC20 _token) Ownable(msg.sender) {
        require(address(_token) != address(0), "VestingContract: Invalid token address");
        token = _token;
    }

    /// @notice Creates a new vesting schedule for a beneficiary
    /// @param _beneficiary Address of the beneficiary
    /// @param _totalAmount Total tokens to vest
    /// @param _startTime Vesting start timestamp
    /// @param _cliffDuration Cliff period in seconds
    /// @param _vestingDuration Total vesting period in seconds
    /// @param _revocable Whether the schedule is revocable
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner whenNotPaused {
        require(_beneficiary != address(0), "VestingContract: Invalid beneficiary");
        require(_totalAmount > 0, "VestingContract: Amount must be greater than 0");
        require(_vestingDuration > 0, "VestingContract: Vesting duration must be greater than 0");
        require(_cliffDuration <= _vestingDuration, "VestingContract: Cliff exceeds vesting duration");
        require(_startTime >= block.timestamp, "VestingContract: Start time must be in the future");

        // Ensure contract has enough tokens
        require(token.balanceOf(address(this)) >= totalTokensLocked.add(_totalAmount), 
                "VestingContract: Insufficient token balance");

        uint256 scheduleId = vestingScheduleCount[_beneficiary];
        vestingSchedules[_beneficiary].push(VestingSchedule({
            beneficiary: _beneficiary,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            revocable: _revocable,
            revoked: false
        }));

        vestingScheduleCount[_beneficiary] = scheduleId.add(1);
        totalTokensLocked = totalTokensLocked.add(_totalAmount);

        emit VestingScheduleCreated(
            _beneficiary,
            scheduleId,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _vestingDuration,
            _revocable
        );
    }

    /// @notice Releases vested tokens for a specific schedule
    /// @param _scheduleId ID of the vesting schedule
    function release(uint256 _scheduleId) external nonReentrant whenNotPaused {
        VestingSchedule storage schedule = vestingSchedules[msg.sender][_scheduleId];
        require(schedule.beneficiary == msg.sender, "VestingContract: Not the beneficiary");
        require(!schedule.revoked, "VestingContract: Schedule revoked");
        require(schedule.totalAmount > 0, "VestingContract: Invalid schedule");

        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount.sub(schedule.releasedAmount);
        require(releasableAmount > 0, "VestingContract: No tokens to release");

        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
        totalTokensLocked = totalTokensLocked.sub(releasableAmount);

        require(token.transfer(msg.sender, releasableAmount), "VestingContract: Token transfer failed");

        emit TokensReleased(msg.sender, _scheduleId, releasableAmount);
    }

    /// @notice Revokes a vesting schedule and returns unvested tokens to the owner
    /// @param _beneficiary Beneficiary address
    /// @param _scheduleId ID of the vesting schedule
    function revoke(address _beneficiary, uint256 _scheduleId) external onlyOwner whenNotPaused {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary][_scheduleId];
        require(schedule.beneficiary == _beneficiary, "VestingContract: Invalid beneficiary");
        require(schedule.revocable, "VestingContract: Schedule not revocable");
        require(!schedule.revoked, "VestingContract: Schedule already revoked");

        schedule.revoked = true;
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 unreleasedAmount = schedule.totalAmount.sub(vestedAmount);
        totalTokensLocked = totalTokensLocked.sub(unreleasedAmount);

        emit VestingRevoked(_beneficiary, _scheduleId, unreleasedAmount);
    }

    /// @notice Withdraws excess tokens from the contract (not allocated to vesting)
    /// @param _amount Amount of tokens to withdraw
    function withdrawExcessTokens(uint256 _amount) external onlyOwner {
        uint256 availableTokens = token.balanceOf(address(this)).sub(totalTokensLocked);
        require(_amount <= availableTokens, "VestingContract: Insufficient excess tokens");

        require(token.transfer(owner(), _amount), "VestingContract: Token transfer failed");

        emit TokensWithdrawn(owner(), _amount);
    }

    /// @notice Pauses the contract (emergency stop)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Calculates the vested amount for a schedule
    /// @param schedule The vesting schedule
    /// @return The amount of tokens vested
    function _calculateVestedAmount(VestingSchedule memory schedule) private view returns (uint256) {
        if (block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }
        if (block.timestamp >= schedule.startTime.add(schedule.vestingDuration)) {
            return schedule.totalAmount;
        }

        return schedule.totalAmount.mul(
            block.timestamp.sub(schedule.startTime)
        ).div(schedule.vestingDuration);
    }

    // @notice Gets the releasable amount for a specific schedule
    // @param _beneficiary Beneficiary address
    // @param _scheduleId ID of the vesting schedule
    // @return The amount of tokens releasable
    function getReleasableAmount(address _beneficiary, uint256 _scheduleId) external view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary][_scheduleId];
        require(schedule.beneficiary == _beneficiary, "VestingContract: Invalid beneficiary");
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        return vestedAmount.sub(schedule.releasedAmount);
    }

    // @notice Gets the details of a vesting schedule
    // @param _beneficiary Beneficiary address
    // @param _scheduleId ID of the vesting schedule
    // @return Vesting schedule details
    
    function getVestingSchedule(address _beneficiary, uint256 _scheduleId) 
        external 
        view 
        returns (
            address beneficiary,
            uint256 startTime,
            uint256 cliffDuration,
            uint256 vestingDuration,
            uint256 totalAmount,
            uint256 releasedAmount,
            bool revocable,
            bool revoked
        ) 
    {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary][_scheduleId];
        return (
            schedule.beneficiary,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.revocable,
            schedule.revoked
        );
    }
}