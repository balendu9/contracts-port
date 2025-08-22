// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TimelockMultisig
 * @dev A secure, gas-optimized multisig contract with timelock functionality.
 * This contract allows multiple owners to propose, confirm, and execute transactions
 * after a specified delay once the required threshold of confirmations is reached.
 
 * Security features:
 * - Owners managed via EnumerableSet for O(1) checks.
 * - Transactions cannot be executed before timelock expires.
 * - Reentrancy protection via state checks.
 * - No self-destruct or delegatecall.
 * - Immutable threshold and delay.
 * 
 * Gas optimizations:
 * - Immutable variables for constants.
 * - Calldata for input bytes.
 * - Minimal storage writes.
 * - No loops over owners.
 * 
 * Scalability:
 * - Supports hundreds of owners via set-based operations.
 * - Confirmation system suitable for small to medium owner counts.
 * 
 * Production-ready notes:
 * - Based on OpenZeppelin patterns.
 * - Recommend external audit before deployment.
 * - Deploy with verified source on Etherscan.
 */
contract TimelockMultisig {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Set of current owners.
    EnumerableSet.AddressSet internal owners;

    /// @notice Required number of confirmations for a transaction.
    uint256 public immutable threshold;

    /// @notice Timelock delay in seconds.
    uint256 public immutable delay;

    /// @dev Structure for a proposed transaction.
    struct Transaction {
        address to; // Target address.
        uint256 value; // ETH value.
        bytes data; // Call data.
        uint256 eta; // Earliest execution timestamp.
        bool executed; // Whether executed.
        EnumerableSet.AddressSet confirmers; // Set of confirmers.
    }

    /// @notice Mapping of txId to Transaction (changed to internal).
    mapping(uint256 => Transaction) internal transactions;

    /// @notice Counter for next txId.
    uint256 public txCount;

    /// @dev Emitted when a new transaction is proposed.
    event TransactionProposed(uint256 indexed txId, address indexed proposer, address to, uint256 value, bytes data, uint256 eta);

    /// @dev Emitted when an owner confirms a transaction.
    event TransactionConfirmed(uint256 indexed txId, address indexed confirmer);

    /// @dev Emitted when a transaction is executed.
    event TransactionExecuted(uint256 indexed txId, address indexed executor);

    /// @dev Emitted when an owner is added.
    event OwnerAdded(address indexed owner);

    /// @dev Emitted when an owner is removed.
    event OwnerRemoved(address indexed owner);

    /// @dev Emitted when ETH is received.
    event Deposit(address indexed sender, uint256 value);

    /// @dev Modifier to restrict to owners.
    modifier onlyOwner() {
        require(owners.contains(msg.sender), "TimelockMultisig: caller is not an owner");
        _;
    }

    /// @dev Modifier to check if tx exists.
    modifier txExists(uint256 txId) {
        require(transactions[txId].to != address(0), "TimelockMultisig: transaction does not exist");
        _;
    }

    /// @dev Modifier to check if tx is not executed.
    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "TimelockMultisig: transaction already executed");
        _;
    }

    /**
     * @dev Constructor to initialize owners, threshold, and delay.
     * @param initialOwners Array of initial owners.
     * @param requiredThreshold Number of required confirmations.
     * @param timelockDelay Delay in seconds.
     */
    constructor(address[] memory initialOwners, uint256 requiredThreshold, uint256 timelockDelay) {
        require(requiredThreshold > 0 && requiredThreshold <= initialOwners.length, "TimelockMultisig: invalid threshold");
        require(timelockDelay > 0, "TimelockMultisig: delay must be greater than zero");

        for (uint256 i = 0; i < initialOwners.length; i++) {
            require(initialOwners[i] != address(0), "TimelockMultisig: invalid owner address");
            require(owners.add(initialOwners[i]), "TimelockMultisig: duplicate owner");
            emit OwnerAdded(initialOwners[i]);
        }

        threshold = requiredThreshold;
        delay = timelockDelay;
    }

    /// @dev Allow receiving ETH.
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Propose a new transaction. Auto-confirms by proposer.
     * @param to Target address.
     * @param value ETH value.
     * @param data Call data.
     * @return txId The ID of the proposed transaction.
     */
    function proposeTransaction(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256 txId) {
        require(to != address(0), "TimelockMultisig: invalid target address");

        txId = ++txCount;
        Transaction storage txn = transactions[txId];
        txn.to = to;
        txn.value = value;
        txn.data = data;
        txn.eta = 0;
        txn.executed = false;
        txn.confirmers.add(msg.sender);

        emit TransactionProposed(txId, msg.sender, to, value, data, 0);
    }

    /**
     * @dev Confirm a proposed transaction.
     * @param txId The transaction ID.
     */
    function confirmTransaction(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        Transaction storage txn = transactions[txId];
        require(!txn.confirmers.contains(msg.sender), "TimelockMultisig: already confirmed");

        txn.confirmers.add(msg.sender);
        emit TransactionConfirmed(txId, msg.sender);

        // Set eta if threshold reached and not set
        if (txn.confirmers.length() >= threshold && txn.eta == 0) {
            txn.eta = block.timestamp + delay;
            emit TransactionProposed(txId, msg.sender, txn.to, txn.value, txn.data, txn.eta);
        }
    }

    /**
     * @dev Execute a confirmed transaction after timelock.
     * @param txId The transaction ID.
     */
    function executeTransaction(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        Transaction storage txn = transactions[txId];
        require(txn.confirmers.length() >= threshold, "TimelockMultisig: insufficient confirmations");
        require(txn.eta != 0 && block.timestamp >= txn.eta, "TimelockMultisig: timelock not expired");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "TimelockMultisig: transaction execution failed");

        emit TransactionExecuted(txId, msg.sender);
    }

    /**
     * @dev Get transaction details.
     * @param txId The transaction ID.
     * @return to Target address.
     * @return value ETH value.
     * @return data Call data.
     * @return eta Earliest execution timestamp.
     * @return executed Whether executed.
     * @return confirmationCount Number of confirmations.
     */
    function getTransaction(uint256 txId)
        external
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            uint256 eta,
            bool executed,
            uint256 confirmationCount
        )
    {
        Transaction storage txn = transactions[txId];
        return (
            txn.to,
            txn.value,
            txn.data,
            txn.eta,
            txn.executed,
            txn.confirmers.length()
        );
    }

    /**
     * @dev Get list of confirmers for a transaction.
     * @param txId The transaction ID.
     * @return Array of confirmer addresses.
     */
    function getTransactionConfirmers(uint256 txId) external view returns (address[] memory) {
        return transactions[txId].confirmers.values();
    }

    /**
     * @dev Get number of confirmations for a tx.
     * @param txId The transaction ID.
     * @return Number of confirmations.
     */
    function getConfirmationCount(uint256 txId) external view returns (uint256) {
        return transactions[txId].confirmers.length();
    }

    /**
     * @dev Get list of owners.
     * @return Array of owners.
     */
    function getOwners() external view returns (address[] memory) {
        return owners.values();
    }
}