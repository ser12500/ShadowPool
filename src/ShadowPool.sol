// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {MerkleProof} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IVerifier} from "./IVerifier.sol";

/**
 * @title ShadowPool
 * @dev A mixer contract for anonymous transactions using zk-SNARKs.
 * Inspired by Tornado Cash with gas optimization considerations.
 */
contract ShadowPool is ReentrancyGuard, Ownable {
    // Fixed deposit amount set to 0.1 ETH
    uint256 public constant DEPOSIT_AMOUNT = 0.1 ether;

    // zk-SNARK verifier contract address
    IVerifier public immutable verifier;

    // Number of Merkle Tree levels
    uint32 public constant TREE_LEVELS = 20;

    // Track used nullifiers to prevent double-spending
    mapping(bytes32 => bool) public nullifiers;

    /// @notice Track commitments to ensure uniqueness
    mapping(bytes32 => bool) public commitments;

    // Current Merkle Tree root
    bytes32 public merkleRoot;

    // Events for deposit and withdrawal tracking
    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
    event Withdrawal(address to, bytes32 nullifierHash);

    // Index of the next leaf in the Merkle Tree
    uint32 public nextLeafIndex = 0;

    /**
     * @dev Constructor to initialize the verifier address.
     * @param _verifier Address of the zk-SNARK verifier contract.
     */
    constructor(address _verifier, address initialOwner) Ownable(initialOwner) {
        verifier = IVerifier(_verifier);
    }
    /**
     * @dev Allows users to deposit funds with a commitment.
     * @param _commitment Hash of the user's secret and recipient data.
     */

    function deposit(bytes32 _commitment) external payable nonReentrant {
        require(msg.value == DEPOSIT_AMOUNT, "Incorrect deposit amount");
        require(!commitments[_commitment], "Commitment already exists");

        commitments[_commitment] = true;
        // Simplified Merkle Tree update (for MVP)
        merkleRoot = keccak256(abi.encodePacked(merkleRoot, _commitment));
        emit Deposit(_commitment, nextLeafIndex, block.timestamp);
        nextLeafIndex += 1;
    }

    /**
     * @dev Withdraws funds using a zk-SNARK proof.
     * @param _proof zk-SNARK proof array.
     * @param _root Merkle root for verification.
     * @param _nullifierHash Hash to prevent double-spending.
     * @param _recipient Address to receive the withdrawn funds.
     */
    function withdraw(uint256[8] memory _proof, bytes32 _root, bytes32 _nullifierHash, address payable _recipient)
        external
        nonReentrant
    {
        require(!nullifiers[_nullifierHash], "Nullifier already spent");
        require(_root == merkleRoot, "Invalid Merkle root");

        nullifiers[_nullifierHash] = true;
        require(
            verifier.verifyProof(
                _proof, [uint256(_root), uint256(_nullifierHash), uint256(uint160(address(_recipient)))]
            ),
            "Invalid zk-SNARK proof"
        );
        (bool success,) = _recipient.call{value: DEPOSIT_AMOUNT}("");
        require(success, "Transfer failed");

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
