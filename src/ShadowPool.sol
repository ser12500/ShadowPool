// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IVerifier} from "./Verifier.sol";

/**
 * @title ShadowPool
 * @dev A mixer contract for anonymous transactions using Noir zk-proofs.
 * Integrates with a Noir-generated verifier and supports a 20-level Merkle tree.
 * Inspired by Tornado Cash with gas optimizations and security features.
 */
contract ShadowPool is ReentrancyGuard, Ownable {
    // Fixed deposit amount set to 0.1 ETH
    uint256 public constant DEPOSIT_AMOUNT = 0.1 ether;

    // Address of the Noir verifier contract
    IVerifier public immutable verifier;

    // Number of Merkle tree levels (aligned with Noir scheme)
    uint32 public constant TREE_LEVELS = 20;

    // Mapping to track used nullifiers and prevent double-spending
    mapping(bytes32 => bool) public nullifiers;

    // Mapping to track commitments and ensure uniqueness
    mapping(bytes32 => bool) public commitments;

    // Events for deposit and withdrawal tracking
    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
    event Withdrawal(address indexed to, bytes32 indexed nullifierHash);

    // Index of the next leaf in the Merkle tree (for event tracking)
    uint32 public nextLeafIndex = 0;

    /**
     * @dev Constructor to initialize the verifier and owner addresses.
     * @param _verifier Address of the Noir verifier contract.
     * @param initialOwner Address of the contract owner.
     */
    constructor(address _verifier, address initialOwner) Ownable(initialOwner) {
        verifier = IVerifier(_verifier);
    }

    /**
     * @dev Allows users to deposit funds with a commitment.
     * @param _commitment Hash of the user's secret and nullifier (Poseidon2 in Noir).
     */
    function deposit(bytes32 _commitment) external payable nonReentrant {
        // Ensure correct deposit amount
        require(msg.value == DEPOSIT_AMOUNT, "Incorrect deposit amount");
        // Ensure commitment is unique
        require(!commitments[_commitment], "Commitment already exists");

        // Store commitment
        commitments[_commitment] = true;

        // Emit deposit event with leaf index and timestamp
        emit Deposit(_commitment, nextLeafIndex, block.timestamp);
        nextLeafIndex += 1;
    }

    /**
     * @dev Withdraws funds using a Noir zk-proof.
     * @param _proof Noir zk-proof (bytes format).
     * @param _root Merkle root for verification (public input).
     * @param _nullifierHash Hash to prevent double-spending (public input).
     * @param _recipient Address to receive the withdrawn funds (public input).
     */
    function withdraw(bytes calldata _proof, bytes32 _root, bytes32 _nullifierHash, address payable _recipient)
        external
        nonReentrant
    {
        // Ensure nullifier hasn't been used
        require(!nullifiers[_nullifierHash], "Nullifier already spent");

        // Mark nullifier as used
        nullifiers[_nullifierHash] = true;

        // Prepare public inputs for Noir verifier: [root, nullifier_hash, recipient]
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = _root;
        publicInputs[1] = _nullifierHash;
        publicInputs[2] = bytes32(uint256(uint160(_recipient)));

        // Verify the Noir proof
        require(verifier.verify(_proof, publicInputs), "Invalid zk-proof");

        // Transfer funds to recipient
        (bool success,) = _recipient.call{value: DEPOSIT_AMOUNT}("");
        require(success, "Transfer failed");

        // Emit withdrawal event
        emit Withdrawal(_recipient, _nullifierHash);
    }

    /**
     * @dev Returns the current contract balance.
     * @return Balance in wei.
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
