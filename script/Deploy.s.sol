// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ShadowPool} from "../src/ShadowPool.sol";
import {Verifier} from "../src/Verifier.sol";
import {Script} from "lib/forge-std/src/Script.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        address owner = address(0x3);
        Verifier verifier = new Verifier();
        ShadowPool shadowpool = new ShadowPool(address(verifier), owner);
        vm.stopBroadcast();
    }
}
