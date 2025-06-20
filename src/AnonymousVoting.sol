// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";
import {Field} from "lib/poseidon2-evm/src/Field.sol";
import {IVotingVerifier} from "./Verifier/VotingVerifier.sol";

/**
 * @title AnonymousVoting
 * @dev Anonymous voting system for DAO using zk-proofs
 * Allows token holders to vote anonymously while proving they own tokens
 */
contract AnonymousVoting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Voting verifier for zk-proofs
    IVotingVerifier public immutable votingVerifier;

    /// @notice Poseidon2 hasher for commitments
    Poseidon2 public immutable poseidon;

    /// @notice Governance token
    IERC20 public immutable governanceToken;

    /// @notice Merkle tree depth for token commitments
    uint32 public immutable merkleTreeDepth;

    /// @notice Current merkle root of governance token commitments
    bytes32 public currentMerkleRoot;

    /// @notice Used nullifier hashes to prevent double voting
    mapping(bytes32 => bool) public usedNullifiers;

    /// @notice Proposal voting data
    mapping(uint256 => ProposalVotes) public proposalVotes;

    /// @notice Token commitment to merkle tree mapping
    mapping(bytes32 => bool) public tokenCommitments;

    /// @notice Struct for proposal voting data
    struct ProposalVotes {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 totalVotes;
        bool votingActive;
        uint256 startBlock;
        uint256 endBlock;
    }

    /// @notice Events
    event TokenCommitmentAdded(bytes32 indexed commitment, uint256 tokenBalance);
    event AnonymousVoteCast(uint256 indexed proposalId, bytes32 indexed nullifierHash, uint256 votes, bool support);
    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);

    /// @notice Errors
    error AnonymousVoting__InvalidProof();
    error AnonymousVoting__NullifierAlreadyUsed();
    error AnonymousVoting__ProposalNotActive();
    error AnonymousVoting__InvalidVoteValue();
    error AnonymousVoting__CommitmentAlreadyExists();
    error AnonymousVoting__InvalidMerkleProof();

    /// @notice Constructor
    /// @param _votingVerifier Address of the voting verifier
    /// @param _poseidon Address of Poseidon2 hasher
    /// @param _governanceToken Address of governance token
    /// @param _merkleTreeDepth Depth of merkle tree
    constructor(
        IVotingVerifier _votingVerifier,
        Poseidon2 _poseidon,
        IERC20 _governanceToken,
        uint32 _merkleTreeDepth
    ) {
        votingVerifier = _votingVerifier;
        poseidon = _poseidon;
        governanceToken = _governanceToken;
        merkleTreeDepth = _merkleTreeDepth;
    }

    /// @notice Add token commitment to merkle tree
    /// @param commitment Commitment hash of token balance
    /// @param tokenBalance Token balance being committed
    function addTokenCommitment(bytes32 commitment, uint256 tokenBalance) external {
        if (tokenCommitments[commitment]) {
            revert AnonymousVoting__CommitmentAlreadyExists();
        }

        tokenCommitments[commitment] = true;
        emit TokenCommitmentAdded(commitment, tokenBalance);
    }

    /// @notice Cast anonymous vote using zk-proof
    /// @param proposalId ID of the proposal to vote on
    /// @param proof Zk-proof bytes
    /// @param publicInputs Public inputs for verification
    /// @param support True for support, false for against
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

        // Mark nullifier as used
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
            votes.endBlock = block.number + 40320; // ~1 week
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
}
