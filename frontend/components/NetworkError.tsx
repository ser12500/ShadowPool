"use client";

import { useAccount, useChainId, useSwitchChain } from "wagmi";
import { FaExclamationTriangle, FaNetworkWired, FaWallet } from "react-icons/fa";

interface NetworkErrorProps {
    error?: string | null;
    isSupportedNetwork?: boolean;
}

export default function NetworkError({ error, isSupportedNetwork = true }: NetworkErrorProps) {
    const { isConnected } = useAccount();
    const chainId = useChainId();
    const { switchChain } = useSwitchChain();

    const handleSwitchToAnvil = () => {
        try {
            switchChain({ chainId: 31337 });
        } catch (error) {
            console.error("Ошибка переключения на Anvil:", error);
        }
    };

    if (!isConnected) {
        return (
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6 animate-fade-in-up">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-yellow-100 rounded-full flex items-center justify-center">
                        <FaWallet className="w-5 h-5 text-yellow-600" />
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-yellow-800">
                            Кошелек не подключен
                        </h3>
                        <p className="text-yellow-700">
                            Для взаимодействия с контрактом необходимо подключить Web3 кошелек
                        </p>
                    </div>
                </div>
            </div>
        );
    }

    if (!isSupportedNetwork) {
        return (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6 animate-fade-in-up">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center">
                        <FaNetworkWired className="w-5 h-5 text-red-600" />
                    </div>
                    <div className="flex-1">
                        <h3 className="text-lg font-semibold text-red-800">
                            Неподдерживаемая сеть
                        </h3>
                        <p className="text-red-700 mb-3">
                            Текущая сеть (Chain ID: {chainId}) не поддерживается.
                            Пожалуйста, переключитесь на Anvil (31337), Mainnet (1) или Sepolia (11155111).
                        </p>
                        <button
                            onClick={handleSwitchToAnvil}
                            className="bg-yellow-500 hover:bg-yellow-600 text-white px-4 py-2 rounded-lg font-medium transition-all duration-300 hover:scale-105 flex items-center gap-2"
                        >
                            <FaNetworkWired className="w-4 h-4" />
                            Переключиться на Anvil
                        </button>
                    </div>
                </div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6 animate-fade-in-up">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center">
                        <FaExclamationTriangle className="w-5 h-5 text-red-600" />
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-red-800">
                            Ошибка подключения
                        </h3>
                        <p className="text-red-700">
                            {error}
                        </p>
                    </div>
                </div>
            </div>
        );
    }

    return null;
} 