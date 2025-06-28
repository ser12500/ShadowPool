"use client";
import { useContractRead, useWriteContract, useWaitForTransactionReceipt, useAccount, useChainId } from "wagmi";
import { parseEther, formatEther } from "viem";
import { useEffect, useState } from "react";

// Импортируем ABI и адреса
import shadowPoolDAOAbi from "../public/ShadowPoolDAO.json";
import { getContractAddresses } from "../lib/contracts";

const SHADOW_POOL_DAO_ABI = shadowPoolDAOAbi.abi;

// Типы для DAO
interface Proposal {
    id: bigint;
    proposer: string;
    targets: string[];
    values: bigint[];
    signatures: string[];
    calldatas: string[];
    startBlock: bigint;
    endBlock: bigint;
    description: string;
    forVotes: bigint;
    againstVotes: bigint;
    executed: boolean;
    canceled: boolean;
}

export function useDAO() {
    const { address } = useAccount();
    const chainId = useChainId();
    const [lastError, setLastError] = useState<string | null>(null);

    // Получаем адреса контрактов для текущей сети
    const contractAddresses = getContractAddresses(chainId);
    const DAO_ADDRESS = contractAddresses.DAO;
    const GOVERNANCE_TOKEN_ADDRESS = contractAddresses.GOVERNANCE_TOKEN;

    // Проверяем, поддерживается ли текущая сеть
    const isSupportedNetwork = chainId === 31337 || chainId === 1 || chainId === 11155111 || chainId === 302;

    // Проверяем, что адреса контрактов не нулевые
    const isContractDeployed = DAO_ADDRESS !== "0x0000000000000000000000000000000000000000" &&
        GOVERNANCE_TOKEN_ADDRESS !== "0x0000000000000000000000000000000000000000";

    // Получение количества токенов пользователя
    const { data: userTokenBalance, error: tokenBalanceError } = useContractRead({
        address: GOVERNANCE_TOKEN_ADDRESS as `0x${string}`,
        abi: [
            {
                "inputs": [{ "internalType": "address", "name": "account", "type": "address" }],
                "name": "balanceOf",
                "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
                "stateMutability": "view",
                "type": "function"
            }
        ],
        functionName: "balanceOf",
        args: [address || "0x0000000000000000000000000000000000000000"],
        query: {
            enabled: isSupportedNetwork && isContractDeployed && !!address,
        },
    });

    // Получение количества активных предложений
    const { data: proposalCount, error: proposalCountError } = useContractRead({
        address: DAO_ADDRESS as `0x${string}`,
        abi: SHADOW_POOL_DAO_ABI,
        functionName: "activeProposalCount",
        query: {
            enabled: isSupportedNetwork && isContractDeployed,
        },
    });

    // Получение порога для создания предложений
    const { data: proposalThreshold, error: proposalThresholdError } = useContractRead({
        address: DAO_ADDRESS as `0x${string}`,
        abi: SHADOW_POOL_DAO_ABI,
        functionName: "proposalThreshold",
        query: {
            enabled: isSupportedNetwork && isContractDeployed,
        },
    });

    // Получение периода голосования
    const { data: votingPeriod, error: votingPeriodError } = useContractRead({
        address: DAO_ADDRESS as `0x${string}`,
        abi: SHADOW_POOL_DAO_ABI,
        functionName: "votingPeriod",
        query: {
            enabled: isSupportedNetwork && isContractDeployed,
        },
    });

    // Получение кворума
    const { data: quorumVotes, error: quorumVotesError } = useContractRead({
        address: DAO_ADDRESS as `0x${string}`,
        abi: SHADOW_POOL_DAO_ABI,
        functionName: "quorumVotes",
        query: {
            enabled: isSupportedNetwork && isContractDeployed,
        },
    });

    // Хук для записи
    const { writeContract, isPending: isWriting, data: transactionHash, error: writeError } = useWriteContract();

    // Ожидание транзакции
    const { isLoading: isWaitingTransaction, isSuccess: isTransactionSuccess, error: transactionError } = useWaitForTransactionReceipt({
        hash: transactionHash,
    });

    // Логирование ошибок
    useEffect(() => {
        if (tokenBalanceError) {
            console.error("Token balance error:", tokenBalanceError);
            setLastError(`Ошибка загрузки баланса токенов: ${tokenBalanceError.message}`);
        }
    }, [tokenBalanceError]);

    useEffect(() => {
        if (proposalCountError) {
            console.error("Proposal count error:", proposalCountError);
            setLastError(`Ошибка загрузки количества предложений: ${proposalCountError.message}`);
        }
    }, [proposalCountError]);

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

    // Функция для создания предложения
    const createProposal = (params: {
        targets: string[];
        values: string[];
        signatures: string[];
        calldatas: string[];
        description: string;
    }) => {
        if (!writeContract || !params.targets || !params.values || !params.signatures || !params.calldatas || !params.description) {
            const error = "Missing required parameters for proposal";
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
            const valuesWei = params.values.map(value => parseEther(value));
            writeContract({
                address: DAO_ADDRESS as `0x${string}`,
                abi: SHADOW_POOL_DAO_ABI,
                functionName: "propose",
                args: [
                    params.targets as `0x${string}`[],
                    valuesWei,
                    params.signatures,
                    params.calldatas,
                    params.description,
                ],
            });
            setLastError(null);
        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : "Unknown error";
            console.error("Error creating proposal:", error);
            setLastError(`Ошибка создания предложения: ${errorMessage}`);
            throw new Error(`Ошибка создания предложения: ${errorMessage}`);
        }
    };

    // Функция для голосования
    const vote = (proposalId: string, support: boolean, reason?: string) => {
        if (!writeContract || !proposalId) {
            const error = "Missing required parameters for vote";
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
            writeContract({
                address: DAO_ADDRESS as `0x${string}`,
                abi: SHADOW_POOL_DAO_ABI,
                functionName: "castVote",
                args: [BigInt(proposalId), support],
            });
            setLastError(null);
        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : "Unknown error";
            console.error("Error voting:", error);
            setLastError(`Ошибка голосования: ${errorMessage}`);
            throw new Error(`Ошибка голосования: ${errorMessage}`);
        }
    };

    // Безопасное форматирование значений
    const formatValue = (value: unknown): string => {
        if (typeof value === 'bigint') {
            return formatEther(value);
        }
        return "0";
    };

    return {
        // Данные
        userTokenBalance: userTokenBalance || BigInt(0),
        proposalCount: proposalCount || BigInt(0),
        proposalThreshold: proposalThreshold || BigInt(0),
        votingPeriod: votingPeriod || BigInt(0),
        quorumVotes: quorumVotes || BigInt(0),

        // Состояние
        isSupportedNetwork,
        isWriting,
        isWaitingTransaction,
        isTransactionSuccess,
        lastError,

        // Функции
        createProposal,
        vote,

        // Форматированные значения
        userTokenBalanceFormatted: formatValue(userTokenBalance),
        proposalThresholdFormatted: formatValue(proposalThreshold),
        quorumVotesFormatted: formatValue(quorumVotes),
    };
}
