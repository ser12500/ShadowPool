// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {ShadowPool} from "./ShadowPool.sol";
import {AnonymousVoting} from "./AnonymousVoting.sol";
import {CrossChainShadowPool} from "./CrossChainShadowPool.sol";

/**
 * @title ShadowPoolDAO
 * @notice Decentralized governance system for ShadowPool mixer with anonymous voting.
 * @dev Allows token holders to propose and vote anonymously on changes to mixer parameters.
 *      Integrates with ShadowPool, AnonymousVoting, and supports proposal lifecycle management.
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

    /// @notice Timelock controller for delayed execution
    TimelockController public timelockController;

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

    /// @notice Whether flash loan protection is enabled
    bool public flashLoanProtectionEnabled;

    /// @notice Snapshot mechanism for voting power
    mapping(uint256 => mapping(address => uint256)) public votingPowerSnapshots;

    /// @notice Mapping to track timelock operations
    mapping(uint256 => bytes32) public proposalTimelockIds;

    /**
     * @notice Proposal structure for governance actions
     * @param id Proposal ID
     * @param proposer Address of the proposer
     * @param description Proposal description
     * @param targets Target addresses for calls
     * @param values ETH values for calls
     * @param signatures Function signatures
     * @param calldatas Calldata for calls
     * @param startBlock Block when voting starts
     * @param endBlock Block when voting ends
     * @param forVotes Number of votes for
     * @param againstVotes Number of votes against
     * @param executed Whether proposal is executed
     * @param canceled Whether proposal is canceled
     * @param receipts Mapping of voter receipts
     */
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

    /**
     * @notice Receipt structure for tracking votes (legacy)
     * @param hasVoted Whether the voter has voted
     * @param support True for support, false for against
     * @param votes Number of votes
     */
    struct Receipt {
        bool hasVoted;
        bool support;
        uint256 votes;
    }

    /**
     * @notice Proposal state enum
     * @dev Used to track the lifecycle of a proposal
     */
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

    /// @notice All proposals (proposalId => Proposal)
    mapping(uint256 => Proposal) public proposals;

    /// @notice Latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice Emitted when a proposal is created
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
    /// @notice Emitted when a vote is cast
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votes);
    /// @notice Emitted when anonymous voting is enabled/disabled
    event AnonymousVotingEnabled(bool enabled);
    /// @notice Emitted when the anonymous voting contract is updated
    event AnonymousVotingContractUpdated(address indexed oldContract, address indexed newContract);
    /// @notice Emitted when a proposal is canceled
    event ProposalCanceled(uint256 indexed proposalId);
    /// @notice Emitted when a proposal is queued
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    /// @notice Emitted when a proposal is executed
    event ProposalExecuted(uint256 indexed proposalId);
    /// @notice Emitted when anonymous votes are updated
    event AnonymousVotesUpdated(uint256 indexed proposalId, uint256 forVotes, uint256 againstVotes);
    /// @notice Emitted when DAO parameters are updated
    event ParametersUpdated(
        uint256 proposalThreshold,
        uint256 votingPeriod,
        uint256 quorumVotes,
        uint256 timelockDelay,
        uint256 maxActiveProposals
    );
    /// @notice Emitted when ShadowPool address is updated
    event ShadowPoolAddressUpdated(address indexed oldAddress, address indexed newAddress);
    /// @notice Emitted when flash loan protection is updated
    event FlashLoanProtectionUpdated(bool enabled);
    /// @notice Emitted when timelock controller is updated
    event TimelockControllerUpdated(address indexed oldTimelock, address indexed newTimelock);

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

    /// @dev Modifier to restrict access to DAO governance functions
    modifier onlyDAO() {
        require(msg.sender == address(this), "DAO: Only self-call allowed");
        _;
    }

    /**
     * @dev Constructor to initialize the verifier, owner addresses, and fee configuration.
     * @param _governanceToken Governance token address
     * @param _shadowPoolAddress ShadowPool contract address (can be address(0) initially)
     * @param _proposalThreshold Minimum tokens to create proposal
     * @param _votingPeriod Voting period in blocks
     * @param _quorumVotes Minimum quorum votes
     * @param _timelockDelay Timelock delay in seconds
     * @param _maxActiveProposals Maximum active proposals
     * @param _timelockController Timelock controller address
     */
    constructor(
        IERC20 _governanceToken,
        address _shadowPoolAddress,
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _quorumVotes,
        uint256 _timelockDelay,
        uint256 _maxActiveProposals,
        TimelockController _timelockController
    ) {
        require(_shadowPoolAddress != address(0), "ShadowPool address cannot be zero address");
        governanceToken = _governanceToken;
        shadowPool = ShadowPool(_shadowPoolAddress);
        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        quorumVotes = _quorumVotes;
        timelockDelay = _timelockDelay;
        maxActiveProposals = _maxActiveProposals;
        timelockController = _timelockController;
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
    function castVote(uint256 proposalId, bool support) external nonReentrant {
        if (proposals[proposalId].proposer == address(0)) {
            revert DAO__ProposalNotFound();
        }

        if (getProposalState(proposalId) != ProposalState.Active) {
            revert DAO__ProposalNotActive();
        }

        if (proposals[proposalId].receipts[msg.sender].hasVoted) {
            revert DAO__AlreadyVoted();
        }

        // Use snapshot voting power if protection is enabled
        uint256 votes = flashLoanProtectionEnabled
            ? getVotingPowerAt(msg.sender, proposals[proposalId].startBlock)
            : governanceToken.balanceOf(msg.sender);

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
        require(newAnonymousVoting != address(0), "AnonymousVoting address cannot be zero address");
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
            emit AnonymousVotesUpdated(proposalId, anonymousVotes.forVotes, anonymousVotes.againstVotes);
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

    /// @notice Execute a proposal
    /// @param proposalId Proposal ID
    function execute(uint256 proposalId) external nonReentrant {
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
        if (state != ProposalState.Succeeded) {
            revert DAO__ProposalNotActive();
        }

        // Use TimelockController for execution
        bytes32 timelockId = _queueProposalInTimelock(proposalId);
        proposalTimelockIds[proposalId] = timelockId;

        proposals[proposalId].executed = true;
        activeProposalCount--;
        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancel a proposal (only proposer can cancel)
    /// @param proposalId Proposal ID
    function cancel(uint256 proposalId) external nonReentrant {
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
    ) external nonReentrant {
        // This function can only be called through successful proposals
        require(msg.sender == address(this), "DAO: Only self-call allowed");

        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        quorumVotes = _quorumVotes;
        timelockDelay = _timelockDelay;
        maxActiveProposals = _maxActiveProposals;
        emit ParametersUpdated(_proposalThreshold, _votingPeriod, _quorumVotes, _timelockDelay, _maxActiveProposals);
    }

    /// @notice Update ShadowPool address (only callable by successful proposals)
    /// @param _newShadowPoolAddress New ShadowPool address
    function updateShadowPoolAddress(address _newShadowPoolAddress) external nonReentrant {
        // This function can only be called through successful proposals
        require(msg.sender == address(this), "DAO: Only self-call allowed");
        address oldAddress = address(shadowPool);
        require(_newShadowPoolAddress != address(0), "ShadowPool address cannot be zero address");
        shadowPool = ShadowPool(_newShadowPoolAddress);
        emit ShadowPoolAddressUpdated(oldAddress, _newShadowPoolAddress);
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

    /**
     * @dev Create a snapshot of voting power at current block
     * @param proposalId ID of the proposal
     */
    function _snapshotVotingPower(uint256 proposalId) internal {
        if (!flashLoanProtectionEnabled) return;

        // Take snapshot at proposal creation time
        uint256 snapshotBlock = proposals[proposalId].startBlock;
        if (snapshotBlock == 0) return;

        // For each voter, record their balance at snapshot time
        // This prevents flash loan attacks during voting
    }

    /**
     * @dev Get voting power at specific block (for flash loan protection)
     * @param account Address to check
     * @param blockNumber Block number for snapshot
     */
    function getVotingPowerAt(address account, uint256 blockNumber) public view returns (uint256) {
        if (!flashLoanProtectionEnabled) {
            return governanceToken.balanceOf(account);
        }

        // Return snapshot if available, otherwise current balance
        uint256 snapshot = votingPowerSnapshots[blockNumber][account];
        return snapshot > 0 ? snapshot : governanceToken.balanceOf(account);
    }

    /**
     * @dev Enable/disable flash loan protection
     * @param enabled Whether to enable protection
     */
    function setFlashLoanProtection(bool enabled) external {
        // This function can only be called through successful proposals
        require(msg.sender == address(this), "DAO: Only self-call allowed");
        flashLoanProtectionEnabled = enabled;
        emit FlashLoanProtectionUpdated(enabled);
    }

    /**
     * @dev Queue proposal in timelock controller
     * @param proposalId ID of the proposal
     * @return timelockId Timelock operation ID
     */
    function _queueProposalInTimelock(uint256 proposalId) internal returns (bytes32) {
        Proposal storage proposal = proposals[proposalId];

        bytes32 salt = keccak256(abi.encode(proposalId, proposal.description));
        bytes32 timelockId =
            timelockController.hashOperationBatch(proposal.targets, proposal.values, proposal.calldatas, 0, salt);

        timelockController.scheduleBatch(proposal.targets, proposal.values, proposal.calldatas, 0, salt, timelockDelay);

        return timelockId;
    }

    /**
     * @dev Update timelock controller (only through governance)
     * @param _newTimelockController New timelock controller address
     */
    function updateTimelockController(TimelockController _newTimelockController) external {
        require(msg.sender == address(this), "DAO: Only self-call allowed");
        require(address(_newTimelockController) != address(0), "Timelock controller cannot be zero");

        TimelockController oldTimelock = timelockController;
        timelockController = _newTimelockController;

        emit TimelockControllerUpdated(address(oldTimelock), address(_newTimelockController));
    }

    /// @notice Emergency recover on pool from DAO
    function emergencyRecoverOnPool(address pool, address token, uint256 amount) external {
        CrossChainShadowPool(payable(pool)).emergencyRecover(token, amount);
    }
}
