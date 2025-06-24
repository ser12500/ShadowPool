// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ShadowPool} from "./ShadowPool.sol";
import {AnonymousVoting} from "./AnonymousVoting.sol";

/**
 * @title ShadowPoolDAO
 * @dev Decentralized governance system for ShadowPool mixer with anonymous voting
 * Allows token holders to propose and vote anonymously on changes to mixer parameters
 * @author Sergey Kerhet
 */
contract ShadowPoolDAO is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Governance token for voting
    IERC20 public immutable governanceToken;

    /// @notice ShadowPool contract
    ShadowPool public shadowPool;

    /// @notice Anonymous voting contract
    AnonymousVoting public anonymousVoting;

    /// @notice Minimum tokens required to create a proposal
    uint256 public proposalThreshold;

    /// @notice Minimum voting period in blocks
    uint256 public votingPeriod;

    /// @notice Minimum quorum required for proposal execution
    uint256 public quorumVotes;

    /// @notice Timelock delay for executed proposals
    uint256 public timelockDelay;

    /// @notice Maximum number of proposals that can be active
    uint256 public maxActiveProposals;

    /// @notice Current number of active proposals
    uint256 public activeProposalCount;

    /// @notice Whether anonymous voting is enabled
    bool public anonymousVotingEnabled;

    /// @notice Proposal struct
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        mapping(address => Receipt) receipts;
    }

    /// @notice Receipt struct for tracking votes (legacy)
    struct Receipt {
        bool hasVoted;
        bool support;
        uint256 votes;
    }

    /// @notice Proposal state enum
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice All proposals
    mapping(uint256 => Proposal) public proposals;

    /// @notice Latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice Timelock mapping for executed proposals
    mapping(uint256 => uint256) public proposalTimelocks;

    /// @notice Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock
    );

    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votes);
    event AnonymousVotingEnabled(bool enabled);
    event AnonymousVotingContractUpdated(address indexed oldContract, address indexed newContract);

    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);

    /// @notice Errors
    error DAO__ProposalNotFound();
    error DAO__ProposalNotActive();
    error DAO__ProposalAlreadyExecuted();
    error DAO__ProposalAlreadyCanceled();
    error DAO__InsufficientTokens();
    error DAO__AlreadyVoted();
    error DAO__TimelockNotExpired();
    error DAO__ExecutionFailed();
    error DAO__InvalidProposal();
    error DAO__TooManyActiveProposals();
    error DAO__AnonymousVotingNotEnabled();
    error DAO__InvalidAnonymousVotingContract();

    /// @dev Constructor to initialize the verifier, owner addresses, and fee configuration.
    /// @param _governanceToken Governance token address
    /// @param _shadowPoolAddress ShadowPool contract address (can be address(0) initially)
    /// @param _proposalThreshold Minimum tokens to create proposal
    /// @param _votingPeriod Voting period in blocks
    /// @param _quorumVotes Minimum quorum votes
    /// @param _timelockDelay Timelock delay in seconds
    /// @param _maxActiveProposals Maximum active proposals
    constructor(
        IERC20 _governanceToken,
        address _shadowPoolAddress,
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _quorumVotes,
        uint256 _timelockDelay,
        uint256 _maxActiveProposals
    ) {
        governanceToken = _governanceToken;
        shadowPool = ShadowPool(_shadowPoolAddress);
        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        quorumVotes = _quorumVotes;
        timelockDelay = _timelockDelay;
        maxActiveProposals = _maxActiveProposals;
    }

    /// @notice Create a new proposal
    /// @param description Proposal description
    /// @param targets Target addresses for calls
    /// @param values ETH values for calls
    /// @param signatures Function signatures
    /// @param calldatas Calldata for calls
    /// @return proposalId The created proposal ID
    function propose(
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) external returns (uint256 proposalId) {
        if (governanceToken.balanceOf(msg.sender) < proposalThreshold) {
            revert DAO__InsufficientTokens();
        }

        if (activeProposalCount >= maxActiveProposals) {
            revert DAO__TooManyActiveProposals();
        }

        proposalId = _propose(msg.sender, description, targets, values, signatures, calldatas);
    }

    /// @notice Cast vote on a proposal (legacy - non-anonymous)
    /// @param proposalId Proposal ID
    /// @param support True for support, false for against
    function castVote(uint256 proposalId, bool support) external {
        if (proposals[proposalId].proposer == address(0)) {
            revert DAO__ProposalNotFound();
        }

        if (getProposalState(proposalId) != ProposalState.Active) {
            revert DAO__ProposalNotActive();
        }

        if (proposals[proposalId].receipts[msg.sender].hasVoted) {
            revert DAO__AlreadyVoted();
        }

        uint256 votes = governanceToken.balanceOf(msg.sender);
        if (votes == 0) {
            revert DAO__InsufficientTokens();
        }

        proposals[proposalId].receipts[msg.sender] = Receipt({hasVoted: true, support: support, votes: votes});

        if (support) {
            proposals[proposalId].forVotes += votes;
        } else {
            proposals[proposalId].againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /// @notice Cast anonymous vote using zk-proof
    /// @param proposalId ID of the proposal to vote on
    /// @param proof Zk-proof bytes
    /// @param publicInputs Public inputs for verification
    /// @param support True for support, false for against
    function castAnonymousVote(uint256 proposalId, bytes calldata proof, bytes32[] calldata publicInputs, bool support)
        external
    {
        if (!anonymousVotingEnabled) {
            revert DAO__AnonymousVotingNotEnabled();
        }

        if (address(anonymousVoting) == address(0)) {
            revert DAO__InvalidAnonymousVotingContract();
        }

        // Cast vote through anonymous voting contract
        anonymousVoting.castAnonymousVote(proposalId, proof, publicInputs, support);

        // Update proposal state with anonymous votes
        _updateProposalWithAnonymousVotes(proposalId);
    }

    /// @notice Enable or disable anonymous voting
    /// @param enabled True to enable, false to disable
    function setAnonymousVotingEnabled(bool enabled) external {
        // This function can only be called through successful proposals
        require(msg.sender == address(this), "DAO: Only self-call allowed");

        anonymousVotingEnabled = enabled;
        emit AnonymousVotingEnabled(enabled);
    }

    /// @notice Update anonymous voting contract address
    /// @param newAnonymousVoting New anonymous voting contract address
    function updateAnonymousVotingContract(address newAnonymousVoting) external {
        // This function can only be called through successful proposals
        require(msg.sender == address(this), "DAO: Only self-call allowed");

        address oldContract = address(anonymousVoting);
        anonymousVoting = AnonymousVoting(newAnonymousVoting);
        emit AnonymousVotingContractUpdated(oldContract, newAnonymousVoting);
    }

    /// @notice Update proposal state with anonymous votes
    /// @param proposalId ID of the proposal
    function _updateProposalWithAnonymousVotes(uint256 proposalId) internal {
        if (address(anonymousVoting) == address(0)) {
            return;
        }

        AnonymousVoting.ProposalVotes memory anonymousVotes = anonymousVoting.getProposalVotes(proposalId);

        if (anonymousVotes.votingActive) {
            // Update proposal with anonymous vote totals
            proposals[proposalId].forVotes = anonymousVotes.forVotes;
            proposals[proposalId].againstVotes = anonymousVotes.againstVotes;
        }
    }

    /// @notice Get combined voting results (legacy + anonymous)
    /// @param proposalId ID of the proposal
    /// @return forVotes Total votes for the proposal
    /// @return againstVotes Total votes against the proposal
    function getCombinedVoteResults(uint256 proposalId)
        external
        view
        returns (uint256 forVotes, uint256 againstVotes)
    {
        Proposal storage proposal = proposals[proposalId];

        forVotes = proposal.forVotes;
        againstVotes = proposal.againstVotes;

        // Add anonymous votes if enabled
        if (anonymousVotingEnabled && address(anonymousVoting) != address(0)) {
            AnonymousVoting.ProposalVotes memory anonymousVotes = anonymousVoting.getProposalVotes(proposalId);
            if (anonymousVotes.votingActive) {
                forVotes = anonymousVotes.forVotes;
                againstVotes = anonymousVotes.againstVotes;
            }
        }

        return (forVotes, againstVotes);
    }

    /// @notice Execute a successful proposal
    /// @param proposalId Proposal ID
    function execute(uint256 proposalId) external {
        if (proposals[proposalId].proposer == address(0)) {
            revert DAO__ProposalNotFound();
        }

        if (proposals[proposalId].executed) {
            revert DAO__ProposalAlreadyExecuted();
        }

        if (proposals[proposalId].canceled) {
            revert DAO__ProposalAlreadyCanceled();
        }

        ProposalState state = getProposalState(proposalId);
        if (state != ProposalState.Succeeded && state != ProposalState.Queued) {
            revert DAO__ProposalNotActive();
        }

        if (state == ProposalState.Queued) {
            if (block.timestamp < proposalTimelocks[proposalId]) {
                revert DAO__TimelockNotExpired();
            }
        }

        proposals[proposalId].executed = true;

        for (uint256 i = 0; i < proposals[proposalId].targets.length; i++) {
            address target = proposals[proposalId].targets[i];
            (bool success,) = target.call{value: proposals[proposalId].values[i]}(proposals[proposalId].calldatas[i]);
            if (!success) {
                revert DAO__ExecutionFailed();
            }
        }

        activeProposalCount--;
        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancel a proposal (only proposer can cancel)
    /// @param proposalId Proposal ID
    function cancel(uint256 proposalId) external {
        if (proposals[proposalId].proposer != msg.sender) {
            revert DAO__InvalidProposal();
        }

        if (proposals[proposalId].executed) {
            revert DAO__ProposalAlreadyExecuted();
        }

        if (proposals[proposalId].canceled) {
            revert DAO__ProposalAlreadyCanceled();
        }

        proposals[proposalId].canceled = true;
        activeProposalCount--;

        emit ProposalCanceled(proposalId);
    }

    /// @notice Get proposal state
    /// @param proposalId Proposal ID
    /// @return Proposal state
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        if (proposals[proposalId].proposer == address(0)) {
            revert DAO__ProposalNotFound();
        }

        if (proposals[proposalId].canceled) {
            return ProposalState.Canceled;
        }

        if (proposals[proposalId].executed) {
            return ProposalState.Executed;
        }

        if (block.number < proposals[proposalId].startBlock) {
            return ProposalState.Pending;
        }

        if (block.number > proposals[proposalId].endBlock) {
            if (
                proposals[proposalId].forVotes > proposals[proposalId].againstVotes
                    && proposals[proposalId].forVotes >= quorumVotes
            ) {
                return ProposalState.Succeeded;
            } else {
                return ProposalState.Defeated;
            }
        }

        return ProposalState.Active;
    }

    /// @notice Get receipt for a voter on a proposal
    /// @param proposalId Proposal ID
    /// @param voter Voter address
    /// @return Receipt struct
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    /// @notice Internal function to create proposal
    /// @param proposer Proposer address
    /// @param description Proposal description
    /// @param targets Target addresses
    /// @param values ETH values
    /// @param signatures Function signatures
    /// @param calldatas Calldata
    /// @return proposalId Created proposal ID
    function _propose(
        address proposer,
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) internal returns (uint256 proposalId) {
        proposalId = _getNextProposalId();
        Proposal storage p = proposals[proposalId];
        p.id = proposalId;
        p.proposer = proposer;
        p.description = description;
        p.targets = targets;
        p.values = values;
        p.signatures = signatures;
        p.calldatas = calldatas;
        p.startBlock = block.number + 1;
        p.endBlock = block.number + votingPeriod;
        p.forVotes = 0;
        p.againstVotes = 0;
        p.executed = false;
        p.canceled = false;
        latestProposalIds[proposer] = proposalId;
        activeProposalCount++;
        emit ProposalCreated(
            proposalId, proposer, description, targets, values, signatures, calldatas, p.startBlock, p.endBlock
        );
    }

    /// @notice Get next proposal ID
    /// @return Next proposal ID
    function _getNextProposalId() internal view returns (uint256) {
        uint256 proposalId = 0;
        while (proposals[proposalId].proposer != address(0)) {
            proposalId++;
        }
        return proposalId;
    }

    /// @notice Update DAO parameters (only callable by successful proposals)
    /// @param _proposalThreshold New proposal threshold
    /// @param _votingPeriod New voting period
    /// @param _quorumVotes New quorum votes
    /// @param _timelockDelay New timelock delay
    /// @param _maxActiveProposals New max active proposals
    function updateParameters(
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _quorumVotes,
        uint256 _timelockDelay,
        uint256 _maxActiveProposals
    ) external {
        // This function can only be called through successful proposals
        require(msg.sender == address(this), "DAO: Only self-call allowed");

        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        quorumVotes = _quorumVotes;
        timelockDelay = _timelockDelay;
        maxActiveProposals = _maxActiveProposals;
    }

    /// @notice Update ShadowPool address (only callable by successful proposals)
    /// @param _newShadowPoolAddress New ShadowPool address
    function updateShadowPoolAddress(address _newShadowPoolAddress) external {
        // This function can only be called through successful proposals
        require(msg.sender == address(this), "DAO: Only self-call allowed");

        shadowPool = ShadowPool(_newShadowPoolAddress);
    }

    /// @notice Allow DAO to receive ETH (for fees from ShadowPool)
    receive() external payable {}

    /// @notice Get forVotes for a proposal
    function getForVotes(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].forVotes;
    }
    /// @notice Get againstVotes for a proposal

    function getAgainstVotes(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].againstVotes;
    }
    /// @notice Get executed status for a proposal

    function getExecuted(uint256 proposalId) external view returns (bool) {
        return proposals[proposalId].executed;
    }
    /// @notice Get canceled status for a proposal

    function getCanceled(uint256 proposalId) external view returns (bool) {
        return proposals[proposalId].canceled;
    }
    /// @notice Get proposer for a proposal

    function getProposer(uint256 proposalId) external view returns (address) {
        return proposals[proposalId].proposer;
    }
    /// @notice Get description for a proposal

    function getDescription(uint256 proposalId) external view returns (string memory) {
        return proposals[proposalId].description;
    }
    /// @notice Get targets for a proposal

    function getTargets(uint256 proposalId) external view returns (address[] memory) {
        return proposals[proposalId].targets;
    }
    /// @notice Get values for a proposal

    function getValues(uint256 proposalId) external view returns (uint256[] memory) {
        return proposals[proposalId].values;
    }
    /// @notice Get signatures for a proposal

    function getSignatures(uint256 proposalId) external view returns (string[] memory) {
        return proposals[proposalId].signatures;
    }
    /// @notice Get calldatas for a proposal

    function getCalldatas(uint256 proposalId) external view returns (bytes[] memory) {
        return proposals[proposalId].calldatas;
    }
    /// @notice Get startBlock for a proposal

    function getStartBlock(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].startBlock;
    }
    /// @notice Get endBlock for a proposal

    function getEndBlock(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].endBlock;
    }
}
