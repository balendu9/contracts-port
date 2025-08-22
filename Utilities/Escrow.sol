// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Escrow contract for secure and scalable transaction mediation
contract Escrow is ReentrancyGuard, Ownable, Pausable {
    using SafeMath for uint256;

    // Struct to store escrow transaction details
    struct Transaction {
        address payable buyer;
        address payable seller;
        uint256 amount;
        uint256 timeout; // Deadline for transaction completion
        TransactionStatus status;
        bool buyerApproved;
        bool sellerApproved;
        bool arbiterApproved;
    }

    // Enum to track transaction status
    enum TransactionStatus {
        Pending, // Transaction is active and awaiting approval
        Completed, // Transaction successfully completed
        Refunded, // Transaction refunded to buyer
        Disputed, // Transaction in dispute
        Cancelled // Transaction cancelled
    }

    // Mapping to store transactions by ID
    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;

    // Address of the arbiter for dispute resolution
    address public arbiter;

    // Fee percentage (basis points, e.g., 100 = 1%)
    uint256 public feeBps;
    uint256 public constant MAX_FEE_BPS = 1000; // Max 10% fee
    address payable public feeRecipient;

    // Events for transparency and off-chain tracking
    event TransactionCreated(
        uint256 indexed transactionId,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        uint256 timeout
    );
    event TransactionApproved(uint256 indexed transactionId, address approver);
    event TransactionCompleted(uint256 indexed transactionId, uint256 amount);
    event TransactionRefunded(uint256 indexed transactionId, uint256 amount);
    event TransactionDisputed(uint256 indexed transactionId);
    event TransactionCancelled(uint256 indexed transactionId);
    event ArbiterUpdated(address indexed newArbiter);
    event FeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed newFeeRecipient);

    // Modifiers
    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Escrow: Caller is not arbiter");
        _;
    }

    modifier onlyParticipant(uint256 transactionId) {
        require(
            msg.sender == transactions[transactionId].buyer ||
                msg.sender == transactions[transactionId].seller ||
                msg.sender == arbiter,
            "Escrow: Caller is not a participant"
        );
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId <= transactionCount, "Escrow: Transaction does not exist");
        _;
    }

    modifier transactionNotCompleted(uint256 transactionId) {
        require(
            transactions[transactionId].status == TransactionStatus.Pending ||
                transactions[transactionId].status == TransactionStatus.Disputed,
            "Escrow: Transaction already finalized"
        );
        _;
    }

    // Constructor to initialize arbiter, fee, and fee recipient
    constructor(address _arbiter, uint256 _feeBps, address payable _feeRecipient) Ownable(msg.sender) {
        require(_arbiter != address(0), "Escrow: Invalid arbiter address");
        require(_feeRecipient != address(0), "Escrow: Invalid fee recipient");
        require(_feeBps <= MAX_FEE_BPS, "Escrow: Fee exceeds maximum");
        arbiter = _arbiter;
        feeBps = _feeBps;
        feeRecipient = _feeRecipient;
    }

    // Create a new escrow transaction
    function createTransaction(
        address payable _seller,
        uint256 _timeoutSeconds
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        require(_seller != address(0), "Escrow: Invalid seller address");
        require(msg.value > 0, "Escrow: Amount must be greater than 0");
        require(_timeoutSeconds >= 1 hours, "Escrow: Timeout too short");
        require(_timeoutSeconds <= 30 days, "Escrow: Timeout too long");

        uint256 transactionId = ++transactionCount;
        transactions[transactionId] = Transaction({
            buyer: payable(msg.sender),
            seller: _seller,
            amount: msg.value,
            timeout: block.timestamp.add(_timeoutSeconds),
            status: TransactionStatus.Pending,
            buyerApproved: false,
            sellerApproved: false,
            arbiterApproved: false
        });

        emit TransactionCreated(transactionId, msg.sender, _seller, msg.value, transactions[transactionId].timeout);
        return transactionId;
    }

    // Approve transaction by buyer or seller
    function approveTransaction(uint256 transactionId)
        external
        whenNotPaused
        nonReentrant
        transactionExists(transactionId)
        transactionNotCompleted(transactionId)
        onlyParticipant(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];
        require(
            msg.sender == transaction.buyer || msg.sender == transaction.seller,
            "Escrow: Arbiter cannot approve"
        );

        if (msg.sender == transaction.buyer) {
            transaction.buyerApproved = true;
        } else {
            transaction.sellerApproved = true;
        }

        emit TransactionApproved(transactionId, msg.sender);

        // If both parties approve, complete the transaction
        if (transaction.buyerApproved && transaction.sellerApproved) {
            _completeTransaction(transactionId);
        }
    }

    // Internal function to complete transaction
    function _completeTransaction(uint256 transactionId) private {
        Transaction storage transaction = transactions[transactionId];
        transaction.status = TransactionStatus.Completed;

        uint256 fee = transaction.amount.mul(feeBps).div(10000);
        uint256 sellerAmount = transaction.amount.sub(fee);

        // Transfer funds
        transaction.seller.transfer(sellerAmount);
        if (fee > 0) {
            feeRecipient.transfer(fee);
        }

        emit TransactionCompleted(transactionId, transaction.amount);
    }

    // Refund buyer (can be called by arbiter or after timeout)
    function refundTransaction(uint256 transactionId)
        external
        whenNotPaused
        nonReentrant
        transactionExists(transactionId)
        transactionNotCompleted(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];
        if (msg.sender != arbiter) {
            require(block.timestamp >= transaction.timeout, "Escrow: Timeout not reached");
            require(
                msg.sender == transaction.buyer || msg.sender == transaction.seller,
                "Escrow: Only participants can refund after timeout"
            );
        }

        transaction.status = TransactionStatus.Refunded;
        transaction.buyer.transfer(transaction.amount);

        emit TransactionRefunded(transactionId, transaction.amount);
    }

    // Initiate dispute (only by buyer or seller)
    function disputeTransaction(uint256 transactionId)
        external
        whenNotPaused
        transactionExists(transactionId)
        transactionNotCompleted(transactionId)
        onlyParticipant(transactionId)
    {
        require(
            msg.sender == transactions[transactionId].buyer ||
                msg.sender == transactions[transactionId].seller,
            "Escrow: Arbiter cannot dispute"
        );

        transactions[transactionId].status = TransactionStatus.Disputed;
        emit TransactionDisputed(transactionId);
    }

    // Resolve dispute by arbiter
    function resolveDispute(uint256 transactionId, bool approveSeller)
        external
        whenNotPaused
        nonReentrant
        onlyArbiter
        transactionExists(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];
        require(transaction.status == TransactionStatus.Disputed, "Escrow: Transaction not in dispute");

        if (approveSeller) {
            transaction.arbiterApproved = true;
            _completeTransaction(transactionId);
        } else {
            transaction.status = TransactionStatus.Refunded;
            transaction.buyer.transfer(transaction.amount);
            emit TransactionRefunded(transactionId, transaction.amount);
        }
    }

    // Cancel transaction before approval
    function cancelTransaction(uint256 transactionId)
        external
        whenNotPaused
        nonReentrant
        transactionExists(transactionId)
        transactionNotCompleted(transactionId)
        onlyParticipant(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];
        require(
            !transaction.buyerApproved && !transaction.sellerApproved,
            "Escrow: Cannot cancel after approval"
        );

        transaction.status = TransactionStatus.Cancelled;
        transaction.buyer.transfer(transaction.amount);

        emit TransactionCancelled(transactionId);
    }

    // Update arbiter (only owner)
    function updateArbiter(address _newArbiter) external onlyOwner {
        require(_newArbiter != address(0), "Escrow: Invalid arbiter address");
        arbiter = _newArbiter;
        emit ArbiterUpdated(_newArbiter);
    }

    // Update fee (only owner)
    function updateFee(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= MAX_FEE_BPS, "Escrow: Fee exceeds maximum");
        feeBps = _newFeeBps;
        emit FeeUpdated(_newFeeBps);
    }

    // Update fee recipient (only owner)
    function updateFeeRecipient(address payable _newFeeRecipient) external onlyOwner {
        require(_newFeeRecipient != address(0), "Escrow: Invalid fee recipient");
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientUpdated(_newFeeRecipient);
    }

    // Pause contract (only owner)
    function pause() external onlyOwner {
        _pause();
    }

    // Unpause contract (only owner)
    function unpause() external onlyOwner {
        _unpause();
    }

    // Emergency withdraw in case of contract issues (only owner)
    function emergencyWithdraw(address payable recipient, uint256 amount) external onlyOwner nonReentrant {
        require(recipient != address(0), "Escrow: Invalid recipient");
        recipient.transfer(amount);
    }

    // Fallback function to prevent accidental ETH transfers
    receive() external payable {
        revert("Escrow: Use createTransaction to send ETH");
    }
}