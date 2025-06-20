// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {IVotingVerifier, VotingVerifier} from "../src/Verifier/VotingVerifier.sol";
import {AnonymousVoting} from "../src/AnonymousVoting.sol";
import {ShadowPoolGovernanceToken} from "../src/ShadowPoolGovernanceToken.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";
import {Field} from "lib/poseidon2-evm/src/Field.sol";
import {MockERC20} from "./mock/MockERC20.sol";

contract AnonymousVotingTest is Test {
    VotingVerifier public verifier;
    AnonymousVoting public anonymousVoting;
    Poseidon2 public poseidon;
    ShadowPoolGovernanceToken public governanceToken;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_TOKEN_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public constant MERKLE_TREE_DEPTH = 20;

    event TokenCommitmentAdded(bytes32 indexed commitment, uint256 tokenBalance);
    event AnonymousVoteCast(uint256 indexed proposalId, bytes32 indexed nullifierHash, uint256 votes, bool support);

    function setUp() public {
        poseidon = new Poseidon2();
        verifier = new VotingVerifier();
        owner = makeAddr("owner");

        // Deploy governance token
        governanceToken = new ShadowPoolGovernanceToken(owner, INITIAL_TOKEN_SUPPLY);

        // Deploy anonymous voting contract
        anonymousVoting =
            new AnonymousVoting(IVotingVerifier(verifier), poseidon, governanceToken, uint32(MERKLE_TREE_DEPTH));

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Distribute tokens
        vm.startPrank(owner);
        governanceToken.transfer(user1, 10000 * 10 ** 18);
        governanceToken.transfer(user2, 5000 * 10 ** 18);
        vm.stopPrank();
    }

    /// @notice Test token commitment generation
    function testTokenCommitmentGeneration() public {
        uint256 nullifier = 123;
        uint256 secret = 456;
        uint256 tokenBalance = 1000 * 10 ** 18;

        bytes32 commitment = anonymousVoting.generateCommitment(nullifier, secret, tokenBalance);

        assertTrue(commitment != 0, "Commitment should not be zero");

        // Add commitment to merkle tree
        anonymousVoting.addTokenCommitment(commitment, tokenBalance);

        assertTrue(anonymousVoting.tokenCommitments(commitment), "Commitment should be added");
    }

    /// @notice Test nullifier hash generation
    function testNullifierHashGeneration() public {
        uint256 nullifier = 789;
        uint256 proposalId = 1;

        bytes32 nullifierHash = anonymousVoting.generateNullifierHash(nullifier, proposalId);

        assertTrue(nullifierHash != 0, "Nullifier hash should not be zero");
        assertFalse(anonymousVoting.isNullifierUsed(nullifierHash), "Nullifier should not be used initially");
    }

    /// @notice Test anonymous vote casting
    function testAnonymousVoteCasting() public {
        uint256 proposalId = 1;
        bool support = true;

        // Mock proof and public inputs
        bytes memory proof = new bytes(100);
        bytes32[] memory publicInputs = new bytes32[](5);

        // Set up public inputs
        publicInputs[0] = bytes32(proposalId); // proposal_id
        publicInputs[1] = bytes32(0); // merkle_root
        publicInputs[2] = bytes32(uint256(123)); // nullifier_hash
        publicInputs[3] = bytes32(uint256(1)); // vote_result (1 = support)
        publicInputs[4] = bytes32(uint256(1000 * 10 ** 18)); // total_votes

        // Cast anonymous vote
        anonymousVoting.castAnonymousVote(proposalId, proof, publicInputs, support);

        // Check that nullifier is marked as used
        assertTrue(anonymousVoting.isNullifierUsed(publicInputs[2]), "Nullifier should be marked as used");

        // Get proposal votes
        AnonymousVoting.ProposalVotes memory votes = anonymousVoting.getProposalVotes(proposalId);
        assertTrue(votes.votingActive, "Voting should be active");
        assertEq(votes.forVotes, 1000 * 10 ** 18, "For votes should match");
        assertEq(votes.againstVotes, 0, "Against votes should be zero");
        assertEq(votes.totalVotes, 1000 * 10 ** 18, "Total votes should match");
    }

    /// @notice Test double voting prevention
    function testDoubleVotingPrevention() public {
        uint256 proposalId = 1;
        bool support = true;

        bytes memory proof = new bytes(100);
        bytes32[] memory publicInputs = new bytes32[](5);

        publicInputs[0] = bytes32(proposalId);
        publicInputs[1] = bytes32(0);
        publicInputs[2] = bytes32(uint256(456)); // nullifier_hash
        publicInputs[3] = bytes32(uint256(1));
        publicInputs[4] = bytes32(uint256(1000 * 10 ** 18));

        // First vote should succeed
        anonymousVoting.castAnonymousVote(proposalId, proof, publicInputs, support);

        // Second vote with same nullifier should fail
        vm.expectRevert();
        anonymousVoting.castAnonymousVote(proposalId, proof, publicInputs, support);
    }

    /// @notice Test invalid vote values
    function testInvalidVoteValues() public {
        uint256 proposalId = 1;
        bool support = true;

        bytes memory proof = new bytes(100);
        bytes32[] memory publicInputs = new bytes32[](5);

        publicInputs[0] = bytes32(proposalId);
        publicInputs[1] = bytes32(0);
        publicInputs[2] = bytes32(uint256(789));
        publicInputs[3] = bytes32(uint256(2)); // Invalid vote value (should be 0 or 1)
        publicInputs[4] = bytes32(uint256(1000 * 10 ** 18));

        // Should revert due to invalid vote value
        vm.expectRevert();
        anonymousVoting.castAnonymousVote(proposalId, proof, publicInputs, support);
    }

    /// @notice Test merkle root update
    function testMerkleRootUpdate() public {
        bytes32 newRoot = bytes32(uint256(123));

        anonymousVoting.updateMerkleRoot(newRoot);

        assertEq(anonymousVoting.currentMerkleRoot(), newRoot, "Merkle root should be updated");
    }

    /// @notice Test commitment already exists
    function testCommitmentAlreadyExists() public {
        uint256 nullifier = 123;
        uint256 secret = 456;
        uint256 tokenBalance = 1000 * 10 ** 18;

        bytes32 commitment = anonymousVoting.generateCommitment(nullifier, secret, tokenBalance);

        // Add commitment first time
        anonymousVoting.addTokenCommitment(commitment, tokenBalance);

        // Try to add same commitment again
        vm.expectRevert();
        anonymousVoting.addTokenCommitment(commitment, tokenBalance);
    }

    /// @notice Test multiple votes on same proposal
    function testMultipleVotesOnSameProposal() public {
        uint256 proposalId = 1;

        // First vote - support
        bytes memory proof1 = new bytes(100);
        bytes32[] memory publicInputs1 = new bytes32[](5);
        publicInputs1[0] = bytes32(proposalId);
        publicInputs1[1] = bytes32(0);
        publicInputs1[2] = bytes32(uint256(123));
        publicInputs1[3] = bytes32(uint256(1));
        publicInputs1[4] = bytes32(uint256(1000 * 10 ** 18));

        anonymousVoting.castAnonymousVote(proposalId, proof1, publicInputs1, true);

        // Second vote - against
        bytes memory proof2 = new bytes(100);
        bytes32[] memory publicInputs2 = new bytes32[](5);
        publicInputs2[0] = bytes32(proposalId);
        publicInputs2[1] = bytes32(0);
        publicInputs2[2] = bytes32(uint256(456));
        publicInputs2[3] = bytes32(uint256(0));
        publicInputs2[4] = bytes32(uint256(500 * 10 ** 18));

        anonymousVoting.castAnonymousVote(proposalId, proof2, publicInputs2, false);

        // Check final vote totals
        AnonymousVoting.ProposalVotes memory votes = anonymousVoting.getProposalVotes(proposalId);
        assertEq(votes.forVotes, 1000 * 10 ** 18, "For votes should be correct");
        assertEq(votes.againstVotes, 500 * 10 ** 18, "Against votes should be correct");
        assertEq(votes.totalVotes, 1500 * 10 ** 18, "Total votes should be correct");
    }
}
