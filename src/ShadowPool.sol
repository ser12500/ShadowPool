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
    IVerifier public immutable i_verifier;

    // Address of the IncrementalMerkleTree contract
    Incremental public immutable merkleTree;

    // Instance of Poseidon2 hasher
    Poseidon2 public immutable poseidon;

    // Number of Merkle tree levels (aligned with Noir scheme)
    uint32 public constant TREE_LEVELS = 20;

    // Mapping to track used nullifiers and prevent double-spending
    mapping(bytes32 => bool) public s_nullifiers;

    // Mapping to track commitments and ensure uniqueness
    mapping(bytes32 => bool) public s_commitments;

    // Events for deposit and withdrawal tracking
    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
    event Withdrawal(address indexed to, bytes32 indexed nullifierHash);

    /**
     * @notice Error that occurs when the expected and actual deposit values do not match.
     * @param expected The expected deposit value.
     * @param actual The actual deposit value.
     */
    error Mixer__DepositValueMismatch(uint256 expected, uint256 actual);

    /**
     * @notice Error that occurs when a payment attempt fails.
     * @param recipient The address of the payment recipient.
     * @param amount The amount that was attempted to be sent.
     */
    error Mixer__PaymentFailed(address recipient, uint256 amount);

    /**
     * @notice Error that occurs when trying to reuse an already spent note.
     * @param nullifierHash The hash of the note that has already been used.
     */
    error Mixer__NoteAlreadySpent(bytes32 nullifierHash);

    /**
     * @notice Error that occurs when an unknown root is used.
     * @param root The unknown root.
     */
    error Mixer__UnknownRoot(bytes32 root);

    /**
     * @notice Error that occurs when an invalid withdrawal proof is provided.
     */
    error Mixer__InvalidWithdrawProof();

    /**
     * @notice Error that occurs when the fee exceeds the deposit value.
     * @param expected The expected deposit value.
     * @param actual The actual deposit value.
     */
    error Mixer__FeeExceedsDepositValue(uint256 expected, uint256 actual);

    /**
     * @notice Error that occurs when attempting to add an already existing commitment.
     * @param commitment The hash of the commitment that has already been added.
     */
    error Mixer__CommitmentAlreadyAdded(bytes32 commitment);

    /**
     * @dev Constructor to initialize the verifier and owner addresses.
     * @param _verifier Address of the Noir verifier contract.
     * @param initialOwner Address of the contract owner.
     */
    constructor(IVerifier _verifier, Poseidon2 _hasher, uint32 _merkleTreeDepth, address initialOwner)
        Incremental(_merkleTreeDepth, _hasher)
        Ownable(initialOwner)
    {
        i_verifier = _verifier;
    }

    /**
     * @dev Allows users to deposit 0.1 ETH with a commitment.
     * Commitment is computed off-chain as Poseidon2(nullifier, secret) and stored in the Merkle tree.
     * @param _commitment Hash of the user's nullifier and secret.
     */
    function deposit(bytes32 _commitment) external payable nonReentrant {
        // check if the commitment is already added
        if (s_commitments[_commitment]) {
            revert Mixer__CommitmentAlreadyAdded(_commitment);
        }
        // check if the value sent is equal to the denomination
        if (msg.value != DEPOSIT_AMOUNT) {
            revert Mixer__DepositValueMismatch({expected: DEPOSIT_AMOUNT, actual: msg.value});
        }

        // add the commitment to the added commitments mapping
        s_commitments[_commitment] = true;
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
        if (s_nullifiers[_nullifierHash]) {
            revert Mixer__NoteAlreadySpent({nullifierHash: _nullifierHash});
        }

        // Mark nullifier as used
        s_nullifiers[_nullifierHash] = true;
        // Verify the Merkle root is known
        if (!isKnownRoot(_root)) {
            revert Mixer__UnknownRoot({root: _root});
        }

        // Prepare public inputs: [root, nullifier_hash, recipient]
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = _root;
        publicInputs[1] = _nullifierHash;
        publicInputs[2] = bytes32(uint256(uint160(address(_recipient))));

        // Verify the Noir proof
        if (!i_verifier.verify(_proof, publicInputs)) {
            revert Mixer__InvalidWithdrawProof();
        }

        // Transfer funds to recipient
        (bool success,) = _recipient.call{value: DEPOSIT_AMOUNT}("");
        if (!success) {
            revert Mixer__PaymentFailed({recipient: _recipient, amount: DEPOSIT_AMOUNT});
        }

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
