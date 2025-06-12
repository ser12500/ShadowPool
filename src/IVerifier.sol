// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IVerifier
 * @dev Interface for the zk-SNARK verifier contract.
 */
interface IVerifier {
    /**
     * @dev Verifies a zk-SNARK proof.
     * @param proof The proof array.
     * @param input Public inputs for verification.
     * @return True if the proof is valid, false otherwise.
     */
    function verifyProof(uint256[8] memory proof, uint256[3] memory input) external view returns (bool);
}
