// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title VoteOnProposals
 * @dev Script for voting on governance proposals in the DAO
 */
contract VoteOnProposals is Script {
    ShadowPoolDAO public dao;
    IERC20 public governanceToken;

    // Private keys for different participants (for demonstration)
    uint256[] public voterPrivateKeys = [
        0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a, // user1
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d, // user2
        0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a, // user3
        0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba, // user4
        0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e // user5
    ];

    function run() external {
        // Use addresses from previous deployment
        dao = ShadowPoolDAO(payable(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9));
        governanceToken = IERC20(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

        console.log("Voting on governance proposals...");
        console.log("DAO:", address(dao));

        // Vote on proposals 0, 1, 2
        _voteOnProposal(0, true); // For fee update
        _voteOnProposal(1, true); // For DAO parameters update
        _voteOnProposal(2, false); // Against proposal threshold increase

        console.log("\n=== Voting Completed ===");
        console.log("Check voting results with: dao.getForVotes(proposalId) and dao.getAgainstVotes(proposalId)");
    }

    function _voteOnProposal(uint256 proposalId, bool support) internal {
        console.log("\n--- Voting on Proposal", proposalId, "---");
        console.log("Support:", support ? "YES" : "NO");

        for (uint256 i = 0; i < voterPrivateKeys.length; i++) {
            uint256 voterPrivateKey = voterPrivateKeys[i];
            address voter = vm.addr(voterPrivateKey);
            uint256 voterBalance = governanceToken.balanceOf(voter);

            if (voterBalance > 0) {
                console.log("Voter", i + 1);
                console.log("Address:", voter);
                console.log("Tokens:", voterBalance / 10 ** 18);

                vm.startBroadcast(voterPrivateKey);
                dao.castVote(proposalId, support);
                vm.stopBroadcast();

                console.log("Vote cast successfully");
            } else {
                console.log("Voter", i + 1);
                console.log("Address:", voter);
                console.log("Status: No tokens, skipping vote");
            }
        }

        // Check voting results
        uint256 forVotes = dao.getForVotes(proposalId);
        uint256 againstVotes = dao.getAgainstVotes(proposalId);

        console.log("Proposal", proposalId, "Results:");
        console.log("For votes:", forVotes / 10 ** 18, "tokens");
        console.log("Against votes:", againstVotes / 10 ** 18, "tokens");
        console.log("Total votes:", (forVotes + againstVotes) / 10 ** 18, "tokens");
    }

    function executeSuccessfulProposals() external {
        console.log("\n=== Executing Successful Proposals ===");

        // Check and execute successful proposals
        for (uint256 proposalId = 0; proposalId < 3; proposalId++) {
            ShadowPoolDAO.ProposalState state = dao.getProposalState(proposalId);
            console.log("Proposal", proposalId, "state:", _getStateString(state));

            if (state == ShadowPoolDAO.ProposalState.Succeeded) {
                console.log("Executing proposal", proposalId, "...");

                uint256 executorPrivateKey = vm.envUint("PRIVATE_KEY");
                vm.startBroadcast(executorPrivateKey);
                dao.execute(proposalId);
                vm.stopBroadcast();

                console.log("Proposal", proposalId, "executed successfully");
            }
        }
    }

    function _getStateString(ShadowPoolDAO.ProposalState state) internal pure returns (string memory) {
        if (state == ShadowPoolDAO.ProposalState.Pending) return "Pending";
        if (state == ShadowPoolDAO.ProposalState.Active) return "Active";
        if (state == ShadowPoolDAO.ProposalState.Canceled) return "Canceled";
        if (state == ShadowPoolDAO.ProposalState.Defeated) return "Defeated";
        if (state == ShadowPoolDAO.ProposalState.Succeeded) return "Succeeded";
        if (state == ShadowPoolDAO.ProposalState.Queued) return "Queued";
        if (state == ShadowPoolDAO.ProposalState.Expired) return "Expired";
        if (state == ShadowPoolDAO.ProposalState.Executed) return "Executed";
        return "Unknown";
    }
}
