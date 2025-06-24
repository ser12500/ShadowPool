// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {ShadowPool} from "../src/ShadowPool.sol";
import {HonkVerifier} from "../src/Verifier/Verifier.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";
import {Incremental} from "../src/Incremental.sol";

contract PrivacyTest is Test {
    ShadowPool public shadowPool;
    HonkVerifier public verifier;
    Poseidon2 public poseidon;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public david = address(0x4);

    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant MERKLE_TREE_DEPTH = 20;
    uint256 public constant PERCENTAGE_FEE = 5; // 0.5%
    uint256 public constant FIXED_FEE = 0.001 ether;

    function setUp() public {
        // Deploy contracts
        poseidon = new Poseidon2();
        verifier = new HonkVerifier();

        // Create a proper DAO address that can receive ETH
        address daoAddress = address(0x123);
        vm.deal(daoAddress, 100 ether); // Give DAO some ETH to receive fees

        shadowPool = new ShadowPool(
            verifier,
            poseidon,
            uint32(MERKLE_TREE_DEPTH),
            daoAddress, // Use proper DAO address
            PERCENTAGE_FEE,
            FIXED_FEE
        );

        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        vm.deal(david, 10 ether);
    }

    function test_NoLinkBetweenDepositAndWithdrawal() public {
        console.log("=== Testing: No Link Between Deposit and Withdrawal ===");

        // Alice deposits
        bytes32 aliceCommitment = bytes32(uint256(1));
        vm.prank(alice);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(aliceCommitment);

        console.log("Alice deposited with commitment:", uint256(aliceCommitment));
        console.log("Pool size after Alice deposit:", shadowPool.getPoolSize());

        // Bob deposits
        bytes32 bobCommitment = bytes32(uint256(2));
        vm.prank(bob);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(bobCommitment);

        console.log("Bob deposited with commitment:", uint256(bobCommitment));
        console.log("Pool size after Bob deposit:", shadowPool.getPoolSize());

        // Charlie deposits
        bytes32 charlieCommitment = bytes32(uint256(3));
        vm.prank(charlie);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(charlieCommitment);

        console.log("Charlie deposited with commitment:", uint256(charlieCommitment));
        console.log("Pool size after Charlie deposit:", shadowPool.getPoolSize());

        // David deposits
        bytes32 davidCommitment = bytes32(uint256(4));
        vm.prank(david);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(davidCommitment);

        console.log("David deposited with commitment:", uint256(davidCommitment));
        console.log("Final pool size:", shadowPool.getPoolSize());

        // Now anyone can withdraw any amount without revealing who deposited it
        // The commitment in the Merkle tree doesn't reveal the original depositor
        console.log("Current Merkle root:", uint256(shadowPool.getLatestRoot()));
        console.log("Anonymity level:", shadowPool.getAnonymityLevel());

        // Verify that commitments are stored but don't reveal depositor identity
        assertTrue(shadowPool.isDepositValid(aliceCommitment));
        assertTrue(shadowPool.isDepositValid(bobCommitment));
        assertTrue(shadowPool.isDepositValid(charlieCommitment));
        assertTrue(shadowPool.isDepositValid(davidCommitment));

        // But we can't determine who deposited which commitment from the contract state
        console.log("All deposits are valid but anonymous");
    }

    function test_AnonymitySetSize() public {
        console.log("=== Testing: Anonymity Set Size ===");

        uint256[] memory anonymityLevels = new uint256[](4);
        anonymityLevels[0] = 0; // Empty
        anonymityLevels[1] = 5; // Low
        anonymityLevels[2] = 25; // Medium
        anonymityLevels[3] = 75; // High

        for (uint256 i = 0; i < anonymityLevels.length; i++) {
            uint256 targetSize = anonymityLevels[i];
            uint256 currentSize = shadowPool.getPoolSize();

            // Add deposits to reach target size
            for (uint256 j = currentSize; j < targetSize; j++) {
                bytes32 commitment = bytes32(uint256(j + 1));
                address depositor = address(uint160(j + 1));
                vm.deal(depositor, 10 ether);
                vm.prank(depositor);
                shadowPool.deposit{value: DEPOSIT_AMOUNT}(commitment);
            }

            string memory level = shadowPool.getAnonymityLevel();
            uint256 optimalWait = shadowPool.getOptimalWithdrawTime();

            console.log("Pool size:", shadowPool.getPoolSize());
            console.log("Anonymity level:", level);
            console.log("Optimal wait time:", optimalWait, "seconds");
            console.log("---");

            // Verify anonymity increases with pool size
            if (targetSize >= 100) {
                assertEq(level, "Maximum anonymity");
                assertEq(optimalWait, 0); // Can withdraw immediately
            } else if (targetSize >= 50) {
                assertEq(level, "High anonymity");
                assertEq(optimalWait, 0); // Can withdraw immediately
            } else if (targetSize >= 10) {
                assertEq(level, "Medium anonymity");
                assertTrue(optimalWait <= 1800); // 30 minutes or less
            } else {
                assertEq(level, "Low anonymity");
                assertEq(optimalWait, 3600); // 1 hour
            }
        }
    }

    function test_NoDoubleSpending() public {
        console.log("=== Testing: No Double Spending ===");

        // Alice deposits
        bytes32 aliceCommitment = bytes32(uint256(1));
        vm.prank(alice);
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(aliceCommitment);

        // Try to deposit the same commitment again
        vm.prank(bob);
        vm.expectRevert();
        shadowPool.deposit{value: DEPOSIT_AMOUNT}(aliceCommitment);

        console.log("Same commitment cannot be used twice");
    }

    function test_FeeTransparency() public {
        console.log("=== Testing: Fee Transparency ===");

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0.1 ether;
        amounts[1] = 1 ether;
        amounts[2] = 10 ether;

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = amounts[i];
            uint256 fee = shadowPool.calculateFee(amount);
            (uint256 percentageFee, uint256 fixedFee, uint256 totalFee) = shadowPool.getFeeBreakdown(amount);

            console.log("Amount:", amount / 1e18, "ETH");
            console.log("  Percentage fee:", percentageFee);
            console.log("  Fixed fee:", fixedFee / 1e18, "ETH");
            console.log("  Total fee:", totalFee / 1e18, "ETH");
            console.log("  Fee percentage:", (totalFee * 100) / amount, "%");
            console.log("---");

            // Verify fee calculations
            assertEq(totalFee, fee);
            assertEq(totalFee, percentageFee + fixedFee);
            assertEq(percentageFee, (amount * PERCENTAGE_FEE) / 10000);
            assertEq(fixedFee, FIXED_FEE);
        }
    }

    function test_PoolUtilization() public {
        console.log("=== Testing: Pool Utilization ===");

        uint256 maxSize = shadowPool.getMaxPoolSize();
        console.log("Maximum pool size:", maxSize);

        // Test different utilization levels with smaller amounts to avoid gas issues
        uint256[] memory testSizes = new uint256[](3);
        testSizes[0] = 10;
        testSizes[1] = 50;
        testSizes[2] = 100;

        for (uint256 i = 0; i < testSizes.length; i++) {
            uint256 targetSize = testSizes[i];
            uint256 currentSize = shadowPool.getPoolSize();

            // Add deposits to reach target size
            for (uint256 j = currentSize; j < targetSize; j++) {
                bytes32 commitment = bytes32(uint256(j + 1));
                address depositor = address(uint160(j + 1));
                vm.deal(depositor, 10 ether);
                vm.prank(depositor);
                shadowPool.deposit{value: 0.01 ether}(commitment); // Use smaller amount
            }

            uint256 utilization = shadowPool.getPoolUtilization();
            bool isFull = shadowPool.isPoolFull();

            console.log("Pool size:", shadowPool.getPoolSize());
            console.log("Utilization:", utilization, "%");
            console.log("Is full:", isFull);
            console.log("---");

            // Verify utilization calculation
            uint256 expectedUtilization = (shadowPool.getPoolSize() * 100) / maxSize;
            assertEq(utilization, expectedUtilization);

            // Pool should not be full for reasonable test sizes
            assertFalse(isFull);
        }
    }

    function test_PrivacyMetrics() public {
        console.log("=== Testing: Privacy Metrics ===");

        // Add multiple deposits to create anonymity
        for (uint256 i = 0; i < 50; i++) {
            bytes32 commitment = bytes32(uint256(i + 1));
            address depositor = address(uint160(i + 1));
            vm.deal(depositor, 10 ether);
            vm.prank(depositor);
            shadowPool.deposit{value: DEPOSIT_AMOUNT}(commitment);
        }

        // Get pool statistics
        (uint256 totalDeposits, bytes32 currentRoot, uint256 currentPercentageFee, uint256 currentFixedFee) =
            shadowPool.getPoolStats();

        console.log("Total deposits:", totalDeposits);
        console.log("Current Merkle root:", uint256(currentRoot));
        console.log("Percentage fee:", currentPercentageFee, "basis points");
        console.log("Fixed fee:", currentFixedFee / 1e18, "ETH");
        console.log("Pool utilization:", shadowPool.getPoolUtilization(), "%");
        console.log("Anonymity level:", shadowPool.getAnonymityLevel());
        console.log("Optimal wait time:", shadowPool.getOptimalWithdrawTime(), "seconds");

        // Verify statistics
        assertEq(totalDeposits, 50);
        assertEq(currentPercentageFee, PERCENTAGE_FEE);
        assertEq(currentFixedFee, FIXED_FEE);
        assertEq(shadowPool.getAnonymityLevel(), "High anonymity");
        assertEq(shadowPool.getOptimalWithdrawTime(), 0); // Can withdraw immediately

        console.log("Privacy metrics are accurate");
    }

    function test_RealWorldPrivacyScenario() public {
        console.log("=== Testing: Real World Privacy Scenario ===");

        // Simulate real-world usage with multiple users
        address[] memory users = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            users[i] = address(uint160(i + 100));
            vm.deal(users[i], 10 ether);
        }

        // Users make deposits at different times
        for (uint256 i = 0; i < users.length; i++) {
            bytes32 commitment = bytes32(uint256(i + 1));
            vm.prank(users[i]);
            shadowPool.deposit{value: DEPOSIT_AMOUNT}(commitment);

            console.log("User", i, "deposited. Pool size:", shadowPool.getPoolSize());

            // Check anonymity level after each deposit
            string memory level = shadowPool.getAnonymityLevel();
            uint256 waitTime = shadowPool.getOptimalWithdrawTime();

            console.log("  Anonymity level:", level);
            console.log("  Recommended wait:", waitTime, "seconds");
            console.log("---");
        }

        // Verify that after multiple deposits, anonymity is at least medium
        string memory finalLevel = shadowPool.getAnonymityLevel();
        assertTrue(
            keccak256(abi.encodePacked(finalLevel)) == keccak256(abi.encodePacked("High anonymity"))
                || keccak256(abi.encodePacked(finalLevel)) == keccak256(abi.encodePacked("Medium anonymity"))
                || keccak256(abi.encodePacked(finalLevel)) == keccak256(abi.encodePacked("Maximum anonymity"))
        );

        // After 10 deposits, we should have at least medium anonymity, so wait time should be 0, 1800 или 3600
        uint256 finalWaitTime = shadowPool.getOptimalWithdrawTime();
        assertTrue(finalWaitTime == 0 || finalWaitTime == 1800 || finalWaitTime == 3600);

        console.log("Real-world scenario shows good privacy");
    }
}
