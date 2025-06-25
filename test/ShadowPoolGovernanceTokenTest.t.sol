// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "lib/forge-std/src/Test.sol";
import {ShadowPoolGovernanceToken} from "../src/ShadowPoolGovernanceToken.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";
import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract ShadowPoolGovernanceTokenTest is Test {
    ShadowPoolGovernanceToken public token;
    address public owner;
    address public user1;
    address public user2;
    TimelockController public timelockController;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        token = new ShadowPoolGovernanceToken(owner, 1000 ether);

        // Deploy TimelockController
        address[] memory proposers = new address[](1);
        proposers[0] = owner;
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute
        timelockController = new TimelockController(1 days, proposers, executors, owner);
    }

    // Test: Owner receives initial supply
    function testInitialSupplyToOwner() public {
        assertEq(token.balanceOf(owner), 1000 ether);
    }

    // Test: Transfer tokens to another user
    function testTransfer() public {
        token.transfer(user1, 100 ether);
        assertEq(token.balanceOf(user1), 100 ether);
        assertEq(token.balanceOf(owner), 900 ether);
    }

    // Test: Transfer more than balance should revert
    function testTransferInsufficientBalanceReverts() public {
        vm.expectRevert();
        token.transfer(user1, 2000 ether);
    }

    // Test: Approve and transferFrom
    function testApproveAndTransferFrom() public {
        token.approve(user1, 50 ether);
        vm.prank(user1);
        token.transferFrom(owner, user2, 50 ether);
        assertEq(token.balanceOf(user2), 50 ether);
        assertEq(token.balanceOf(owner), 950 ether);
    }

    // Test: Transfer to zero address should revert
    function testTransferToZeroAddressReverts() public {
        vm.expectRevert();
        token.transfer(address(0), 1 ether);
    }

    // Test: Double approve (reset allowance)
    function testDoubleApprove() public {
        token.approve(user1, 10 ether);
        token.approve(user1, 20 ether);
        assertEq(token.allowance(owner, user1), 20 ether);
    }

    // Integration: Use token to create a proposal in DAO
    function testTokenUsedForProposalInDAO() public {
        // Deploy ShadowPool with temporary DAO
        address tempShadowPool = address(this);
        ShadowPoolDAO dao = new ShadowPoolDAO(
            token,
            tempShadowPool,
            100 * 10 ** 18, // proposalThreshold
            100, // votingPeriod
            100 * 10 ** 18, // quorumVotes
            1 days,
            10,
            timelockController
        );
        // Transfer enough tokens to user1
        token.transfer(address(0x1), 200 * 10 ** 18);
        vm.startPrank(address(0x1));
        string memory description = "Token-based proposal";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        // Should succeed
        dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();
    }

    // Integration: Transfer tokens, then vote in DAO
    function testTokenTransferAndVoteInDAO() public {
        address tempShadowPool = address(this);
        ShadowPoolDAO dao = new ShadowPoolDAO(
            token, tempShadowPool, 100 * 10 ** 18, 100, 100 * 10 ** 18, 1 days, 10, timelockController
        );
        // Transfer tokens to user1 and user2
        token.transfer(address(0x1), 100 * 10 ** 18);
        token.transfer(address(0x2), 100 * 10 ** 18);
        // User1 creates proposal
        vm.startPrank(address(0x1));
        string memory description = "Voting test";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();
        // Advance block to enter voting period
        vm.roll(block.number + 2);
        // User2 votes
        vm.startPrank(address(0x2));
        dao.castVote(proposalId, true);
        vm.stopPrank();
        // Check that user2's vote is counted
        assertEq(dao.getForVotes(proposalId), 100 * 10 ** 18);
    }

    // Integration: TransferFrom and then vote
    function testTransferFromAndVote() public {
        address tempShadowPool = address(this);
        ShadowPoolDAO dao =
            new ShadowPoolDAO(token, tempShadowPool, 50 * 10 ** 18, 100, 50 * 10 ** 18, 1 days, 10, timelockController);
        // Approve user1 to spend owner's tokens
        token.approve(address(0x1), 60 * 10 ** 18);
        vm.prank(address(0x1));
        token.transferFrom(address(this), address(0x1), 60 * 10 ** 18);
        // User1 creates proposal
        vm.startPrank(address(0x1));
        string memory description = "TransferFrom proposal";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();
        // Advance block to enter voting period
        vm.roll(block.number + 2);
        // User1 votes
        vm.startPrank(address(0x1));
        dao.castVote(proposalId, true);
        vm.stopPrank();
        assertEq(dao.getForVotes(proposalId), 60 * 10 ** 18);
    }

    // Integration: Approve, transferFrom, and proposal creation
    function testApproveTransferFromAndProposal() public {
        address tempShadowPool = address(this);
        ShadowPoolDAO dao =
            new ShadowPoolDAO(token, tempShadowPool, 30 * 10 ** 18, 100, 30 * 10 ** 18, 1 days, 10, timelockController);
        // Approve user2 to spend owner's tokens
        token.approve(address(0x2), 40 * 10 ** 18);
        vm.prank(address(0x2));
        token.transferFrom(address(this), address(0x2), 40 * 10 ** 18);
        // User2 creates proposal
        vm.startPrank(address(0x2));
        string memory description = "Approve/TransferFrom proposal";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();
        // Advance block to enter voting period
        vm.roll(block.number + 2);
        // User2 votes
        vm.startPrank(address(0x2));
        dao.castVote(proposalId, true);
        vm.stopPrank();
        assertEq(dao.getForVotes(proposalId), 40 * 10 ** 18);
    }

    // Integration: Transfer tokens to a contract and vote
    function testTransferToContractAndVote() public {
        address tempShadowPool = address(this);
        ShadowPoolDAO dao =
            new ShadowPoolDAO(token, tempShadowPool, 10 * 10 ** 18, 100, 10 * 10 ** 18, 1 days, 10, timelockController);
        // Deploy a dummy contract
        address contractAddr = address(new DummyVoter());
        token.transfer(contractAddr, 15 * 10 ** 18);
        // Contract creates proposal
        vm.startPrank(contractAddr);
        string memory description = "Contract proposal";
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);
        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        vm.stopPrank();
        // Advance block to enter voting period
        vm.roll(block.number + 2);
        // Contract votes
        vm.startPrank(contractAddr);
        dao.castVote(proposalId, true);
        vm.stopPrank();
        assertEq(dao.getForVotes(proposalId), 15 * 10 ** 18);
    }

    // Integration: Transfer tokens and check allowance logic
    function testTransferAndAllowanceLogic() public {
        token.transfer(user1, 10 ether);
        token.approve(user2, 5 ether);
        vm.prank(user2);
        token.transferFrom(owner, user2, 5 ether);
        assertEq(token.balanceOf(user2), 5 ether);
        assertEq(token.allowance(owner, user2), 0);
    }
}

// Dummy contract for contract voting
contract DummyVoter {}
