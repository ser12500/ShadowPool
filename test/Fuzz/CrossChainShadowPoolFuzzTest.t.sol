// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "lib/forge-std/src/Test.sol";
import {CrossChainShadowPool} from "../../src/CrossChainShadowPool.sol";
import {HonkVerifier} from "../../src/Verifier/Verifier.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";
import {Incremental} from "../../src/Incremental.sol";

uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

contract CrossChainShadowPoolFuzzTest is Test {
    CrossChainShadowPool public pool;
    HonkVerifier public verifier;
    Poseidon2 public poseidon;
    address public user = address(0x1);

    function setUp() public {
        poseidon = new Poseidon2();
        verifier = new HonkVerifier();
        pool = new CrossChainShadowPool(verifier, poseidon, 20, address(0x123), 50, 0.001 ether, address(0));
        vm.deal(user, 100 ether);
    }

    // Fuzz: Deposit with random value
    function testFuzz_CrossChainDeposit(uint256 amount) public {
        vm.assume(amount > 0.01 ether && amount < 10 ether);
        bytes32 commitment = bytes32(uint256(keccak256(abi.encodePacked(amount, block.timestamp))) % FIELD_SIZE);
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: amount,
            commitment: commitment,
            targetChainIds: new uint16[](0)
        });
        vm.prank(user);
        pool.multiDeposit{value: amount}(deposits);
        assertTrue(pool.s_commitments(commitment));
    }

    // Fuzz: Deposit with random commitment (should not revert)
    function testFuzz_CrossChainDepositRandomCommitment(bytes32 commitment) public {
        commitment = bytes32(uint256(commitment) % FIELD_SIZE);
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: commitment,
            targetChainIds: new uint16[](0)
        });
        vm.prank(user);
        pool.multiDeposit{value: 1 ether}(deposits);
        assertTrue(pool.s_commitments(commitment));
    }

    // Fuzz: Deposit with zero value should revert
    function testFuzz_CrossChainDepositZeroValueReverts(bytes32 commitment) public {
        commitment = bytes32(uint256(commitment) % FIELD_SIZE);
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 0,
            commitment: commitment,
            targetChainIds: new uint16[](0)
        });
        vm.prank(user);
        vm.expectRevert();
        pool.multiDeposit{value: 0}(deposits);
    }

    //  Deposit with the same commitment twice should revert
    function testCrossChainDeposit_DuplicateCommitmentReverts() public {
        bytes32 commitment = bytes32(uint256(keccak256("duplicate")) % FIELD_SIZE);
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 1 ether,
            commitment: commitment,
            targetChainIds: new uint16[](0)
        });
        vm.prank(user);
        pool.multiDeposit{value: 1 ether}(deposits);
        vm.prank(user);
        vm.expectRevert();
        pool.multiDeposit{value: 1 ether}(deposits);
    }

    // Edge: Deposit with amount less than fee should revert
    function testCrossChainDeposit_AmountLessThanFeeReverts() public {
        bytes32 commitment = bytes32(uint256(keccak256("lowfee")));
        CrossChainShadowPool.CrossChainDepositData[] memory deposits =
            new CrossChainShadowPool.CrossChainDepositData[](1);
        deposits[0] = CrossChainShadowPool.CrossChainDepositData({
            token: address(0),
            amount: 0.0001 ether,
            commitment: commitment,
            targetChainIds: new uint16[](0)
        });
        vm.prank(user);
        vm.expectRevert();
        pool.multiDeposit{value: 0.0001 ether}(deposits);
    }

    // Fuzz: Withdraw with random data (should revert)
    function testFuzz_CrossChainWithdrawRandom(
        bytes memory proof,
        bytes32[] memory nullifiers,
        bytes32 root,
        address payable recipient,
        address[] memory tokens,
        uint256[] memory amounts
    ) public {
        CrossChainShadowPool.CrossChainWithdrawalProof memory withdrawalProof = CrossChainShadowPool
            .CrossChainWithdrawalProof({
            nullifierHashes: nullifiers,
            root: root,
            proof: proof,
            sourceChainId: 1,
            tokens: tokens,
            amounts: amounts
        });
        vm.expectRevert();
        pool.crossChainWithdraw(withdrawalProof, recipient);
    }
}
