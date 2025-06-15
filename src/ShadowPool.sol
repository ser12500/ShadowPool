// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IVerifier} from "./Verifier.sol";
import {Incremental, Poseidon2} from "./Incremental.sol";

/**
 * @title ShadowPool
 * @dev A mixer contract for anonymous transactions using Noir zk-proofs.
 * Integrates with a Noir-generated verifier and supports a 20-level Merkle tree.
 * Inspired by Tornado Cash with gas optimizations and security features.
 */
contract ShadowPool is ReentrancyGuard, Ownable, Incremental {
    // Fixed deposit amount set to 0.1 ETH
    uint256 public constant DEPOSIT_AMOUNT = 0.1 ether;

    // Address of the Noir verifier contract
    IVerifier public immutable verifier;

    // Address of the IncrementalMerkleTree contract
    Incremental public immutable merkleTree;

    // Instance of Poseidon2 hasher
    Poseidon2 public immutable poseidon;

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
    constructor(IVerifier _verifier, Poseidon2 _hasher, uint32 _merkleTreeDepth, address initialOwner)
        Incremental(_merkleTreeDepth, _hasher)
        Ownable(initialOwner)
    {
        verifier = _verifier;
    }

    /**
     * @dev Allows users to deposit 0.1 ETH with a commitment.
     * Commitment is computed off-chain as Poseidon2(nullifier, secret) and stored in the Merkle tree.
     * @param _commitment Hash of the user's nullifier and secret.
     */
    function deposit(bytes32 _commitment) external payable nonReentrant {
        // Ensure correct deposit amount
        require(msg.value == DEPOSIT_AMOUNT, "Incorrect deposit amount");

        // add the commitment to the added commitments mapping
        commitments[_commitment] = true;
        // Insert commitment into the Merkle tree
        uint32 leafIndex = _insert(_commitment);

        // Emit deposit event
        emit Deposit(_commitment, leafIndex, block.timestamp);
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

        // Verify the Merkle root is known
        require(merkleTree.isKnownRoot(_root), "Invalid Merkle root");

        // Mark nullifier as used
        nullifiers[_nullifierHash] = true;

        // Prepare public inputs: [root, nullifier_hash, recipient]
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = _root;
        publicInputs[1] = _nullifierHash;
        publicInputs[2] = bytes32(uint256(uint160(address(_recipient))));

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
