// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVerifier} from "./Verifier/Verifier.sol";
import {Incremental, Poseidon2} from "./Incremental.sol";

/**
 * @title ShadowPool
 * @dev A multi-currency mixer contract for anonymous transactions using Noir zk-proofs.
 * Supports ETH and ERC20 tokens with dynamic fee mechanism and multi-deposit functionality.
 * Integrates with a Noir-generated verifier and supports a 20-level Merkle tree.
 * Governance is handled by DAO contract.
 * @author Sergey Kerhet
 *
 */
contract ShadowPool is ReentrancyGuard, Incremental {
    using SafeERC20 for IERC20;

    // Fee configuration
    uint256 public percentageFee; // Fee as percentage (basis points, e.g., 50 = 0.5%)
    uint256 public fixedFee; // Fixed fee in wei
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 public constant MAXIMUM_PERCENTAGE_FEE = 500; // Maximum 5% fee (500 basis points)

    // Anonymity level thresholds
    uint256 public constant LOW_ANONYMITY_THRESHOLD = 10;
    uint256 public constant MEDIUM_ANONYMITY_THRESHOLD = 50;
    uint256 public constant HIGH_ANONYMITY_THRESHOLD = 100;

    // Wait time thresholds (in seconds)
    uint256 public constant SHORT_WAIT_TIME = 1800; // 30 minutes
    uint256 public constant LONG_WAIT_TIME = 3600; // 1 hour
    uint256 public constant SMALL_POOL_THRESHOLD = 20;
    uint256 public constant MEDIUM_POOL_THRESHOLD = 50;

    // Public inputs array size for Noir verification
    uint256 public constant PUBLIC_INPUTS_SIZE = 10;

    // Percentage calculation
    uint256 public constant PERCENTAGE_MULTIPLIER = 100;

    // Address of the Noir verifier contract
    IVerifier public immutable i_verifier;

    // Address of the DAO contract
    address public daoAddress;

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
    event DAOUpdated(address indexed oldDAO, address indexed newDAO);

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
     * @notice Error that occurs when caller is not the DAO.
     */
    error Mixer__NotDAO();

    /**
     * @notice Error that occurs when invalid address is provided.
     */
    error Mixer__InvalidAddress();

    /**
     * @dev Modifier to restrict access to DAO only
     */
    modifier onlyDAO() {
        if (msg.sender != daoAddress) {
            revert Mixer__NotDAO();
        }
        _;
    }

    /**
     * @dev Constructor to initialize the verifier, DAO address, and fee configuration.
     * @param _verifier Address of the Noir verifier contract.
     * @param _hasher Address of the Poseidon2 hasher contract.
     * @param _merkleTreeDepth Depth of the Merkle tree.
     * @param _daoAddress Address of the DAO contract.
     * @param _percentageFee Initial percentage fee in basis points (e.g., 50 = 0.5%).
     * @param _fixedFee Initial fixed fee in wei.
     */
    constructor(
        IVerifier _verifier,
        Poseidon2 _hasher,
        uint32 _merkleTreeDepth,
        address _daoAddress,
        uint256 _percentageFee,
        uint256 _fixedFee
    ) Incremental(_merkleTreeDepth, _hasher) {
        i_verifier = _verifier;
        daoAddress = _daoAddress;
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
                    IERC20(dep.token).safeTransfer(daoAddress, totalFee);
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
                    (bool success,) = daoAddress.call{value: totalFee}("");
                    if (!success) {
                        revert Mixer__PaymentFailed({recipient: daoAddress, amount: totalFee});
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
            (bool success,) = daoAddress.call{value: totalFee}("");
            if (!success) {
                revert Mixer__PaymentFailed({recipient: daoAddress, amount: totalFee});
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
     * @dev Updates the fee configuration. Only callable by DAO.
     * @param _percentageFee New percentage fee in basis points.
     * @param _fixedFee New fixed fee in wei.
     */
    function updateFees(uint256 _percentageFee, uint256 _fixedFee) external onlyDAO {
        // Limit percentage fee to 5% (MAXIMUM_PERCENTAGE_FEE basis points)
        if (_percentageFee > MAXIMUM_PERCENTAGE_FEE) {
            revert Mixer__PercentageFeeTooHigh({maxAllowed: MAXIMUM_PERCENTAGE_FEE, provided: _percentageFee});
        }

        percentageFee = _percentageFee;
        fixedFee = _fixedFee;

        emit FeeUpdated(_percentageFee, _fixedFee);
    }

    /**
     * @dev Updates the DAO address. Only callable by current DAO.
     * @param _newDAOAddress New DAO address.
     */
    function updateDAOAddress(address _newDAOAddress) external onlyDAO {
        if (_newDAOAddress == address(0)) {
            revert Mixer__InvalidAddress();
        }

        address oldDAO = daoAddress;
        daoAddress = _newDAOAddress;

        emit DAOUpdated(oldDAO, _newDAOAddress);
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
        bytes32[] memory publicInputs = new bytes32[](PUBLIC_INPUTS_SIZE);
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

    // ============ USER UTILITY FUNCTIONS ============

    /**
     * @dev Returns the current number of deposits in the pool.
     * @return Number of deposits in the pool.
     */
    function getPoolSize() external view returns (uint256) {
        return s_nextLeafIndex;
    }

    /**
     * @dev Returns the anonymity level based on pool size.
     * @return Anonymity level description.
     */
    function getAnonymityLevel() external view returns (string memory) {
        uint256 size = s_nextLeafIndex;
        if (size < LOW_ANONYMITY_THRESHOLD) return "Low anonymity";
        if (size < MEDIUM_ANONYMITY_THRESHOLD) return "Medium anonymity";
        if (size < HIGH_ANONYMITY_THRESHOLD) return "High anonymity";
        return "Maximum anonymity";
    }

    /**
     * @dev Returns the recommended wait time for optimal anonymity.
     * @return Recommended wait time in seconds.
     */
    function getOptimalWithdrawTime() external view returns (uint256) {
        uint256 currentSize = s_nextLeafIndex;
        if (currentSize < SMALL_POOL_THRESHOLD) {
            return LONG_WAIT_TIME; // Wait 1 hour
        } else if (currentSize < MEDIUM_POOL_THRESHOLD) {
            return SHORT_WAIT_TIME; // Wait 30 minutes
        } else {
            return 0; // Can withdraw now
        }
    }

    /**
     * @dev Calculates the fee for a given deposit amount.
     * @param _amount Deposit amount in wei.
     * @return Total fee in wei.
     */
    function calculateFee(uint256 _amount) external view returns (uint256) {
        uint256 percentageFeeAmount = (_amount * percentageFee) / BASIS_POINTS;
        return percentageFeeAmount + fixedFee;
    }

    /**
     * @dev Returns detailed fee breakdown for a given amount.
     * @param _amount Deposit amount in wei.
     * @return percentageFeeAmount Percentage fee amount.
     * @return fixedFeeAmount Fixed fee amount.
     * @return totalFee Total fee amount.
     */
    function getFeeBreakdown(uint256 _amount)
        external
        view
        returns (uint256 percentageFeeAmount, uint256 fixedFeeAmount, uint256 totalFee)
    {
        percentageFeeAmount = (_amount * percentageFee) / BASIS_POINTS;
        fixedFeeAmount = fixedFee;
        totalFee = percentageFeeAmount + fixedFeeAmount;
    }

    /**
     * @dev Checks if a commitment exists in the pool.
     * @param _commitment Commitment hash to check.
     * @return True if commitment exists.
     */
    function isDepositValid(bytes32 _commitment) external view returns (bool) {
        return s_commitments[_commitment];
    }

    /**
     * @dev Returns pool statistics for transparency.
     * @return totalDeposits Number of total deposits.
     * @return currentRoot Current Merkle root.
     * @return currentPercentageFee Current percentage fee.
     * @return currentFixedFee Current fixed fee.
     */
    function getPoolStats()
        external
        view
        returns (uint256 totalDeposits, bytes32 currentRoot, uint256 currentPercentageFee, uint256 currentFixedFee)
    {
        totalDeposits = s_nextLeafIndex;
        currentRoot = getLatestRoot();
        currentPercentageFee = percentageFee;
        currentFixedFee = fixedFee;
    }

    /**
     * @dev Returns the maximum number of deposits the pool can handle.
     * @return Maximum number of deposits.
     */
    function getMaxPoolSize() external view returns (uint256) {
        return 2 ** i_depth;
    }

    /**
     * @dev Returns the pool utilization percentage.
     * @return Utilization percentage (0-100).
     */
    function getPoolUtilization() external view returns (uint256) {
        uint256 maxSize = 2 ** i_depth;
        return (s_nextLeafIndex * PERCENTAGE_MULTIPLIER) / maxSize;
    }

    /**
     * @dev Returns whether the pool is full.
     * @return True if pool is full.
     */
    function isPoolFull() external view returns (bool) {
        return s_nextLeafIndex >= 2 ** i_depth;
    }
}
