"use client";
import { useAccount, useBalance } from "wagmi";
import { formatEther } from "viem";

export default function WalletInfo() {
    const { address, isConnected } = useAccount();
    const { data: balance } = useBalance({
        address,
    });

    if (!isConnected || !address) {
        return null;
    }

    return (
        <div className="bg-white rounded-lg shadow p-4 mb-6">
            <h3 className="text-lg font-medium text-gray-800 mb-3">Информация о кошельке</h3>

            <div className="space-y-2">
                <div className="flex justify-between">
                    <span className="text-gray-600">Адрес:</span>
                    <span className="font-mono text-sm text-gray-800">
                        {address.slice(0, 6)}...{address.slice(-4)}
                    </span>
                </div>

                {balance && (
                    <div className="flex justify-between">
                        <span className="text-gray-600">Баланс:</span>
                        <span className="font-medium text-gray-800">
                            {parseFloat(formatEther(balance.value)).toFixed(4)} {balance.symbol}
                        </span>
                    </div>
                )}
            </div>
        </div>
    );
} 