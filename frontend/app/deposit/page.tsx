"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useShadowPool } from "@/hooks/useShadowPool";
import { FaRocket, FaShieldAlt, FaCoins, FaCalculator, FaMagic, FaArrowRight, FaEye, FaEyeSlash } from "react-icons/fa";

export default function DepositPage() {
    const { isConnected } = useAccount();
    const {
        calculateFeeForAmount,
        performDeposit,
        isDepositing,
        isWaitingDeposit,
        isDepositSuccess,
        percentageFee,
        fixedFee,
    } = useShadowPool();

    const [amount, setAmount] = useState("");
    const [showAdvanced, setShowAdvanced] = useState(false);
    const [customCommitment, setCustomCommitment] = useState("");
    const [showFee, setShowFee] = useState(true);

    const calculatedFee = calculateFeeForAmount(amount);
    const totalAmount = amount && calculatedFee ? parseFloat(amount) + parseFloat(calculatedFee) : 0;

    const handleDeposit = () => {
        if (!amount || parseFloat(amount) <= 0) return;

        // Генерируем случайный commitment если не указан пользователем
        const commitment = customCommitment || `0x${Math.random().toString(16).slice(2, 66).padEnd(64, '0')}`;

        performDeposit(amount, commitment);
    };

    const generateRandomCommitment = () => {
        const randomCommitment = `0x${Math.random().toString(16).slice(2, 66).padEnd(64, '0')}`;
        setCustomCommitment(randomCommitment);
    };

    if (!isConnected) {
        return (
            <div className="min-h-[60vh] flex items-center justify-center">
                <div className="text-center animate-fade-in-up">
                    <div className="w-24 h-24 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-6 animate-pulse-glow">
                        <FaRocket className="w-12 h-12 text-white" />
                    </div>
                    <h2 className="text-3xl font-bold text-gray-800 mb-4">
                        Подключите кошелек для депозита
                    </h2>
                    <p className="text-gray-600 mb-8 max-w-md">
                        Для внесения средств в анонимный пул необходимо подключить Web3 кошелек
                    </p>
                    <div className="hover:scale-105 transition-transform duration-300">
                        <ConnectButton />
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="max-w-4xl mx-auto">
            {/* Заголовок */}
            <div className="text-center mb-12 animate-fade-in-up">
                <h1 className="text-5xl font-bold mb-4">
                    <span className="bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
                        Безумный депозит
                    </span>
                </h1>
                <p className="text-xl text-gray-600">
                    Внесите средства в анонимный пул с полной защитой
                </p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {/* Основная форма */}
                <div className="animate-slide-in-left">
                    <div className="card hover-lift">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="w-12 h-12 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-full flex items-center justify-center animate-pulse-glow">
                                <FaCoins className="w-6 h-6 text-white" />
                            </div>
                            <h2 className="text-2xl font-bold text-gray-800">Депозит средств</h2>
                        </div>

                        {/* Сумма депозита */}
                        <div className="mb-6">
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Сумма (ETH)
                            </label>
                            <div className="relative">
                                <input
                                    type="number"
                                    value={amount}
                                    onChange={(e) => setAmount(e.target.value)}
                                    placeholder="0.0"
                                    step="0.001"
                                    min="0"
                                    className="form-input pr-12"
                                />
                                <div className="absolute right-3 top-1/2 transform -translate-y-1/2">
                                    <FaCalculator className="w-5 h-5 text-gray-400" />
                                </div>
                            </div>
                        </div>

                        {/* Комиссии */}
                        <div className="mb-6">
                            <div className="flex items-center justify-between mb-2">
                                <label className="text-sm font-medium text-gray-700">
                                    Комиссии
                                </label>
                                <button
                                    onClick={() => setShowFee(!showFee)}
                                    className="text-indigo-600 hover:text-indigo-800 transition-colors"
                                >
                                    {showFee ? <FaEyeSlash className="w-4 h-4" /> : <FaEye className="w-4 h-4" />}
                                </button>
                            </div>

                            {showFee && (
                                <div className="space-y-2 p-4 bg-gray-50 rounded-lg animate-fade-in-up">
                                    <div className="flex justify-between text-sm">
                                        <span className="text-gray-600">Процентная комиссия ({percentageFee} basis points):</span>
                                        <span className="font-medium">
                                            {amount ? `${(parseFloat(amount) * percentageFee / 10000).toFixed(6)} ETH` : '0 ETH'}
                                        </span>
                                    </div>
                                    <div className="flex justify-between text-sm">
                                        <span className="text-gray-600">Фиксированная комиссия:</span>
                                        <span className="font-medium">{fixedFee} ETH</span>
                                    </div>
                                    <div className="border-t pt-2 flex justify-between font-semibold">
                                        <span className="text-gray-800">Общая комиссия:</span>
                                        <span className="text-indigo-600">{calculatedFee} ETH</span>
                                    </div>
                                </div>
                            )}
                        </div>

                        {/* Итого */}
                        {amount && (
                            <div className="mb-6 p-4 bg-gradient-to-r from-indigo-50 to-purple-50 rounded-lg border border-indigo-200 animate-fade-in-up">
                                <div className="flex justify-between items-center">
                                    <span className="text-lg font-semibold text-gray-800">Итого к оплате:</span>
                                    <span className="text-2xl font-bold text-indigo-600">
                                        {totalAmount.toFixed(6)} ETH
                                    </span>
                                </div>
                            </div>
                        )}

                        {/* Расширенные настройки */}
                        <div className="mb-6">
                            <button
                                onClick={() => setShowAdvanced(!showAdvanced)}
                                className="flex items-center gap-2 text-indigo-600 hover:text-indigo-800 transition-colors"
                            >
                                <FaMagic className="w-4 h-4" />
                                Расширенные настройки
                                <FaArrowRight className={`w-4 h-4 transition-transform ${showAdvanced ? 'rotate-90' : ''}`} />
                            </button>

                            {showAdvanced && (
                                <div className="mt-4 space-y-4 animate-fade-in-up">
                                    <div>
                                        <label className="block text-sm font-medium text-gray-700 mb-2">
                                            Пользовательский commitment (опционально)
                                        </label>
                                        <div className="flex gap-2">
                                            <input
                                                type="text"
                                                value={customCommitment}
                                                onChange={(e) => setCustomCommitment(e.target.value)}
                                                placeholder="0x..."
                                                className="form-input flex-1"
                                            />
                                            <button
                                                onClick={generateRandomCommitment}
                                                className="px-4 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors"
                                            >
                                                <FaMagic className="w-4 h-4" />
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>

                        {/* Кнопка депозита */}
                        <button
                            onClick={handleDeposit}
                            disabled={!amount || parseFloat(amount) <= 0 || isDepositing}
                            className="btn-primary w-full flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {isDepositing ? (
                                <>
                                    <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                                    Депозит...
                                </>
                            ) : isWaitingDeposit ? (
                                <>
                                    <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                                    Ожидание подтверждения...
                                </>
                            ) : (
                                <>
                                    <FaRocket className="w-5 h-5" />
                                    Внести депозит
                                    <FaArrowRight className="w-4 h-4" />
                                </>
                            )}
                        </button>

                        {/* Статус транзакции */}
                        {isDepositSuccess && (
                            <div className="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg animate-fade-in-up">
                                <div className="flex items-center gap-2 text-green-800">
                                    <div className="w-5 h-5 bg-green-500 rounded-full flex items-center justify-center">
                                        <span className="text-white text-xs">✓</span>
                                    </div>
                                    <span className="font-medium">Депозит успешно внесен!</span>
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* Информационная панель */}
                <div className="animate-slide-in-right">
                    <div className="card hover-lift mb-6">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="w-12 h-12 bg-gradient-to-r from-green-500 to-emerald-600 rounded-full flex items-center justify-center animate-pulse-glow">
                                <FaShieldAlt className="w-6 h-6 text-white" />
                            </div>
                            <h3 className="text-xl font-bold text-gray-800">Безопасность</h3>
                        </div>

                        <div className="space-y-4">
                            <div className="flex items-start gap-3">
                                <div className="w-6 h-6 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                                    <span className="text-white text-xs">✓</span>
                                </div>
                                <div>
                                    <h4 className="font-medium text-gray-800">Zero-Knowledge доказательства</h4>
                                    <p className="text-sm text-gray-600">Ваши транзакции полностью анонимны</p>
                                </div>
                            </div>

                            <div className="flex items-start gap-3">
                                <div className="w-6 h-6 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                                    <span className="text-white text-xs">✓</span>
                                </div>
                                <div>
                                    <h4 className="font-medium text-gray-800">Прозрачные комиссии</h4>
                                    <p className="text-sm text-gray-600">Все комиссии рассчитываются заранее</p>
                                </div>
                            </div>

                            <div className="flex items-start gap-3">
                                <div className="w-6 h-6 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                                    <span className="text-white text-xs">✓</span>
                                </div>
                                <div>
                                    <h4 className="font-medium text-gray-800">Мгновенное исполнение</h4>
                                    <p className="text-sm text-gray-600">Депозиты обрабатываются мгновенно</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Статистики */}
                    <div className="card hover-lift">
                        <h3 className="text-xl font-bold text-gray-800 mb-4">Статистики пула</h3>
                        <div className="space-y-4">
                            <div className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                                <span className="text-gray-600">Процентная комиссия</span>
                                <span className="font-semibold text-indigo-600">{percentageFee} basis points</span>
                            </div>
                            <div className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                                <span className="text-gray-600">Фиксированная комиссия</span>
                                <span className="font-semibold text-indigo-600">{fixedFee} ETH</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
} 