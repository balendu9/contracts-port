// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// Quadratic Voting contract optimized for gas and security
contract QuadraticVoting is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    // Struct to store proposal details
    struct Proposal {
        string description;
        uint256 voteCount; // Total quadratic votes
        uint256 totalCredits; // Total credits spent on this proposal
        bool active;
        address proposer;
    }

    // Struct to store voter information
    struct Voter {
        uint256 credits; // Available voting credits
        mapping(uint256 => uint256) votes; // Votes per proposal
        bool hasVoted;
    }

    // Contract state
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    uint256 public proposalCount;
    uint256 public constant MAX_CREDITS = 100; // Maximum credits per voter
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public votingEndTime;
    
    // Events for transparency and frontend integration
    event ProposalCreated(uint256 indexed proposalId, string description, address indexed proposer);
    event Voted(address indexed voter, uint256 indexed proposalId, uint256 votes, uint256 creditsUsed);
    event VotingEnded(uint256 indexed winningProposalId);
    event CreditsDistributed(address indexed voter, uint256 credits);

    // Modifiers for validation
    modifier onlyActiveVoting() {
        require(block.timestamp < votingEndTime, "Voting period has ended");
        require(!paused(), "Contract is paused");
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(proposals[_proposalId].active, "Proposal is not active");
        _;
    }

    constructor() Ownable(msg.sender) {
        votingEndTime = block.timestamp + VOTING_PERIOD;
    }

    // Create a new proposal
    function createProposal(string calldata _description) external onlyOwner whenNotPaused returns (uint256) {
        require(bytes(_description).length > 0 && bytes(_description).length <= 200, "Invalid description length");
        
        uint256 proposalId = proposalCount;
        proposals[proposalId] = Proposal({
            description: _description,
            voteCount: 0,
            totalCredits: 0,
            active: true,
            proposer: msg.sender
        });
        
        proposalCount = proposalCount.add(1);
        emit ProposalCreated(proposalId, _description, msg.sender);
        return proposalId;
    }

    // Distribute voting credits to a voter
    function distributeCredits(address _voter, uint256 _credits) external onlyOwner whenNotPaused {
        require(_credits <= MAX_CREDITS, "Exceeds maximum credits");
        require(_voter != address(0), "Invalid voter address");
        
        voters[_voter].credits = voters[_voter].credits.add(_credits);
        emit CreditsDistributed(_voter, _credits);
    }

    // Quadratic voting function
    function vote(uint256 _proposalId, uint256 _votes) 
        external 
        onlyActiveVoting 
        validProposal(_proposalId) 
        nonReentrant 
    {
        Voter storage voter = voters[msg.sender];
        require(voter.credits > 0, "No credits available");
        
        // Calculate quadratic cost (votes^2)
        uint256 cost = _votes.mul(_votes);
        require(cost <= voter.credits, "Insufficient credits for vote");
        
        // Update voter state
        voter.credits = voter.credits.sub(cost);
        voter.votes[_proposalId] = voter.votes[_proposalId].add(_votes);
        voter.hasVoted = true;
        
        // Update proposal state
        Proposal storage proposal = proposals[_proposalId];
        proposal.voteCount = proposal.voteCount.add(_votes);
        proposal.totalCredits = proposal.totalCredits.add(cost);
        
        emit Voted(msg.sender, _proposalId, _votes, cost);
    }

    // Get the winning proposal after voting ends
    function getWinningProposal() external view returns (uint256, string memory, uint256) {
        require(block.timestamp >= votingEndTime, "Voting period not ended");
        
        uint256 winningProposalId = 0;
        uint256 highestVotes = 0;
        
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active && proposals[i].voteCount > highestVotes) {
                highestVotes = proposals[i].voteCount;
                winningProposalId = i;
            }
        }
        
        return (
            winningProposalId,
            proposals[winningProposalId].description,
            proposals[winningProposalId].voteCount
        );
    }

    // Emergency pause function
    function pause() external onlyOwner {
        _pause();
    }

    // Resume voting
    function unpause() external onlyOwner {
        _unpause();
    }

    // Get voter's voting history
    function getVoterHistory(address _voter, uint256 _proposalId) 
        external 
        view 
        returns (uint256) 
    {
        return voters[_voter].votes[_proposalId];
    }

    // Get remaining credits for a voter
    function getRemainingCredits(address _voter) 
        external 
        view 
        returns (uint256) 
    {
        return voters[_voter].credits;
    }

    // Extend voting period if needed
    function extendVotingPeriod(uint256 _additionalTime) 
        external 
        onlyOwner 
    {
        require(_additionalTime <= 7 days, "Extension too long");
        votingEndTime = votingEndTime.add(_additionalTime);
    }

    // Deactivate a proposal
    function deactivateProposal(uint256 _proposalId) 
        external 
        onlyOwner 
        validProposal(_proposalId) 
    {
        proposals[_proposalId].active = false;
    }
}