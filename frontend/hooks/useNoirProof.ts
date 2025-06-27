"use client";
import { useState } from "react";
import { useAccount } from 'wagmi';
import generateCommitment, { decodeCommitmentResult } from '../utils/generateCommitment';
import generateProof, { decodeProofResult } from '../utils/generateProof';
import { addLeafToGlobalTree } from '../utils/merkleTree';

// Динамические импорты для WebAssembly модулей
let Barretenberg: any = null;
let Fr: any = null;

async function loadWebAssemblyModules() {
    if (!Barretenberg || !Fr) {
        try {
            const bbModule = await import('@aztec/bb.js');
            Barretenberg = bbModule.Barretenberg;
            Fr = bbModule.Fr;
        } catch (error) {
            console.error('Ошибка загрузки WebAssembly модулей:', error);
            throw new Error('Не удалось загрузить WebAssembly модули');
        }
    }
}

// Типы для входных данных (оставляем для обратной совместимости)
export interface DepositProofInputs {
    nullifiers: string[];
    secrets: string[];
    recipient: string;
    tokenAddresses: string[];
    amounts: string[];
    merkleProofs: string[][];
    isEvenArrays: boolean[][];
}

export interface VotingProofInputs {
    nullifier: string;
    secret: string;
    tokenBalance: string;
    proposalId: string;
    voteResult: string;
    totalVotes: string;
    merklePath: string[];
    isRight: boolean[];
    proposalStartBlock: string;
    proposalEndBlock: string;
    currentBlock: string;
}

export interface ProofData {
    commitment: string;
    nullifier: string;
    secret: string;
    proof: string;
    publicInputs: string[];
    merkleRoot: string;
}

export const useNoirProof = () => {
    const [isGenerating, setIsGenerating] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const { address } = useAccount();

    const generateCommitmentAndProof = async (
        token: string,
        amount: string,
        recipient: string,
        existingLeaves: string[] = []
    ): Promise<ProofData | null> => {
        if (!address) {
            setError('Кошелек не подключен');
            return null;
        }

        setIsGenerating(true);
        setError(null);

        try {
            console.log('Генерация commitment...');

            // 1. Генерируем commitment
            const commitmentResult = await generateCommitment(token, amount);
            const { commitment, nullifier, secret } = decodeCommitmentResult(commitmentResult);

            console.log('Commitment сгенерирован:', commitment);
            console.log('Nullifier:', nullifier);
            console.log('Secret:', secret);

            // 2. Добавляем commitment в Merkle дерево
            console.log('Добавление в Merkle дерево...');
            const tree = await addLeafToGlobalTree(commitment);
            const merkleRoot = tree.root();

            console.log('Merkle root:', merkleRoot);

            // 3. Получаем все листья для proof
            const allLeaves = [...existingLeaves, commitment];
            console.log('Все листья для proof:', allLeaves);

            // 4. Генерируем proof
            console.log('Генерация proof...');
            const proofResult = await generateProof(nullifier, secret, recipient, allLeaves);
            const { proof, publicInputs } = decodeProofResult(proofResult);

            console.log('Proof сгенерирован успешно');

            const proofData: ProofData = {
                commitment,
                nullifier,
                secret,
                proof,
                publicInputs,
                merkleRoot
            };

            return proofData;
        } catch (err) {
            console.error('Ошибка генерации proof:', err);
            setError(err instanceof Error ? err.message : 'Неизвестная ошибка');
            return null;
        } finally {
            setIsGenerating(false);
        }
    };

    const generateVoteProof = async (
        nullifier: string,
        secret: string,
        recipient: string,
        existingLeaves: string[]
    ): Promise<ProofData | null> => {
        if (!address) {
            setError('Кошелек не подключен');
            return null;
        }

        setIsGenerating(true);
        setError(null);

        try {
            console.log('Генерация proof для голосования...');

            // Загружаем WebAssembly модули
            await loadWebAssemblyModules();

            // Создаем commitment из nullifier и secret
            const bb = await Barretenberg.new();
            const nullifierFr = Fr.fromString(nullifier);
            const secretFr = Fr.fromString(secret);
            const commitment = await bb.poseidon2Hash([nullifierFr, secretFr]);

            console.log('Commitment для голосования:', commitment.toString());

            // Генерируем proof
            const proofResult = await generateProof(nullifier, secret, recipient, existingLeaves);
            const { proof, publicInputs } = decodeProofResult(proofResult);

            console.log('Proof для голосования сгенерирован успешно');

            const proofData: ProofData = {
                commitment: commitment.toString(),
                nullifier,
                secret,
                proof,
                publicInputs,
                merkleRoot: '' // Будет получен из proof
            };

            return proofData;
        } catch (err) {
            console.error('Ошибка генерации proof для голосования:', err);
            setError(err instanceof Error ? err.message : 'Неизвестная ошибка');
            return null;
        } finally {
            setIsGenerating(false);
        }
    };

    return {
        generateCommitmentAndProof,
        generateVoteProof,
        isGenerating,
        error,
        clearError: () => setError(null)
    };
}; 