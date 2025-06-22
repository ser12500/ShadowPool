// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {ShadowPool} from "../src/ShadowPool.sol";
import {AnonymousVoting} from "../src/AnonymousVoting.sol";
import {Incremental} from "../src/Incremental.sol";
import {MockERC20} from "../test/mock/MockERC20.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";
import {HonkVerifier} from "../src/Verifier/Verifier.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IVerifier as IVerifierVoting} from "../src/Verifier/VotingVerifier.sol";
import {IVerifier as IVerifierPool, HonkVerifier} from "../src/Verifier/Verifier.sol";

/**
 * @title DemoScript
 * @dev Demonstration script for ShadowPoold system showcasing anonymous mixing, voting, and privacy features
 * @notice This script demonstrates the complete functionality of the ShadowPoold ecosystem
 * @author ShadowPoold Team
 */
contract DemoScript is Script {
    ShadowPool public shadowPool;
    AnonymousVoting public voting;
    Incremental public incremental;
    MockERC20 public mockToken;

    address public daoAddress;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;

    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant VOTE_AMOUNT = 0.5 ether;

    // User private keys (example values, replace with real ones if needed)
    uint256 private user1Key = 0x1111111111111111111111111111111111111111111111111111111111111111;
    uint256 private user2Key = 0x2222222222222222222222222222222222222222222222222222222222222222;
    uint256 private user3Key = 0x3333333333333333333333333333333333333333333333333333333333333333;
    uint256 private user4Key = 0x4444444444444444444444444444444444444444444444444444444444444444;
    uint256 private user5Key = 0x5555555555555555555555555555555555555555555555555555555555555555;

    /**
     * @dev Main function to run the complete ShadowPoold demonstration
     * @notice Deploys contracts, sets up users, and demonstrates all system features
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Starting ShadowPoold Demo...");
        console.log("Deployer:", deployer);
        console.log("---");

        // Deploy contracts
        vm.startBroadcast(deployerPrivateKey);
        _deployContracts();
        vm.stopBroadcast();

        // Setup users (doesn't require broadcast)
        _setupUsers();

        // Demo actions (each user uses their own startBroadcast)
        _demoDeposits();
        _demoVoting();
        _demoWithdrawals();
        _demoPrivacyFeatures();

        console.log("Demo completed successfully!");
    }

    /**
     * @dev Deploys all necessary contracts for the demonstration
     * @notice Deploys MockERC20, Poseidon2, Incremental, AnonymousVoting, and ShadowPool
     */
    function _deployContracts() internal {
        console.log("Deploying contracts...");

        // Deploy mock token
        mockToken = new MockERC20("Demo Token", "DEMO");
        console.log("MockERC20 deployed at:", address(mockToken));

        // Use real HonkVerifier from DAO deployment
        address verifierAddress = 0xdbCaa365Aed4dd5F55e0C68dCE2D0aDDb9eEe596;
        console.log("Using HonkVerifier at:", verifierAddress);

        // Deploy Poseidon2 hasher
        Poseidon2 hasher = new Poseidon2();
        console.log("Poseidon2 deployed at:", address(hasher));

        // Deploy incremental (inherits from ShadowPool)
        incremental = new Incremental(20, hasher); // 20 levels depth
        console.log("Incremental deployed at:", address(incremental));

        // Deploy voting
        voting = new AnonymousVoting(IVerifierVoting(verifierAddress), hasher, IERC20(address(mockToken)), 20);
        console.log("AnonymousVoting deployed at:", address(voting));

        // Deploy ShadowPool
        shadowPool = new ShadowPool(
            IVerifierPool(verifierAddress),
            hasher,
            20,
            daoAddress, // Use correct DAO address
            500, // 0.5% fee
            0.001 ether // 0.001 ETH fixed fee
        );
        console.log("ShadowPool deployed at:", address(shadowPool));

        // Set DAO address - use correct ShadowPoolDAO address
        daoAddress = address(0x1bCF6726C2eC8C64d1621349337856330cB3D081); // ShadowPoolDAO from deployment
        console.log("DAO address:", daoAddress);
    }

    /**
     * @dev Sets up user accounts and funds them with ETH and tokens
     * @notice Calculates user addresses from private keys and provides initial funding
     */
    function _setupUsers() internal {
        console.log("Setting up users...");

        // Calculate user addresses from their private keys
        user1 = vm.addr(user1Key);
        user2 = vm.addr(user2Key);
        user3 = vm.addr(user3Key);
        user4 = vm.addr(user4Key);
        user5 = vm.addr(user5Key);

        console.log("User addresses:");
        console.log("  User1:", user1);
        console.log("  User2:", user2);
        console.log("  User3:", user3);
        console.log("  User4:", user4);
        console.log("  User5:", user5);

        // Fund users with ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
        vm.deal(user5, 10 ether);

        // Fund users with tokens
        mockToken.mint(user1, 1000 ether);
        mockToken.mint(user2, 1000 ether);
        mockToken.mint(user3, 1000 ether);
        mockToken.mint(user4, 1000 ether);
        mockToken.mint(user5, 1000 ether);

        console.log("Users setup complete!");
        console.log("---");
    }

    /**
     * @dev Demonstrates deposit functionality with multiple users
     * @notice Shows how users can deposit ETH with commitments for privacy
     */
    function _demoDeposits() internal {
        console.log("Demo: Making deposits...");

        // User 1 deposits - use values within field range
        uint256 commitment1Value = 123456789; // Simple number within field range
        bytes32 commitment1 = bytes32(commitment1Value);
        vm.startBroadcast(user1Key);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(commitment1);
        vm.stopBroadcast();
        console.log("User 1 deposited", DEPOSIT_AMOUNT / 1e18, "ETH");

        // User 2 deposits
        uint256 commitment2Value = 987654321;
        bytes32 commitment2 = bytes32(commitment2Value);
        vm.startBroadcast(user2Key);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(commitment2);
        vm.stopBroadcast();
        console.log("User 2 deposited", DEPOSIT_AMOUNT / 1e18, "ETH");

        // User 3 deposits
        uint256 commitment3Value = 555666777;
        bytes32 commitment3 = bytes32(commitment3Value);
        vm.startBroadcast(user3Key);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(commitment3);
        vm.stopBroadcast();
        console.log("User 3 deposited", DEPOSIT_AMOUNT / 1e18, "ETH");

        // Show pool status
        console.log("Pool status:");
        console.log("  Pool size:", shadowPool.getPoolSize());
        console.log("  Current balance:", address(shadowPool).balance / 1e18, "ETH");
        console.log("  Fee percentage:", shadowPool.percentageFee());
        console.log("  Fixed fee:", shadowPool.fixedFee() / 1e18, "ETH");
        console.log("  Anonymity level:", shadowPool.getAnonymityLevel());
        console.log("  Optimal withdraw time:", shadowPool.getOptimalWithdrawTime(), "seconds");

        console.log("Deposits completed!");
        console.log("---");
    }

    /**
     * @dev Demonstrates anonymous voting functionality
     * @notice Shows how users can participate in anonymous voting with token commitments
     */
    function _demoVoting() internal {
        console.log("Demo: Anonymous voting...");

        // Create a proposal
        string memory proposal = "Should we increase the percentage fee to 1%?";
        bytes32 proposalHash = keccak256(abi.encodePacked(proposal));

        // For demo purposes, we'll use a simplified voting approach
        // In real implementation, this would use zk-proofs

        // Add token commitments to voting contract
        bytes32 commitment1 = keccak256(abi.encodePacked("user1_tokens", uint256(1000 ether)));
        bytes32 commitment2 = keccak256(abi.encodePacked("user2_tokens", uint256(1000 ether)));
        bytes32 commitment3 = keccak256(abi.encodePacked("user3_tokens", uint256(1000 ether)));

        vm.startBroadcast(user1Key);
        voting.addTokenCommitment(commitment1, 1000 ether);
        vm.stopBroadcast();
        console.log("User 1 added token commitment");

        vm.startBroadcast(user2Key);
        voting.addTokenCommitment(commitment2, 1000 ether);
        vm.stopBroadcast();
        console.log("User 2 added token commitment");

        vm.startBroadcast(user3Key);
        voting.addTokenCommitment(commitment3, 1000 ether);
        vm.stopBroadcast();
        console.log("User 3 added token commitment");

        // Show voting stats
        console.log("Total token commitments added");
        console.log("Voting contract ready for anonymous voting");

        console.log("Voting completed!");
        console.log("---");
    }

    /**
     * @dev Demonstrates withdrawal functionality
     * @notice Shows the concept of withdrawals (would require zk-proofs in real implementation)
     */
    function _demoWithdrawals() internal {
        console.log("Demo: Making withdrawals...");

        // User 4 deposits
        uint256 commitment4Value = 111222333;
        bytes32 commitment4 = bytes32(commitment4Value);
        vm.startBroadcast(user4Key);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(commitment4);
        vm.stopBroadcast();
        console.log("User 4 deposited", DEPOSIT_AMOUNT / 1e18, "ETH");

        // Note: In real implementation, withdrawal would require zk-proof
        // For demo, we'll just show the concept
        console.log("User 4 withdrawal would require zk-proof in real implementation");

        // Show final status (read-only operations)
        console.log("Final status:");
        console.log("  Pool size:", shadowPool.getPoolSize());
        console.log("  Current balance:", address(shadowPool).balance / 1e18, "ETH");
        console.log("  Anonymity level:", shadowPool.getAnonymityLevel());
        console.log("  Optimal withdraw time:", shadowPool.getOptimalWithdrawTime(), "seconds");

        console.log("Withdrawals completed!");
        console.log("---");
    }

    /**
     * @dev Demonstrates privacy features and fee transparency
     * @notice Shows fee breakdown, anonymity levels, and pool statistics
     */
    function _demoPrivacyFeatures() internal view {
        console.log("Demo: Privacy features...");

        // Show fee transparency (read-only operations)
        uint256 testAmount = 5 ether;
        (uint256 percentageFee, uint256 fixedFee, uint256 totalFee) = shadowPool.getFeeBreakdown(testAmount);

        console.log("Fee breakdown for", testAmount / 1e18, "ETH:");
        console.log("  Percentage fee:", percentageFee);
        console.log("  Fixed fee:", fixedFee / 1e18, "ETH");
        console.log("  Total fee:", totalFee / 1e18, "ETH");
        console.log("  Fee percentage:", (totalFee * 100) / testAmount, "%");

        // Show anonymity levels (read-only)
        console.log("Current anonymity level:", shadowPool.getAnonymityLevel());
        console.log("Optimal wait time:", shadowPool.getOptimalWithdrawTime(), "seconds");

        // Show pool statistics (read-only)
        console.log("Pool statistics:");
        console.log("  Active deposits:", shadowPool.getPoolSize());
        console.log("  Pool utilization:", shadowPool.getPoolUtilization(), "%");

        console.log("Privacy features demonstrated!");
        console.log("---");
    }
}
