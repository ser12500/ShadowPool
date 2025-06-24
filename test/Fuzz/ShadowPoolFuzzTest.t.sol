// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {HonkVerifier} from "../../src/Verifier/Verifier.sol";
import {ShadowPool, IVerifier, Poseidon2} from "../../src/ShadowPool.sol";
import {Incremental} from "../../src/Incremental.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Field} from "lib/poseidon2-evm/src/Field.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract ShadowPoolFuzzTest is Test {
    IVerifier public verifier;
    ShadowPool public shadowPool;
    Poseidon2 public poseidon;

    // Mock tokens
    MockERC20 public token1;
    MockERC20 public token2;

    address public owner;
    address public user1;
    address public user2;
    address public testRecipient;

    uint256 public constant INITIAL_PERCENTAGE_FEE = 50; // 0.5%
    uint256 public constant INITIAL_FIXED_FEE = 0.001 ether;
    uint256 public constant MERKLE_TREE_DEPTH = 20;
    uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /// @notice Deploys contracts and sets up initial state for fuzz tests
    function setUp() public {
        // Deploy Poseidon hasher contract
        poseidon = new Poseidon2();

        // Deploy Groth16 verifier contract
        verifier = new HonkVerifier();

        // Create addresses
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        testRecipient = makeAddr("recipient");

        // Deploy ShadowPool with fee configuration
        shadowPool = new ShadowPool(
            IVerifier(verifier), poseidon, uint32(MERKLE_TREE_DEPTH), owner, INITIAL_PERCENTAGE_FEE, INITIAL_FIXED_FEE
        );

        // Deploy mock tokens
        token1 = new MockERC20("Token1", "TK1");
        token2 = new MockERC20("Token2", "TK2");

        // Mint tokens to users
        token1.mint(user1, 10000 ether);
        token2.mint(user1, 10000 ether);

        // Fund users with ETH
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
    }

    /// @notice Helper to generate a commitment using Poseidon2
    /// @param token Token address (address(0) for ETH)
    /// @param amount Deposit amount
    /// @param nullifier Nullifier value
    /// @param secret Secret value
    /// @return Commitment as bytes32
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

    /// @notice Fuzz test for multiDeposit with various ETH amounts
    function testFuzz_MultiDeposit_ETH_Amounts(uint256 amount) public {
        /// Limit the amount to reasonable bounds, considering the fee
        vm.assume(amount > 0.002 ether && amount <= 100 ether);

        vm.startPrank(user1);

        uint256 nullifier = uint256(keccak256(abi.encodePacked(amount, block.timestamp)));
        uint256 secret = uint256(keccak256(abi.encodePacked(amount, block.timestamp + 1)));
        bytes32 commitment = generateCommitment(address(0), amount, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: amount, commitment: commitment});

        uint256 userBalanceBefore = user1.balance;
        uint256 ownerBalanceBefore = owner.balance;

        shadowPool.multiDeposit{value: amount}(deposits);

        uint256 fee = (amount * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;
        assertEq(user1.balance, userBalanceBefore - amount);
        assertEq(owner.balance, ownerBalanceBefore + fee);
        assertTrue(shadowPool.s_commitments(commitment));

        vm.stopPrank();
    }

    /// @notice Fuzz test for multiDeposit with various ERC20 token amounts
    function testFuzz_MultiDeposit_ERC20_Amounts(uint256 amount) public {
        /// Limit the amount to reasonable bounds, considering the fee
        vm.assume(amount > 0.002 ether && amount <= 1000 ether);

        vm.startPrank(user1);

        uint256 nullifier = uint256(keccak256(abi.encodePacked(amount, block.timestamp)));
        uint256 secret = uint256(keccak256(abi.encodePacked(amount, block.timestamp + 1)));
        bytes32 commitment = generateCommitment(address(token1), amount, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(token1), amount: amount, commitment: commitment});

        token1.approve(address(shadowPool), amount);

        uint256 userBalanceBefore = token1.balanceOf(user1);
        uint256 ownerBalanceBefore = token1.balanceOf(owner);

        shadowPool.multiDeposit(deposits);

        uint256 fee = (amount * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;
        assertEq(token1.balanceOf(user1), userBalanceBefore - amount);
        assertEq(token1.balanceOf(owner), ownerBalanceBefore + fee);
        assertTrue(shadowPool.s_commitments(commitment));

        vm.stopPrank();
    }

    /// @notice Fuzz test for updating fees with various values
    function testFuzz_UpdateFees(uint256 percentageFee, uint256 fixedFee) public {
        /// Limit the fees to reasonable bounds
        vm.assume(percentageFee <= 500); // Max 5%
        vm.assume(fixedFee <= 0.1 ether); // Max 0.1 ETH

        vm.startPrank(owner);

        if (percentageFee <= 500) {
            shadowPool.updateFees(percentageFee, fixedFee);
            assertEq(shadowPool.percentageFee(), percentageFee);
            assertEq(shadowPool.fixedFee(), fixedFee);
        }

        vm.stopPrank();
    }

    /// @notice Fuzz test for duplicate commitment rejection
    function testFuzz_DuplicateCommitment(uint256 amount) public {
        vm.assume(amount > 0.002 ether && amount <= 100 ether);

        vm.startPrank(user1);

        uint256 nullifier = uint256(keccak256(abi.encodePacked(amount, block.timestamp)));
        uint256 secret = uint256(keccak256(abi.encodePacked(amount, block.timestamp + 1)));
        bytes32 commitment = generateCommitment(address(0), amount, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: amount, commitment: commitment});

        // First deposit should succeed
        shadowPool.multiDeposit{value: amount}(deposits);
        assertTrue(shadowPool.s_commitments(commitment));

        // Second deposit with the same commitment should revert
        vm.expectRevert(abi.encodeWithSelector(ShadowPool.Mixer__CommitmentAlreadyAdded.selector, commitment));
        shadowPool.multiDeposit{value: amount}(deposits);

        vm.stopPrank();
    }

    /// @notice Fuzz test for msg.value mismatch
    function testFuzz_ValueMismatch(uint256 depositAmount, uint256 sentValue) public {
        vm.assume(depositAmount > 0.002 ether && depositAmount <= 100 ether);
        vm.assume(sentValue != depositAmount);
        vm.assume(sentValue > 0 && sentValue <= 200 ether);

        vm.startPrank(user1);

        uint256 nullifier = uint256(keccak256(abi.encodePacked(depositAmount, block.timestamp)));
        uint256 secret = uint256(keccak256(abi.encodePacked(depositAmount, block.timestamp + 1)));
        bytes32 commitment = generateCommitment(address(0), depositAmount, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: depositAmount, commitment: commitment});

        // Deposit should revert due to msg.value mismatch
        vm.expectRevert(
            abi.encodeWithSelector(ShadowPool.Mixer__DepositValueMismatch.selector, depositAmount, sentValue)
        );
        shadowPool.multiDeposit{value: sentValue}(deposits);

        vm.stopPrank();
    }

    /// @notice Fuzz test for insufficient balance
    function testFuzz_InsufficientBalance(uint256 amount) public {
        /// Set amount greater than user1's balance (1000 ether)
        vm.assume(amount > 1000 ether && amount <= 10000 ether);

        vm.startPrank(user1);

        uint256 nullifier = uint256(keccak256(abi.encodePacked(amount, block.timestamp)));
        uint256 secret = uint256(keccak256(abi.encodePacked(amount, block.timestamp + 1)));
        bytes32 commitment = generateCommitment(address(0), amount, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: amount, commitment: commitment});

        // Deposit should revert due to insufficient balance
        try shadowPool.multiDeposit{value: amount}(deposits) {
            fail();
        } catch {
            // Expected revert
        }

        vm.stopPrank();
    }

    /// @notice Fuzz test for multiDeposit with different token addresses
    function testFuzz_DifferentTokenAddresses(address tokenAddress, uint256 amount) public {
        vm.assume(tokenAddress != address(0));
        vm.assume(amount > 0.002 ether && amount <= 100 ether);

        // Deploy a temporary token
        MockERC20 tempToken = new MockERC20("TempToken", "TEMP");
        tempToken.mint(user1, 1000 ether);

        vm.startPrank(user1);

        uint256 nullifier = uint256(keccak256(abi.encodePacked(amount, block.timestamp)));
        uint256 secret = uint256(keccak256(abi.encodePacked(amount, block.timestamp + 1)));
        bytes32 commitment = generateCommitment(address(tempToken), amount, nullifier, secret);

        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](1);
        deposits[0] = ShadowPool.Deposit({token: address(tempToken), amount: amount, commitment: commitment});

        tempToken.approve(address(shadowPool), amount);

        uint256 userBalanceBefore = tempToken.balanceOf(user1);
        uint256 ownerBalanceBefore = tempToken.balanceOf(owner);

        shadowPool.multiDeposit(deposits);

        uint256 fee = (amount * INITIAL_PERCENTAGE_FEE) / 10000 + INITIAL_FIXED_FEE;
        assertEq(tempToken.balanceOf(user1), userBalanceBefore - amount);
        assertEq(tempToken.balanceOf(owner), ownerBalanceBefore + fee);
        assertTrue(shadowPool.s_commitments(commitment));

        vm.stopPrank();
    }

    // Fuzz: Deposit with random value
    function testFuzz_Deposit(uint256 amount) public {
        vm.assume(amount > 0.01 ether && amount < 10 ether);
        bytes32 commitment = bytes32(uint256(keccak256(abi.encodePacked(amount, block.timestamp))) % FIELD_SIZE);
        vm.prank(user1);
        shadowPool.deposit{value: amount}(commitment);
        assertTrue(shadowPool.s_commitments(commitment));
    }

    // Fuzz: Deposit with random commitment (should not revert)
    function testFuzz_DepositRandomCommitment(bytes32 commitment) public {
        commitment = bytes32(uint256(commitment) % FIELD_SIZE);
        vm.prank(user1);
        shadowPool.deposit{value: 1 ether}(commitment);
        assertTrue(shadowPool.s_commitments(commitment));
    }

    // Fuzz: Deposit with zero value should revert
    function testFuzz_DepositZeroValueReverts(bytes32 commitment) public {
        vm.prank(user1);
        vm.expectRevert();
        shadowPool.deposit{value: 0}(commitment);
    }

    // Fuzz: MultiDeposit with random values
    function testFuzz_MultiDeposit(uint256[3] memory amounts) public {
        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](3);
        uint256 total = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint256 amt = (amounts[i] % 10 ether) + 0.02 ether;
            bytes32 commitment = bytes32(uint256(keccak256(abi.encodePacked(i, amt))) % FIELD_SIZE);
            deposits[i] = ShadowPool.Deposit({token: address(0), amount: amt, commitment: commitment});
            total += amt;
        }
        vm.prank(user1);
        shadowPool.multiDeposit{value: total}(deposits);
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(shadowPool.s_commitments(deposits[i].commitment));
        }
    }

    // Fuzz: Withdraw with random data (should revert)
    function testFuzz_WithdrawRandom(
        bytes memory proof,
        bytes32 root,
        bytes32[] memory nullifiers,
        address payable recipient,
        address[] memory tokens,
        uint256[] memory amounts
    ) public {
        vm.expectRevert();
        shadowPool.withdraw(proof, root, nullifiers, recipient, tokens, amounts);
    }

    // Edge: Deposit with the same commitment twice should revert
    function testDeposit_DuplicateCommitmentReverts() public {
        bytes32 commitment = bytes32(uint256(keccak256("duplicate")) % FIELD_SIZE);
        vm.prank(user1);
        shadowPool.deposit{value: 1 ether}(commitment);
        vm.prank(user1);
        vm.expectRevert();
        shadowPool.deposit{value: 1 ether}(commitment);
    }

    // Edge: MultiDeposit with duplicate commitments should revert
    function testMultiDeposit_DuplicateCommitmentReverts() public {
        ShadowPool.Deposit[] memory deposits = new ShadowPool.Deposit[](2);
        bytes32 commitment = bytes32(uint256(keccak256("dup")));
        deposits[0] = ShadowPool.Deposit({token: address(0), amount: 1 ether, commitment: commitment});
        deposits[1] = ShadowPool.Deposit({token: address(0), amount: 1 ether, commitment: commitment});
        vm.prank(user1);
        vm.expectRevert();
        shadowPool.multiDeposit{value: 2 ether}(deposits);
    }

    // Edge: Deposit with amount less than fee should revert
    function testDeposit_AmountLessThanFeeReverts() public {
        bytes32 commitment = bytes32(uint256(keccak256("lowfee")));
        vm.prank(user1);
        vm.expectRevert();
        shadowPool.deposit{value: 0.0001 ether}(commitment);
    }
}
