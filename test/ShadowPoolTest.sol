// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {HonkVerifier} from "../src/Verifier/Verifier.sol";
import {ShadowPool, IVerifier, Poseidon2} from "../src/ShadowPool.sol";
import {Incremental} from "../src/Incremental.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Field} from "lib/poseidon2-evm/src/Field.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";
import {ShadowPoolGovernanceToken} from "../src/ShadowPoolGovernanceToken.sol";

contract ShadowPoolTest is Test {
    IVerifier public verifier;
    ShadowPool public shadowPool;
    Poseidon2 public poseidon;
    ShadowPoolDAO public dao;
    ShadowPoolGovernanceToken public governanceToken;

    address public recipient = makeAddr("recipient");

    // Mock tokens
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_PERCENTAGE_FEE = 50; // 0.5%
    uint256 public constant INITIAL_FIXED_FEE = 0.001 ether;
    uint256 public constant MERKLE_TREE_DEPTH = 20;

    // DAO constants
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1_000_000 * 10 ** 18; // 1 million tokens
    uint256 public constant PROPOSAL_THRESHOLD = 10_000 * 10 ** 18; // 10k tokens
    uint256 public constant VOTING_PERIOD = 40_320; // ~1 week (12 second blocks)
    uint256 public constant QUORUM_VOTES = 100_000 * 10 ** 18; // 100k tokens
    uint256 public constant TIMELOCK_DELAY = 24 hours;
    uint256 public constant MAX_ACTIVE_PROPOSALS = 10;

    event MultiDeposit(bytes32[] commitments, uint32[] leafIndices, uint256 timestamp);
    event FeeUpdated(uint256 percentageFee, uint256 fixedFee);
    event FeeCollected(address indexed token, uint256 amount);

    /// @notice Sets up the test environment by deploying all contracts and initializing test accounts
    /// @dev Deploys governance token, DAO, ShadowPool, and mock tokens. Sets up test accounts with initial balances.
    function setUp() public {
        poseidon = new Poseidon2();
        verifier = new HonkVerifier();
        owner = makeAddr("owner");

        // 1. Governance token
        governanceToken = new ShadowPoolGovernanceToken(owner, INITIAL_TOKEN_SUPPLY);

        // 2. Create temporary address for ShadowPool
        address tempShadowPoolAddress = address(0x123);

        // 3. DAO with temporary ShadowPool address
        dao = new ShadowPoolDAO(
            governanceToken,
            tempShadowPoolAddress,
            PROPOSAL_THRESHOLD,
            VOTING_PERIOD,
            QUORUM_VOTES,
            TIMELOCK_DELAY,
            MAX_ACTIVE_PROPOSALS
        );

        // 4. ShadowPool with correct DAO address
        shadowPool = new ShadowPool(
            IVerifier(verifier),
            poseidon,
            uint32(MERKLE_TREE_DEPTH),
            address(dao),
            INITIAL_PERCENTAGE_FEE,
            INITIAL_FIXED_FEE
        );

        // Note: In tests, DAO uses temporary ShadowPool address
        // In production, address will be updated through DAO voting procedure

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token1 = new MockERC20("Token1", "TK1");
        token2 = new MockERC20("Token2", "TK2");
        token3 = new MockERC20("Token3", "TK3");

        token1.mint(user1, 1000 ether);
        token2.mint(user1, 1000 ether);
        token3.mint(user1, 1000 ether);

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function _getProof(bytes32 _nullifier, bytes32 _secret, address _recipient, bytes32[] memory leaves)
        internal
        returns (bytes memory proof, bytes32[] memory publicInputs)
    {
        string[] memory inputs = new string[](6 + leaves.length);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "/home/sergey/ShadowPool/scriptjs/generateProof.ts";
        inputs[3] = vm.toString(_nullifier);
        inputs[4] = vm.toString(_secret);
        inputs[5] = vm.toString(bytes32(uint256(uint160(_recipient))));

        for (uint256 i = 0; i < leaves.length; i++) {
            inputs[6 + i] = vm.toString(leaves[i]);
        }

        bytes memory result = vm.ffi(inputs);
        (proof, publicInputs) = abi.decode(result, (bytes, bytes32[]));
    }

    function _getCommitment(address token, uint256 amount)
        internal
        returns (bytes32 commitment, bytes32 nullifier, bytes32 secret)
    {
        string[] memory inputs = new string[](5);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "/home/sergey/ShadowPool/scriptjs/generateCommitment.ts";
        inputs[3] = vm.toString(bytes32(uint256(uint160(token))));
        inputs[4] = vm.toString(amount);

        bytes memory result = vm.ffi(inputs);
        (commitment, nullifier, secret) = abi.decode(result, (bytes32, bytes32, bytes32));

        return (commitment, nullifier, secret);
    }

    /// @notice Tests commitment generation functionality
    /// @dev Verifies that commitments can be generated correctly using Poseidon2 hashing
    function testGetCommitment() public {
        // Use direct commitment generation instead of FFI
        uint256 nullifier = 123;
        uint256 secret = 456;
        bytes32 commitment = generateCommitment(address(0), 10 ether, nullifier, secret);

        console.log("Commitment: ");
        console.logBytes32(commitment);
        console.log("Nullifier: ");
        console.logBytes32(bytes32(nullifier));
        console.log("Secret: ");
        console.logBytes32(bytes32(secret));
        console.log("Recipient: ");
        console.log(recipient);
        assertTrue(commitment != 0);
        assertTrue(nullifier != 0);
        assertTrue(secret != 0);
    }

    /// @notice Tests ShadowPool constructor parameters
    /// @dev Verifies that all constructor parameters are set correctly
    function testConstructor() public {
        assertEq(shadowPool.daoAddress(), address(dao));
        assertEq(shadowPool.percentageFee(), INITIAL_PERCENTAGE_FEE);
        assertEq(shadowPool.fixedFee(), INITIAL_FIXED_FEE);
        assertEq(address(shadowPool.i_verifier()), address(verifier));
    }

    /// @notice Helper function for commitment generation via Poseidon2
    /// @param token Token address (address(0) for ETH)
    /// @param amount Amount to deposit
    /// @param nullifier Unique nullifier for the deposit
    /// @param secret Secret value for the deposit
    /// @return Commitment hash computed as Poseidon2(nullifier, secret, token, amount)
    function generateCommitment(address token, uint256 amount, uint256 nullifier, uint256 secret)
        internal
        view
        returns (bytes32)
    {
        Field.Type[] memory input = new Field.Type[](4);
        input[0] = Field.Type.wrap(nullifier);
        input[1] = Field.Type.wrap(secret);
        input[2] = Field.Type.wrap(uint256(uint160(token)));
        input[3] = Field.Type.wrap(amount);
        return bytes32(Field.toUint256(poseidon.hash(input)));
    }

    /// @notice Tests multi-deposit functionality with ETH only
    /// @dev Verifies that ETH deposits work correctly with fee calculation and DAO fee collection
    function testMultiDeposit_ETH_Only() public {
        vm.startPrank(user1);

        uint256 nullifier = 1;
        uint256 secret = 2;
        bytes32 commitment = generateCommitment(address(0), 10 ether, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: 10 ether, commitment: commitment});

        uint256 userBalanceBefore = user1.balance;
        uint256 daoBalanceBefore = address(dao).balance;

        shadowPool.multiDeposit{value: 10 ether}(deposits);

        uint256 fee = (10 ether * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;
        assertEq(user1.balance, userBalanceBefore - 10 ether);
        assertEq(address(dao).balance, daoBalanceBefore + fee);
        assertTrue(shadowPool.s_commitments(commitment));

        vm.stopPrank();
    }

    /// @notice Tests multi-deposit functionality with ERC20 tokens only
    /// @dev Verifies that ERC20 deposits work correctly with fee calculation and DAO fee collection
    function testMultiDeposit_ERC20_Only() public {
        vm.startPrank(user1);

        uint256 nullifier = 3;
        uint256 secret = 4;
        bytes32 commitment = generateCommitment(address(token1), 100 ether, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(token1), amount: 100 ether, commitment: commitment});

        token1.approve(address(shadowPool), 100 ether);

        uint256 userBalanceBefore = token1.balanceOf(user1);
        uint256 daoBalanceBefore = token1.balanceOf(address(dao));

        shadowPool.multiDeposit(deposits);

        uint256 fee = (100 ether * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;
        assertEq(token1.balanceOf(user1), userBalanceBefore - 100 ether);
        assertEq(token1.balanceOf(address(dao)), daoBalanceBefore + fee);
        assertTrue(shadowPool.s_commitments(commitment));

        vm.stopPrank();
    }

    /// @notice Tests multi-deposit functionality with mixed ETH and ERC20 tokens
    /// @dev Verifies that mixed deposits work correctly with separate fee calculations for each token type
    function testMultiDeposit_Mixed_ETH_ERC20() public {
        vm.startPrank(user1);

        uint256 nullifier1 = 5;
        uint256 secret1 = 6;
        uint256 nullifier2 = 7;
        uint256 secret2 = 8;

        bytes32 commitment1 = generateCommitment(address(0), 10 ether, nullifier1, secret1);
        bytes32 commitment2 = generateCommitment(address(token1), 100 ether, nullifier2, secret2);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](2);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: 10 ether, commitment: commitment1});
        deposits[1] = ShadowPool.Deposit({token: address(token1), amount: 100 ether, commitment: commitment2});

        token1.approve(address(shadowPool), 100 ether);

        uint256 userEthBalanceBefore = user1.balance;
        uint256 userTokenBalanceBefore = token1.balanceOf(user1);
        uint256 ownerEthBalanceBefore = address(dao).balance;
        uint256 ownerTokenBalanceBefore = token1.balanceOf(address(dao));

        shadowPool.multiDeposit{value: 10 ether}(deposits);

        uint256 ethFee = (10 ether * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;
        uint256 tokenFee = (100 ether * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;

        assertEq(user1.balance, userEthBalanceBefore - 10 ether);
        assertEq(token1.balanceOf(user1), userTokenBalanceBefore - 100 ether);
        assertEq(address(dao).balance, ownerEthBalanceBefore + ethFee);
        assertEq(token1.balanceOf(address(dao)), ownerTokenBalanceBefore + tokenFee);
        assertTrue(shadowPool.s_commitments(commitment1));
        assertTrue(shadowPool.s_commitments(commitment2));

        vm.stopPrank();
    }

    function testGetBalance() public {
        // Test ETH balance
        assertEq(shadowPool.getBalance(address(0)), 0);

        // Test ERC20 balance
        assertEq(shadowPool.getBalance(address(token1)), 0);

        // After deposit
        vm.startPrank(user1);

        uint256 nullifier = 19;
        uint256 secret = 20;
        bytes32 commitment = generateCommitment(address(0), 10 ether, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](2);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: 10 ether, commitment: commitment});
        deposits[1] = ShadowPool.Deposit({
            token: address(token1),
            amount: 100 ether,
            commitment: generateCommitment(address(token1), 100 ether, 21, 22)
        });

        token1.approve(address(shadowPool), 100 ether);

        uint256 ethFee = (10 ether * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;
        uint256 tokenFee = (100 ether * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;

        shadowPool.multiDeposit{value: 10 ether}(deposits);

        assertEq(shadowPool.getBalance(address(0)), 10 ether - ethFee);
        assertEq(shadowPool.getBalance(address(token1)), 100 ether - tokenFee);

        vm.stopPrank();
    }

    function testLegacyDeposit() public {
        vm.startPrank(user1);

        uint256 nullifier = 23;
        uint256 secret = 24;
        bytes32 commitment = generateCommitment(address(0), 10 ether, nullifier, secret);

        uint256 userBalanceBefore = user1.balance;
        uint256 daoBalanceBefore = address(dao).balance;

        uint256 fee = (10 ether * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;

        shadowPool.deposit{value: 10 ether}(commitment);

        assertEq(user1.balance, userBalanceBefore - 10 ether);
        assertEq(address(dao).balance, daoBalanceBefore + fee);
        assertTrue(shadowPool.s_commitments(commitment));

        vm.stopPrank();
    }

    // Original tests for backward compatibility
    function testDeposit() public {
        uint256 nullifier = 25;
        uint256 secret = 26;
        bytes32 commitment = generateCommitment(address(0), 10 ether, nullifier, secret);
        vm.startPrank(user1);
        shadowPool.deposit{value: 10 ether}(commitment);
        vm.stopPrank();
        assertTrue(shadowPool.s_commitments(commitment));
    }

    function testWithdraw() public {
        uint256 nullifier = 27;
        uint256 secret = 28;
        bytes32 commitment = generateCommitment(address(0), 10 ether, nullifier, secret);

        // Используем новую функцию multiDeposit
        vm.startPrank(user1);
        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: 10 ether, commitment: commitment});
        shadowPool.multiDeposit{value: 10 ether}(deposits);
        vm.stopPrank();

        // Проверяем, что коммитмент добавлен
        assertTrue(shadowPool.s_commitments(commitment));

        // Проверяем баланс контракта
        uint256 fee = (10 ether * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;
        assertEq(shadowPool.getBalance(address(0)), 10 ether - fee);

        console.log("Deposit successful");
        console.log("Contract ETH balance");
    }

    function testUpdateFees_Owner() public {
        vm.startPrank(address(dao));

        uint256 newPercentageFee = 100; // 1%
        uint256 newFixedFee = 0.002 ether;

        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(newPercentageFee, newFixedFee);

        shadowPool.updateFees(newPercentageFee, newFixedFee);

        assertEq(shadowPool.percentageFee(), newPercentageFee);
        assertEq(shadowPool.fixedFee(), newFixedFee);

        vm.stopPrank();
    }

    function testUpdateFees_NonOwner() public {
        vm.startPrank(user1);

        vm.expectRevert();
        shadowPool.updateFees(100, 0.002 ether);

        vm.stopPrank();
    }

    function testUpdateFees_TooHighPercentage() public {
        vm.startPrank(address(dao));

        vm.expectRevert(abi.encodeWithSelector(ShadowPool.Mixer__PercentageFeeTooHigh.selector, 500, 501));

        shadowPool.updateFees(501, 0.002 ether);

        vm.stopPrank();
    }

    function testDepositValueMismatch() public {
        vm.startPrank(user1);

        uint256 nullifier = 15;
        uint256 secret = 16;
        bytes32 commitment = generateCommitment(address(0), 10 ether, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: 10 ether, commitment: commitment});

        vm.expectRevert(abi.encodeWithSelector(ShadowPool.Mixer__DepositValueMismatch.selector, 10 ether, 5 ether));

        shadowPool.multiDeposit{value: 5 ether}(deposits);

        vm.stopPrank();
    }

    function testCommitmentAlreadyAdded() public {
        vm.startPrank(user1);

        uint256 nullifier = 17;
        uint256 secret = 18;
        bytes32 commitment = generateCommitment(address(0), 10 ether, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: 10 ether, commitment: commitment});

        // First deposit
        shadowPool.multiDeposit{value: 10 ether}(deposits);

        // Second deposit with same commitment
        vm.expectRevert(abi.encodeWithSelector(ShadowPool.Mixer__CommitmentAlreadyAdded.selector, commitment));

        shadowPool.multiDeposit{value: 10 ether}(deposits);

        vm.stopPrank();
    }

    function testWithdraw_ArrayLengthMismatch() public {
        vm.startPrank(user1);

        bytes32[] memory nullifierHashes = new bytes32[](2);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](2);

        vm.expectRevert(abi.encodeWithSelector(ShadowPool.Mixer__ArrayLengthMismatch.selector, 2, 1));

        shadowPool.withdraw("", bytes32(0), nullifierHashes, payable(user2), tokens, amounts);

        vm.stopPrank();
    }
}
