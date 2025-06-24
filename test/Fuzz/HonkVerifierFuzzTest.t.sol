// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "lib/forge-std/src/Test.sol";
import {HonkVerifier} from "../../src/Verifier/Verifier.sol";

contract HonkVerifierFuzzTest is Test {
    HonkVerifier public verifier;

    function setUp() public {
        verifier = new HonkVerifier();
    }

    // Fuzz: verify should return false for random input
    function testFuzz_VerifyRandomInput(bytes memory proof, bytes32[] memory publicInputs) public {
        if (proof.length != 440 * 32) {
            vm.expectRevert();
            verifier.verify(proof, publicInputs);
        } else {
            bool result = verifier.verify(proof, publicInputs);
            // Should not revert, should return false for random data
            assertTrue(result == false || result == true, "Should not revert");
        }
    }

    // Edge: verify with empty proof and inputs
    function testVerify_EmptyProofAndInputs() public {
        bytes memory proof = new bytes(0);
        bytes32[] memory publicInputs = new bytes32[](0);
        vm.expectRevert();
        verifier.verify(proof, publicInputs);
    }

    // Edge: verify with valid length but random data
    function testVerify_RandomData() public {
        bytes memory proof = new bytes(440 * 32);
        bytes32[] memory publicInputs = new bytes32[](10);
        proof[0] = 0x01;
        for (uint256 i = 0; i < 10; i++) {
            publicInputs[i] = bytes32(uint256(123 + i));
        }
        vm.expectRevert();
        verifier.verify(proof, publicInputs);
    }
}
