// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVerifier} from "./Verifier.sol";
import {Incremental, Poseidon2} from "./Incremental.sol";

/**
 * @title ShadowPool
 * @dev A multi-currency mixer contract for anonymous transactions using Noir zk-proofs.
 * Supports ETH and ERC20 tokens with dynamic fee mechanism and multi-deposit functionality.
 * Integrates with a Noir-generated verifier and supports a 20-level Merkle tree.
 */
contract ShadowPool is ReentrancyGuard, Ownable, Incremental {
    using SafeERC20 for IERC20;

    // Fee configuration
    uint256 public percentageFee; // Fee as percentage (basis points, e.g., 50 = 0.5%)
    uint256 public fixedFee; // Fixed fee in wei
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points

    // Address of the Noir verifier contract
    IVerifier public immutable i_verifier;

    // Mapping to track used nullifiers and prevent double-spending
    mapping(bytes32 => bool) public s_nullifiers;

    // Mapping to track commitments and ensure uniqueness
    mapping(bytes32 => bool) public s_commitments;

    // Structure for multi-deposit
    struct Deposit {
        address token; // Address(0) for ETH, ERC20 address for tokens
        uint256 amount;
        bytes32 commitment;
    }

    // Events for deposit and withdrawal tracking
    event SingleDeposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
    event MultiDeposit(bytes32[] commitments, uint32[] leafIndices, uint256 timestamp);
    event Withdrawal(address indexed to, bytes32[] nullifierHashes, address[] tokens, uint256[] amounts);
    event FeeUpdated(uint256 percentageFee, uint256 fixedFee);
    event FeeCollected(address indexed token, uint256 amount);

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
     * @notice Error that occurs when arrays have different lengths.
     * @param expected The expected length.
     * @param actual The actual length.
     */
    error Mixer__ArrayLengthMismatch(uint256 expected, uint256 actual);

    /**
     * @notice Error that occurs when percentage fee exceeds maximum allowed.
     * @param maxAllowed The maximum allowed percentage fee.
     * @param provided The provided percentage fee.
     */
    error Mixer__PercentageFeeTooHigh(uint256 maxAllowed, uint256 provided);

    /**
     * @dev Constructor to initialize the verifier, owner addresses, and fee configuration.
     * @param _verifier Address of the Noir verifier contract.
     * @param _hasher Address of the Poseidon2 hasher contract.
     * @param _merkleTreeDepth Depth of the Merkle tree.
     * @param initialOwner Address of the contract owner.
     * @param _percentageFee Initial percentage fee in basis points (e.g., 50 = 0.5%).
     * @param _fixedFee Initial fixed fee in wei.
     */
    constructor(
        IVerifier _verifier,
        Poseidon2 _hasher,
        uint32 _merkleTreeDepth,
        address initialOwner,
        uint256 _percentageFee,
        uint256 _fixedFee
    ) Incremental(_merkleTreeDepth, _hasher) Ownable(initialOwner) {
        i_verifier = _verifier;
        percentageFee = _percentageFee;
        fixedFee = _fixedFee;
    }

    /**
     * @dev Allows users to deposit multiple tokens (ETH and ERC20) with commitments.
     * Each deposit has its own commitment computed off-chain as Poseidon2(nullifier, secret, token_address, amount).
     * @param _deposits Array of deposit structures containing token, amount, and commitment.
     */
    function multiDeposit(Deposit[] calldata _deposits) external payable nonReentrant {
        uint256 totalEthValue = 0;
        bytes32[] memory commitments = new bytes32[](_deposits.length);
        uint32[] memory leafIndices = new uint32[](_deposits.length);

        // Process each deposit
        for (uint256 i = 0; i < _deposits.length; i++) {
            Deposit calldata dep = _deposits[i];

            // Check if the commitment is already added
            if (s_commitments[dep.commitment]) {
                revert Mixer__CommitmentAlreadyAdded(dep.commitment);
            }

            // Calculate fee for this deposit
            uint256 percentageFeeAmount = (dep.amount * percentageFee) / BASIS_POINTS;
            uint256 totalFee = percentageFeeAmount + fixedFee;

            // Ensure deposit amount is greater than fee
            if (dep.amount <= totalFee) {
                revert Mixer__FeeExceedsDepositValue({expected: dep.amount, actual: totalFee});
            }

            // Handle ETH deposits
            if (dep.token == address(0)) {
                totalEthValue += dep.amount;
            } else {
                // Handle ERC20 deposits
                IERC20(dep.token).safeTransferFrom(msg.sender, address(this), dep.amount);

                // Transfer fee to owner immediately for ERC20
                if (totalFee > 0) {
                    IERC20(dep.token).safeTransfer(owner(), totalFee);
                    emit FeeCollected(dep.token, totalFee);
                }
            }

            // Add the commitment to the mapping
            s_commitments[dep.commitment] = true;
            commitments[i] = dep.commitment;

            // Insert commitment into the Merkle tree
            leafIndices[i] = _insert(dep.commitment);
        }

        // Verify total ETH value matches msg.value
        if (totalEthValue != msg.value) {
            revert Mixer__DepositValueMismatch({expected: totalEthValue, actual: msg.value});
        }

        // Calculate and transfer ETH fees after all deposits are processed
        for (uint256 i = 0; i < _deposits.length; i++) {
            Deposit calldata dep = _deposits[i];
            if (dep.token == address(0)) {
                uint256 percentageFeeAmount = (dep.amount * percentageFee) / BASIS_POINTS;
                uint256 totalFee = percentageFeeAmount + fixedFee;

                if (totalFee > 0) {
                    (bool success,) = owner().call{value: totalFee}("");
                    if (!success) {
                        revert Mixer__PaymentFailed({recipient: owner(), amount: totalFee});
                    }
                    emit FeeCollected(dep.token, totalFee);
                }
            }
        }

        // Emit multi-deposit event
        emit MultiDeposit(commitments, leafIndices, block.timestamp);
    }

    /**
     * @dev Legacy single deposit function for backward compatibility.
     * @param _commitment Hash of the user's nullifier and secret.
     */
    function deposit(bytes32 _commitment) external payable nonReentrant {
        // Check if the commitment is already added
        if (s_commitments[_commitment]) {
            revert Mixer__CommitmentAlreadyAdded(_commitment);
        }

        // Calculate fee for this deposit
        uint256 percentageFeeAmount = (msg.value * percentageFee) / BASIS_POINTS;
        uint256 totalFee = percentageFeeAmount + fixedFee;

        // Ensure deposit amount is greater than fee
        if (msg.value <= totalFee) {
            revert Mixer__FeeExceedsDepositValue({expected: msg.value, actual: totalFee});
        }

        // Add the commitment to the mapping
        s_commitments[_commitment] = true;

        // Insert commitment into the Merkle tree
        uint32 leafIndex = _insert(_commitment);

        // Transfer fee to owner after commitment is added
        if (totalFee > 0) {
            (bool success,) = owner().call{value: totalFee}("");
            if (!success) {
                revert Mixer__PaymentFailed({recipient: owner(), amount: totalFee});
            }
            emit FeeCollected(address(0), totalFee);
        }

        // Emit deposit event
        emit SingleDeposit(_commitment, leafIndex, block.timestamp);
    }

    /**
     * @dev Withdraws funds using a Noir zk-proof for multi-currency deposits.
     * @param _proof Noir zk-proof (bytes format).
     * @param _root Merkle root for verification (public input).
     * @param _nullifierHashes Array of nullifier hashes to prevent double-spending.
     * @param _recipient Address to receive the withdrawn funds.
     * @param _tokens Array of token addresses to withdraw.
     * @param _amounts Array of amounts to withdraw.
     */
    function withdraw(
        bytes calldata _proof,
        bytes32 _root,
        bytes32[] calldata _nullifierHashes,
        address payable _recipient,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external nonReentrant {
        // Validate array lengths
        if (_nullifierHashes.length != _tokens.length || _tokens.length != _amounts.length) {
            revert Mixer__ArrayLengthMismatch({expected: _nullifierHashes.length, actual: _tokens.length});
        }

        // Ensure nullifiers haven't been used
        for (uint256 i = 0; i < _nullifierHashes.length; i++) {
            if (s_nullifiers[_nullifierHashes[i]]) {
                revert Mixer__NoteAlreadySpent({nullifierHash: _nullifierHashes[i]});
            }
            s_nullifiers[_nullifierHashes[i]] = true;
        }

        // Verify the Merkle root is known
        if (!isKnownRoot(_root)) {
            revert Mixer__UnknownRoot({root: _root});
        }

        // Prepare public inputs for Noir verification
        bytes32[] memory publicInputs = _preparePublicInputs(_root, _nullifierHashes, _recipient, _tokens, _amounts);

        // Verify the Noir proof
        if (!i_verifier.verify(_proof, publicInputs)) {
            revert Mixer__InvalidWithdrawProof();
        }

        // Transfer funds to recipient
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == address(0)) {
                // Transfer ETH
                (bool success,) = _recipient.call{value: _amounts[i]}("");
                if (!success) {
                    revert Mixer__PaymentFailed({recipient: _recipient, amount: _amounts[i]});
                }
            } else {
                // Transfer ERC20
                IERC20(_tokens[i]).safeTransfer(_recipient, _amounts[i]);
            }
        }

        // Emit withdrawal event
        emit Withdrawal(_recipient, _nullifierHashes, _tokens, _amounts);
    }

    /**
     * @dev Updates the fee configuration. Only callable by owner.
     * @param _percentageFee New percentage fee in basis points.
     * @param _fixedFee New fixed fee in wei.
     */
    function updateFees(uint256 _percentageFee, uint256 _fixedFee) external onlyOwner {
        // Limit percentage fee to 5% (500 basis points)
        if (_percentageFee > 500) {
            revert Mixer__PercentageFeeTooHigh({maxAllowed: 500, provided: _percentageFee});
        }

        percentageFee = _percentageFee;
        fixedFee = _fixedFee;

        emit FeeUpdated(_percentageFee, _fixedFee);
    }

    /**
     * @dev Returns the current contract balance for a specific token.
     * @param _token Token address (address(0) for ETH).
     * @return Balance of the token.
     */
    function getBalance(address _token) external view returns (uint256) {
        if (_token == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(_token).balanceOf(address(this));
        }
    }

    /**
     * @dev Internal function to prepare public inputs for Noir verification.
     * @param _root Merkle root.
     * @param _nullifierHashes Array of nullifier hashes.
     * @param _recipient Recipient address.
     * @param _tokens Array of token addresses.
     * @param _amounts Array of amounts.
     * @return Array of public inputs for Noir verification.
     */
    function _preparePublicInputs(
        bytes32 _root,
        bytes32[] calldata _nullifierHashes,
        address _recipient,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) internal pure returns (bytes32[] memory) {
        // Prepare public inputs: [root, nullifier_hashes[3], recipient, token_addresses[3], amounts[3]]
        bytes32[] memory publicInputs = new bytes32[](10);
        publicInputs[0] = _root;

        // Add nullifier hashes (pad to 3 elements)
        for (uint256 i = 0; i < 3; i++) {
            if (i < _nullifierHashes.length) {
                publicInputs[1 + i] = _nullifierHashes[i];
            } else {
                publicInputs[1 + i] = bytes32(0);
            }
        }

        // Add recipient
        publicInputs[4] = bytes32(uint256(uint160(_recipient)));

        // Add token addresses (pad to 3 elements)
        for (uint256 i = 0; i < 3; i++) {
            if (i < _tokens.length) {
                publicInputs[5 + i] = bytes32(uint256(uint160(_tokens[i])));
            } else {
                publicInputs[5 + i] = bytes32(0);
            }
        }

        // Add amounts (pad to 3 elements)
        for (uint256 i = 0; i < 3; i++) {
            if (i < _amounts.length) {
                publicInputs[8 + i] = bytes32(_amounts[i]);
            } else {
                publicInputs[8 + i] = bytes32(0);
            }
        }

        return publicInputs;
    }
}
