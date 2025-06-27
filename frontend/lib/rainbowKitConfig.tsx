"use client"

import { mainnet, sepolia, hardhat, arbitrum, base, optimism, zksyncSepoliaTestnet } from "wagmi/chains"
import { http, createConfig } from "wagmi"

// Создаем собственную конфигурацию с проверенными RPC URL
const config = createConfig({
    chains: [
        {
            ...mainnet,
            rpcUrls: {
                ...mainnet.rpcUrls,
                default: {
                    http: [
                        "https://rpc.ankr.com/eth",
                        "https://ethereum.publicnode.com",
                        "https://cloudflare-eth.com"
                    ],
                },
                public: {
                    http: [
                        "https://rpc.ankr.com/eth",
                        "https://ethereum.publicnode.com",
                        "https://cloudflare-eth.com"
                    ],
                },
            },
        },
        {
            ...sepolia,
            rpcUrls: {
                ...sepolia.rpcUrls,
                default: {
                    http: [
                        "https://rpc.sepolia.org",
                        "https://rpc2.sepolia.org",
                        "https://ethereum-sepolia.publicnode.com"
                    ],
                },
                public: {
                    http: [
                        "https://rpc.sepolia.org",
                        "https://rpc2.sepolia.org",
                        "https://ethereum-sepolia.publicnode.com"
                    ],
                },
            },
        },
        hardhat,
        {
            ...arbitrum,
            rpcUrls: {
                ...arbitrum.rpcUrls,
                default: {
                    http: [
                        "https://arb1.arbitrum.io/rpc",
                        "https://arbitrum.publicnode.com"
                    ],
                },
                public: {
                    http: [
                        "https://arb1.arbitrum.io/rpc",
                        "https://arbitrum.publicnode.com"
                    ],
                },
            },
        },
        {
            ...base,
            rpcUrls: {
                ...base.rpcUrls,
                default: {
                    http: [
                        "https://mainnet.base.org",
                        "https://base.publicnode.com"
                    ],
                },
                public: {
                    http: [
                        "https://mainnet.base.org",
                        "https://base.publicnode.com"
                    ],
                },
            },
        },
        {
            ...optimism,
            rpcUrls: {
                ...optimism.rpcUrls,
                default: {
                    http: [
                        "https://mainnet.optimism.io",
                        "https://optimism.publicnode.com"
                    ],
                },
                public: {
                    http: [
                        "https://mainnet.optimism.io",
                        "https://optimism.publicnode.com"
                    ],
                },
            },
        },
        {
            ...zksyncSepoliaTestnet,
            rpcUrls: {
                ...zksyncSepoliaTestnet.rpcUrls,
                default: {
                    http: [
                        "https://sepolia.era.zksync.io",
                        "https://rpc.sepolia.zksync.io"
                    ],
                },
                public: {
                    http: [
                        "https://sepolia.era.zksync.io",
                        "https://rpc.sepolia.zksync.io"
                    ],
                },
            },
        },
    ],
    transports: {
        [mainnet.id]: http(),
        [sepolia.id]: http(),
        [hardhat.id]: http(),
        [arbitrum.id]: http(),
        [base.id]: http(),
        [optimism.id]: http(),
        [zksyncSepoliaTestnet.id]: http(),
    },
})

export default config 