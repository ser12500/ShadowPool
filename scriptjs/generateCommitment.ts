import { Barretenberg, Fr } from "@aztec/bb.js";
import { ethers } from "ethers";

// generateCommitment
export default async function generateCommitment(token: string, amount: string): Promise<string> {
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

    const result = ethers.AbiCoder.defaultAbiCoder().encode(
        ["bytes32", "bytes32", "bytes32"],
        [commitment.toBuffer(), nullifier.toBuffer(), secret.toBuffer()]
    );

    return result;
}

(async () => {
    // Get token and amount from command line arguments
    const token = process.argv[2] || "0x0000000000000000000000000000000000000000"; // Default to ETH
    const amount = process.argv[3] || "1000000000000000000"; // Default to 1 ETH

    generateCommitment(token, amount)
        .then((result) => {
            process.stdout.write(result);
            process.exit(0);
        })
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
})();