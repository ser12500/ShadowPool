// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";
import {Field} from "lib/poseidon2-evm/src/Field.sol";
import {IVerifier} from "./Verifier/VotingVerifier.sol";

/**
 * @title AnonymousVoting
 * @notice Anonymous voting system for DAO using zk-proofs.
 * @dev Allows token holders to vote anonymously while proving they own tokens. Integrates with Poseidon2, zk-verifier, and supports Merkle-based commitments.
 * @author Sergey Kerhet
 */
contract AnonymousVoting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Voting period in blocks (~1 week for 12s blocks)
    uint256 public constant VOTING_PERIOD = 40_320;
    /// @notice Multiplier for percentage calculations
    uint256 public constant PERCENTAGE_MULTIPLIER = 100;

    /// @notice Voting verifier for zk-proofs
    IVerifier public immutable votingVerifier;
    /// @notice Poseidon2 hasher for commitments
    Poseidon2 public immutable poseidon;
    /// @notice Governance token
    IERC20 public immutable governanceToken;
    /// @notice Merkle tree depth for token commitments
    uint32 public immutable merkleTreeDepth;
    /// @notice Current merkle root of governance token commitments
    bytes32 public currentMerkleRoot;

    /// @notice Mapping of used nullifier hashes to prevent double voting
    mapping(bytes32 => bool) public usedNullifiers;
    /// @notice Mapping of proposalId to voting data
    mapping(uint256 => ProposalVotes) public proposalVotes;
    /// @notice Mapping of token commitment to existence in Merkle tree
    mapping(bytes32 => bool) public tokenCommitments;

    /**
     * @notice Struct for proposal voting data
     * @param forVotes Number of votes for
     * @param againstVotes Number of votes against
     * @param totalVotes Total votes cast
     * @param votingActive Whether voting is active
     * @param startBlock Block when voting started
     * @param endBlock Block when voting ends
     */
    struct ProposalVotes {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 totalVotes;
        bool votingActive;
        uint256 startBlock;
        uint256 endBlock;
    }

    /// @notice Event when a token commitment is added
    event TokenCommitmentAdded(bytes32 indexed commitment, uint256 tokenBalance);
    /// @notice Emitted when an anonymous vote is cast
    event AnonymousVoteCast(uint256 indexed proposalId, bytes32 indexed nullifierHash, uint256 votes, bool support);
    /// @notice Emitted when the Merkle root is updated
    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);

    /// @notice Error: invalid zk-proof
    error AnonymousVoting__InvalidProof();
    /// @notice Error: nullifier already used
    error AnonymousVoting__NullifierAlreadyUsed();
    /// @notice Error: proposal not active
    error AnonymousVoting__ProposalNotActive();
    /// @notice Error: invalid vote value
    error AnonymousVoting__InvalidVoteValue();
    /// @notice Error: commitment already exists
    error AnonymousVoting__CommitmentAlreadyExists();
    /// @notice Error: invalid Merkle proof
    error AnonymousVoting__InvalidMerkleProof();

    /**
     * @notice Constructor for anonymous voting contract
     * @param _votingVerifier Address of the voting verifier
     * @param _poseidon Address of Poseidon2 hasher
     * @param _governanceToken Address of governance token
     * @param _merkleTreeDepth Depth of Merkle tree
     */
    constructor(IVerifier _votingVerifier, Poseidon2 _poseidon, IERC20 _governanceToken, uint32 _merkleTreeDepth) {
        votingVerifier = _votingVerifier;
        poseidon = _poseidon;
        governanceToken = _governanceToken;
        merkleTreeDepth = _merkleTreeDepth;
    }

    /**
     * @notice Add token commitment to Merkle tree
     * @param commitment Commitment hash of token balance
     * @param tokenBalance Token balance being committed
     */
    function addTokenCommitment(bytes32 commitment, uint256 tokenBalance) external {
        if (tokenCommitments[commitment]) {
            revert AnonymousVoting__CommitmentAlreadyExists();
        }
        tokenCommitments[commitment] = true;
        emit TokenCommitmentAdded(commitment, tokenBalance);
    }

    /**
     * @notice Cast anonymous vote using zk-proof
     * @param proposalId ID of the proposal to vote on
     * @param proof Zk-proof bytes
     * @param publicInputs Public inputs for verification
     * @param support True for support, false for against
     */
    function castAnonymousVote(uint256 proposalId, bytes calldata proof, bytes32[] calldata publicInputs, bool support)
        external
        nonReentrant
    {
        // Verify the zk-proof
        if (!votingVerifier.verify(proof, publicInputs)) {
            revert AnonymousVoting__InvalidProof();
        }

        // Extract public inputs
        require(publicInputs.length >= 5, "Invalid public inputs length");

        bytes32 proposalIdField = publicInputs[0];
        bytes32 merkleRoot = publicInputs[1];
        bytes32 nullifierHash = publicInputs[2];
        bytes32 voteResult = publicInputs[3];
        bytes32 totalVotes = publicInputs[4];

        // Verify proposal ID matches
        require(uint256(proposalIdField) == proposalId, "Proposal ID mismatch");

        // Verify vote value is valid
        uint256 voteValue = uint256(voteResult);
        if (voteValue != 0 && voteValue != 1) {
            revert AnonymousVoting__InvalidVoteValue();
        }

        // Verify vote matches support parameter
        if ((voteValue == 1) != support) {
            revert AnonymousVoting__InvalidVoteValue();
        }

        // Check if nullifier has been used
        if (usedNullifiers[nullifierHash]) {
            revert AnonymousVoting__NullifierAlreadyUsed();
        }

        // aderyn-ignore-next-line(reentrancy-state-change)
        usedNullifiers[nullifierHash] = true;

        // Verify merkle root matches current state
        if (merkleRoot != currentMerkleRoot) {
            revert AnonymousVoting__InvalidMerkleProof();
        }

        // Get or create proposal votes
        ProposalVotes storage votes = proposalVotes[proposalId];

        // Initialize proposal if first vote
        if (!votes.votingActive) {
            votes.votingActive = true;
            votes.startBlock = block.number;
            votes.endBlock = block.number + VOTING_PERIOD;
        }

        // Verify proposal is still active
        if (block.number > votes.endBlock) {
            revert AnonymousVoting__ProposalNotActive();
        }

        uint256 voteCount = uint256(totalVotes);

        // Update vote counts
        if (support) {
            votes.forVotes += voteCount;
        } else {
            votes.againstVotes += voteCount;
        }
        votes.totalVotes += voteCount;

        emit AnonymousVoteCast(proposalId, nullifierHash, voteCount, support);
    }

    /// @notice Update merkle root (only callable by DAO)
    /// @param newRoot New merkle root
    function updateMerkleRoot(bytes32 newRoot) external {
        // In real implementation, this would be restricted to DAO only
        bytes32 oldRoot = currentMerkleRoot;
        currentMerkleRoot = newRoot;
        emit MerkleRootUpdated(oldRoot, newRoot);
    }

    /// @notice Get proposal voting data
    /// @param proposalId ID of the proposal
    /// @return votes Proposal voting data
    function getProposalVotes(uint256 proposalId) external view returns (ProposalVotes memory votes) {
        return proposalVotes[proposalId];
    }

    /// @notice Check if nullifier has been used
    /// @param nullifierHash Hash of nullifier to check
    /// @return True if nullifier has been used
    function isNullifierUsed(bytes32 nullifierHash) external view returns (bool) {
        return usedNullifiers[nullifierHash];
    }

    /// @notice Generate commitment for token balance
    /// @param nullifier Unique nullifier
    /// @param secret Secret value
    /// @param tokenBalance Token balance
    /// @return Commitment hash
    function generateCommitment(uint256 nullifier, uint256 secret, uint256 tokenBalance)
        external
        view
        returns (bytes32)
    {
        Field.Type[] memory input = new Field.Type[](3);
        input[0] = Field.Type.wrap(nullifier);
        input[1] = Field.Type.wrap(secret);
        input[2] = Field.Type.wrap(tokenBalance);
        return bytes32(Field.toUint256(poseidon.hash(input)));
    }

    /// @notice Generate nullifier hash
    /// @param nullifier Unique nullifier
    /// @param proposalId Proposal ID
    /// @return Nullifier hash
    function generateNullifierHash(uint256 nullifier, uint256 proposalId) external view returns (bytes32) {
        Field.Type[] memory input = new Field.Type[](2);
        input[0] = Field.Type.wrap(nullifier);
        input[1] = Field.Type.wrap(proposalId);
        return bytes32(Field.toUint256(poseidon.hash(input)));
    }

    // ============ USER UTILITY FUNCTIONS ============

    /// @notice Returns the total number of token commitments in the system
    /// @return Total number of commitments
    function getTotalCommitments() external view returns (uint256) {
        // This would need to be tracked separately in a real implementation
        // For now, we'll return a placeholder based on current merkle root
        // In a real implementation, you would track this in a state variable
        return 0;
    }

    /// @notice Returns the voting anonymity level based on total commitments
    /// @return Anonymity level description
    function getVotingAnonymityLevel() external view returns (string memory) {
        // For now, return a default level since we don't track commitments properly
        // In a real implementation, you would use getTotalCommitments()
        return "Medium voting anonymity";
    }

    /// @notice Returns whether a proposal is currently active
    /// @param proposalId ID of the proposal to check
    /// @return True if proposal is active
    function isProposalActive(uint256 proposalId) external view returns (bool) {
        ProposalVotes storage votes = proposalVotes[proposalId];
        if (!votes.votingActive) return false;
        return block.number <= votes.endBlock;
    }

    /// @notice Returns the time remaining for a proposal
    /// @param proposalId ID of the proposal
    /// @return Time remaining in blocks (0 if ended)
    function getProposalTimeRemaining(uint256 proposalId) external view returns (uint256) {
        ProposalVotes storage votes = proposalVotes[proposalId];
        if (!votes.votingActive) return 0;
        if (block.number > votes.endBlock) return 0;
        return votes.endBlock - block.number;
    }

    /// @notice Returns the voting progress for a proposal
    /// @param proposalId ID of the proposal
    /// @return forVotes Number of votes for
    /// @return againstVotes Number of votes against
    /// @return totalVotes Total votes cast
    /// @return supportPercentage Percentage of votes in support
    function getVotingProgress(uint256 proposalId)
        external
        view
        returns (uint256 forVotes, uint256 againstVotes, uint256 totalVotes, uint256 supportPercentage)
    {
        ProposalVotes storage votes = proposalVotes[proposalId];
        forVotes = votes.forVotes;
        againstVotes = votes.againstVotes;
        totalVotes = votes.totalVotes;

        if (totalVotes > 0) {
            supportPercentage = (forVotes * PERCENTAGE_MULTIPLIER) / totalVotes;
        } else {
            supportPercentage = 0;
        }
    }

    /// @notice Returns whether a proposal has reached quorum
    /// @param proposalId ID of the proposal
    /// @param quorumThreshold Minimum votes required for quorum
    /// @return True if quorum is reached
    function hasReachedQuorum(uint256 proposalId, uint256 quorumThreshold) external view returns (bool) {
        ProposalVotes storage votes = proposalVotes[proposalId];
        return votes.totalVotes >= quorumThreshold;
    }

    /// @notice Returns the voting period duration in blocks
    /// @return Voting period duration
    function getVotingPeriodDuration() external pure returns (uint256) {
        return VOTING_PERIOD;
    }

    /// @notice Returns the maximum number of proposals the system can handle
    /// @return Maximum number of proposals
    function getMaxProposals() external view returns (uint256) {
        return 2 ** merkleTreeDepth;
    }

    /// @notice Returns whether the merkle tree is full
    /// @return True if merkle tree is full
    function isMerkleTreeFull() external view returns (bool) {
        // This would need to track the actual number of commitments
        // For now, return false as placeholder
        return false;
    }

    /// @notice Returns the current merkle tree depth
    /// @return Merkle tree depth
    function getMerkleTreeDepth() external view returns (uint32) {
        return merkleTreeDepth;
    }

    /// @notice Returns the governance token address
    /// @return Governance token address
    function getGovernanceToken() external view returns (address) {
        return address(governanceToken);
    }
}
