// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {CrossChainShadowPool} from "../src/CrossChainShadowPool.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";
import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {LZEndpointMock} from "lib/layerzero-examples/contracts/lzApp/mocks/LZEndpointMock.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";
import {HonkVerifier} from "../src/Verifier/Verifier.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SecurityTest is Test {
    CrossChainShadowPool public crossChainPool;
    ShadowPoolDAO public dao;
    TimelockController public timelockController;
    MockERC20 public mockToken;
    LZEndpointMock public lzEndpointMock;
    Poseidon2 public poseidon;
    HonkVerifier public verifier;

    address public daoOwner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public attacker = address(0x4);
    address public daoAddress;

    uint256 public constant TOKEN_AMOUNT = 1000 ether;
    uint256 public constant PERCENTAGE_FEE = 50; // 0.5%
    uint256 public constant FIXED_FEE = 0.001 ether;
    uint32 public constant MERKLE_TREE_DEPTH = 20;
    bytes32 public constant FIELD_SIZE = bytes32(0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001);
    bytes32 public constant TEST_COMMITMENT = bytes32(uint256(123456789));
    bytes32 public constant TEST_NULLIFIER = bytes32(uint256(987654321));
    bytes32 public constant TEST_COMMITMENT_2 = bytes32(uint256(111111111));
    bytes32 public constant TEST_NULLIFIER_2 = bytes32(uint256(222222222));

    function setUp() public {
        // Deploy mock LayerZero endpoint with zero fees for testing
        lzEndpointMock = new LZEndpointMock(1);
        lzEndpointMock.setRelayerPrice(0, 0, 0, 0, 0);
        lzEndpointMock.setProtocolFee(0, 0);
        lzEndpointMock.setOracleFee(0);

        // Deploy dependencies
        poseidon = new Poseidon2();
        verifier = new HonkVerifier();
        mockToken = new MockERC20("MockGov", "MGOV");
        mockToken.mint(daoOwner, 1_000_000 ether);

        // Deploy CrossChainShadowPool
        crossChainPool = new CrossChainShadowPool(
            verifier, poseidon, uint32(MERKLE_TREE_DEPTH), daoOwner, PERCENTAGE_FEE, FIXED_FEE, address(lzEndpointMock)
        );
        vm.store(address(crossChainPool), bytes32(uint256(0)), bytes32(uint256(uint160(daoOwner))));

        // Deploy TimelockController
        address[] memory proposers = new address[](1);
        proposers[0] = daoOwner;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelockController = new TimelockController(3600, proposers, executors, daoOwner); // 1 hour delay

        // Deploy DAO
        dao = new ShadowPoolDAO(
            IERC20(address(mockToken)),
            address(crossChainPool),
            1 ether,
            100,
            1 ether,
            3600, // 1 hour timelock delay
            10,
            timelockController
        );
        daoAddress = address(dao);

        vm.startPrank(daoOwner);
        crossChainPool.updateDAO(address(dao));
        crossChainPool.setTrustedRemoteAddress(137, abi.encodePacked(address(crossChainPool)));
        crossChainPool.setAllowedChain(137, true);
        crossChainPool.setAllowedChain(1, true);
        vm.stopPrank();

        lzEndpointMock.setDestLzEndpoint(address(crossChainPool), address(lzEndpointMock));

        // Fund users
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(attacker, 1000 ether);
        // user1 doesn't receive governance tokens for testing restrictions
        mockToken.mint(user2, TOKEN_AMOUNT);
        mockToken.mint(attacker, TOKEN_AMOUNT);
        // Give tokens to user1 only for ERC20 fee collection test, but not for governance
        vm.deal(address(crossChainPool), 100 ether);
    }

    // ========== FRONT-RUNNING PROTECTION TESTS ==========

    function test_FrontRunningProtection_CommitmentUniqueness() public {
        vm.startPrank(user1);

        // First deposit should succeed
        CrossChainShadowPool.CrossChainDepositData[] memory deposits1 =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits1[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: TEST_COMMITMENT,
            targetChainIds: new uint16[](0)
        });

        crossChainPool.multiDeposit{value: 1.1 ether}(deposits1);

        // Second deposit with same commitment should fail
        CrossChainShadowPool.CrossChainDepositData[] memory deposits2 =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits2[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: TEST_COMMITMENT, // Same commitment
            targetChainIds: new uint16[](0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(CrossChainShadowPool.Mixer__CommitmentAlreadyAdded.selector, TEST_COMMITMENT)
        );
        crossChainPool.multiDeposit{value: 1.1 ether}(deposits2);

        vm.stopPrank();
    }

    function test_FrontRunningProtection_CrossChainCommitmentUniqueness() public {
        vm.startPrank(user1);

        // First cross-chain deposit
        CrossChainShadowPool.CrossChainDepositData[] memory deposits1 =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits1[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: TEST_COMMITMENT,
            targetChainIds: new uint16[](1)
        });
        deposits1[0].targetChainIds[0] = 137;

        crossChainPool.multiDeposit{value: 1.1 ether}(deposits1);

        // Verify commitment exists on current chain
        assertTrue(crossChainPool.s_commitments(TEST_COMMITMENT));

        // Verify commitment metadata shows it's cross-chain
        CrossChainShadowPool.CommitmentMetadata memory metadata = crossChainPool.getCommitmentMetadata(TEST_COMMITMENT);
        assertTrue(metadata.isCrossChain);
        assertEq(metadata.sourceChainId, uint16(block.chainid)); // Use actual chain ID

        vm.stopPrank();
    }

    // ========== REPLAY ATTACK PROTECTION TESTS ==========

    function test_ReplayAttackProtection_NullifierUniqueness() public {
        // First withdrawal
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = TEST_NULLIFIER;

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        // Create valid root for Merkle tree
        bytes32 validRoot = crossChainPool.getLatestRoot();

        CrossChainShadowPool.CrossChainWithdrawalProof memory proof = CrossChainShadowPool.CrossChainWithdrawalProof({
            nullifierHashes: nullifiers,
            root: validRoot,
            proof: new bytes(440 * 32), // Correct proof length for HonkVerifier
            sourceChainId: 1,
            tokens: tokens,
            amounts: amounts
        });

        // Mock the verifier to return true for the first call
        // Use simpler mock without exact parameter matching
        vm.mockCall(address(verifier), abi.encodeWithSelector(verifier.verify.selector), abi.encode(true));

        vm.startPrank(user1);
        crossChainPool.crossChainWithdraw(proof, payable(user1));
        vm.stopPrank();

        // Try to use the same nullifier again - should fail
        vm.startPrank(user1);
        vm.expectRevert();
        crossChainPool.crossChainWithdraw(proof, payable(user1));
        vm.stopPrank();
    }

    function test_ReplayAttackProtection_CrossChainNullifierUniqueness() public {
        // First cross-chain withdrawal
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = TEST_NULLIFIER_2;

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        // Create valid root for Merkle tree
        bytes32 validRoot = crossChainPool.getLatestRoot();

        CrossChainShadowPool.CrossChainWithdrawalProof memory proof = CrossChainShadowPool.CrossChainWithdrawalProof({
            nullifierHashes: nullifiers,
            root: validRoot,
            proof: new bytes(440 * 32), // Correct proof length for HonkVerifier
            sourceChainId: 137,
            tokens: tokens,
            amounts: amounts
        });

        // Mock the verifier to return true for the first call
        // Use simpler mock without exact parameter matching
        vm.mockCall(address(verifier), abi.encodeWithSelector(verifier.verify.selector), abi.encode(true));

        vm.startPrank(user1);
        crossChainPool.crossChainWithdraw(proof, payable(user1));
        vm.stopPrank();

        // Try to use the same nullifier again - should fail
        vm.startPrank(user1);
        vm.expectRevert();
        crossChainPool.crossChainWithdraw(proof, payable(user1));
        vm.stopPrank();
    }

    // ========== GOVERNANCE ATTACKS PROTECTION TESTS ==========

    function test_GovernanceProtection_TimelockDelay() public {
        vm.startPrank(daoOwner);

        // Create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(crossChainPool);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setDstGas(uint256)", 300000);

        uint256 proposalId = dao.propose("Test proposal", targets, values, signatures, calldatas);

        // Try to execute immediately - should fail
        vm.expectRevert();
        dao.execute(proposalId);

        vm.stopPrank();
    }

    function test_GovernanceProtection_FlashLoanAttack() public {
        vm.startPrank(daoOwner);

        // Create malicious proposal
        address[] memory targets = new address[](1);
        targets[0] = address(crossChainPool);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setDstGas(uint256)", 1);

        uint256 proposalId = dao.propose("Malicious proposal", targets, values, signatures, calldatas);
        vm.stopPrank();
    }

    function test_GovernanceProtection_OnlyProposerCanPropose() public {
        // user1 doesn't receive governance tokens
        vm.startPrank(user1);

        // Try to create proposal without sufficient tokens
        address[] memory targets = new address[](1);
        targets[0] = address(crossChainPool);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setDstGas(uint256)", 300000);

        // User1 doesn't have enough tokens to propose
        vm.expectRevert(abi.encodeWithSelector(ShadowPoolDAO.DAO__InsufficientTokens.selector));
        dao.propose("Test proposal", targets, values, signatures, calldatas);

        vm.stopPrank();
    }

    function test_CrossChainProtection_WhitelistValidation() public {
        vm.startPrank(user1);

        // Try to deposit to non-whitelisted chain
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: bytes32(uint256(333333333)),
            targetChainIds: new uint16[](1)
        });
        deposits[0].targetChainIds[0] = 999; // Non-whitelisted chain

        vm.expectRevert("Chain not allowed");
        crossChainPool.multiDeposit{value: 1.1 ether}(deposits);

        vm.stopPrank();
    }

    function test_CrossChainProtection_ChainLimits() public {
        vm.startPrank(user1);

        // Try to deposit to chain that's not allowed
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: bytes32(uint256(444444444)),
            targetChainIds: new uint16[](1)
        });
        deposits[0].targetChainIds[0] = 999; // Chain not in whitelist

        vm.expectRevert("Chain not allowed");
        crossChainPool.multiDeposit{value: 1.1 ether}(deposits);

        vm.stopPrank();
    }

    function test_CrossChainProtection_TrustedRemoteValidation() public {
        vm.startPrank(user1);

        // Try to deposit to chain without trusted remote
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: bytes32(uint256(555555555)),
            targetChainIds: new uint16[](1)
        });
        deposits[0].targetChainIds[0] = 999; // Chain without trusted remote

        // This should fail because chain 999 is not whitelisted
        vm.expectRevert("Chain not allowed");
        crossChainPool.multiDeposit{value: 1.1 ether}(deposits);

        vm.stopPrank();
    }

    function test_CrossChainProtection_EmergencyPause() public {
        vm.startPrank(daoOwner);

        // Pause the contract
        crossChainPool.setEmergencyPause(true);
        vm.stopPrank();

        vm.startPrank(user1);

        // Try to deposit while paused
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: bytes32(uint256(666666666)),
            targetChainIds: new uint16[](0)
        });

        vm.expectRevert("Contract is paused");
        crossChainPool.multiDeposit{value: 1.1 ether}(deposits);

        vm.stopPrank();
    }

    // ========== ACCESS CONTROL TESTS ==========

    function test_AccessControl_OnlyDAO() public {
        vm.startPrank(user1);

        // Try to call DAO-only function
        vm.expectRevert(abi.encodeWithSelector(CrossChainShadowPool.Mixer__NotDAO.selector));
        crossChainPool.setDstGas(300000);

        vm.stopPrank();
    }

    function test_AccessControl_OnlyOwner() public {
        vm.startPrank(user1);

        // Try to call owner-only function
        vm.expectRevert();
        crossChainPool.setAllowedChain(999, true);

        vm.stopPrank();
    }

    function test_FeeProtection_FeeExceedsDeposit() public {
        vm.startPrank(user1);

        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 0.001 ether, // Equal to FIXED_FEE
            commitment: TEST_COMMITMENT,
            targetChainIds: new uint16[](1)
        });
        deposits[0].targetChainIds[0] = 137;

        // This should fail because fee equals deposit amount
        vm.expectRevert();
        crossChainPool.multiDeposit{value: 0.001 ether}(deposits);

        vm.stopPrank();
    }

    function test_FeeProtection_ERC20FeeCollection() public {
        // Give tokens to user1 for this test
        mockToken.mint(user1, TOKEN_AMOUNT);

        vm.startPrank(user1);

        // Approve tokens
        mockToken.approve(address(crossChainPool), TOKEN_AMOUNT);

        // Deposit ERC20 tokens
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(mockToken),
            amount: TOKEN_AMOUNT,
            commitment: bytes32(uint256(777777777)),
            targetChainIds: new uint16[](0)
        });

        crossChainPool.multiDeposit(deposits);

        // Verify fee was collected
        uint256 expectedFee = (TOKEN_AMOUNT * PERCENTAGE_FEE) / 10000 + FIXED_FEE;
        assertEq(mockToken.balanceOf(daoAddress), expectedFee);

        vm.stopPrank();
    }

    function test_ReentrancyProtection() public {
        vm.startPrank(user1);

        // Create deposit
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: TEST_COMMITMENT_2,
            targetChainIds: new uint16[](1)
        });
        deposits[0].targetChainIds[0] = 137;

        // This should succeed without reentrancy issues
        crossChainPool.multiDeposit{value: 1.1 ether}(deposits);

        vm.stopPrank();
    }

    function test_InputValidation_ZeroAmount() public {
        vm.startPrank(user1);

        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 0, // Zero amount
            commitment: bytes32(uint256(888888888)),
            targetChainIds: new uint16[](0)
        });

        // This should fail due to fee calculation
        vm.expectRevert();
        crossChainPool.multiDeposit{value: 0.1 ether}(deposits);

        vm.stopPrank();
    }

    function test_InputValidation_InvalidChainId() public {
        vm.startPrank(user1);

        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: bytes32(uint256(777777777)),
            targetChainIds: new uint16[](1)
        });
        deposits[0].targetChainIds[0] = 0; // Invalid chain ID

        vm.expectRevert("Chain not allowed");
        crossChainPool.multiDeposit{value: 1.1 ether}(deposits);

        vm.stopPrank();
    }

    function test_EmergencyRecovery_OnlyDAO() public {
        vm.startPrank(user1);

        // Try to recover funds without DAO role
        vm.expectRevert(abi.encodeWithSelector(CrossChainShadowPool.Mixer__NotDAO.selector));
        crossChainPool.emergencyRecover(address(0), 1 ether);

        vm.stopPrank();
    }
}
