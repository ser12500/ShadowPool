use std::hash::poseidon2;
mod merkle_tree;

/// Multi-currency anonymous deposit circuit
/// Supports multiple deposits of different tokens (ETH and ERC20) in a single transaction
/// Each deposit has its own commitment, nullifier, and secret
fn main(
    // Public inputs
    root: pub Field,
    nullifier_hashes: pub [Field; 3], // Array of nullifier hashes for each deposit
    recipient: pub Field,
    token_addresses: pub [Field; 3], // Array of token addresses (0 for ETH, ERC20 address for tokens)
    amounts: pub [Field; 3], // Array of amounts for each deposit
    // Private inputs
    nullifiers: [Field; 3], // Array of nullifiers for each deposit
    secrets: [Field; 3], // Array of secrets for each deposit
    merkle_proofs: [[Field; 20]; 3], // Array of merkle proofs for each commitment
    is_even_arrays: [[bool; 20]; 3], // Array of even flags for each merkle proof
) {
    // Process each deposit
    for i in 0..3 {
        // Compute commitment for this deposit: Poseidon2(nullifier, secret, token_address, amount)
        let commitment: Field = poseidon2::Poseidon2::hash(
            [nullifiers[i], secrets[i], token_addresses[i], amounts[i]],
            4,
        );

        // Check that the nullifier matches the nullifier hash
        let computed_nullifier_hash: Field = poseidon2::Poseidon2::hash([nullifiers[i]], 1);
        assert(computed_nullifier_hash == nullifier_hashes[i]);

        // Check that the commitment is in the Merkle tree
        let computed_root: Field =
            merkle_tree::compute_merkle_root(commitment, merkle_proofs[i], is_even_arrays[i]);
        assert(computed_root == root);
    }
}
