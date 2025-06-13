pragma circom 2.0.0;

include "mimcsponge.circom";
include "merkleTree.circom";

template Withdraw(levels)
{
signal input root;
signal input nullifierHash;
signal input recipient;
signal input secret;
signal input nullifier;
signal input pathElements[levels];
signal input pathIndices[levels];

// Compute commitment hash
component hasher = MiMCSponge(2, 220, 1);
hasher.ins[0] <== secret;
hasher.ins[1] <== recipient;
hasher.k <== 0;
signal commitment;
commitment <== hasher.outs[0];

// Verify Merkle Tree inclusion
component tree = MerkleTreeChecker(levels);
tree.leaf <== commitment;
tree.root <== root;
for (var i = 0; i < levels; i++) {
    tree.pathElements[i] <== pathElements[i];
    tree.pathIndices[i] <== pathIndices[i];
}

// Verify nullifier hash
component nullifierHasher = MiMCSponge(1, 220, 1);
nullifierHasher.ins[0] <== nullifier;
nullifierHasher.k <== 0;
nullifierHash === nullifierHasher.outs[0];

// Public outputs
signal output publicRoot;
signal output publicNullifierHash;
signal output publicRecipient;
publicRoot <== root;
publicNullifierHash <== nullifierHash;
publicRecipient <== recipient;
}

component main {public [root, nullifierHash, recipient]} = Withdraw(10);