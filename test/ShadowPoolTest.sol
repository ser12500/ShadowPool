// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "lib/forge-std/src/Test.sol";
import {ShadowPool} from "../src/ShadowPool.sol";
import "../src/IVerifier.sol";

// Mock Verifier for testing
contract MockVerifier is IVerifier {
    function verifyProof(uint256[8] memory, uint256[3] memory) external pure returns (bool) {
        return true; // Mocked to always pass for testing
    }
}

contract ShadowPoolTest is Test {
    ShadowPool shadowPool;
    MockVerifier verifier; // Changed from Verifier to MockVerifier
    address user = address(0x1);
    address recipient = address(0x2);
    address owner = address(0x3);

    function setUp() public {
        verifier = new MockVerifier(); // Deploy MockVerifier instead of Verifier
        shadowPool = new ShadowPool(address(verifier), owner);
        vm.deal(user, 1 ether);
    }

    function testDepositSuccess() public {
        bytes32 commitment = keccak256(abi.encodePacked("secret", user));
        vm.prank(user);
        shadowPool.deposit{value: 0.1 ether}(commitment);
        assertEq(shadowPool.getBalance(), 0.1 ether);
        assertTrue(shadowPool.commitments(commitment));
        assertEq(shadowPool.nextLeafIndex(), 1);
    }

    function testDepositInvalidAmount() public {
        bytes32 commitment = keccak256(abi.encodePacked("secret", user));
        vm.prank(user);
        vm.expectRevert("Incorrect deposit amount");
        shadowPool.deposit{value: 0.2 ether}(commitment);
    }

    function testDepositDuplicateCommitment() public {
        bytes32 commitment = keccak256(abi.encodePacked("secret", user));
        vm.prank(user);
        shadowPool.deposit{value: 0.1 ether}(commitment);
        vm.prank(user);
        vm.expectRevert("Commitment already exists");
        shadowPool.deposit{value: 0.1 ether}(commitment);
    }

    function testWithdraw() public {
        // Deposit first
        bytes32 commitment = keccak256(abi.encodePacked("secret", user));
        vm.prank(user);
        shadowPool.deposit{value: 0.1 ether}(commitment);

        // Mock proof (no need for real proof with MockVerifier)
        uint256[8] memory proof =
            [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)];
        bytes32 nullifierHash = keccak256(abi.encodePacked("nullifier"));
        bytes32 root = shadowPool.merkleRoot();

        // Withdraw
        vm.prank(user);
        shadowPool.withdraw(proof, root, nullifierHash, payable(recipient));
        assertEq(recipient.balance, 0.1 ether);
        assertTrue(shadowPool.nullifiers(nullifierHash));
    }

    function testWithdrawDoubleSpend() public {
        bytes32 commitment = keccak256(abi.encodePacked("secret", user));
        vm.prank(user);
        shadowPool.deposit{value: 0.1 ether}(commitment);

        uint256[8] memory proof =
            [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)];
        bytes32 nullifierHash = keccak256(abi.encodePacked("nullifier"));
        bytes32 root = shadowPool.merkleRoot();

        vm.prank(user);
        shadowPool.withdraw(proof, root, nullifierHash, payable(recipient));

        vm.prank(user);
        vm.expectRevert("Nullifier already spent");
        shadowPool.withdraw(proof, root, nullifierHash, payable(recipient));
    }
}
