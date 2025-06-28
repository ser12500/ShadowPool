"use client";
import Link from "next/link";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useChainId, useSwitchChain } from "wagmi";
import { sepolia, hardhat, mainnet, arbitrum, base, optimism, zksyncSepoliaTestnet } from "wagmi/chains";
import { FaGithub, FaRocket, FaShieldAlt, FaCoins, FaChartLine, FaCog, FaNetworkWired, FaSkull, FaRadiation, FaExclamationTriangle, FaBiohazard } from "react-icons/fa";
import ThemeToggle from "./ThemeToggle";
import { useState } from "react";

export default function Navbar() {
    const { isConnected } = useAccount();
    const chainId = useChainId();
    const { switchChain } = useSwitchChain();
    const [hoveredLink, setHoveredLink] = useState<string | null>(null);

    const getNetworkInfo = () => {
        if (chainId === sepolia.id) return { name: "Sepolia", color: "bg-green-500", icon: "🌱" };
        if (chainId === hardhat.id || chainId === 31337) return { name: "Anvil", color: "bg-yellow-500", icon: "⚒️" };
        if (chainId === mainnet.id) return { name: "Ethereum", color: "bg-blue-500", icon: "🔷" };
        if (chainId === arbitrum.id) return { name: "Arbitrum", color: "bg-blue-600", icon: "🔵" };
        if (chainId === base.id) return { name: "Base", color: "bg-blue-700", icon: "🏗️" };
        if (chainId === optimism.id) return { name: "Optimism", color: "bg-red-500", icon: "🚀" };
        if (chainId === zksyncSepoliaTestnet.id) return { name: "zkSync Era Sepolia", color: "bg-purple-500", icon: "⚡" };
        return { name: "Unknown", color: "bg-gray-500", icon: "❓" };
    };

    const networkInfo = getNetworkInfo();
    const isSupportedNetwork = chainId === 31337 || chainId === 1 || chainId === 11155111;

    const handleSwitchToAnvil = () => {
        try {
            switchChain({ chainId: 31337 });
        } catch (error) {
            console.error("Ошибка переключения на Anvil:", error);
        }
    };

    const navLinks = [
        { href: "/", label: "НЕЗАКОННЫЙ ПУЛ", icon: FaBiohazard },
        { href: "/deposit", label: "ТЕНЕВОЙ ДЕПОЗИТ", icon: FaRocket },
        { href: "/withdraw", label: "СКРЫТЫЙ ВЫВОД", icon: FaShieldAlt },
        { href: "/proof", label: "ХАКЕРСКИЙ PROOF", icon: FaCog },
        { href: "/dao", label: "ПОДПОЛЬНАЯ DAO", icon: FaChartLine },
        { href: "/test-connection", label: "ТЕСТ ВЗЛОМА", icon: FaSkull },
    ];

    return (
        <nav className="px-8 py-4.5 border-b-[2px] border-red-500 flex flex-row justify-between items-center bg-black/90 backdrop-blur-md xl:min-h-[77px] relative z-10 nav-danger">
            {/* Опасный фон для навигации */}
            <div className="absolute inset-0 bg-gradient-to-r from-red-500/20 via-black/50 to-red-500/20 animate-pulse"></div>

            <div className="flex items-center gap-2.5 md:gap-6 relative z-10">
                <Link href="/" className="flex items-center gap-1 text-red-400 group">
                    <div className="w-8 h-8 bg-gradient-to-r from-red-600 to-red-800 rounded-lg flex items-center justify-center danger-pulse group-hover:scale-110 transition-transform duration-300">
                        <FaSkull className="text-white text-sm" />
                    </div>
                    <h1 className="font-bold text-2xl hidden md:block bg-gradient-to-r from-red-400 to-red-600 bg-clip-text text-transparent glitch" data-text="ShadowPool">
                        ShadowPool
                    </h1>
                </Link>

                <div className="flex items-center gap-4">
                    {navLinks.map((link) => {
                        const Icon = link.icon;
                        return (
                            <Link
                                key={link.href}
                                href={link.href}
                                className="relative text-red-400 hover:text-red-300 transition-all duration-300 group flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-red-500/20 nav-link"
                                onMouseEnter={() => setHoveredLink(link.href)}
                                onMouseLeave={() => setHoveredLink(null)}
                            >
                                <Icon className="w-4 h-4 group-hover:animate-bounce" />
                                <span className="font-medium text-xs">{link.label}</span>

                                {/* Опасные эффекты при наведении */}
                                {hoveredLink === link.href && (
                                    <div className="absolute inset-0 rounded-lg bg-gradient-to-r from-red-500/30 to-red-800/30 danger-pulse"></div>
                                )}

                                {/* Частицы опасности при наведении */}
                                <div className="absolute -top-1 -right-1 w-1 h-1 bg-red-500 rounded-full opacity-0 group-hover:opacity-100 group-hover:animate-float"></div>
                                <div className="absolute -bottom-1 -left-1 w-1 h-1 bg-red-600 rounded-full opacity-0 group-hover:opacity-100 group-hover:animate-float" style={{ animationDelay: '0.5s' }}></div>
                            </Link>
                        );
                    })}
                </div>

                <a
                    href="https://github.com/ser12500/ShadowPoold"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="p-2 rounded-lg bg-gradient-to-r from-red-900 to-red-800 hover:from-red-800 hover:to-red-700 transition-all duration-300 border-2 border-red-600 hover:border-red-500 cursor-alias hidden md:block hover:scale-110 hover:rotate-3 danger-pulse"
                >
                    <FaGithub className="h-5 w-5 text-white" />
                </a>
            </div>

            <h3 className="italic text-left hidden text-red-400 lg:block relative z-10">
                <span className="bg-gradient-to-r from-red-400 to-red-600 bg-clip-text text-transparent font-semibold glitch" data-text="НЕЗАКОННЫЙ анонимный пул">
                    <FaRadiation className="inline mr-2" />
                    НЕЗАКОННЫЙ анонимный пул
                    <FaExclamationTriangle className="inline ml-2" />
                </span>
            </h3>

            <div className="flex items-center gap-4 relative z-10">
                {isConnected && (
                    <div className="flex items-center gap-2 px-3 py-1 bg-black/80 backdrop-blur-sm rounded-full border border-red-500 hover:scale-105 transition-transform duration-300 danger-border">
                        <div className={`w-2 h-2 rounded-full ${networkInfo.color} danger-pulse`}></div>
                        <span className="text-sm text-red-400 font-medium flex items-center gap-1">
                            <span>{networkInfo.icon}</span>
                            {networkInfo.name}
                        </span>
                    </div>
                )}

                {isConnected && !isSupportedNetwork && (
                    <button
                        onClick={handleSwitchToAnvil}
                        className="flex items-center gap-2 px-3 py-2 bg-yellow-500 hover:bg-yellow-600 text-black rounded-lg font-medium transition-all duration-300 hover:scale-105 hover:shadow-lg danger-pulse"
                        title="Переключиться на Anvil для работы с контрактом"
                    >
                        <FaNetworkWired className="w-4 h-4" />
                        <span className="text-sm">Переключиться на Anvil</span>
                    </button>
                )}

                <ThemeToggle />

                <div className="hover:scale-105 transition-transform duration-300">
                    <ConnectButton
                        showBalance={true}
                        chainStatus="icon"
                    />
                </div>
            </div>
        </nav>
    );
} 