// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ICO is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    // Token being sold
    IERC20 public token;
    
    // ICO parameters
    uint256 public constant RATE = 1000; // 1000 tokens per ETH
    uint256 public constant HARD_CAP = 1000 ether; // 1000 ETH hard cap
    uint256 public constant SOFT_CAP = 200 ether; // 200 ETH soft cap
    uint256 public constant MIN_CONTRIBUTION = 0.1 ether; // Minimum buy amount
    uint256 public constant MAX_CONTRIBUTION = 10 ether; // Maximum buy amount per address
    
    // Time parameters
    uint256 public startTime;
    uint256 public endTime;
    
    // State variables
    uint256 public totalRaised;
    mapping(address => uint256) public contributions;
    mapping(address => bool) public whitelist;
    bool public softCapReached;
    bool public refundEnabled;
    
    // Events
    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event RefundClaimed(address indexed user, uint256 amount);
    event WhitelistUpdated(address indexed user, bool status);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    
    constructor(
        address _token,
        uint256 _startTime,
        uint256 _endTime
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        require(_startTime >= block.timestamp, "Start time must be in future");
        require(_endTime > _startTime, "End time must be after start time");
        
        token = IERC20(_token);
        startTime = _startTime;
        endTime = _endTime;
    }
    
    // Modifier to check if ICO is active
    modifier whenIcoActive() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "ICO not active");
        require(totalRaised < HARD_CAP, "Hard cap reached");
        _;
    }
    
    // Modifier to check if user is whitelisted
    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }
    
    // Buy tokens
    function buyTokens() external payable whenIcoActive whenNotPaused onlyWhitelisted nonReentrant {
        uint256 ethAmount = msg.value;
        require(ethAmount >= MIN_CONTRIBUTION, "Below minimum contribution");
        require(contributions[msg.sender].add(ethAmount) <= MAX_CONTRIBUTION, "Exceeds maximum contribution");
        require(totalRaised.add(ethAmount) <= HARD_CAP, "Exceeds hard cap");
        
        uint256 tokenAmount = ethAmount.mul(RATE);
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        contributions[msg.sender] = contributions[msg.sender].add(ethAmount);
        totalRaised = totalRaised.add(ethAmount);
        
        // Update soft cap status
        if (totalRaised >= SOFT_CAP && !softCapReached) {
            softCapReached = true;
        }
        
        // Transfer tokens
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
        
        emit TokensPurchased(msg.sender, ethAmount, tokenAmount);
    }
    
    // Refund functionality
    function claimRefund() external nonReentrant {
        require(refundEnabled, "Refunds not enabled");
        require(contributions[msg.sender] > 0, "No contribution found");
        
        uint256 amount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        totalRaised = totalRaised.sub(amount);
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Refund failed");
        
        emit RefundClaimed(msg.sender, amount);
    }
    
    // Enable refunds if soft cap not reached by end time
    function enableRefunds() external onlyOwner {
        require(block.timestamp > endTime, "ICO still active");
        require(!softCapReached, "Soft cap reached");
        refundEnabled = true;
    }
    
    // Withdraw funds to owner if soft cap reached
    function withdrawFunds() external onlyOwner nonReentrant {
        require(softCapReached, "Soft cap not reached");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
        
        emit FundsWithdrawn(owner(), balance);
    }
    
    // Whitelist management
    function updateWhitelist(address[] calldata users, bool status) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = status;
            emit WhitelistUpdated(users[i], status);
        }
    }
    
    // Emergency pause
    function pause() external onlyOwner {
        _pause();
    }
    
    // Emergency unpause
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Recover tokens sent to contract by mistake
    function recoverTokens(address _token, uint256 amount) external onlyOwner {
        if (_token == address(token)) {
            require(block.timestamp > endTime, "ICO still active");
        }
        IERC20(_token).transfer(owner(), amount);
    }
    
    // Fallback function
    receive() external payable {
        revert("Use buyTokens function");
    }
    
    // Get remaining tokens
    function getRemainingTokens() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    // Get ICO status
    function getIcoStatus() external view returns (
        uint256 _totalRaised,
        bool _softCapReached,
        bool _refundEnabled,
        uint256 _startTime,
        uint256 _endTime
    ) {
        return (
            totalRaised,
            softCapReached,
            refundEnabled,
            startTime,
            endTime
        );
    }
}