"use client";
import { useAccount, useChainId } from "wagmi";
import { sepolia, hardhat } from "wagmi/chains";

export default function ConnectionStatus() {
    const { isConnected } = useAccount();
    const chainId = useChainId();

    if (!isConnected) {
        return (
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
                <div className="flex items-center gap-3">
                    <div className="w-2 h-2 bg-yellow-500 rounded-full"></div>
                    <div>
                        <h3 className="text-yellow-800 font-medium">Кошелёк не подключен</h3>
                        <p className="text-yellow-700 text-sm">Подключите кошелёк для взаимодействия с dApp</p>
                    </div>
                </div>
            </div>
        );
    }

    if (chainId !== sepolia.id && chainId !== hardhat.id) {
        return (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
                <div className="flex items-center gap-3">
                    <div className="w-2 h-2 bg-red-500 rounded-full"></div>
                    <div>
                        <h3 className="text-red-800 font-medium">Неподдерживаемая сеть</h3>
                        <p className="text-red-700 text-sm">
                            Переключитесь на Sepolia или Hardhat для тестирования
                        </p>
                    </div>
                </div>
            </div>
        );
    }

    const networkName = chainId === sepolia.id ? "Sepolia" :
        chainId === hardhat.id ? "Hardhat" : "сети";

    return (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
            <div className="flex items-center gap-3">
                <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                <div>
                    <h3 className="text-green-800 font-medium">Готов к работе</h3>
                    <p className="text-green-700 text-sm">
                        Подключен к {networkName}
                    </p>
                </div>
            </div>
        </div>
    );
} 