// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title A secure, scalable, and gas-optimized DAO contract
/// @notice Manages proposals, voting, and execution with governance token-based voting
contract DAO is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeMath for uint256;

    // Governance token used for voting
    IERC20 public governanceToken;

    // Minimum quorum percentage (e.g., 10% = 1000 basis points)
    uint256 public minQuorum; // Basis points (100 = 1%)
    
    // Minimum voting period in seconds
    uint256 public minVotingPeriod;
    
    // Minimum proposal threshold (tokens needed to propose)
    uint256 public proposalThreshold;
    
    // Timelock period before execution (in seconds)
    uint256 public executionDelay;

    // Proposal struct
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        address[] targets; // Contracts to call
        uint256[] values; // ETH values to send
        bytes[] calldatas; // Function calls
        uint256 startTime; // Voting start time
        uint256 endTime; // Voting end time
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
    }

    // Mapping of proposal ID to Proposal
    mapping(uint256 => Proposal) public proposals;
    
    // Mapping of proposal ID to voter address to vote status
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    // Total number of proposals
    uint256 public proposalCount;
    
    // Snapshot of voter balances at proposal creation
    mapping(uint256 => mapping(address => uint256)) public voteSnapshot;
    
    // Events
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);
    event VotingPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event ProposalThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event ExecutionDelayUpdated(uint256 oldDelay, uint256 newDelay);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the DAO contract
    /// @param _governanceToken Address of the governance token
    /// @param _minQuorum Minimum quorum in basis points
    /// @param _minVotingPeriod Minimum voting period in seconds
    /// @param _proposalThreshold Minimum tokens needed to propose
    /// @param _executionDelay Delay before proposal execution
    function initialize(
        address _governanceToken,
        uint256 _minQuorum,
        uint256 _minVotingPeriod,
        uint256 _proposalThreshold,
        uint256 _executionDelay
    ) public initializer {
        require(_governanceToken != address(0), "Invalid token address");
        require(_minQuorum <= 10000, "Quorum exceeds 100%");
        require(_minVotingPeriod > 0, "Invalid voting period");
        require(_proposalThreshold > 0, "Invalid proposal threshold");
        require(_executionDelay > 0, "Invalid execution delay");

        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        governanceToken = IERC20(_governanceToken);
        minQuorum = _minQuorum;
        minVotingPeriod = _minVotingPeriod;
        proposalThreshold = _proposalThreshold;
        executionDelay = _executionDelay;
    }

    /// @notice Creates a new proposal
    /// @param targets Contracts to call
    /// @param values ETH values to send
    /// @param calldatas Function calls
    /// @param description Proposal description
    /// @param votingPeriod Duration of voting in seconds
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 votingPeriod
    ) public whenNotPaused nonReentrant returns (uint256) {
        require(governanceToken.balanceOf(msg.sender) >= proposalThreshold, "Insufficient tokens to propose");
        require(targets.length == values.length && values.length == calldatas.length, "Invalid proposal parameters");
        require(votingPeriod >= minVotingPeriod, "Voting period too short");

        proposalCount++;
        uint256 proposalId = proposalCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime.add(votingPeriod);

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            description: description,
            targets: targets,
            values: values,
            calldatas: calldatas,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            executed: false,
            canceled: false
        });

        emit ProposalCreated(proposalId, msg.sender, targets, values, calldatas, description, startTime, endTime);
        return proposalId;
    }

    /// @notice Casts a vote on a proposal
    /// @param proposalId ID of the proposal
    /// @param support Whether the vote is for or against
    function vote(uint256 proposalId, bool support) public whenNotPaused nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime, "Voting period invalid");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        require(voterBalance > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;
        voteSnapshot[proposalId][msg.sender] = voterBalance;

        if (support) {
            proposal.forVotes = proposal.forVotes.add(voterBalance);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(voterBalance);
        }

        emit Voted(proposalId, msg.sender, support, voterBalance);
    }

    /// @notice Executes a proposal if it has passed
    /// @param proposalId ID of the proposal
    function execute(uint256 proposalId) public whenNotPaused nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp > proposal.endTime.add(executionDelay), "Execution delay not met");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(hasPassed(proposalId), "Proposal not passed");

        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancels a proposal (only by owner or proposer)
    /// @param proposalId ID of the proposal
    function cancel(uint256 proposalId) public nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(msg.sender == proposal.proposer || msg.sender == owner(), "Not authorized");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /// @notice Checks if a proposal has passed
    /// @param proposalId ID of the proposal
    /// @return True if the proposal has passed
    function hasPassed(uint256 proposalId) public view returns (bool) {
        Proposal memory proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp > proposal.endTime, "Voting not ended");

        uint256 totalSupply = governanceToken.totalSupply();
        uint256 totalVotes = proposal.forVotes.add(proposal.againstVotes);
        uint256 quorumVotes = totalSupply.mul(minQuorum).div(10000);

        return totalVotes >= quorumVotes && proposal.forVotes > proposal.againstVotes;
    }

    /// @notice Updates the minimum quorum (only owner)
    /// @param _minQuorum New quorum in basis points
    function setMinQuorum(uint256 _minQuorum) public onlyOwner {
        require(_minQuorum <= 10000, "Quorum exceeds 100%");
        emit QuorumUpdated(minQuorum, _minQuorum);
        minQuorum = _minQuorum;
    }

    /// @notice Updates the minimum voting period (only owner)
    /// @param _minVotingPeriod New voting period in seconds
    function setMinVotingPeriod(uint256 _minVotingPeriod) public onlyOwner {
        require(_minVotingPeriod > 0, "Invalid voting period");
        emit VotingPeriodUpdated(minVotingPeriod, _minVotingPeriod);
        minVotingPeriod = _minVotingPeriod;
    }

    /// @notice Updates the proposal threshold (only owner)
    /// @param _proposalThreshold New threshold in tokens
    function setProposalThreshold(uint256 _proposalThreshold) public onlyOwner {
        require(_proposalThreshold > 0, "Invalid threshold");
        emit ProposalThresholdUpdated(proposalThreshold, _proposalThreshold);
        proposalThreshold = _proposalThreshold;
    }

    /// @notice Updates the execution delay (only owner)
    /// @param _executionDelay New delay in seconds
    function setExecutionDelay(uint256 _executionDelay) public onlyOwner {
        require(_executionDelay > 0, "Invalid delay");
        emit ExecutionDelayUpdated(executionDelay, _executionDelay);
        executionDelay = _executionDelay;
    }

    /// @notice Pauses the contract (only owner)
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract (only owner)
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @notice Authorizes contract upgrades (only owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Allows the DAO to receive ETH
    receive() external payable {}
}