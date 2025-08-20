// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Assuming we use a standard ERC20 for tokens
import "@balendu/optimized-utils/contracts/OptimizedUtils.sol"; // Import the library
// this feature will come sooon

/**
 * @title SimpleStaking
 * @author balendu
 * @notice A simple staking contract demonstrating the use of OptimizedUtils library.
 *         Users can stake ERC20 tokens and earn rewards based on compound interest.
 *         Rewards are calculated using fixed-point math from the library.
 *         Includes gas-optimized operations like safe math, time deltas, and bit manipulation for flags.
 * @dev This is an example contract for illustration. In production, add access controls, pauses, etc.
 *      Assumes a fixed annual reward rate for simplicity.
 */
contract SimpleStaking {
    using OptimizedUtils for uint256;
    using OptimizedUtils for int256;

    // Constants
    uint256 public constant REWARD_RATE = 0.1e18; // 10% annual rate in WAD
    uint256 public constant SECONDS_IN_YEAR = 365 days;

    // ERC20 token for staking
    IERC20 public immutable stakingToken;

    // User staking info
    struct UserInfo {
        uint256 stakedAmount;
        uint256 rewardDebt; // Pending rewards at last update
        uint256 lastStakeTime;
        uint256 flags; // Bit flags, e.g., bit 0: isActive
    }

    mapping(address => UserInfo) public userInfo;

    // Total staked
    uint256 public totalStaked;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
    }

    /**
     * @notice Stake tokens into the contract.
     * @param amount Amount of tokens to stake.
     */
    function stake(uint256 amount) external {
        if (amount == 0) revert OptimizedUtils.InvalidInput();

        UserInfo storage user = userInfo[msg.sender];
        _updateRewards(msg.sender);

        stakingToken.transferFrom(msg.sender, address(this), amount);
        user.stakedAmount = user.stakedAmount.safeAdd(amount);
        totalStaked = totalStaked.safeAdd(amount);

        user.flags = user.flags.bitSet(0); // Set active flag

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens and claim rewards.
     * @param amount Amount to unstake.
     */
    function unstake(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];
        if (amount == 0 || amount > user.stakedAmount) revert OptimizedUtils.InvalidInput();

        _updateRewards(msg.sender);

        user.stakedAmount = user.stakedAmount.safeSub(amount);
        totalStaked = totalStaked.safeSub(amount);
        stakingToken.transfer(msg.sender, amount);

        if (user.stakedAmount == 0) {
            user.flags = user.flags & ~(1 << 0); // Clear active flag using bitwise
        }

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim pending rewards without unstaking.
     */
    function claimRewards() external {
        _updateRewards(msg.sender);
        uint256 pending = userInfo[msg.sender].rewardDebt;
        if (pending > 0) {
            userInfo[msg.sender].rewardDebt = 0;
            stakingToken.transfer(msg.sender, pending); // Assuming rewards are in stakingToken
            emit RewardsClaimed(msg.sender, pending);
        }
    }

    /**
     * @notice View pending rewards for a user.
     * @param user Address of the user.
     * @return Pending rewards.
     */
    function pendingRewards(address user) external view returns (uint256) {
        UserInfo memory info = userInfo[user];
        if (info.stakedAmount == 0) return 0;

        uint256 timeDelta = block.timestamp.timeDelta(info.lastStakeTime);
        uint256 periods = timeDelta.mulWad(OptimizedUtils.WAD).divWad(SECONDS_IN_YEAR);

        uint256 factor = (OptimizedUtils.WAD.safeAdd(REWARD_RATE)).powWad(periods);
        uint256 accrued = info.stakedAmount.mulWad(factor).safeSub(info.stakedAmount);

        return accrued.safeAdd(info.rewardDebt);
    }

    /**
     * @notice Internal function to update rewards.
     * @param user Address of the user.
     */
    function _updateRewards(address user) internal {
        UserInfo storage info = userInfo[user];
        if (info.stakedAmount == 0) return;

        uint256 pending = pendingRewards(user).safeSub(info.rewardDebt); // Only add new accrued
        info.rewardDebt = info.rewardDebt.safeAdd(pending);
        info.lastStakeTime = block.timestamp;
    }

    /**
     * @notice Check if a user is active using bit flags.
     * @param user Address to check.
     * @return True if active.
     */
    function isActive(address user) external view returns (bool) {
        return userInfo[user].flags.bitGet(0) == 1;
    }
}