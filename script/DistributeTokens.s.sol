// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "lib/forge-std/src/Script.sol";
import {ShadowPoolGovernanceToken} from "../src/ShadowPoolGovernanceToken.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DistributeTokens
 * @dev Script for distributing governance tokens to community members
 */
contract DistributeTokens is Script {
    ShadowPoolGovernanceToken public governanceToken;

    // Community members addresses (replace with real addresses if needed)
    address[] public communityMembers = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8, // user1
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, // user2
        0x90F79bf6EB2c4f870365E785982E1f101E93b906, // user3
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65, // user4
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc, // user5
        0x976EA74026E726554dB657fA54763abd0C3a0aa9, // user6
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955, // user7
        0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f, // user8
        0xa0Ee7A142d267C1f36714E4a8F75612F20a79720, // user9
        0xBcd4042DE499D14e55001CcbB24a551F3b954096 // user10
    ];

    // Token distribution amounts (in tokens)
    uint256[] public tokenAmounts = [
        10000 * 10 ** 18, // 10,000 tokens
        8000 * 10 ** 18, // 8,000 tokens
        7000 * 10 ** 18, // 7,000 tokens
        6000 * 10 ** 18, // 6,000 tokens
        5000 * 10 ** 18, // 5,000 tokens
        4000 * 10 ** 18, // 4,000 tokens
        3000 * 10 ** 18, // 3,000 tokens
        2000 * 10 ** 18, // 2,000 tokens
        1500 * 10 ** 18, // 1,500 tokens
        1000 * 10 ** 18 // 1,000 tokens
    ];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Use governance token address from previous deployment
        governanceToken = ShadowPoolGovernanceToken(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

        console.log("Distributing governance tokens to community members...");
        console.log("Deployer:", deployer);
        console.log("Governance Token:", address(governanceToken));

        vm.startBroadcast(deployerPrivateKey);

        uint256 totalDistributed = 0;

        for (uint256 i = 0; i < communityMembers.length; i++) {
            address member = communityMembers[i];
            uint256 amount = tokenAmounts[i];

            // Transfer tokens to the community member
            governanceToken.transfer(member, amount);
            totalDistributed += amount;

            console.log("Distributed", amount / 10 ** 18, "tokens to", member);
        }

        vm.stopBroadcast();

        console.log("\n=== Token Distribution Summary ===");
        console.log("Total tokens distributed:", totalDistributed / 10 ** 18);
        console.log("Number of community members:", communityMembers.length);
        console.log("Remaining tokens with deployer:", governanceToken.balanceOf(deployer) / 10 ** 18);

        console.log("\n=== Community Members ===");
        for (uint256 i = 0; i < communityMembers.length; i++) {}
    }
}
