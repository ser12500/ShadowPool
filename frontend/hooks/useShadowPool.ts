"use client";
import { useContractRead, useWriteContract, useWaitForTransactionReceipt, useAccount, useChainId, useSwitchChain } from "wagmi";
import { parseEther, formatEther } from "viem";
import { useEffect, useState } from "react";

// Импортируем полный ABI из сгенерированного файла
import shadowPoolAbi from "../public/ShadowPool.json";
const SHADOW_POOL_ABI = shadowPoolAbi.abi;

// Импортируем адреса контрактов
import { getContractAddresses } from "../lib/contracts";

// Тип возвращаемых данных getPoolStats
interface PoolStats {
    totalDeposits: bigint;
    currentRoot: string;
    currentPercentageFee: bigint;
    currentFixedFee: bigint;
}

export function useShadowPool() {
    const { address } = useAccount();
    const chainId = useChainId();
    const { switchChain } = useSwitchChain();
    const [lastError, setLastError] = useState<string | null>(null);

    // Получаем адреса контрактов для текущей сети
    const contractAddresses = getContractAddresses(chainId);
    const SHADOW_POOL_ADDRESS = contractAddresses.SHADOW_POOL;

    // Проверяем, поддерживается ли текущая сеть
    const isSupportedNetwork = chainId === 31337 || chainId === 1 || chainId === 11155111 || chainId === 302; // Anvil, Mainnet, Sepolia, zkSync Era Sepolia

    // Проверяем, что адрес контракта не нулевой
    const isContractDeployed = SHADOW_POOL_ADDRESS !== "0x0000000000000000000000000000000000000000";

    // Автоматическое переключение на Anvil, если подключен к неподдерживаемой сети или контракт не развернут
    useEffect(() => {
        if (chainId && (!isSupportedNetwork || !isContractDeployed)) {
            console.log(`Текущая сеть (${chainId}) не поддерживается или контракт не развернут. Переключаемся на Anvil...`);
            try {
                switchChain({ chainId: 31337 });
            } catch (error) {
                console.error("Ошибка переключения сети:", error);
                setLastError("Не удалось переключиться на сеть Anvil. Пожалуйста, сделайте это вручную.");
            }
        }
    }, [chainId, isSupportedNetwork, isContractDeployed, switchChain]);

    // Получение статистики пула (включает комиссии)
    const { data: poolStats, error: poolStatsError } = useContractRead({
        address: SHADOW_POOL_ADDRESS as `0x${string}`,
        abi: SHADOW_POOL_ABI,
        functionName: "getPoolStats",
        query: {
            enabled: isSupportedNetwork && isContractDeployed,
        },
    }) as { data: PoolStats | undefined; error: Error | null };

    // Получение уровня анонимности
    const { data: anonymityLevel, error: anonymityLevelError } = useContractRead({
        address: SHADOW_POOL_ADDRESS as `0x${string}`,
        abi: SHADOW_POOL_ABI,
        functionName: "getAnonymityLevel",
        query: {
            enabled: isSupportedNetwork && isContractDeployed,
        },
    }) as { data: string | undefined; error: Error | null };

    // Получение утилизации пула
    const { data: poolUtilization, error: poolUtilizationError } = useContractRead({
        address: SHADOW_POOL_ADDRESS as `0x${string}`,
        abi: SHADOW_POOL_ABI,
        functionName: "getPoolUtilization",
        query: {
            enabled: isSupportedNetwork && isContractDeployed,
        },
    }) as { data: bigint | undefined; error: Error | null };

    // Единый хук для записи контракта
    const { writeContract, isPending: isWriting, data: transactionHash, error: writeError } = useWriteContract();

    // Ожидание транзакции
    const { isLoading: isWaitingTransaction, isSuccess: isTransactionSuccess, error: transactionError } = useWaitForTransactionReceipt({
        hash: transactionHash,
    });

    // Логирование ошибок для диагностики
    useEffect(() => {
        if (poolStatsError) {
            console.error("Pool stats error:", poolStatsError);
            setLastError(`Ошибка загрузки статистики пула: ${poolStatsError.message}`);
        }
    }, [poolStatsError]);

    useEffect(() => {
        if (anonymityLevelError) {
            console.error("Anonymity level error:", anonymityLevelError);
            setLastError(`Ошибка загрузки уровня анонимности: ${anonymityLevelError.message}`);
        }
    }, [anonymityLevelError]);

    useEffect(() => {
        if (poolUtilizationError) {
            console.error("Pool utilization error:", poolUtilizationError);
            setLastError(`Ошибка загрузки утилизации пула: ${poolUtilizationError.message}`);
        }
    }, [poolUtilizationError]);

    useEffect(() => {
        if (writeError) {
            console.error("Write contract error:", writeError);
            setLastError(`Ошибка записи в контракт: ${writeError.message}`);
        }
    }, [writeError]);

    useEffect(() => {
        if (transactionError) {
            console.error("Transaction error:", transactionError);
            setLastError(`Ошибка транзакции: ${transactionError.message}`);
        }
    }, [transactionError]);

    // Очистка ошибки при успешной транзакции
    useEffect(() => {
        if (isTransactionSuccess) {
            setLastError(null);
        }
    }, [isTransactionSuccess]);

    // Расчёт комиссии для суммы (используя данные из getPoolStats)
    const calculateFeeForAmount = (amount: string) => {
        if (!amount || parseFloat(amount) <= 0) return "0";

        try {
            const amountWei = parseEther(amount);

            if (poolStats) {
                const percentageFeeAmount = (amountWei * poolStats.currentPercentageFee) / BigInt(10000); // basis points
                const totalFee = percentageFeeAmount + poolStats.currentFixedFee;
                return formatEther(totalFee);
            }

            // Fallback если данные не загружены
            const fallbackPercentageFee = (amountWei * BigInt(50)) / BigInt(10000); // 0.5%
            const fallbackFixedFee = parseEther("0.001"); // 0.001 ETH
            const totalFee = fallbackPercentageFee + fallbackFixedFee;

            return formatEther(totalFee);
        } catch (error) {
            console.error("Error calculating fee:", error);
            return "0";
        }
    };

    // Функция для выполнения депозита
    const performDeposit = (amount: string, commitment: string) => {
        if (!writeContract || !amount || !commitment) {
            const error = "Missing required parameters for deposit";
            console.error(error);
            setLastError(error);
            return;
        }

        if (!isSupportedNetwork) {
            const error = "Неподдерживаемая сеть. Пожалуйста, переключитесь на Anvil, Mainnet, Sepolia или zkSync Era Sepolia.";
            console.error(error);
            setLastError(error);
            return;
        }

        if (!isContractDeployed) {
            const error = "Контракт не развернут в текущей сети. Пожалуйста, переключитесь на Anvil.";
            console.error(error);
            setLastError(error);
            return;
        }

        try {
            const amountWei = parseEther(amount);
            writeContract({
                address: SHADOW_POOL_ADDRESS as `0x${string}`,
                abi: SHADOW_POOL_ABI,
                functionName: "deposit",
                args: [commitment as `0x${string}`],
                value: amountWei,
            });
            setLastError(null);
        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : "Unknown error";
            console.error("Error performing deposit:", error);
            setLastError(`Ошибка выполнения депозита: ${errorMessage}`);
        }
    };

    // Новая функция deposit для совместимости с новой страницей
    const deposit = (params: {
        proof: string;
        publicInputs: string[];
        token: string;
        amount: string;
    }) => {
        if (!writeContract || !params.proof || !params.publicInputs || !params.token || !params.amount) {
            const error = "Missing required parameters for deposit";
            console.error(error);
            setLastError(error);
            throw new Error(error);
        }

        if (!isSupportedNetwork) {
            const error = "Неподдерживаемая сеть. Пожалуйста, переключитесь на Anvil, Mainnet, Sepolia или zkSync Era Sepolia.";
            console.error(error);
            setLastError(error);
            throw new Error(error);
        }

        if (!isContractDeployed) {
            const error = "Контракт не развернут в текущей сети. Пожалуйста, переключитесь на Anvil.";
            console.error(error);
            setLastError(error);
            throw new Error(error);
        }

        try {
            const amountWei = parseEther(params.amount);
            writeContract({
                address: SHADOW_POOL_ADDRESS as `0x${string}`,
                abi: SHADOW_POOL_ABI,
                functionName: "deposit",
                args: [params.proof as `0x${string}`, params.publicInputs as `0x${string}`[]],
                value: amountWei,
            });
            setLastError(null);
        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : "Unknown error";
            console.error("Error performing deposit:", error);
            setLastError(`Ошибка выполнения депозита: ${errorMessage}`);
            throw new Error(`Ошибка выполнения депозита: ${errorMessage}`);
        }
    };

    // Функция для выполнения вывода
    const performWithdraw = (
        proof: string,
        root: string,
        nullifierHashes: `0x${string}`[],
        recipient: string,
        amount: string
    ) => {
        if (!writeContract || !proof || !root || !nullifierHashes || !recipient || !amount) {
            const error = "Missing required parameters for withdraw";
            console.error(error);
            setLastError(error);
            return;
        }

        if (!isSupportedNetwork) {
            const error = "Неподдерживаемая сеть. Пожалуйста, переключитесь на Anvil, Mainnet, Sepolia или zkSync Era Sepolia.";
            console.error(error);
            setLastError(error);
            return;
        }

        if (!isContractDeployed) {
            const error = "Контракт не развернут в текущей сети. Пожалуйста, переключитесь на Anvil.";
            console.error(error);
            setLastError(error);
            return;
        }

        try {
            const amountWei = parseEther(amount);
            writeContract({
                address: SHADOW_POOL_ADDRESS as `0x${string}`,
                abi: SHADOW_POOL_ABI,
                functionName: "withdraw",
                args: [
                    proof as `0x${string}`,
                    root as `0x${string}`,
                    nullifierHashes,
                    recipient as `0x${string}`,
                    amountWei,
                ],
            });
            setLastError(null);
        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : "Unknown error";
            console.error("Error performing withdraw:", error);
            setLastError(`Ошибка выполнения вывода: ${errorMessage}`);
        }
    };

    // Функция для генерации proof (заглушка)
    const generateProof = (params: {
        nullifier: string;
        secret: string;
        token: string;
        amount: string;
    }) => {
        console.log("generateProof called with params:", params);
        // Здесь должна быть логика генерации proof
        return Promise.resolve({
            proof: "0x",
            publicInputs: [],
        });
    };

    // Возвращаем данные с дефолтными значениями для неработающих функций
    return {
        // Основные данные
        poolStats,
        totalDeposits: poolStats?.totalDeposits || BigInt(0),
        currentRoot: poolStats?.currentRoot || "0x0000000000000000000000000000000000000000000000000000000000000000",
        currentPercentageFee: poolStats?.currentPercentageFee || BigInt(50), // 0.5%
        currentFixedFee: poolStats?.currentFixedFee || parseEther("0.001"), // 0.001 ETH

        // Данные из контракта
        anonymityLevel: anonymityLevel || "Low anonymity", // Дефолтный уровень анонимности
        poolUtilization: poolUtilization || BigInt(0), // Дефолтная утилизация 0%

        // Состояния
        isLoading: false,
        isWriting,
        isWaitingTransaction,
        isTransactionSuccess,
        lastError,
        isSupportedNetwork,
        isContractDeployed,

        // Функции
        calculateFeeForAmount,
        performDeposit,
        deposit,
        performWithdraw,
        generateProof,
    };
} 