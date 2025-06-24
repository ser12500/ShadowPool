// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {CrossChainShadowPool} from "../src/CrossChainShadowPool.sol";
import {Poseidon2} from "../src/Incremental.sol";
import {HonkVerifier} from "../src/Verifier/Verifier.sol";

/**
 * @title DeployCrossChain
 * @dev Script for deploying CrossChainShadowPool with LayerZero integration.
 * Supports deployment across multiple chains with proper configuration.
 */
contract DeployCrossChain is Script {
    // LayerZero endpoint addresses for different chains
    mapping(uint256 => address) public lzEndpoints;

    function setUp() public {
        // Initialize LayerZero endpoints for different chains
        lzEndpoints[1] = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675; // Ethereum Mainnet
        lzEndpoints[137] = 0x3c2269811836af69497E5F486A85D7316753cf62; // Polygon
        lzEndpoints[56] = 0x3c2269811836af69497E5F486A85D7316753cf62; // BNB Chain
        lzEndpoints[42161] = 0x3c2269811836af69497E5F486A85D7316753cf62; // Arbitrum One
        lzEndpoints[10] = 0x3c2269811836af69497E5F486A85D7316753cf62; // Optimism
        lzEndpoints[43114] = 0x3c2269811836af69497E5F486A85D7316753cf62; // Avalanche
        lzEndpoints[250] = 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7; // Fantom
        lzEndpoints[1101] = 0x3c2269811836af69497E5F486A85D7316753cf62; // Polygon zkEVM
        lzEndpoints[8453] = 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7; // Base
        lzEndpoints[59144] = 0x3c2269811836af69497E5F486A85D7316753cf62; // Linea
        lzEndpoints[31337] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address daoAddress = vm.envAddress("DAO_ADDRESS");

        // Get current chain ID
        uint256 chainId = block.chainid;
        address lzEndpoint = lzEndpoints[chainId];

        if (lzEndpoint == address(0)) {
            revert("LayerZero endpoint not configured for this chain");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Poseidon2 hasher
        Poseidon2 hasher = new Poseidon2();
        console.log("Poseidon2 deployed at:", address(hasher));

        // Deploy Verifier
        HonkVerifier verifier = new HonkVerifier();
        console.log("Verifier deployed at:", address(verifier));

        // Deploy CrossChainShadowPool
        CrossChainShadowPool crossChainPool = new CrossChainShadowPool(
            verifier,
            hasher,
            20, // Merkle tree depth
            daoAddress,
            50, // 0.5% percentage fee
            0.001 ether, // 0.001 ETH fixed fee
            lzEndpoint
        );
        console.log("CrossChainShadowPool deployed at:", address(crossChainPool));
        console.log("Chain ID:", chainId);
        console.log("LayerZero Endpoint:", lzEndpoint);

        vm.stopBroadcast();

        // Output deployment information
        console.log("\n=== CrossChainShadowPool Deployment Complete ===");
        console.log("Chain ID:", chainId);
        console.log("Poseidon2 Hasher:", address(hasher));
        console.log("Verifier:", address(verifier));
        console.log("CrossChainShadowPool:", address(crossChainPool));
        console.log("DAO Address:", daoAddress);
        console.log("LayerZero Endpoint:", lzEndpoint);
        console.log("Percentage Fee: 0.5%");
        console.log("Fixed Fee: 0.001 ETH");
        console.log("Merkle Tree Depth: 20");
    }

    /**
     * @dev Deploy to a specific chain with custom parameters.
     * @param _chainId Target chain ID.
     * @param _daoAddress DAO contract address.
     * @param _percentageFee Percentage fee in basis points.
     * @param _fixedFee Fixed fee in wei.
     */
    function deployToChain(uint256 _chainId, address _daoAddress, uint256 _percentageFee, uint256 _fixedFee) public {
        address lzEndpoint = lzEndpoints[_chainId];
        if (lzEndpoint == address(0)) {
            revert("LayerZero endpoint not configured for this chain");
        }

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Poseidon2 hasher
        Poseidon2 hasher = new Poseidon2();

        // Deploy Verifier
        HonkVerifier verifier = new HonkVerifier();

        // Deploy CrossChainShadowPool
        CrossChainShadowPool crossChainPool = new CrossChainShadowPool(
            verifier,
            hasher,
            20, // Merkle tree depth
            _daoAddress,
            _percentageFee,
            _fixedFee,
            lzEndpoint
        );

        vm.stopBroadcast();

        console.log("Deployed to chain", _chainId);
        console.log("CrossChainShadowPool:", address(crossChainPool));
    }

    /**
     * @dev Configure trusted remotes for cross-chain communication.
     * @param _poolAddress Address of the CrossChainShadowPool.
     * @param _remoteChainId Remote chain ID.
     * @param _remotePoolAddress Address of the pool on the remote chain.
     */
    function configureTrustedRemote(address _poolAddress, uint16 _remoteChainId, address _remotePoolAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address payable poolAddressPayable = payable(_poolAddress);
        CrossChainShadowPool pool = CrossChainShadowPool(poolAddressPayable);

        // Encode the remote address
        bytes memory remoteAddress = abi.encodePacked(_remotePoolAddress);

        // Set trusted remote
        pool.setTrustedRemote(_remoteChainId, remoteAddress);

        vm.stopBroadcast();

        console.log("Configured trusted remote for chain", _remoteChainId);
        console.log("Remote pool address:", _remotePoolAddress);
    }

    /**
     * @dev Deploy to multiple chains with the same configuration.
     * @param _chainIds Array of chain IDs to deploy to.
     * @param _daoAddress DAO contract address.
     */
    function deployToMultipleChains(uint256[] memory _chainIds, address _daoAddress) public {
        for (uint256 i = 0; i < _chainIds.length; i++) {
            console.log("Deploying to chain:", _chainIds[i]);
            deployToChain(_chainIds[i], _daoAddress, 50, 0.001 ether);
        }
    }
}
