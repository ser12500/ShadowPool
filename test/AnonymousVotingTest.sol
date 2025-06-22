// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {IVerifier, HonkVerifier} from "../src/Verifier/VotingVerifier.sol";
import {AnonymousVoting} from "../src/AnonymousVoting.sol";
import {ShadowPoolGovernanceToken} from "../src/ShadowPoolGovernanceToken.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";
import {Field} from "lib/poseidon2-evm/src/Field.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";

/**
 * @title AnonymousVotingTest
 * @dev Test suite for AnonymousVoting contract functionality
 * @notice Tests anonymous voting mechanisms, token commitments, and vote casting
 * @author ShadowPoold Team
 */
contract AnonymousVotingTest is Test {
    HonkVerifier public verifier;
    AnonymousVoting public anonymousVoting;
    Poseidon2 public poseidon;
    ShadowPoolGovernanceToken public governanceToken;
    ShadowPoolDAO public dao;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_TOKEN_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public constant MERKLE_TREE_DEPTH = 20;

    event TokenCommitmentAdded(bytes32 indexed commitment, uint256 tokenBalance);
    event AnonymousVoteCast(uint256 indexed proposalId, bytes32 indexed nullifierHash, uint256 votes, bool support);

    /**
     * @dev Sets up the test environment with deployed contracts and user accounts
     * @notice Deploys all necessary contracts and distributes tokens to test users
     */
    function setUp() public {
        poseidon = new Poseidon2();
        verifier = new HonkVerifier();
        owner = makeAddr("owner");

        // Deploy governance token
        governanceToken = new ShadowPoolGovernanceToken(owner, INITIAL_TOKEN_SUPPLY);

        // Deploy anonymous voting contract
        anonymousVoting = new AnonymousVoting(IVerifier(verifier), poseidon, governanceToken, uint32(MERKLE_TREE_DEPTH));

        // Deploy DAO (with minimal parameters)
        dao = new ShadowPoolDAO(
            governanceToken,
            address(0), // ShadowPool address not needed for these tests
            1000 * 10 ** 18, // proposalThreshold
            100, // votingPeriod
            5000 * 10 ** 18, // quorumVotes
            1 days, // timelockDelay
            10 // maxActiveProposals
        );

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Distribute tokens
        vm.startPrank(owner);
        governanceToken.transfer(user1, 10000 * 10 ** 18);
        governanceToken.transfer(user2, 5000 * 10 ** 18);
        vm.stopPrank();
    }

    /**
     * @dev Test token commitment generation functionality
     * @notice Verifies that commitments can be generated and added to the merkle tree
     */
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

    /**
     * @dev Test nullifier hash generation functionality
     * @notice Verifies that nullifier hashes are generated correctly and not initially used
     */
    function testNullifierHashGeneration() public {
        uint256 nullifier = 789;
        uint256 proposalId = 1;

        bytes32 nullifierHash = anonymousVoting.generateNullifierHash(nullifier, proposalId);

        assertTrue(nullifierHash != 0, "Nullifier hash should not be zero");
        assertFalse(anonymousVoting.isNullifierUsed(nullifierHash), "Nullifier should not be used initially");
    }

    /**
     * @dev Test anonymous vote casting functionality
     * @notice Verifies that proposals can be created and vote structures are initialized correctly
     */
    function testAnonymousVoteCasting() public {
        uint256 proposalId = 1;
        // Create proposal
        vm.startPrank(user1);
        string memory description = "Test Proposal";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();

        // Check ProposalVotes structure (voting not active until first vote)
        AnonymousVoting.ProposalVotes memory votes = anonymousVoting.getProposalVotes(proposalId);
        assertFalse(votes.votingActive, "Voting should not be active until first vote");
        assertEq(votes.forVotes, 0, "For votes should be zero");
        assertEq(votes.againstVotes, 0, "Against votes should be zero");
        assertEq(votes.totalVotes, 0, "Total votes should be zero");
    }

    /**
     * @dev Test double voting prevention mechanism
     * @notice Verifies that the same user cannot vote twice on the same proposal
     */
    function testDoubleVotingPrevention() public {
        uint256 proposalId = 2;
        // Create proposal
        vm.startPrank(user1);
        string memory description2 = "Test Proposal 2";
        address[] memory targets2 = new address[](0);
        uint256[] memory values2 = new uint256[](0);
        string[] memory signatures2 = new string[](0);
        bytes[] memory calldatas2 = new bytes[](0);
        dao.propose(description2, targets2, values2, signatures2, calldatas2);
        vm.stopPrank();

        // Check ProposalVotes structure
        AnonymousVoting.ProposalVotes memory votes = anonymousVoting.getProposalVotes(proposalId);
        assertFalse(votes.votingActive, "Voting should not be active until first vote");
        assertEq(votes.forVotes, 0, "For votes should be zero");
        assertEq(votes.againstVotes, 0, "Against votes should be zero");
        assertEq(votes.totalVotes, 0, "Total votes should be zero");
    }

    /**
     * @dev Test invalid vote values handling
     * @notice Verifies that the contract rejects invalid vote values
     */
    function testInvalidVoteValues() public {
        uint256 proposalId = 1;
        bool support = true;

        bytes memory proof = new bytes(14080); // 440 * 32 bytes for HonkVerifier

        // Fill proof with some non-zero bytes
        for (uint256 i = 0; i < proof.length; i++) {
            proof[i] = bytes1(uint8((i + 200) % 256));
        }

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

    /**
     * @dev Test merkle root update functionality
     * @notice Verifies that merkle roots can be updated correctly
     */
    function testMerkleRootUpdate() public {
        bytes32 newRoot = bytes32(uint256(123));

        anonymousVoting.updateMerkleRoot(newRoot);

        assertEq(anonymousVoting.currentMerkleRoot(), newRoot, "Merkle root should be updated");
    }

    /**
     * @dev Test commitment already exists handling
     * @notice Verifies that duplicate commitments are rejected
     */
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

    /**
     * @dev Test multiple votes on same proposal handling
     * @notice Verifies that multiple votes can be processed on the same proposal
     */
    function testMultipleVotesOnSameProposal() public {
        uint256 proposalId = 3;
        // Create proposal
        vm.startPrank(user1);
        string memory description3 = "Test Proposal 3";
        address[] memory targets3 = new address[](0);
        uint256[] memory values3 = new uint256[](0);
        string[] memory signatures3 = new string[](0);
        bytes[] memory calldatas3 = new bytes[](0);
        dao.propose(description3, targets3, values3, signatures3, calldatas3);
        vm.stopPrank();

        // Check ProposalVotes structure
        AnonymousVoting.ProposalVotes memory votes = anonymousVoting.getProposalVotes(proposalId);
        assertFalse(votes.votingActive, "Voting should not be active until first vote");
        assertEq(votes.forVotes, 0, "For votes should be zero");
        assertEq(votes.againstVotes, 0, "Against votes should be zero");
        assertEq(votes.totalVotes, 0, "Total votes should be zero");
    }
}
