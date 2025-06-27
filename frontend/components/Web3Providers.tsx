"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { type ReactNode, useState } from "react";
import config from "@/lib/rainbowKitConfig";
import { WagmiProvider } from "wagmi";
import { lightTheme, RainbowKitProvider } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";
import Navbar from "./Navbar";
import ParticleBackground from "./ParticleBackground";

export default function Web3Providers({ children }: { children: ReactNode }) {
    const [queryClient] = useState(() => new QueryClient({
        defaultOptions: {
            queries: {
                retry: (failureCount, error: any) => {
                    // Не повторяем попытки для ошибок сети
                    if (error?.message?.includes('CORS') || error?.message?.includes('network')) {
                        return false;
                    }
                    return failureCount < 3;
                },
                retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
                staleTime: 5 * 60 * 1000, // 5 минут
                gcTime: 10 * 60 * 1000, // 10 минут
            },
            mutations: {
                retry: (failureCount, error: any) => {
                    // Не повторяем попытки для ошибок сети
                    if (error?.message?.includes('CORS') || error?.message?.includes('network')) {
                        return false;
                    }
                    return failureCount < 2;
                },
                retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 5000),
            },
        },
    }));

    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
                <RainbowKitProvider
                    theme={lightTheme({
                        borderRadius: "medium",
                        accentColor: "#6366f1",
                        overlayBlur: "small",
                    })}
                    locale="ru-RU"
                    showRecentTransactions={true}
                >
                    {/* Анимированный фон */}
                    <ParticleBackground />

                    {/* Навигация */}
                    <Navbar />

                    {/* Основной контент */}
                    <main className="relative z-10 max-w-7xl mx-auto py-8 px-4">
                        {children}
                    </main>
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    );
} 