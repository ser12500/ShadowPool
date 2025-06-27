"use client";
import Link from "next/link";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useChainId } from "wagmi";
import { sepolia, hardhat, mainnet, arbitrum, base, optimism, zksyncSepoliaTestnet } from "wagmi/chains";
import { FaGithub, FaRocket, FaShieldAlt, FaCoins, FaChartLine, FaCog } from "react-icons/fa";
import ThemeToggle from "./ThemeToggle";
import { useState } from "react";

export default function Navbar() {
    const { isConnected } = useAccount();
    const chainId = useChainId();
    const [hoveredLink, setHoveredLink] = useState<string | null>(null);

    const getNetworkInfo = () => {
        if (chainId === sepolia.id) return { name: "Sepolia", color: "bg-green-500", icon: "🌱" };
        if (chainId === hardhat.id) return { name: "Anvil", color: "bg-yellow-500", icon: "⚒️" };
        if (chainId === mainnet.id) return { name: "Ethereum", color: "bg-blue-500", icon: "🔷" };
        if (chainId === arbitrum.id) return { name: "Arbitrum", color: "bg-blue-600", icon: "🔵" };
        if (chainId === base.id) return { name: "Base", color: "bg-blue-700", icon: "🏗️" };
        if (chainId === optimism.id) return { name: "Optimism", color: "bg-red-500", icon: "🚀" };
        if (chainId === zksyncSepoliaTestnet.id) return { name: "zkSync Era Sepolia", color: "bg-purple-500", icon: "⚡" };
        return { name: "Unknown", color: "bg-gray-500", icon: "❓" };
    };

    const networkInfo = getNetworkInfo();

    const navLinks = [
        { href: "/", label: "Пул", icon: FaCoins },
        { href: "/deposit", label: "Депозит", icon: FaRocket },
        { href: "/withdraw", label: "Вывод", icon: FaShieldAlt },
        { href: "/proof", label: "Proof", icon: FaCog },
        { href: "/dao", label: "DAO", icon: FaChartLine },
        { href: "/test-connection", label: "Тест", icon: FaCog },
    ];

    return (
        <nav className="px-8 py-4.5 border-b-[1px] border-zinc-100 flex flex-row justify-between items-center bg-white/80 backdrop-blur-md xl:min-h-[77px] relative z-10">
            {/* Безумный фон для навигации */}
            <div className="absolute inset-0 bg-gradient-to-r from-indigo-500/10 via-purple-500/10 to-pink-500/10 animate-rotate-gradient"></div>

            <div className="flex items-center gap-2.5 md:gap-6 relative z-10">
                <Link href="/" className="flex items-center gap-1 text-zinc-800 group">
                    <div className="w-8 h-8 bg-gradient-to-r from-indigo-600 to-purple-600 rounded-lg flex items-center justify-center animate-pulse-glow group-hover:scale-110 transition-transform duration-300">
                        <span className="text-white font-bold text-sm">SP</span>
                    </div>
                    <h1 className="font-bold text-2xl hidden md:block bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
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
                                className="relative text-gray-700 hover:text-indigo-600 transition-all duration-300 group flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-white/50"
                                onMouseEnter={() => setHoveredLink(link.href)}
                                onMouseLeave={() => setHoveredLink(null)}
                            >
                                <Icon className="w-4 h-4 group-hover:animate-bounce" />
                                <span className="font-medium">{link.label}</span>

                                {/* Безумные эффекты при наведении */}
                                {hoveredLink === link.href && (
                                    <div className="absolute inset-0 rounded-lg bg-gradient-to-r from-indigo-500/20 to-purple-500/20 animate-pulse-glow"></div>
                                )}

                                {/* Частицы при наведении */}
                                <div className="absolute -top-1 -right-1 w-1 h-1 bg-indigo-500 rounded-full opacity-0 group-hover:opacity-100 group-hover:animate-float"></div>
                                <div className="absolute -bottom-1 -left-1 w-1 h-1 bg-purple-500 rounded-full opacity-0 group-hover:opacity-100 group-hover:animate-float" style={{ animationDelay: '0.5s' }}></div>
                            </Link>
                        );
                    })}
                </div>

                <a
                    href="https://github.com/ser12500/ShadowPoold"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="p-2 rounded-lg bg-gradient-to-r from-zinc-900 to-zinc-800 hover:from-zinc-800 hover:to-zinc-700 transition-all duration-300 border-2 border-zinc-600 hover:border-zinc-500 cursor-alias hidden md:block hover:scale-110 hover:rotate-3"
                >
                    <FaGithub className="h-5 w-5 text-white" />
                </a>
            </div>

            <h3 className="italic text-left hidden text-zinc-500 lg:block relative z-10">
                <span className="bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent font-semibold">
                    Анонимный пул ликвидности с доказательствами
                </span>
            </h3>

            <div className="flex items-center gap-4 relative z-10">
                {isConnected && (
                    <div className="flex items-center gap-2 px-3 py-1 bg-white/80 backdrop-blur-sm rounded-full border border-gray-200 hover:scale-105 transition-transform duration-300">
                        <div className={`w-2 h-2 rounded-full ${networkInfo.color} animate-pulse-glow`}></div>
                        <span className="text-sm text-gray-600 font-medium flex items-center gap-1">
                            <span>{networkInfo.icon}</span>
                            {networkInfo.name}
                        </span>
                    </div>
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