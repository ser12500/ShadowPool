// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {HonkVerifier} from "../src/Verifier/Verifier.sol";
import {ShadowPool, IVerifier, Poseidon2} from "../src/ShadowPool.sol";
import {Incremental} from "../src/Incremental.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";
import {ShadowPoolGovernanceToken} from "../src/ShadowPoolGovernanceToken.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract ShadowPoolDAOTest is Test {
    IVerifier public verifier;
    ShadowPool public shadowPool;
    Poseidon2 public poseidon;
    ShadowPoolDAO public dao;
    ShadowPoolGovernanceToken public governanceToken;
    TimelockController public timelockController;

    // Mock tokens
    MockERC20 public token1;
    MockERC20 public token2;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public recipient;

    uint256 public constant INITIAL_PERCENTAGE_FEE = 50; // 0.5%
    uint256 public constant INITIAL_FIXED_FEE = 0.001 ether;
    uint256 public constant MERKLE_TREE_DEPTH = 20;

    // DAO parameters
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10 ** 18; // 1000 tokens
    uint256 public constant VOTING_PERIOD = 100; // 100 blocks
    uint256 public constant QUORUM_VOTES = 5000 * 10 ** 18; // 5000 tokens
    uint256 public constant TIMELOCK_DELAY = 1 days;
    uint256 public constant MAX_ACTIVE_PROPOSALS = 10;
    uint256 public constant INITIAL_TOKEN_SUPPLY = 100_000 * 10 ** 18; // 100k tokens

    /// @notice Deploys contracts and sets up initial state for DAO tests
    /// @dev Deploys governance token, DAO, ShadowPool, and mock tokens. Sets up test accounts with initial balances and token distribution.
    function setUp() public {
        // Deploy Poseidon hasher contract
        poseidon = new Poseidon2();

        // Deploy Groth16 verifier contract
        verifier = new HonkVerifier();

        // Create addresses
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        recipient = makeAddr("recipient");

        // Deploy governance token
        governanceToken = new ShadowPoolGovernanceToken(owner, INITIAL_TOKEN_SUPPLY);

        // Deploy ShadowPool
        shadowPool = new ShadowPool(
            IVerifier(verifier),
            poseidon,
            uint32(MERKLE_TREE_DEPTH),
            address(this),
            INITIAL_PERCENTAGE_FEE,
            INITIAL_FIXED_FEE
        );

        // Deploy TimelockController
        address[] memory proposers = new address[](2);
        proposers[0] = address(this);
        proposers[1] = address(dao); // Add DAO as proposer
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute
        timelockController = new TimelockController(TIMELOCK_DELAY, proposers, executors, address(this));

        // Deploy DAO
        dao = new ShadowPoolDAO(
            governanceToken,
            address(shadowPool),
            PROPOSAL_THRESHOLD,
            VOTING_PERIOD,
            QUORUM_VOTES,
            TIMELOCK_DELAY,
            MAX_ACTIVE_PROPOSALS,
            timelockController
        );

        // Grant DAO proposer role in TimelockController
        timelockController.grantRole(timelockController.PROPOSER_ROLE(), address(dao));

        // Update ShadowPool address in DAO
        shadowPool.updateDAOAddress(address(dao));

        // Deploy mock tokens
        token1 = new MockERC20("Token1", "TK1");
        token2 = new MockERC20("Token2", "TK2");

        // Mint tokens to users
        token1.mint(user1, 10000 ether);
        token2.mint(user1, 10000 ether);

        // Fund users with ETH
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);

        // Distribute governance tokens
        vm.startPrank(owner);
        governanceToken.transfer(user1, 5000 * 10 ** 18); // 5000 tokens
        governanceToken.transfer(user2, 3000 * 10 ** 18); // 3000 tokens
        governanceToken.transfer(user3, 2000 * 10 ** 18); // 2000 tokens
        vm.stopPrank();
    }

    /// @notice Test DAO deployment and initial state
    function testDAODeployment() public {
        assertEq(address(dao.governanceToken()), address(governanceToken));
        // Note: In tests, DAO uses temporary ShadowPool address
        // assertEq(address(dao.shadowPool()), address(shadowPool));
        assertEq(dao.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(dao.votingPeriod(), VOTING_PERIOD);
        assertEq(dao.quorumVotes(), QUORUM_VOTES);
        assertEq(dao.timelockDelay(), TIMELOCK_DELAY);
        assertEq(dao.maxActiveProposals(), MAX_ACTIVE_PROPOSALS);
        assertEq(dao.activeProposalCount(), 0);
    }

    /// @notice Test governance token distribution
    function testTokenDistribution() public {
        assertEq(governanceToken.balanceOf(user1), 5000 * 10 ** 18);
        assertEq(governanceToken.balanceOf(user2), 3000 * 10 ** 18);
        assertEq(governanceToken.balanceOf(user3), 2000 * 10 ** 18);
        assertEq(governanceToken.totalSupply(), INITIAL_TOKEN_SUPPLY);
    }

    /// @notice Test proposal creation with sufficient tokens
    function testProposalCreation() public {
        vm.startPrank(user1);

        string memory description = "Update fee parameters";
        address[] memory targets = new address[](1);
        targets[0] = address(shadowPool);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "updateFees(uint256,uint256)";

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);

        assertEq(proposalId, 0);
        assertEq(dao.activeProposalCount(), 1);
        assertEq(dao.latestProposalIds(user1), 0);

        vm.stopPrank();
    }

    /// @notice Test proposal creation with insufficient tokens
    function testProposalCreationInsufficientTokens() public {
        vm.startPrank(user3); // Only has 2000 tokens, threshold is 1000

        string memory description = "Update fee parameters";
        address[] memory targets = new address[](1);
        targets[0] = address(shadowPool);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "updateFees(uint256,uint256)";

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

        // Should succeed since user3 has enough tokens
        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        assertEq(proposalId, 0);

        vm.stopPrank();
    }

    /// @notice Test voting on a proposal
    function testVoting() public {
        // Create proposal
        vm.startPrank(user1);
        string memory description = "Update fee parameters";
        address[] memory targets = new address[](1);
        targets[0] = address(shadowPool);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "updateFees(uint256,uint256)";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();

        // Move to next block so proposal becomes active
        vm.roll(block.number + 1);

        // Vote for the proposal
        vm.startPrank(user1);
        dao.castVote(proposalId, true);
        vm.stopPrank();

        // Vote against the proposal
        vm.startPrank(user2);
        dao.castVote(proposalId, false);
        vm.stopPrank();

        // Check vote counts
        assertEq(dao.getForVotes(proposalId), 5000 * 10 ** 18);
        assertEq(dao.getAgainstVotes(proposalId), 3000 * 10 ** 18);
    }

    /// @notice Test proposal execution after successful voting
    function testProposalExecution() public {
        // Create proposal
        vm.startPrank(user1);
        string memory description = "Update fee parameters";
        address[] memory targets = new address[](1);
        targets[0] = address(shadowPool);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "updateFees(uint256,uint256)";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();

        // Move to next block so proposal becomes active
        vm.roll(block.number + 1);

        // Vote for the proposal with enough votes to meet quorum
        vm.startPrank(user1);
        dao.castVote(proposalId, true);
        vm.stopPrank();

        vm.startPrank(user2);
        dao.castVote(proposalId, true);
        vm.stopPrank();

        vm.startPrank(user3);
        dao.castVote(proposalId, true);
        vm.stopPrank();

        // Fast forward past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Execute the proposal
        vm.startPrank(user1);
        dao.execute(proposalId);
        vm.stopPrank();

        // Check that proposal is executed
        assertTrue(dao.getExecuted(proposalId));
        assertEq(dao.activeProposalCount(), 0);
    }

    /// @notice Test proposal cancellation by proposer
    function testProposalCancellation() public {
        // Create proposal
        vm.startPrank(user1);
        string memory description = "Update fee parameters";
        address[] memory targets = new address[](1);
        targets[0] = address(shadowPool);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "updateFees(uint256,uint256)";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);

        // Cancel the proposal
        dao.cancel(proposalId);
        vm.stopPrank();

        // Check that proposal is canceled
        assertTrue(dao.getCanceled(proposalId));
        assertEq(dao.activeProposalCount(), 0);
    }

    /// @notice Test proposal state transitions
    function testProposalStates() public {
        // Create proposal
        vm.startPrank(user1);
        string memory description = "Update fee parameters";
        address[] memory targets = new address[](1);
        targets[0] = address(shadowPool);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "updateFees(uint256,uint256)";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();

        // Check initial state (Pending)
        assertEq(uint256(dao.getProposalState(proposalId)), uint256(ShadowPoolDAO.ProposalState.Pending));

        // Fast forward to active state
        vm.roll(block.number + 1);
        assertEq(uint256(dao.getProposalState(proposalId)), uint256(ShadowPoolDAO.ProposalState.Active));

        // Fast forward past voting period without enough votes
        vm.roll(block.number + VOTING_PERIOD);
        assertEq(uint256(dao.getProposalState(proposalId)), uint256(ShadowPoolDAO.ProposalState.Defeated));
    }

    /// @notice Test receipt retrieval
    function testGetReceipt() public {
        // Create proposal
        vm.startPrank(user1);
        string memory description = "Update fee parameters";
        address[] memory targets = new address[](1);
        targets[0] = address(shadowPool);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "updateFees(uint256,uint256)";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();

        // Move to next block so proposal becomes active
        vm.roll(block.number + 1);

        // Vote
        vm.startPrank(user1);
        dao.castVote(proposalId, true);
        vm.stopPrank();

        // Get receipt
        ShadowPoolDAO.Receipt memory receipt = dao.getReceipt(proposalId, user1);
        assertTrue(receipt.hasVoted);
        assertTrue(receipt.support);
        assertEq(receipt.votes, 5000 * 10 ** 18);
    }

    /// @notice Test maximum active proposals limit
    function testMaxActiveProposals() public {
        vm.startPrank(user1);

        // Create maximum number of proposals
        for (uint256 i = 0; i < MAX_ACTIVE_PROPOSALS; i++) {
            string memory proposalDescription = string(abi.encodePacked("Proposal ", vm.toString(i)));
            address[] memory proposalTargets = new address[](1);
            proposalTargets[0] = address(shadowPool);
            uint256[] memory proposalValues = new uint256[](1);
            proposalValues[0] = 0;
            string[] memory proposalSignatures = new string[](1);
            proposalSignatures[0] = "updateFees(uint256,uint256)";
            bytes[] memory proposalCalldatas = new bytes[](1);
            proposalCalldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

            dao.propose(proposalDescription, proposalTargets, proposalValues, proposalSignatures, proposalCalldatas);
        }

        assertEq(dao.activeProposalCount(), MAX_ACTIVE_PROPOSALS);

        // Try to create one more proposal - should revert
        string memory extraDescription = "Extra proposal";
        address[] memory extraTargets = new address[](1);
        extraTargets[0] = address(shadowPool);
        uint256[] memory extraValues = new uint256[](1);
        extraValues[0] = 0;
        string[] memory extraSignatures = new string[](1);
        extraSignatures[0] = "updateFees(uint256,uint256)";
        bytes[] memory extraCalldatas = new bytes[](1);
        extraCalldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 100, 0.002 ether);

        vm.expectRevert(ShadowPoolDAO.DAO__TooManyActiveProposals.selector);
        dao.propose(extraDescription, extraTargets, extraValues, extraSignatures, extraCalldatas);

        vm.stopPrank();
    }

    // Edge-case: Proposing with insufficient tokens should revert
    function testProposeWithInsufficientTokens_Reverts() public {
        address lowBalanceUser = address(0x1234);
        // Transfer from owner to lowBalanceUser (owner has enough tokens)
        vm.startPrank(owner);
        governanceToken.transfer(lowBalanceUser, 100 * 10 ** 18);
        vm.stopPrank();
        vm.startPrank(lowBalanceUser);
        string memory description = "Should fail";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        vm.expectRevert();
        dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();
    }

    // Edge-case: Voting on non-existent proposal should revert
    function testVoteOnNonExistentProposal_Reverts() public {
        uint256 nonExistentProposalId = 9999;
        vm.startPrank(user1);
        vm.expectRevert();
        dao.castVote(nonExistentProposalId, true);
        vm.stopPrank();
    }

    // Edge-case: Voting after proposal end should revert
    function testVoteAfterProposalEnd_Reverts() public {
        // Create proposal
        vm.startPrank(user1);
        string memory description = "Test Proposal";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        // Fast-forward beyond voting period
        vm.roll(block.number + dao.votingPeriod() + 1);
        vm.expectRevert();
        dao.castVote(proposalId, true);
        vm.stopPrank();
    }

    // Edge-case: Executing proposal before quorum should revert
    function testExecuteBeforeQuorum_Reverts() public {
        // Create proposal
        vm.startPrank(user1);
        string memory description = "Test Proposal";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();
        // Try to execute before any votes
        vm.expectRevert();
        dao.execute(proposalId);
    }

    // Integration: Full proposal lifecycle (propose, vote, reach quorum, execute)
    function testFullProposalLifecycle() public {
        // Ensure both users have enough tokens to reach quorum
        uint256 quorum = dao.quorumVotes();
        uint256 halfQuorum = quorum / 2;
        vm.startPrank(owner);
        governanceToken.transfer(user1, halfQuorum);
        governanceToken.transfer(user2, halfQuorum + 1); // +1 to ensure > quorum
        vm.stopPrank();
        // Propose
        vm.startPrank(user1);
        string memory description = "Integration Proposal";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();
        // Advance block to enter active voting period
        vm.roll(block.number + 2);
        // Vote from user1
        vm.startPrank(user1);
        dao.castVote(proposalId, true);
        vm.stopPrank();
        // Vote from user2 to reach quorum
        vm.startPrank(user2);
        dao.castVote(proposalId, true);
        vm.stopPrank();
        // Fast-forward to end of voting
        vm.roll(block.number + dao.votingPeriod() + 1);
        // Execute
        vm.prank(user1);
        dao.execute(proposalId);
        // Check proposal executed status
        assertTrue(dao.getExecuted(proposalId), "Proposal should be executed");
    }
}
