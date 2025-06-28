"use client"

import { mainnet, sepolia, arbitrum, base, optimism, zksyncSepoliaTestnet } from "wagmi/chains"
import { http, createConfig } from "wagmi"

// Определяем сеть Anvil прямо здесь
const anvil = {
    id: 31337,
    name: "Anvil",
    network: "anvil",
    nativeCurrency: {
        name: "Ethereum",
        symbol: "ETH",
        decimals: 18,
    },
    rpcUrls: {
        default: { http: ["http://127.0.0.1:8545"] },
        public: { http: ["http://127.0.0.1:8545"] },
    },
    blockExplorers: {
        default: { name: "Etherscan", url: "https://etherscan.io" },
    },
    testnet: true,
} as const

// Создаем собственную конфигурацию с проверенными RPC URL и улучшенной обработкой ошибок
const config = createConfig({
    chains: [
        anvil, // Добавляем Anvil первым для удобства локальной разработки
        {
            ...mainnet,
            rpcUrls: {
                ...mainnet.rpcUrls,
                default: {
                    http: [
                        "https://ethereum.publicnode.com",
                        "https://cloudflare-eth.com",
                        "https://rpc.ankr.com/eth"
                    ],
                },
                public: {
                    http: [
                        "https://ethereum.publicnode.com",
                        "https://cloudflare-eth.com",
                        "https://rpc.ankr.com/eth"
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
                        "https://ethereum-sepolia.publicnode.com",
                        "https://rpc.sepolia.org",
                        "https://rpc2.sepolia.org"
                    ],
                },
                public: {
                    http: [
                        "https://ethereum-sepolia.publicnode.com",
                        "https://rpc.sepolia.org",
                        "https://rpc2.sepolia.org"
                    ],
                },
            },
        },
        {
            ...arbitrum,
            rpcUrls: {
                ...arbitrum.rpcUrls,
                default: {
                    http: [
                        "https://arbitrum.publicnode.com",
                        "https://arb1.arbitrum.io/rpc"
                    ],
                },
                public: {
                    http: [
                        "https://arbitrum.publicnode.com",
                        "https://arb1.arbitrum.io/rpc"
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
                        "https://base.publicnode.com",
                        "https://mainnet.base.org"
                    ],
                },
                public: {
                    http: [
                        "https://base.publicnode.com",
                        "https://mainnet.base.org"
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
                        "https://optimism.publicnode.com",
                        "https://mainnet.optimism.io"
                    ],
                },
                public: {
                    http: [
                        "https://optimism.publicnode.com",
                        "https://mainnet.optimism.io"
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
        [anvil.id]: http(),
        [mainnet.id]: http(),
        [sepolia.id]: http(),
        [arbitrum.id]: http(),
        [base.id]: http(),
        [optimism.id]: http(),
        [zksyncSepoliaTestnet.id]: http(),
    },
})

export default config
