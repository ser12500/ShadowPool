"use client";
import { useContractRead, useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { parseEther, formatEther } from "viem";
import { useEffect } from "react";

// Полный ABI контракта ShadowPool
const SHADOW_POOL_ABI = [
    {
        "type": "constructor",
        "inputs": [
            { "name": "_verifier", "type": "address", "internalType": "contract IVerifier" },
            { "name": "_hasher", "type": "address", "internalType": "contract Poseidon2" },
            { "name": "_merkleTreeDepth", "type": "uint32", "internalType": "uint32" },
            { "name": "_daoAddress", "type": "address", "internalType": "address" },
            { "name": "_percentageFee", "type": "uint256", "internalType": "uint256" },
            { "name": "_fixedFee", "type": "uint256", "internalType": "uint256" }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "getPoolStats",
        "inputs": [],
        "outputs": [
            { "name": "totalDeposits", "type": "uint256", "internalType": "uint256" },
            { "name": "currentRoot", "type": "bytes32", "internalType": "bytes32" },
            { "name": "currentPercentageFee", "type": "uint256", "internalType": "uint256" },
            { "name": "currentFixedFee", "type": "uint256", "internalType": "uint256" }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getAnonymityLevel",
        "inputs": [],
        "outputs": [{ "name": "", "type": "string", "internalType": "string" }],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "calculateFee",
        "inputs": [{ "name": "_amount", "type": "uint256", "internalType": "uint256" }],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getFeeBreakdown",
        "inputs": [{ "name": "_amount", "type": "uint256", "internalType": "uint256" }],
        "outputs": [
            { "name": "percentageFeeAmount", "type": "uint256", "internalType": "uint256" },
            { "name": "fixedFeeAmount", "type": "uint256", "internalType": "uint256" },
            { "name": "totalFee", "type": "uint256", "internalType": "uint256" }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "deposit",
        "inputs": [{ "name": "_commitment", "type": "bytes32", "internalType": "bytes32" }],
        "outputs": [],
        "stateMutability": "payable"
    },
    {
        "type": "function",
        "name": "multiDeposit",
        "inputs": [{ "name": "_deposits", "type": "tuple[]", "internalType": "struct ShadowPool.Deposit[]", "components": [{ "name": "token", "type": "address", "internalType": "address" }, { "name": "amount", "type": "uint256", "internalType": "uint256" }, { "name": "commitment", "type": "bytes32", "internalType": "bytes32" }] }],
        "outputs": [],
        "stateMutability": "payable"
    },
    {
        "type": "function",
        "name": "withdraw",
        "inputs": [
            { "name": "_proof", "type": "bytes", "internalType": "bytes" },
            { "name": "_root", "type": "bytes32", "internalType": "bytes32" },
            { "name": "_nullifierHashes", "type": "bytes32[]", "internalType": "bytes32[]" },
            { "name": "_recipient", "type": "address", "internalType": "address payable" },
            { "name": "_tokens", "type": "address[]", "internalType": "address[]" },
            { "name": "_amounts", "type": "uint256[]", "internalType": "uint256[]" }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "getPoolUtilization",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getOptimalWithdrawTime",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getMaxPoolSize",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isPoolFull",
        "inputs": [],
        "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "percentageFee",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "fixedFee",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
    }
] as const;

// Реальный адрес контракта ShadowPool
const SHADOW_POOL_ADDRESS = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9" as `0x${string}`;

export function useShadowPool() {
    const { address } = useAccount();

    // Получение статистики пула
    const { data: poolStats, isLoading: isLoadingStats, error: poolStatsError } = useContractRead({
        address: SHADOW_POOL_ADDRESS,
        abi: SHADOW_POOL_ABI,
        functionName: "getPoolStats",
    });

    // Получение уровня анонимности
    const { data: anonymityLevel, isLoading: isLoadingAnonymity, error: anonymityError } = useContractRead({
        address: SHADOW_POOL_ADDRESS,
        abi: SHADOW_POOL_ABI,
        functionName: "getAnonymityLevel",
    });

    // Получение утилизации пула
    const { data: poolUtilization, isLoading: isLoadingUtilization, error: utilizationError } = useContractRead({
        address: SHADOW_POOL_ADDRESS,
        abi: SHADOW_POOL_ABI,
        functionName: "getPoolUtilization",
    });

    // Получение комиссий
    const { data: percentageFee, isLoading: isLoadingPercentageFee, error: percentageFeeError } = useContractRead({
        address: SHADOW_POOL_ADDRESS,
        abi: SHADOW_POOL_ABI,
        functionName: "percentageFee",
    });

    const { data: fixedFee, isLoading: isLoadingFixedFee, error: fixedFeeError } = useContractRead({
        address: SHADOW_POOL_ADDRESS,
        abi: SHADOW_POOL_ABI,
        functionName: "fixedFee",
    });

    // Единый хук для записи контракта
    const { writeContract, isPending: isWriting, data: transactionHash, error: writeError } = useWriteContract();

    // Ожидание транзакции
    const { isLoading: isWaitingTransaction, isSuccess: isTransactionSuccess, error: transactionError } = useWaitForTransactionReceipt({
        hash: transactionHash,
    });

    // Логирование ошибок для диагностики (только при изменении ошибок)
    useEffect(() => {
        if (poolStatsError) console.error("Pool stats error:", poolStatsError);
    }, [poolStatsError]);

    useEffect(() => {
        if (anonymityError) console.error("Anonymity level error:", anonymityError);
    }, [anonymityError]);

    useEffect(() => {
        if (utilizationError) console.error("Pool utilization error:", utilizationError);
    }, [utilizationError]);

    useEffect(() => {
        if (percentageFeeError) console.error("Percentage fee error:", percentageFeeError);
    }, [percentageFeeError]);

    useEffect(() => {
        if (fixedFeeError) console.error("Fixed fee error:", fixedFeeError);
    }, [fixedFeeError]);

    useEffect(() => {
        if (writeError) console.error("Write contract error:", writeError);
    }, [writeError]);

    useEffect(() => {
        if (transactionError) console.error("Transaction error:", transactionError);
    }, [transactionError]);

    // Расчёт комиссии для суммы (используя реальные данные из контракта)
    const calculateFeeForAmount = (amount: string) => {
        if (!amount || parseFloat(amount) <= 0) return "0";

        const amountWei = parseEther(amount);

        if (percentageFee && fixedFee) {
            const percentageFeeAmount = (amountWei * BigInt(percentageFee)) / BigInt(10000); // basis points
            const fixedFeeWei = typeof fixedFee === 'bigint' ? fixedFee : parseEther(fixedFee as string);
            const totalFee = percentageFeeAmount + fixedFeeWei;
            return formatEther(totalFee);
        }

        // Fallback если данные не загружены
        const fallbackPercentageFee = (amountWei * BigInt(50)) / BigInt(10000); // 0.5%
        const fallbackFixedFee = parseEther("0.001"); // 0.001 ETH
        const totalFee = fallbackPercentageFee + fallbackFixedFee;

        return formatEther(totalFee);
    };

    // Функция для выполнения депозита
    const performDeposit = (amount: string, commitment: string) => {
        if (!writeContract || !amount || !commitment) {
            console.error("Missing required parameters for deposit");
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
        } catch (error) {
            console.error("Error performing deposit:", error);
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
            console.error("Missing required parameters for deposit");
            throw new Error("Missing required parameters for deposit");
        }

        try {
            const amountWei = parseEther(params.amount);

            // Для простоты используем первый public input как commitment
            const commitment = params.publicInputs[0] || "0x0000000000000000000000000000000000000000000000000000000000000000";

            writeContract({
                address: SHADOW_POOL_ADDRESS as `0x${string}`,
                abi: SHADOW_POOL_ABI,
                functionName: "deposit",
                args: [commitment as `0x${string}`],
                value: amountWei,
            });
        } catch (error) {
            console.error("Error performing deposit:", error);
            throw error;
        }
    };

    // Функция для выполнения вывода средств
    const performWithdraw = (
        proof: string,
        root: string,
        nullifierHashes: `0x${string}`[],
        recipient: string,
        amount: string
    ) => {
        if (!writeContract || !proof || !root || !nullifierHashes || !recipient || !amount) {
            console.error("Missing required parameters for withdraw");
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
                    [], // tokens array (empty for ETH)
                    [amountWei], // amounts array
                ],
            });
        } catch (error) {
            console.error("Error performing withdraw:", error);
        }
    };

    return {
        // Данные
        poolStats: poolStats ? {
            totalDeposits: typeof poolStats[0] === 'bigint' ? poolStats[0] : BigInt(poolStats[0]),
            currentRoot: poolStats[1] as `0x${string}`,
            currentPercentageFee: Number(poolStats[2]),
            currentFixedFee: formatEther(poolStats[3]),
        } : null,
        anonymityLevel: anonymityLevel as string,
        poolUtilization: poolUtilization ? Number(poolUtilization) / 100 : 0,
        percentageFee: percentageFee ? Number(percentageFee) : 50, // basis points
        fixedFee: fixedFee ? (typeof fixedFee === 'bigint' ? formatEther(fixedFee) : fixedFee as string) : "0.001",

        // Состояния загрузки
        isLoadingStats,
        isLoadingAnonymity,
        isLoadingUtilization,
        isLoadingPercentageFee,
        isLoadingFixedFee,
        isDepositing: isWriting,
        isWaitingDeposit: isWaitingTransaction,
        isDepositSuccess: isTransactionSuccess,
        isWithdrawing: isWriting,
        isWaitingWithdraw: isWaitingTransaction,
        isWithdrawSuccess: isTransactionSuccess,

        // Ошибки
        poolStatsError,
        anonymityError,
        utilizationError,
        percentageFeeError,
        fixedFeeError,
        writeError,
        transactionError,

        // Функции
        calculateFeeForAmount,
        performDeposit,
        performWithdraw,
        deposit,

        // Адрес контракта
        contractAddress: SHADOW_POOL_ADDRESS,
    };
} 