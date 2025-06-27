"use client";

import { useAccount, useBalance, useChainId } from "wagmi";
import { useShadowPool } from "@/hooks/useShadowPool";
import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function TestConnectionPage() {
    const { address, isConnected } = useAccount();
    const chainId = useChainId();
    const { data: balance } = useBalance({ address });

    const {
        poolStats,
        anonymityLevel,
        poolUtilization,
        percentageFee,
        fixedFee,
        isLoadingStats,
        isLoadingAnonymity,
        isLoadingUtilization,
        isLoadingPercentageFee,
        isLoadingFixedFee,
        poolStatsError,
        anonymityError,
        utilizationError,
        percentageFeeError,
        fixedFeeError,
        contractAddress,
    } = useShadowPool();

    return (
        <div className="space-y-6">
            <div className="text-center">
                <h1 className="text-3xl font-bold text-gray-900 mb-2">Тест подключения</h1>
                <p className="text-gray-600">Диагностика подключения к RPC провайдерам и смарт-контракту</p>
            </div>

            {/* Подключение кошелька */}
            <div className="bg-white rounded-lg shadow p-6">
                <h2 className="text-xl font-semibold mb-4">Подключение кошелька</h2>
                <div className="flex items-center justify-between">
                    <div>
                        <p className="text-sm text-gray-600">Статус подключения:</p>
                        <p className={`font-medium ${isConnected ? 'text-green-600' : 'text-red-600'}`}>
                            {isConnected ? 'Подключен' : 'Не подключен'}
                        </p>
                    </div>
                    <ConnectButton />
                </div>
                {isConnected && (
                    <div className="mt-4 space-y-2">
                        <p><span className="text-sm text-gray-600">Адрес:</span> {address}</p>
                        <p><span className="text-sm text-gray-600">Chain ID:</span> {chainId}</p>
                        <p><span className="text-sm text-gray-600">Баланс:</span> {balance?.formatted} {balance?.symbol}</p>
                    </div>
                )}
            </div>

            {/* Информация о контракте */}
            <div className="bg-white rounded-lg shadow p-6">
                <h2 className="text-xl font-semibold mb-4">Информация о контракте ShadowPool</h2>
                <p className="text-sm text-gray-600 mb-4">Адрес контракта: {contractAddress}</p>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {/* Статистика пула */}
                    <div className="space-y-2">
                        <h3 className="font-medium">Статистика пула</h3>
                        {isLoadingStats ? (
                            <p className="text-sm text-gray-500">Загрузка...</p>
                        ) : poolStatsError ? (
                            <p className="text-sm text-red-600">Ошибка: {poolStatsError.message}</p>
                        ) : poolStats ? (
                            <div className="text-sm space-y-1">
                                <p>Всего депозитов: {poolStats.totalDeposits}</p>
                                <p>Текущий корень: {poolStats.currentRoot}</p>
                                <p>Процентная комиссия: {poolStats.currentPercentageFee}</p>
                                <p>Фиксированная комиссия: {poolStats.currentFixedFee} ETH</p>
                            </div>
                        ) : (
                            <p className="text-sm text-gray-500">Нет данных</p>
                        )}
                    </div>

                    {/* Уровень анонимности */}
                    <div className="space-y-2">
                        <h3 className="font-medium">Уровень анонимности</h3>
                        {isLoadingAnonymity ? (
                            <p className="text-sm text-gray-500">Загрузка...</p>
                        ) : anonymityError ? (
                            <p className="text-sm text-red-600">Ошибка: {anonymityError.message}</p>
                        ) : anonymityLevel ? (
                            <p className="text-sm">{anonymityLevel}</p>
                        ) : (
                            <p className="text-sm text-gray-500">Нет данных</p>
                        )}
                    </div>

                    {/* Утилизация пула */}
                    <div className="space-y-2">
                        <h3 className="font-medium">Утилизация пула</h3>
                        {isLoadingUtilization ? (
                            <p className="text-sm text-gray-500">Загрузка...</p>
                        ) : utilizationError ? (
                            <p className="text-sm text-red-600">Ошибка: {utilizationError.message}</p>
                        ) : (
                            <p className="text-sm">{poolUtilization}%</p>
                        )}
                    </div>

                    {/* Комиссии */}
                    <div className="space-y-2">
                        <h3 className="font-medium">Комиссии</h3>
                        <div className="space-y-1">
                            {isLoadingPercentageFee ? (
                                <p className="text-sm text-gray-500">Загрузка процентной комиссии...</p>
                            ) : percentageFeeError ? (
                                <p className="text-sm text-red-600">Ошибка процентной комиссии: {percentageFeeError.message}</p>
                            ) : (
                                <p className="text-sm">Процентная комиссия: {percentageFee} basis points</p>
                            )}

                            {isLoadingFixedFee ? (
                                <p className="text-sm text-gray-500">Загрузка фиксированной комиссии...</p>
                            ) : fixedFeeError ? (
                                <p className="text-sm text-red-600">Ошибка фиксированной комиссии: {fixedFeeError.message}</p>
                            ) : (
                                <p className="text-sm">Фиксированная комиссия: {fixedFee} ETH</p>
                            )}
                        </div>
                    </div>
                </div>
            </div>

            {/* Инструкции по устранению неполадок */}
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
                <h2 className="text-xl font-semibold mb-4 text-yellow-800">Устранение неполадок</h2>
                <div className="space-y-3 text-sm text-yellow-700">
                    <p><strong>Если возникают ошибки CORS:</strong></p>
                    <ul className="list-disc list-inside space-y-1 ml-4">
                        <li>Проверьте подключение к интернету</li>
                        <li>Попробуйте обновить страницу</li>
                        <li>Убедитесь, что используете поддерживаемый браузер</li>
                        <li>Проверьте консоль браузера для дополнительных ошибок</li>
                    </ul>

                    <p><strong>Если контракт не отвечает:</strong></p>
                    <ul className="list-disc list-inside space-y-1 ml-4">
                        <li>Убедитесь, что подключены к правильной сети</li>
                        <li>Проверьте, что контракт развернут на текущей сети</li>
                        <li>Попробуйте переключиться на другую сеть и обратно</li>
                    </ul>
                </div>
            </div>
        </div>
    );
} 