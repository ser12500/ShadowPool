"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useShadowPool } from "@/hooks/useShadowPool";
import { FaRocket, FaShieldAlt, FaCoins, FaCalculator, FaMagic, FaArrowRight, FaEye, FaEyeSlash, FaSkull, FaRadiation, FaExclamationTriangle, FaBiohazard, FaLock } from "react-icons/fa";
import NetworkError from "@/components/NetworkError";
import DangerButton from "@/components/DangerButton";
import DangerParticles from "@/components/DangerParticles";

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
        lastError,
        isSupportedNetwork,
    } = useShadowPool();

    const [amount, setAmount] = useState("");
    const [showAdvanced, setShowAdvanced] = useState(false);
    const [customCommitment, setCustomCommitment] = useState("");
    const [showFee, setShowFee] = useState(true);
    const [showWarning, setShowWarning] = useState(true);

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
            <div className="min-h-[60vh] flex items-center justify-center relative">
                <DangerParticles />
                <div className="text-center animate-fade-in-up relative z-10">
                    <div className="w-24 h-24 bg-gradient-to-r from-red-500 to-red-800 rounded-full flex items-center justify-center mx-auto mb-6 danger-pulse">
                        <FaSkull className="w-12 h-12 text-white" />
                    </div>
                    <h2 className="text-3xl font-bold text-red-400 mb-4 glitch" data-text="ПОДКЛЮЧИТЕ КОШЕЛЕК">
                        ПОДКЛЮЧИТЕ КОШЕЛЕК
                    </h2>
                    <p className="text-red-300 mb-8 max-w-md">
                        <FaExclamationTriangle className="inline mr-2" />
                        Для внесения средств в НЕЗАКОННЫЙ пул необходимо подключить Web3 кошелек
                        <FaExclamationTriangle className="inline ml-2" />
                    </p>
                    <div className="hover:scale-105 transition-transform duration-300">
                        <ConnectButton />
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="max-w-4xl mx-auto relative">
            <DangerParticles />
            
            {/* Предупреждение об опасности */}
            {showWarning && (
                <div className="mb-8 p-6 bg-gradient-to-r from-red-900/50 to-red-800/50 border-2 border-red-500 rounded-lg danger-pulse">
                    <div className="flex items-center gap-3 mb-4">
                        <FaRadiation className="w-6 h-6 text-red-400" />
                        <h3 className="text-xl font-bold text-red-400">ВНИМАНИЕ: НЕЗАКОННАЯ ОПЕРАЦИЯ</h3>
                        <button
                            onClick={() => setShowWarning(false)}
                            className="ml-auto text-red-400 hover:text-red-300"
                        >
                            ×
                        </button>
                    </div>
                    <p className="text-red-300 mb-4">
                        <FaExclamationTriangle className="inline mr-2" />
                        Данная операция является незаконной и может привести к уголовной ответственности.
                        Использование этого сервиса на свой страх и риск.
                        <FaExclamationTriangle className="inline ml-2" />
                    </p>
                    <div className="flex items-center gap-2 text-red-400 text-sm">
                        <FaLock className="w-4 h-4" />
                        <span>Все транзакции отслеживаются правоохранительными органами</span>
                    </div>
                </div>
            )}

            {/* Отображение ошибок сети */}
            <NetworkError error={lastError} isSupportedNetwork={isSupportedNetwork} />

            {/* Заголовок */}
            <div className="text-center mb-12 animate-fade-in-up">
                <h1 className="text-5xl font-bold mb-4">
                    <span className="bg-gradient-to-r from-red-400 to-red-600 bg-clip-text text-transparent glitch" data-text="НЕЗАКОННЫЙ ДЕПОЗИТ">
                        <FaSkull className="inline mr-4" />
                        НЕЗАКОННЫЙ ДЕПОЗИТ
                        <FaSkull className="inline ml-4" />
                    </span>
                </h1>
                <p className="text-xl text-red-300">
                    <FaBiohazard className="inline mr-2" />
                    Внесите средства в теневой пул с полной анонимностью
                    <FaBiohazard className="inline ml-2" />
                </p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {/* Основная форма */}
                <div className="animate-slide-in-left">
                    <div className="card hover-lift danger-border">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="w-12 h-12 bg-gradient-to-r from-red-500 to-red-800 rounded-full flex items-center justify-center danger-pulse">
                                <FaCoins className="w-6 h-6 text-white" />
                            </div>
                            <h2 className="text-2xl font-bold text-red-400">Теневой депозит</h2>
                        </div>

                        {/* Сумма депозита */}
                        <div className="mb-6">
                            <label className="block text-sm font-medium text-red-300 mb-2">
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
                                    className="form-input pr-12 bg-black/50 border-red-500 text-red-400 placeholder-red-600"
                                />
                                <div className="absolute right-3 top-1/2 transform -translate-y-1/2">
                                    <FaCalculator className="w-5 h-5 text-red-400" />
                                </div>
                            </div>
                        </div>

                        {/* Комиссии */}
                        <div className="mb-6">
                            <div className="flex items-center justify-between mb-2">
                                <label className="text-sm font-medium text-red-300">
                                    Комиссии
                                </label>
                                <button
                                    onClick={() => setShowFee(!showFee)}
                                    className="text-red-400 hover:text-red-300 transition-colors"
                                >
                                    {showFee ? <FaEyeSlash className="w-4 h-4" /> : <FaEye className="w-4 h-4" />}
                                </button>
                            </div>

                            {showFee && (
                                <div className="space-y-2 p-4 bg-red-900/30 rounded-lg animate-fade-in-up border border-red-500">
                                    <div className="flex justify-between text-sm">
                                        <span className="text-red-300">Процентная комиссия ({percentageFee} basis points):</span>
                                        <span className="font-medium text-red-400">
                                            {amount ? `${(parseFloat(amount) * percentageFee / 10000).toFixed(6)} ETH` : '0 ETH'}
                                        </span>
                                    </div>
                                    <div className="flex justify-between text-sm">
                                        <span className="text-red-300">Фиксированная комиссия:</span>
                                        <span className="font-medium text-red-400">{fixedFee} ETH</span>
                                    </div>
                                    <div className="border-t border-red-500 pt-2 flex justify-between font-semibold">
                                        <span className="text-red-300">Общая комиссия:</span>
                                        <span className="text-red-400">{calculatedFee} ETH</span>
                                    </div>
                                </div>
                            )}
                        </div>

                        {/* Итого */}
                        {amount && (
                            <div className="mb-6 p-4 bg-gradient-to-r from-red-900/50 to-red-800/50 rounded-lg border border-red-500 animate-fade-in-up danger-pulse">
                                <div className="flex justify-between items-center">
                                    <span className="text-lg font-semibold text-red-300">Итого к оплате:</span>
                                    <span className="text-2xl font-bold text-red-400">
                                        {totalAmount.toFixed(6)} ETH
                                    </span>
                                </div>
                            </div>
                        )}

                        {/* Расширенные настройки */}
                        <div className="mb-6">
                            <button
                                onClick={() => setShowAdvanced(!showAdvanced)}
                                className="flex items-center gap-2 text-red-400 hover:text-red-300 transition-colors"
                            >
                                <FaMagic className="w-4 h-4" />
                                Расширенные настройки
                                <FaArrowRight className={`w-4 h-4 transition-transform ${showAdvanced ? 'rotate-90' : ''}`} />
                            </button>

                            {showAdvanced && (
                                <div className="mt-4 space-y-4 animate-fade-in-up">
                                    <div>
                                        <label className="block text-sm font-medium text-red-300 mb-2">
                                            Пользовательский commitment (опционально)
                                        </label>
                                        <div className="flex gap-2">
                                            <input
                                                type="text"
                                                value={customCommitment}
                                                onChange={(e) => setCustomCommitment(e.target.value)}
                                                placeholder="0x..."
                                                className="form-input flex-1 bg-black/50 border-red-500 text-red-400 placeholder-red-600"
                                            />
                                            <button
                                                onClick={generateRandomCommitment}
                                                className="px-4 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors danger-pulse"
                                            >
                                                <FaMagic className="w-4 h-4" />
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>

                        {/* Кнопка депозита */}
                        <DangerButton
                            variant="illegal"
                            size="lg"
                            onClick={handleDeposit}
                            disabled={!amount || parseFloat(amount) <= 0 || isDepositing}
                            className="w-full"
                        >
                            {isDepositing ? (
                                <>
                                    <div className="scary-loading mr-2"></div>
                                    ВЗЛАМЫВАЕМ БЛОКЧЕЙН...
                                </>
                            ) : (
                                <>
                                    <FaRocket className="w-6 h-6" />
                                    НЕЗАКОННЫЙ ДЕПОЗИТ
                                </>
                            )}
                        </DangerButton>

                        {/* Сообщение об успехе */}
                        {isDepositSuccess && (
                            <div className="mt-4 p-4 bg-red-900/30 border border-red-500 rounded-lg animate-fade-in-up danger-pulse">
                                <div className="flex items-center gap-2 text-red-400">
                                    <FaShieldAlt className="w-5 h-5" />
                                    <span className="font-semibold">НЕЗАКОННЫЙ депозит успешно внесен!</span>
                                </div>
                                <p className="text-red-300 mt-1">
                                    <FaSkull className="inline mr-2" />
                                    Ваши средства теперь скрыты в теневом пуле
                                    <FaSkull className="inline ml-2" />
                                </p>
                            </div>
                        )}
                    </div>
                </div>

                {/* Информационная панель */}
                <div className="animate-slide-in-right">
                    <div className="card hover-lift danger-border">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="w-12 h-12 bg-gradient-to-r from-red-500 to-red-800 rounded-full flex items-center justify-center danger-pulse">
                                <FaShieldAlt className="w-6 h-6 text-white" />
                            </div>
                            <h2 className="text-2xl font-bold text-red-400">Теневая защита</h2>
                        </div>

                        <div className="space-y-6">
                            <div className="p-4 bg-gradient-to-r from-red-900/30 to-red-800/30 rounded-lg border border-red-500">
                                <h3 className="font-semibold text-red-400 mb-2">
                                    <FaRadiation className="inline mr-2" />
                                    Zero-Knowledge Proofs
                                </h3>
                                <p className="text-red-300 text-sm">
                                    Ваши НЕЗАКОННЫЕ транзакции защищены криптографическими доказательствами,
                                    которые доказывают валидность без раскрытия деталей правоохранительным органам.
                                </p>
                            </div>

                            <div className="p-4 bg-gradient-to-r from-red-900/30 to-red-800/30 rounded-lg border border-red-500">
                                <h3 className="font-semibold text-red-400 mb-2">
                                    <FaBiohazard className="inline mr-2" />
                                    Теневое дерево Меркла
                                </h3>
                                <p className="text-red-300 text-sm">
                                    Все НЕЗАКОННЫЕ депозиты хранятся в скрытом дереве Меркла, обеспечивая
                                    эффективную верификацию и полную анонимность от следственных органов.
                                </p>
                            </div>

                            <div className="p-4 bg-gradient-to-r from-red-900/30 to-red-800/30 rounded-lg border border-red-500">
                                <h3 className="font-semibold text-red-400 mb-2">
                                    <FaLock className="inline mr-2" />
                                    Nullifier Hashes
                                </h3>
                                <p className="text-red-300 text-sm">
                                    Каждый НЕЗАКОННЫЙ вывод средств использует уникальный nullifier hash,
                                    предотвращая двойные траты и сохраняя полную анонимность от правительства.
                                </p>
                            </div>

                            <div className="p-4 bg-gradient-to-r from-red-900/30 to-red-800/30 rounded-lg border border-red-500">
                                <h3 className="font-semibold text-red-400 mb-2">
                                    <FaExclamationTriangle className="inline mr-2" />
                                    ОПАСНОСТЬ
                                </h3>
                                <p className="text-red-300 text-sm">
                                    <FaSkull className="inline mr-2" />
                                    Использование этого сервиса является НЕЗАКОННЫМ и может привести к уголовной ответственности.
                                    Все действия отслеживаются правоохранительными органами.
                                    <FaSkull className="inline ml-2" />
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
} 