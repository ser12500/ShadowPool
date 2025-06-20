// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {HonkVerifier} from "../src/Verifier/Verifier.sol";
import {ShadowPool, IVerifier, Poseidon2} from "../src/ShadowPool.sol";
import {Incremental} from "../src/Incremental.sol";
import {ShadowPoolDAO} from "../src/ShadowPoolDAO.sol";
import {ShadowPoolGovernanceToken} from "../src/ShadowPoolGovernanceToken.sol";

contract DeployDAOScript is Script {
    IVerifier public verifier;
    ShadowPool public shadowPool;
    Poseidon2 public poseidon;
    ShadowPoolDAO public dao;
    ShadowPoolGovernanceToken public governanceToken;

    // DAO parameters
    uint256 public constant INITIAL_PERCENTAGE_FEE = 50; // 0.5%
    uint256 public constant INITIAL_FIXED_FEE = 0.001 ether;
    uint256 public constant MERKLE_TREE_DEPTH = 20;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10 ** 18; // 1000 tokens
    uint256 public constant VOTING_PERIOD = 100; // 100 blocks
    uint256 public constant QUORUM_VOTES = 5000 * 10 ** 18; // 5000 tokens
    uint256 public constant TIMELOCK_DELAY = 1 days;
    uint256 public constant MAX_ACTIVE_PROPOSALS = 10;
    uint256 public constant INITIAL_TOKEN_SUPPLY = 100_000 * 10 ** 18; // 100k tokens

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying ShadowPool DAO system...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Poseidon2 hasher
        console.log("Deploying Poseidon2 hasher...");
        poseidon = new Poseidon2();
        console.log("Poseidon2 deployed at:", address(poseidon));

        // 2. Deploy HonkVerifier
        console.log("Deploying HonkVerifier...");
        verifier = new HonkVerifier();
        console.log("HonkVerifier deployed at:", address(verifier));

        // 3. Deploy Governance Token
        console.log("Deploying Governance Token...");
        governanceToken = new ShadowPoolGovernanceToken(deployer, INITIAL_TOKEN_SUPPLY);
        console.log("Governance Token deployed at:", address(governanceToken));

        // 4. Deploy DAO
        console.log("Deploying DAO...");
        dao = new ShadowPoolDAO(
            governanceToken,
            address(0), // Placeholder for ShadowPool address
            PROPOSAL_THRESHOLD,
            VOTING_PERIOD,
            QUORUM_VOTES,
            TIMELOCK_DELAY,
            MAX_ACTIVE_PROPOSALS
        );
        console.log("DAO deployed at:", address(dao));

        // 5. Deploy ShadowPool with DAO address
        console.log("Deploying ShadowPool...");
        shadowPool = new ShadowPool(
            IVerifier(verifier),
            poseidon,
            uint32(MERKLE_TREE_DEPTH),
            address(dao), // DAO address
            INITIAL_PERCENTAGE_FEE,
            INITIAL_FIXED_FEE
        );
        console.log("ShadowPool deployed at:", address(shadowPool));

        // 6. Update DAO with ShadowPool address
        console.log("Updating DAO with ShadowPool address...");
        dao.updateShadowPoolAddress(address(shadowPool));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Poseidon2:", address(poseidon));
        console.log("HonkVerifier:", address(verifier));
        console.log("ShadowPool:", address(shadowPool));
        console.log("Governance Token:", address(governanceToken));
        console.log("DAO:", address(dao));
        console.log("\n=== DAO Parameters ===");
        console.log("Proposal Threshold:", PROPOSAL_THRESHOLD / 10 ** 18, "tokens");
        console.log("Voting Period:", VOTING_PERIOD, "blocks");
        console.log("Quorum Votes:", QUORUM_VOTES / 10 ** 18, "tokens");
        console.log("Timelock Delay:", TIMELOCK_DELAY, "seconds");
        console.log("Max Active Proposals:", MAX_ACTIVE_PROPOSALS);
        console.log("Initial Token Supply:", INITIAL_TOKEN_SUPPLY / 10 ** 18, "tokens");
        console.log("\n=== Next Steps ===");
        console.log("1. Transfer governance tokens to community members");
        console.log("2. Set up governance proposals");
        console.log("3. Begin community voting process");
    }
}
