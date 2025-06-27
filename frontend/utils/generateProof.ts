import { ethers } from "ethers";
import { merkleTree } from "./merkleTree";

// Динамические импорты для WebAssembly модулей
let Barretenberg: any = null;
let Fr: any = null;
let UltraHonkBackend: any = null;
let Noir: any = null;

// Загружаем схему Noir из public папки
let circuit: any = null;

async function loadCircuit() {
    if (!circuit) {
        try {
            const response = await fetch('/noir.json');
            if (!response.ok) {
                throw new Error('Схема Noir не найдена');
            }
            circuit = await response.json();
        } catch (error) {
            console.error('Ошибка загрузки схемы Noir:', error);
            // Возвращаем заглушку для разработки
            circuit = {
                bytecode: '0x',
                abi: []
            };
        }
    }
    return circuit;
}

async function loadWebAssemblyModules() {
    if (!Barretenberg || !Fr || !UltraHonkBackend || !Noir) {
        try {
            const bbModule = await import('@aztec/bb.js');
            Barretenberg = bbModule.Barretenberg;
            Fr = bbModule.Fr;
            UltraHonkBackend = bbModule.UltraHonkBackend;

            // Динамический импорт Noir
            const noirModule = await import('@noir-lang/noir_js');
            Noir = noirModule.Noir;
        } catch (error) {
            console.error('Ошибка загрузки WebAssembly модулей:', error);
            throw new Error('Не удалось загрузить WebAssembly модули');
        }
    }
}

export default async function generateProof(
    nullifier: string,
    secret: string,
    recipient: string,
    leaves: string[]
): Promise<string> {
    // Загружаем WebAssembly модули
    await loadWebAssemblyModules();

    // Initialize Barretenberg
    const bb = await Barretenberg.new();

    // 1. Get nullifier and secret
    const nullifierFr = Fr.fromString(nullifier);
    const secretFr = Fr.fromString(secret);

    // 2. Create the nullifier hash
    const nullifierHash = await bb.poseidon2Hash([nullifierFr]);

    // 3. Create merkle tree, insert leaves and get merkle proof for commitment
    const tree = await merkleTree(leaves);

    // Create the commitment
    const commitment = await bb.poseidon2Hash([nullifierFr, secretFr]);
    const merkleProof = tree.proof(tree.getIndex(commitment.toString()));

    try {
        const noirCircuit = await loadCircuit();
        const noir = new Noir(noirCircuit);
        const honk = new UltraHonkBackend(noirCircuit.bytecode, { threads: 1 });

        const input = {
            // Public inputs
            root: merkleProof.root,
            nullifier_hash: nullifierHash.toString(),
            recipient: recipient,

            // Private inputs
            nullifier: nullifierFr.toString(),
            secret: secretFr.toString(),
            merkle_proof: merkleProof.pathElements.map((i: any) => i.toString()), // Convert to string
            is_even: merkleProof.pathIndices.map((i: any) => i % 2 == 0), // if the proof indicie is even, set to false as the hash will be odd
        };

        const { witness } = await noir.execute(input);

        const originalLog = console.log; // Save original
        // Override to silence all logs
        console.log = () => { };

        const { proof, publicInputs } = await honk.generateProof(witness, { keccak: true });
        // Restore original console.log
        console.log = originalLog;

        // Используем правильный AbiCoder для ethers v6
        const abiCoder = new ethers.AbiCoder();
        const result = abiCoder.encode(
            ["bytes", "bytes32[]"],
            [proof, publicInputs]
        );
        return result;
    } catch (error) {
        console.log(error);
        throw error;
    }
}

// Функция для декодирования результата proof
export function decodeProofResult(result: string): {
    proof: string;
    publicInputs: string[];
} {
    // Используем правильный AbiCoder для ethers v6
    const abiCoder = new ethers.AbiCoder();
    const decoded = abiCoder.decode(
        ["bytes", "bytes32[]"],
        result
    );

    return {
        proof: decoded[0],
        publicInputs: decoded[1]
    };
} 