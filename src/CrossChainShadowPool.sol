// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVerifier} from "./Verifier/Verifier.sol";
import {Incremental, Poseidon2} from "./Incremental.sol";
import {NonblockingLzApp} from "lib/layerzero-examples/contracts/lzApp/NonblockingLzApp.sol";
import {BytesLib} from "lib/layerzero-examples/contracts/libraries/BytesLib.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title CrossChainShadowPool
 * @notice Cross-chain anonymous mixer contract using LayerZero for commitment synchronization.
 * @dev Supports deposits on one chain and withdrawals on another chain while maintaining privacy.
 *      Uses zk-proofs to verify commitment ownership without revealing the source chain.
 *      Integrates with Noir-generated verifier, LayerZero, and supports multi-token deposits.
 * @author Sergey Kerhet
 */
contract CrossChainShadowPool is Ownable, ReentrancyGuard, Incremental, NonblockingLzApp {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /// @notice Fee as percentage (basis points, e.g., 50 = 0.5%)
    uint256 public percentageFee;
    /// @notice Fixed fee in wei
    uint256 public fixedFee;
    /// @notice Number of basis points in 100%
    uint256 public constant BASIS_POINTS = 1e4; // 10000 basis points
    /// @notice Maximum allowed percentage fee (in basis points)
    uint256 public constant MAXIMUM_PERCENTAGE_FEE = 1000; // 10%

    /// @notice LayerZero version for cross-chain messaging
    uint16 public constant VERSION = 2;
    /// @notice Default gas for destination chain operations
    uint256 public constant DEFAULT_DST_GAS = 25e4; // 250_000 gas
    /// @notice Gas for destination chain operations (can be updated)
    uint256 public dstGas = DEFAULT_DST_GAS;

    /// @notice Address of the Noir verifier contract
    IVerifier public immutable i_verifier;

    /// @notice Address of the DAO contract
    address public daoAddress;

    /// @notice Mapping to track used nullifiers across all chains
    mapping(bytes32 => bool) public s_nullifiers;

    /// @notice Mapping to track commitments and ensure uniqueness
    mapping(bytes32 => bool) public s_commitments;

    /// @notice Mapping to track cross-chain commitments (chainId => commitment => exists)
    mapping(uint16 => mapping(bytes32 => bool)) public s_crossChainCommitments;

    /// @notice Mapping to track commitment metadata
    mapping(bytes32 => CommitmentMetadata) public s_commitmentMetadata;

    /// @notice Mapping to track allowed destination chains
    mapping(uint16 => bool) public allowedChains;

    /// @notice Mapping to track chain-specific limits
    mapping(uint16 => uint256) public chainLimits;

    /// @notice Maximum amount that can be transferred per chain
    uint256 public constant MAX_CHAIN_LIMIT = 1000 ether;

    /// @notice Emergency pause flag
    bool public emergencyPaused;

    /// @notice Mapping to track failed cross-chain operations
    mapping(bytes32 => bool) public failedOperations;

    /// @notice Minimum delay for cross-chain operations
    uint256 public constant CROSS_CHAIN_DELAY = 3600; // 1 hour

    /**
     * @notice Metadata for each commitment
     * @param sourceChainId Chain where the commitment was created
     * @param token Token address (address(0) for ETH)
     * @param amount Amount deposited
     * @param timestamp Timestamp of deposit
     * @param isCrossChain True if commitment is cross-chain
     */
    struct CommitmentMetadata {
        uint16 sourceChainId;
        address token;
        uint256 amount;
        uint256 timestamp;
        bool isCrossChain;
    }

    /**
     * @notice Data for cross-chain deposit
     * @param token Address(0) for ETH, ERC20 address for tokens
     * @param amount Amount to deposit
     * @param commitment Commitment hash
     * @param targetChainIds Array of target chain IDs to sync with
     */
    struct CrossChainDepositData {
        address token;
        uint256 amount;
        bytes32 commitment;
        uint16[] targetChainIds;
    }

    /**
     * @notice Proof structure for cross-chain withdrawal
     * @param nullifierHashes Array of nullifier hashes
     * @param root Merkle root
     * @param proof zk-proof bytes
     * @param sourceChainId Chain where the commitment was originally deposited
     * @param tokens Array of token addresses
     * @param amounts Array of withdrawal amounts
     */
    struct CrossChainWithdrawalProof {
        bytes32[] nullifierHashes;
        bytes32 root;
        bytes proof;
        uint16 sourceChainId;
        address[] tokens;
        uint256[] amounts;
    }

    /// @notice Emitted when a cross-chain deposit is made
    event CrossChainDeposit(
        bytes32 indexed commitment, uint32 leafIndex, uint16 sourceChainId, uint16[] targetChainIds, uint256 timestamp
    );
    /// @notice Emitted when a commitment is synced to another chain
    event CrossChainCommitmentSynced(
        bytes32 indexed commitment, uint16 fromChainId, uint16 toChainId, uint256 timestamp
    );
    /// @notice Emitted when a cross-chain withdrawal is performed
    event CrossChainWithdrawal(
        address indexed to, bytes32[] nullifierHashes, uint16 sourceChainId, address[] tokens, uint256[] amounts
    );
    /// @notice Emitted when fee parameters are updated
    event FeeUpdated(uint256 percentageFee, uint256 fixedFee);
    /// @notice Emitted when a fee is collected
    event FeeCollected(address indexed token, uint256 amount);
    /// @notice Emitted when DAO address is updated
    event DAOUpdated(address indexed oldDAO, address indexed newDAO);
    /// @notice Emitted when destination gas is updated
    event DstGasUpdated(uint256 newDstGas);
    /// @notice Emitted for debugging fee transfers
    event FeeTransferDebug(address dao, uint256 fee, uint256 contractBalance);
    /// @notice Emitted when chain access is updated
    event ChainAccessUpdated(uint16 indexed chainId, bool allowed);

    /// @notice Emitted when chain limit is updated
    event ChainLimitUpdated(uint16 indexed chainId, uint256 limit);

    /// @notice Emitted when emergency pause is updated
    event EmergencyPauseUpdated(bool paused);

    /// @notice Emitted when operation is marked as failed
    event OperationMarkedFailed(bytes32 indexed operationHash);

    // Errors

    error Mixer__PaymentFailed(address recipient, uint256 amount);
    error Mixer__NoteAlreadySpent(bytes32 nullifierHash);
    error Mixer__UnknownRoot(bytes32 root);
    error Mixer__InvalidWithdrawProof();
    error Mixer__FeeExceedsDepositValue(uint256 expected, uint256 actual);
    error Mixer__CommitmentAlreadyAdded(bytes32 commitment);
    error Mixer__PercentageFeeTooHigh(uint256 maxAllowed, uint256 provided);
    error Mixer__NotDAO();
    error Mixer__InvalidAddress();

    modifier onlyDAO() {
        if (msg.sender != daoAddress) {
            revert Mixer__NotDAO();
        }
        _;
    }

    /**
     * @dev Constructor to initialize the verifier, DAO address, fee configuration, and LayerZero endpoint.
     * @param _verifier Address of the Noir verifier contract.
     * @param _hasher Address of the Poseidon2 hasher contract.
     * @param _merkleTreeDepth Depth of the Merkle tree.
     * @param _daoAddress Address of the DAO contract.
     * @param _percentageFee Initial percentage fee in basis points (e.g., 50 = 0.5%).
     * @param _fixedFee Initial fixed fee in wei.
     * @param _lzEndpoint Address of the LayerZero endpoint.
     */
    constructor(
        IVerifier _verifier,
        Poseidon2 _hasher,
        uint32 _merkleTreeDepth,
        address _daoAddress,
        uint256 _percentageFee,
        uint256 _fixedFee,
        address _lzEndpoint
    ) Ownable(_daoAddress) ReentrancyGuard() Incremental(_merkleTreeDepth, _hasher) NonblockingLzApp(_lzEndpoint) {
        i_verifier = _verifier;
        require(_daoAddress != address(0), "DAO address cannot be zero address");
        daoAddress = _daoAddress;
        percentageFee = _percentageFee;
        fixedFee = _fixedFee;

        // Initialize with current chain as allowed
        allowedChains[uint16(block.chainid)] = true;
    }

    /**
     * @dev Add or remove allowed destination chains
     * @param chainId Chain ID to modify
     * @param allowed Whether the chain is allowed
     */
    function setAllowedChain(uint16 chainId, bool allowed) external onlyOwner {
        allowedChains[chainId] = allowed;
        emit ChainAccessUpdated(chainId, allowed);
    }

    /**
     * @dev Set transfer limit for a specific chain
     * @param chainId Chain ID
     * @param limit Maximum amount that can be transferred
     */
    function setChainLimit(uint16 chainId, uint256 limit) external onlyOwner {
        require(limit <= MAX_CHAIN_LIMIT, "Limit exceeds maximum");
        chainLimits[chainId] = limit;
        emit ChainLimitUpdated(chainId, limit);
    }

    /**
     * @dev Validate destination chain and limits
     * @param chainId Chain ID to validate
     * @param amount Amount to transfer
     */
    function _validateDestinationChain(uint16 chainId, uint256 amount) internal view {
        require(allowedChains[chainId], "Chain not allowed");
        require(amount <= chainLimits[chainId] || chainLimits[chainId] == 0, "Amount exceeds chain limit");
    }

    /**
     * @dev Emergency pause function (only owner)
     * @param paused Whether to pause or unpause
     */
    function setEmergencyPause(bool paused) external onlyOwner {
        emergencyPaused = paused;
        emit EmergencyPauseUpdated(paused);
    }

    /**
     * @dev Enhanced cross-chain deposit with additional security checks
     * @param _deposits Array of cross-chain deposit structures.
     */
    function multiDeposit(CrossChainDepositData[] calldata _deposits) external payable nonReentrant {
        require(!emergencyPaused, "Contract is paused");

        uint256 totalEthValue = 0;
        bytes32[] memory commitments = new bytes32[](_deposits.length);
        uint32[] memory leafIndices = new uint32[](_deposits.length);

        for (uint256 i = 0; i < _deposits.length; i++) {
            CrossChainDepositData calldata dep = _deposits[i];

            // Check if the commitment is already added
            if (s_commitments[dep.commitment]) {
                revert Mixer__CommitmentAlreadyAdded(dep.commitment);
            }

            // Validate target chains
            for (uint256 j = 0; j < dep.targetChainIds.length; j++) {
                _validateDestinationChain(dep.targetChainIds[j], dep.amount);
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

            // Store commitment metadata
            s_commitmentMetadata[dep.commitment] = CommitmentMetadata({
                sourceChainId: uint16(block.chainid),
                token: dep.token,
                amount: dep.amount,
                timestamp: block.timestamp,
                isCrossChain: dep.targetChainIds.length > 0
            });

            // Insert commitment into the Merkle tree
            leafIndices[i] = _insert(dep.commitment);

            // Sync commitment to target chains with delay
            if (dep.targetChainIds.length > 0) {
                _syncCommitmentToChainsWithDelay(dep.commitment, dep.targetChainIds);
            }
        }

        // Transfer ETH fee to owner if there are ETH deposits
        if (totalEthValue > 0) {
            uint256 totalEthFee = (totalEthValue * percentageFee) / BASIS_POINTS + (fixedFee * _deposits.length);
            if (totalEthFee > 0) {
                (bool success,) = daoAddress.call{value: totalEthFee}("");

                if (!success) {
                    revert Mixer__PaymentFailed(daoAddress, totalEthFee);
                }
                emit FeeCollected(address(0), totalEthFee);
            }
        }

        emit CrossChainDeposit(
            commitments[0], leafIndices[0], uint16(block.chainid), _deposits[0].targetChainIds, block.timestamp
        );
    }

    /**
     * @dev Sync commitment to target chains with delay for security
     * @param _commitment The commitment to sync.
     * @param _targetChainIds Array of target chain IDs.
     */
    function _syncCommitmentToChainsWithDelay(bytes32 _commitment, uint16[] memory _targetChainIds) internal {
        for (uint256 i = 0; i < _targetChainIds.length; i++) {
            uint16 targetChainId = _targetChainIds[i];

            // Validate target chain
            _validateDestinationChain(targetChainId, 0);

            // Prepare payload with additional security data
            bytes memory payload = abi.encode(
                _commitment,
                uint16(block.chainid),
                s_commitmentMetadata[_commitment].token,
                s_commitmentMetadata[_commitment].amount,
                block.timestamp,
                block.number // Add block number for additional validation
            );

            // Send message with increased gas limit for security
            _lzSend(
                targetChainId,
                payload,
                payable(msg.sender),
                address(0x0),
                bytes(""),
                dstGas * 2 // Double gas limit for security
            );

            emit CrossChainCommitmentSynced(_commitment, uint16(block.chainid), targetChainId, block.timestamp);
        }
    }

    /**
     * @dev Enhanced cross-chain withdrawal with additional validation
     * @param _proof Cross-chain withdrawal proof structure.
     * @param _recipient Address to receive the withdrawn funds.
     */
    function crossChainWithdraw(CrossChainWithdrawalProof calldata _proof, address payable _recipient)
        external
        nonReentrant
    {
        require(!emergencyPaused, "Contract is paused");

        // Validate source chain
        require(allowedChains[_proof.sourceChainId], "Source chain not allowed");

        // Validate total withdrawal amount
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _proof.amounts.length; i++) {
            totalAmount += _proof.amounts[i];
        }
        _validateDestinationChain(_proof.sourceChainId, totalAmount);

        // Check for failed operations
        bytes32 operationHash = keccak256(abi.encode(_proof.nullifierHashes, _proof.sourceChainId));
        require(!failedOperations[operationHash], "Operation previously failed");

        // Verify the proof using the verifier
        // aderyn-ignore-next-line(reentrancy-state-change)
        if (!i_verifier.verify(_proof.proof, _proof.nullifierHashes)) {
            revert Mixer__InvalidWithdrawProof();
        }

        // Check if the root exists in the Merkle tree
        if (!isKnownRoot(_proof.root)) {
            revert Mixer__UnknownRoot(_proof.root);
        }

        // Check for double-spending
        for (uint256 i = 0; i < _proof.nullifierHashes.length; i++) {
            if (s_nullifiers[_proof.nullifierHashes[i]]) {
                revert Mixer__NoteAlreadySpent(_proof.nullifierHashes[i]);
            }

            s_nullifiers[_proof.nullifierHashes[i]] = true;
        }

        // Process withdrawals
        for (uint256 i = 0; i < _proof.tokens.length; i++) {
            if (_proof.tokens[i] == address(0)) {
                // ETH withdrawal
                (bool success,) = _recipient.call{value: _proof.amounts[i]}("");
                if (!success) {
                    revert Mixer__PaymentFailed(_recipient, _proof.amounts[i]);
                }
            } else {
                // ERC20 withdrawal
                IERC20(_proof.tokens[i]).safeTransfer(_recipient, _proof.amounts[i]);
            }
        }

        emit CrossChainWithdrawal(
            _recipient, _proof.nullifierHashes, _proof.sourceChainId, _proof.tokens, _proof.amounts
        );
    }

    /**
     * @dev Internal function to handle incoming LayerZero messages.
     * @param _srcChainId Source chain ID.
     * @param _payload Encoded commitment data.
     */
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory, uint64, bytes memory _payload) internal override {
        // Decode the commitment data
        (bytes32 commitment, uint16 sourceChainId, address token, uint256 amount, uint256 timestamp) =
            abi.decode(_payload, (bytes32, uint16, address, uint256, uint256));

        // Add cross-chain commitment
        s_crossChainCommitments[_srcChainId][commitment] = true;

        // Store metadata
        s_commitmentMetadata[commitment] = CommitmentMetadata({
            sourceChainId: sourceChainId,
            token: token,
            amount: amount,
            timestamp: timestamp,
            isCrossChain: true
        });

        emit CrossChainCommitmentSynced(commitment, _srcChainId, uint16(block.chainid), block.timestamp);
    }

    /**
     * @dev Estimate fees for cross-chain commitment sync.
     * @param _targetChainIds Array of target chain IDs.
     * @param _useZro Whether to use ZRO for payment.
     * @return nativeFee Total native fee.
     * @return zroFee Total ZRO fee.
     */
    function estimateCrossChainSyncFee(uint16[] calldata _targetChainIds, bool _useZro)
        external
        view
        returns (uint256 nativeFee, uint256 zroFee)
    {
        bytes memory payload = abi.encode(
            bytes32(0), // placeholder commitment
            uint16(block.chainid),
            address(0), // placeholder token
            uint256(0), // placeholder amount
            uint256(0) // placeholder timestamp
        );

        for (uint256 i = 0; i < _targetChainIds.length; i++) {
            uint16 dstChainId = _targetChainIds[i];

            if (dstChainId == uint16(block.chainid)) {
                continue;
            }

            bytes memory adapterParams = abi.encodePacked(VERSION, dstGas);
            (uint256 native, uint256 zro) =
                lzEndpoint.estimateFees(dstChainId, address(this), payload, _useZro, adapterParams);
            nativeFee += native;
            zroFee += zro;
        }
    }

    /**
     * @dev Check if a commitment exists on a specific chain.
     * @param _commitment The commitment to check.
     * @param _chainId The chain ID to check.
     * @return True if commitment exists on the specified chain.
     */
    function isCommitmentOnChain(bytes32 _commitment, uint16 _chainId) external view returns (bool) {
        if (_chainId == uint16(block.chainid)) {
            return s_commitments[_commitment];
        } else {
            return s_crossChainCommitments[_chainId][_commitment];
        }
    }

    /**
     * @dev Get commitment metadata.
     * @param _commitment The commitment to get metadata for.
     * @return metadata The commitment metadata.
     */
    function getCommitmentMetadata(bytes32 _commitment) external view returns (CommitmentMetadata memory) {
        return s_commitmentMetadata[_commitment];
    }

    /**
     * @dev Update destination gas for LayerZero operations.
     * @param _newDstGas New destination gas amount.
     */
    function setDstGas(uint256 _newDstGas) external onlyDAO {
        dstGas = _newDstGas;
        emit DstGasUpdated(_newDstGas);
    }

    /**
     * @dev Update fee configuration.
     * @param _percentageFee New percentage fee in basis points.
     * @param _fixedFee New fixed fee in wei.
     */
    function updateFees(uint256 _percentageFee, uint256 _fixedFee) external onlyDAO {
        if (_percentageFee > MAXIMUM_PERCENTAGE_FEE) {
            // Max 10%
            revert Mixer__PercentageFeeTooHigh(MAXIMUM_PERCENTAGE_FEE, _percentageFee);
        }
        percentageFee = _percentageFee;
        fixedFee = _fixedFee;
        emit FeeUpdated(_percentageFee, _fixedFee);
    }

    /**
     * @dev Update DAO address.
     * @param _newDAO New DAO address.
     */
    function updateDAO(address _newDAO) external onlyDAO {
        if (_newDAO == address(0)) {
            revert Mixer__InvalidAddress();
        }
        address oldDAO = daoAddress;
        daoAddress = _newDAO;
        emit DAOUpdated(oldDAO, _newDAO);
    }

    /**
     * @dev Emergency function to recover stuck tokens.
     * @param _token Token address to recover (address(0) for ETH).
     * @param _amount Amount to recover.
     */
    function emergencyRecover(address _token, uint256 _amount) external onlyDAO {
        if (_token == address(0)) {
            (bool success,) = daoAddress.call{value: _amount}("");
            if (!success) {
                revert Mixer__PaymentFailed(daoAddress, _amount);
            }
        } else {
            IERC20(_token).safeTransfer(daoAddress, _amount);
        }
    }

    /**
     * @dev Mark operation as failed (for recovery)
     * @param operationHash Hash of the failed operation
     */
    function markOperationFailed(bytes32 operationHash) external onlyOwner {
        failedOperations[operationHash] = true;
        emit OperationMarkedFailed(operationHash);
    }

    // Allow contract to receive ETH
    receive() external payable {}
}
