pragma circom 2.0.0;

include "mimcsponge.circom";

template MerkleTreeChecker(levels)
 { 
signal input leaf;
signal input root;
signal input pathElements[levels];
signal input pathIndices[levels];
signal computedHash[levels + 1];
signal left[levels];
signal right[levels];
signal leftTerm1[levels];
signal leftTerm2[levels];
signal rightTerm1[levels];
signal rightTerm2[levels];
component hashers[levels];

computedHash[0] <== leaf;

for (var i = 0; i < levels; i++) {
    // Ensure pathIndices[i] is binary (0 or 1)
    pathIndices[i] * (pathIndices[i] - 1) === 0;

    // Compute left and right inputs for hashing
    leftTerm1[i] <== computedHash[i] * (1 - pathIndices[i]);
    leftTerm2[i] <== pathElements[i] * pathIndices[i];
    left[i] <== leftTerm1[i] + leftTerm2[i];

    rightTerm1[i] <== pathElements[i] * (1 - pathIndices[i]);
    rightTerm2[i] <== computedHash[i] * pathIndices[i];
    right[i] <== rightTerm1[i] + rightTerm2[i];

    // Hash the left and right inputs
    hashers[i] = MiMCSponge(2, 220, 1);
    hashers[i].ins[0] <== left[i];
    hashers[i].ins[1] <== right[i];
    hashers[i].k <== 0;

    computedHash[i + 1] <== hashers[i].outs[0];
}

// Verify the computed root matches the input root
root === computedHash[levels];
}