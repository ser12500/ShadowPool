// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";
import {ShadowPool} from "../src/ShadowPool.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title CreateProposals
 * @dev Script for creating governance proposals in the DAO
 */
contract CreateProposals is Script {
    ShadowPoolDAO public dao;
    ShadowPool public shadowPool;
    IERC20 public governanceToken;

    function run() external {
        uint256 proposerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proposer = vm.addr(proposerPrivateKey);

        // Use addresses from previous deployment
        dao = ShadowPoolDAO(payable(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9));
        shadowPool = ShadowPool(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
        governanceToken = IERC20(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

        console.log("Creating governance proposals...");
        console.log("Proposer:", proposer);
        console.log("DAO:", address(dao));
        console.log("ShadowPool:", address(shadowPool));

        vm.startBroadcast(proposerPrivateKey);

        // Proposal 1: Update ShadowPool fees
        _createFeeUpdateProposal();

        // Proposal 2: Update DAO parameters
        _createDAOParametersProposal();

        // Proposal 3: Update proposal threshold
        _createProposalThresholdProposal();

        vm.stopBroadcast();

        console.log("\n=== Proposals Created Successfully ===");
        console.log("Check proposal status with: dao.getProposalState(proposalId)");
    }

    function _createFeeUpdateProposal() internal {
        console.log("\n--- Creating Fee Update Proposal ---");

        string memory description = "Update ShadowPool fee structure to 0.3% percentage fee and 0.002 ETH fixed fee";

        address[] memory targets = new address[](1);
        targets[0] = address(shadowPool);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "updateFees(uint256,uint256)";

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFees(uint256,uint256)", 30, 0.002 ether); // 0.3%

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        console.log("Fee Update Proposal ID:", proposalId);
    }

    function _createDAOParametersProposal() internal {
        console.log("\n--- Creating DAO Parameters Proposal ---");

        string memory description = "Update DAO parameters: reduce voting period to 50 blocks and quorum to 3000 tokens";

        address[] memory targets = new address[](1);
        targets[0] = address(dao);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "updateParameters(uint256,uint256,uint256,uint256,uint256)";

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "updateParameters(uint256,uint256,uint256,uint256,uint256)",
            1000 * 10 ** 18, // proposalThreshold
            50, // votingPeriod
            3000 * 10 ** 18, // quorumVotes
            1 days, // timelockDelay
            10 // maxActiveProposals
        );

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        console.log("DAO Parameters Proposal ID:", proposalId);
    }

    function _createProposalThresholdProposal() internal {
        console.log("\n--- Creating Proposal Threshold Proposal ---");

        string memory description = "Increase proposal threshold to 2000 tokens to reduce spam proposals";

        address[] memory targets = new address[](1);
        targets[0] = address(dao);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "updateParameters(uint256,uint256,uint256,uint256,uint256)";

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "updateParameters(uint256,uint256,uint256,uint256,uint256)",
            2000 * 10 ** 18, // proposalThreshold
            100, // votingPeriod
            5000 * 10 ** 18, // quorumVotes
            1 days, // timelockDelay
            10 // maxActiveProposals
        );

        uint256 proposalId = dao.propose(description, targets, values, signatures, calldatas);
        console.log("Proposal Threshold Proposal ID:", proposalId);
    }
}
