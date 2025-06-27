import { ethers } from "ethers";

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

// generateCommitment
export default async function generateCommitment(token: string, amount: string): Promise<string> {
    // Загружаем WebAssembly модули
    await loadWebAssemblyModules();

    // Initialize Barretenberg
    const bb = await Barretenberg.new();

    // 1. generate nullifier
    const nullifier = Fr.random();

    // 2. generate secret
    const secret = Fr.random();

    // 3. create commitment with 4 parameters: nullifier, secret, token, amount
    // Convert token address to uint256 and then to Fr
    // Handle long addresses by truncating to 20 bytes (42 characters including 0x)
    let tokenUint: bigint;
    if (token === "0x0000000000000000000000000000000000000000" ||
        token === "0x0000000000000000000000000000000000000000000000000000000000000000") {
        tokenUint = 0n; // Use 0 for ETH
    } else {
        // If address is longer than 42 characters, truncate it to 20 bytes
        let normalizedToken = token;
        if (token.length > 42) {
            normalizedToken = "0x" + token.slice(-40); // Take last 40 characters after 0x
        }
        tokenUint = BigInt(normalizedToken);
    }

    // Use simple integer values instead of string conversion to avoid Aztec library issues
    const tokenFr = Fr.fromString(tokenUint.toString());
    const amountUint = BigInt(amount);
    const amountFr = Fr.fromString(amountUint.toString());

    const commitment: Fr = await bb.poseidon2Hash([nullifier, secret, tokenFr, amountFr]);

    // Используем правильный AbiCoder для ethers v6
    const abiCoder = new ethers.AbiCoder();
    const result = abiCoder.encode(
        ["bytes32", "bytes32", "bytes32"],
        [commitment.toBuffer(), nullifier.toBuffer(), secret.toBuffer()]
    );

    return result;
}

// Функция для декодирования результата
export function decodeCommitmentResult(result: string): {
    commitment: string;
    nullifier: string;
    secret: string;
} {
    // Используем правильный AbiCoder для ethers v6
    const abiCoder = new ethers.AbiCoder();
    const decoded = abiCoder.decode(
        ["bytes32", "bytes32", "bytes32"],
        result
    );

    return {
        commitment: decoded[0],
        nullifier: decoded[1],
        secret: decoded[2]
    };
} 