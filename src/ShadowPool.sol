// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @notice Interface for zk-SNARK verifier

interface IVerifier {
    function verifyProof(uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c, uint256[3] memory input)
        external
        view
        returns (bool);
}

/// @title ShadowPool - A privacy-focused mixer for anonymous ETH transactions
/// @notice Allows users to deposit and withdraw ETH anonymously using zk-SNARK proofs
contract ShadowPool is ReentrancyGuard, Ownable {
    /// @notice Fixed deposit amount (0.1 ETH)
    uint256 public constant DEPOSIT_AMOUNT = 0.1 ether;

    /// @notice Address of the zk-SNARK verifier contract
    address public immutable verifier;

    /// @notice Mapping of commitment hashes to track used commitments
    mapping(bytes32 => bool) public commitments;
    /// @notice Mapping of nullifier hashes to prevent double-spending
    mapping(bytes32 => bool) public nullifiers;

    /// @notice Merkle tree root for commitments
    bytes32 public merkleRoot;
    /// @notice Current leaf index for Merkle tree
    uint32 public nextLeafIndex;

    /// @notice Event emitted when a deposit is made
    /// @param commitment Hash of the commitment
    /// @param leafIndex Index of the leaf in the Merkle tree
    /// @param timestamp Timestamp of the deposit
    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);

    /// @notice Event emitted when a withdrawal is made
    /// @param to Recipient address
    /// @param nullifierHash Nullifier hash to prevent double-spending
    event Withdrawal(address indexed to, bytes32 indexed nullifierHash);

    /// @notice Constructor to set the verifier address
    /// @param _verifier Address of the zk-SNARK verifier contract
    constructor(address _verifier) Ownable(msg.sender) {
        verifier = _verifier;
    }

    /// @notice Deposits 0.1 ETH with a commitment hash
    /// @param _commitment Hash of the commitment (generated off-chain)
    function deposit(bytes32 _commitment) external payable nonReentrant {
        require(msg.value == DEPOSIT_AMOUNT, "Invalid deposit amount");
        require(!commitments[_commitment], "Commitment already used");

        commitments[_commitment] = true;
        // Update Merkle root (simplified for MVP, assumes off-chain tree updates)
        merkleRoot = keccak256(abi.encodePacked(merkleRoot, _commitment));
        emit Deposit(_commitment, nextLeafIndex, block.timestamp);
        nextLeafIndex++;
    }

    /// @notice Withdraws funds to a recipient address using a zk-SNARK proof
    /// @param a zk-SNARK proof parameter a
    /// @param b zk-SNARK proof parameter b
    /// @param c zk-SNARK proof parameter c
    /// @param input Public inputs [merkleRoot, nullifierHash, recipient]
    /// @param _recipient Address to receive the withdrawn funds
    /// @param _nullifierHash Nullifier hash to prevent double-spending
    function withdraw(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[3] memory input,
        address payable _recipient,
        bytes32 _nullifierHash
    ) external nonReentrant {
        require(!nullifiers[_nullifierHash], "Nullifier already used");
        require(input[0] == uint256(merkleRoot), "Invalid Merkle root");
        require(input[2] == uint256(uint160(address(_recipient))), "Invalid recipient");

        nullifiers[_nullifierHash] = true;

        require(IVerifier(verifier).verifyProof(a, b, c, input), "Invalid zk-SNARK proof");

        (bool success,) = _recipient.call{value: DEPOSIT_AMOUNT}("");
        require(success, "Transfer failed");

        emit Withdrawal(_recipient, _nullifierHash);
    }

    /// @notice Returns the contract balance (for debugging)
    /// @return Current balance in wei
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
