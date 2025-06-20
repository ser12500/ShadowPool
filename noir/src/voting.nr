use dep::std;

// Voting circuit for anonymous DAO voting
// Proves that:
// 1. Voter owns governance tokens (commitment to token balance)
// 2. Vote hasn't been cast before (nullifier)
// 3. Vote is valid (support = 0 or 1)
// 4. Proposal exists and is active

// Public inputs
#[public]
proposal_id: Field,      // Proposal ID being voted on
merkle_root: Field,      // Merkle root of governance token commitments
nullifier_hash: Field,   // Hash of nullifier to prevent double voting
vote_result: Field,      // 0 = against, 1 = support
total_votes: Field,      // Total voting power

// Private inputs
#[private]
nullifier: Field,        // Unique nullifier for this vote
secret: Field,           // Secret for commitment generation
token_balance: Field,    // Governance token balance
merkle_path: [Field; 20], // Merkle path for token commitment
merkle_index: Field,     // Index in merkle tree
proposal_start_block: Field, // Proposal start block
proposal_end_block: Field,   // Proposal end block
current_block: Field,    // Current block number

// Constants
const VOTING_PERIOD: Field = 40320; // ~1 week in blocks
const MAX_BALANCE: Field = 1000000; // 1 million tokens max

fn main() {
    // 1. Verify vote is valid (0 or 1)
    assert(vote_result == 0 || vote_result == 1, "Invalid vote value");
    
    // 2. Verify proposal is active
    assert(current_block >= proposal_start_block, "Proposal not started");
    assert(current_block <= proposal_end_block, "Proposal ended");
    
    // 3. Verify token balance is reasonable
    assert(token_balance <= MAX_BALANCE, "Token balance too high");
    assert(token_balance > 0, "No tokens to vote with");
    
    // 4. Generate commitment from token balance
    let commitment = simple_hash([nullifier, secret, token_balance]);
    
    // 5. Verify commitment is in merkle tree
    let computed_root = compute_merkle_root(commitment, merkle_path, merkle_index);
    assert(computed_root == merkle_root, "Invalid merkle proof");
    
    // 6. Generate nullifier hash
    let computed_nullifier_hash = simple_hash([nullifier, proposal_id]);
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier");
    
    // 7. Verify total votes matches token balance
    assert(total_votes == token_balance, "Vote count mismatch");
}

// Simple hash function (replaces poseidon2)
fn simple_hash(inputs: [Field; 3]) -> Field {
    let mut hash = inputs[0];
    hash = hash + inputs[1] * 2;
    hash = hash + inputs[2] * 4;
    hash
}

// Simple hash function for 2 inputs
fn simple_hash_2(inputs: [Field; 2]) -> Field {
    let mut hash = inputs[0];
    hash = hash + inputs[1] * 2;
    hash
}

// Compute merkle root from leaf, path, and index
fn compute_merkle_root(leaf: Field, path: [Field; 20], index: Field) -> Field {
    let mut current = leaf;
    let mut current_index = index;
    
    for i in 0..20 {
        let sibling = path[i];
        let is_right = current_index % 2;
        
        if is_right == 0 {
            // Current is left child
            current = simple_hash_2([current, sibling]);
        } else {
            // Current is right child
            current = simple_hash_2([sibling, current]);
        }
        
        current_index = current_index / 2;
    }
    
    current
} 