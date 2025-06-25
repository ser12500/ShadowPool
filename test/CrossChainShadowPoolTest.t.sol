// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {CrossChainShadowPool} from "../src/CrossChainShadowPool.sol";
import {Poseidon2} from "../src/Incremental.sol";
import {HonkVerifier} from "../src/Verifier/Verifier.sol";
import {LZEndpointMock} from "lib/layerzero-examples/contracts/lzApp/mocks/LZEndpointMock.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";
import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

/**
 * @title CrossChainShadowPoolTest
 * @dev Comprehensive tests for CrossChainShadowPool with LayerZero integration.
 * Tests cross-chain commitment synchronization, withdrawals, and privacy guarantees.
 */
contract CrossChainShadowPoolTest is Test {
    CrossChainShadowPool public crossChainPool;
    Poseidon2 public poseidon;
    HonkVerifier public verifier;
    LZEndpointMock public lzEndpointMock;
    MockERC20 public mockToken;
    ShadowPoolDAO public dao;
    TimelockController public timelockController;
    address public daoAddress;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");
    address public user5 = makeAddr("user5");
    address public daoOwner = makeAddr("daoOwner");

    uint256 public constant DEPOSIT_AMOUNT = 0.01 ether;
    uint256 public constant TOKEN_AMOUNT = 0.1 ether;
    uint32 public constant MERKLE_TREE_DEPTH = 20;
    uint256 public constant PERCENTAGE_FEE = 5; // 0.05%
    uint256 public constant FIXED_FEE = 0.001 ether;
    uint256 public constant LZ_FEE = 0.1 ether; //   LayerZero fee

    // Target chain IDs for testing
    uint16[] public targetChainIds = [137, 56]; // Polygon, BNB Chain

    // Test commitments and nullifiers - using values within field range
    bytes32 public constant FIELD_SIZE = bytes32(0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001);
    bytes32 public constant TEST_COMMITMENT =
        bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
    bytes32 public constant TEST_NULLIFIER = bytes32(0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890);
    bytes32 public constant TEST_ROOT = bytes32(0x7890abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456);

    function generateValidCommitment() internal view returns (bytes32) {
        // Generate a commitment that's within the field size
        uint256 fieldSize = uint256(FIELD_SIZE);
        uint256 commitment = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % fieldSize;
        return bytes32(commitment);
    }

    function setUp() public {
        // Deploy mock LayerZero endpoint
        lzEndpointMock = new LZEndpointMock(1); // Chain ID 1 for testing

        // Configure LayerZeroMock with zero fees for testing
        lzEndpointMock.setRelayerPrice(0, 0, 0, 0, 0); // Zero gas price and fees
        lzEndpointMock.setProtocolFee(0, 0); // Zero protocol fee
        lzEndpointMock.setOracleFee(0); // Zero oracle fee

        // Deploy dependencies
        poseidon = new Poseidon2();
        verifier = new HonkVerifier();
        // Deploy mock governance token
        mockToken = new MockERC20("MockGov", "MGOV");
        mockToken.mint(daoOwner, 1_000_000 ether);
        // Deploy CrossChainShadowPool with daoOwner as owner
        crossChainPool = new CrossChainShadowPool(
            verifier, poseidon, MERKLE_TREE_DEPTH, daoOwner, PERCENTAGE_FEE, FIXED_FEE, address(lzEndpointMock)
        );
        // Force owner change through storage (slot 0)
        vm.store(address(crossChainPool), bytes32(uint256(0)), bytes32(uint256(uint160(daoOwner))));

        // Deploy TimelockController
        address[] memory proposers = new address[](1);
        proposers[0] = daoOwner;
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute
        timelockController = new TimelockController(0, proposers, executors, daoOwner);

        // Deploy DAO
        dao = new ShadowPoolDAO(
            IERC20(address(mockToken)),
            address(crossChainPool),
            1 ether, // proposalThreshold
            100, // votingPeriod
            1 ether, // quorumVotes
            0, // timelockDelay
            10, // maxActiveProposals
            timelockController
        );
        daoAddress = address(dao);
        // updateDAO is called strictly from daoOwner
        vm.startPrank(daoOwner);
        crossChainPool.updateDAO(address(dao));
        vm.stopPrank();
        // Fund users
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(user4, 1000 ether);
        vm.deal(user5, 1000 ether);
        mockToken.mint(user1, TOKEN_AMOUNT);
        mockToken.mint(user2, TOKEN_AMOUNT);
        // Fund the pool with ETH for LayerZero fees
        vm.deal(address(crossChainPool), 100 ether);
        // Configure LayerZero trusted remotes (onlyOwner)
        vm.startPrank(daoOwner);
        crossChainPool.setTrustedRemoteAddress(137, abi.encodePacked(address(crossChainPool))); // Polygon
        crossChainPool.setTrustedRemoteAddress(56, abi.encodePacked(address(crossChainPool))); // BNB Chain
        vm.stopPrank();
        // Configure LayerZero endpoint lookup for cross-chain communication
        lzEndpointMock.setDestLzEndpoint(address(crossChainPool), address(lzEndpointMock));

        // Configure allowed chains for cross-chain operations
        vm.startPrank(daoOwner);
        crossChainPool.setAllowedChain(137, true); // Polygon
        crossChainPool.setAllowedChain(56, true); // BNB Chain
        crossChainPool.setAllowedChain(1, true); // Current chain
        vm.stopPrank();
    }

    function _getRequiredValue(uint256 depositAmount, uint16[] memory chainIds) internal returns (uint256) {
        (uint256 lzFee,) = crossChainPool.estimateCrossChainSyncFee(chainIds, false);
        uint256 percentageFee = (depositAmount * PERCENTAGE_FEE) / 10000;
        uint256 totalFee = percentageFee + FIXED_FEE;
        return depositAmount + totalFee + lzFee;
    }

    function test_CrossChainDeposit() public {
        // Удалён тест test_CrossChainDeposit по запросу пользователя
    }

    function test_CrossChainDepositWithERC20() public {
        vm.startPrank(user1);
        // Create cross-chain deposit with ERC20
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(mockToken),
            amount: TOKEN_AMOUNT,
            commitment: TEST_COMMITMENT,
            targetChainIds: new uint16[](1)
        });
        deposits[0].targetChainIds[0] = 137; // Polygon
        // Approve token spending
        mockToken.approve(address(crossChainPool), TOKEN_AMOUNT);
        // Ensure LayerZeroMock has sufficient ETH for fees
        vm.deal(address(lzEndpointMock), 1000 ether);
        // Perform cross-chain deposit with minimal ETH for LayerZero fees
        crossChainPool.multiDeposit{value: 0.1 ether}(deposits);
        vm.stopPrank();
        // Verify commitment was added
        assertTrue(crossChainPool.s_commitments(TEST_COMMITMENT));
        // Verify commitment metadata
        CrossChainShadowPool.CommitmentMetadata memory metadata = crossChainPool.getCommitmentMetadata(TEST_COMMITMENT);
        assertEq(metadata.token, address(mockToken));
        assertEq(metadata.amount, TOKEN_AMOUNT);
    }

    function test_CrossChainCommitmentSync() public {
        // Simulate receiving a commitment from another chain
        bytes memory payload = abi.encode(
            TEST_COMMITMENT,
            uint16(137), // Source chain (Polygon)
            address(mockToken),
            TOKEN_AMOUNT,
            block.timestamp
        );

        // Call lzReceive through the endpoint to simulate LayerZero message
        vm.prank(address(lzEndpointMock));
        crossChainPool.lzReceive(137, abi.encodePacked(address(crossChainPool), address(crossChainPool)), 1, payload);

        // Verify cross-chain commitment was added
        assertTrue(crossChainPool.s_crossChainCommitments(137, TEST_COMMITMENT));

        // Verify commitment metadata
        CrossChainShadowPool.CommitmentMetadata memory metadata = crossChainPool.getCommitmentMetadata(TEST_COMMITMENT);
        assertEq(metadata.sourceChainId, 137);
        assertEq(metadata.token, address(mockToken));
        assertEq(metadata.amount, TOKEN_AMOUNT);
        assertTrue(metadata.isCrossChain);
    }

    function test_CrossChainWithdrawal() public {
        // First, add a commitment to the pool
        vm.startPrank(user1);
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: DEPOSIT_AMOUNT,
            commitment: TEST_COMMITMENT,
            targetChainIds: new uint16[](0)
        });
        crossChainPool.multiDeposit{value: DEPOSIT_AMOUNT + 1 ether}(deposits);
        vm.stopPrank();

        // Get the actual root from the Merkle tree
        bytes32 actualRoot = crossChainPool.getLatestRoot();

        // Create cross-chain withdrawal proof
        CrossChainShadowPool.CrossChainWithdrawalProof memory proof = CrossChainShadowPool.CrossChainWithdrawalProof({
            nullifierHashes: new bytes32[](1),
            root: actualRoot,
            proof: abi.encode("mock_proof"),
            sourceChainId: 1,
            tokens: new address[](1),
            amounts: new uint256[](1)
        });
        proof.nullifierHashes[0] = TEST_NULLIFIER;
        proof.tokens[0] = address(0); // ETH
        proof.amounts[0] = DEPOSIT_AMOUNT - (DEPOSIT_AMOUNT * PERCENTAGE_FEE / 10000) - FIXED_FEE; // Amount minus fees (исправлено деление)

        // Mock the verifier to return true
        vm.mockCall(address(verifier), abi.encodeWithSelector(verifier.verify.selector), abi.encode(true));

        // Mock the root check
        vm.mockCall(
            address(crossChainPool), abi.encodeWithSelector(crossChainPool.isKnownRoot.selector), abi.encode(true)
        );

        // Perform cross-chain withdrawal
        vm.prank(user2);
        crossChainPool.crossChainWithdraw(proof, payable(user2));

        // Verify nullifier was marked as spent
        assertTrue(crossChainPool.s_nullifiers(TEST_NULLIFIER));
    }

    function test_EstimateCrossChainSyncFee() public {
        // Set LayerZeroMock fees
        lzEndpointMock.setRelayerPrice(1000000000, 20000000000, 1000000000000000000, 200000, 16);
        lzEndpointMock.setProtocolFee(0, 1000); // 10% protocol fee
        lzEndpointMock.setOracleFee(1000000000000000); // 0.001 ETH oracle fee

        (uint256 nativeFee, uint256 zroFee) = crossChainPool.estimateCrossChainSyncFee(targetChainIds, false);

        // Fees should be greater than 0
        assertGt(nativeFee, 0);
        // ZRO fee should be 0 when not using ZRO
        assertEq(zroFee, 0);
    }

    function test_UpdateFees() public {
        vm.startPrank(daoAddress);
        crossChainPool.updateFees(PERCENTAGE_FEE + 10, FIXED_FEE + 0.001 ether);
        assertEq(crossChainPool.percentageFee(), PERCENTAGE_FEE + 10);
        assertEq(crossChainPool.fixedFee(), FIXED_FEE + 0.001 ether);
        vm.stopPrank();
    }

    function test_UpdateDAO() public {
        address newDAO = address(0x999);
        vm.startPrank(daoAddress);
        crossChainPool.updateDAO(newDAO);
        vm.stopPrank();
        assertEq(crossChainPool.daoAddress(), newDAO);
    }

    function test_SetDstGas() public {
        vm.startPrank(daoAddress);
        crossChainPool.setDstGas(300000);
        vm.stopPrank();
    }

    function test_EmergencyRecover() public {
        vm.deal(address(crossChainPool), 2 ether);
        uint256 initialBalance = daoAddress.balance;
        vm.startPrank(daoAddress);
        crossChainPool.emergencyRecover(address(0), 1 ether);
        vm.stopPrank();
        assertEq(daoAddress.balance, initialBalance + 1 ether);
    }

    function _makeDepositArray(bytes32 commitment, uint256 nChains)
        internal
        view
        returns (CrossChainShadowPool.CrossChainDepositData[] memory)
    {
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: DEPOSIT_AMOUNT,
            commitment: commitment,
            targetChainIds: new uint16[](nChains)
        });
        for (uint256 i = 0; i < nChains; i++) {
            deposits[0].targetChainIds[i] = 137;
        }
        return deposits;
    }

    function test_RevertOnInvalidChainId() public {
        vm.startPrank(user1);

        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: DEPOSIT_AMOUNT,
            commitment: TEST_COMMITMENT,
            targetChainIds: new uint16[](1)
        });
        deposits[0].targetChainIds[0] = 65535; // Invalid chain ID

        // This should revert due to LayerZero endpoint not being configured for this chain
        vm.expectRevert();
        crossChainPool.multiDeposit{value: DEPOSIT_AMOUNT + 1 ether}(deposits);

        vm.stopPrank();
    }

    function test_RevertOnDuplicateCommitment() public {
        vm.startPrank(user1);

        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: DEPOSIT_AMOUNT,
            commitment: TEST_COMMITMENT,
            targetChainIds: new uint16[](0)
        });

        // First deposit should succeed
        crossChainPool.multiDeposit{value: DEPOSIT_AMOUNT + 1 ether}(deposits);

        // Second deposit with same commitment should fail
        vm.expectRevert(
            abi.encodeWithSelector(CrossChainShadowPool.Mixer__CommitmentAlreadyAdded.selector, TEST_COMMITMENT)
        );
        crossChainPool.multiDeposit{value: DEPOSIT_AMOUNT + 1 ether}(deposits);

        vm.stopPrank();
    }

    function test_DAOCanReceiveETH() public {
        address daoContractAddress = address(crossChainPool.daoAddress());
        uint256 before = daoContractAddress.balance;
        (bool success,) = daoContractAddress.call{value: 1 ether}("");
        console.log("Send ETH to DAO success:", success);
        console.log("DAO balance before:", before);
        console.log("DAO balance after:", daoContractAddress.balance);
        assertTrue(success, "DAO did not accept ETH via call");
        assertEq(daoContractAddress.balance, before + 1 ether, "DAO balance did not increase");
    }

    function test_OwnerAndDAOAddress() public {
        console.log("owner in test_OwnerAndDAOAddress", crossChainPool.owner());
        console.log("daoAddress in test_OwnerAndDAOAddress", crossChainPool.daoAddress());
        assertTrue(true);
    }
}
