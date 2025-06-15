const circomlibjs = require('circomlibjs');
const bigInt = require('big-integer');

async function main() {
    // Initialize circomlibjs MiMCSponge
    const mimcSponge = await circomlibjs.buildMimcSponge();

    // Initialize an empty Merkle Tree with 10 levels (1024 leaves)
    const depth = 10;
    const leaves = new Array(2 ** depth).fill(0); // Zero-filled leaves
    const tree = new Array(depth + 1).fill().map(() => []);

    // Compute commitment (leaf) using MiMCSponge
    const secret = bigInt('123456789');
    const recipient = bigInt('2');
    const commitment = mimcSponge.F.toString(mimcSponge.multiHash([secret, recipient], 0));
    leaves[0] = commitment; // Place commitment as first leaf
    console.log(commitment);

    // Build Merkle Tree
    tree[0] = leaves.map(leaf => bigInt(leaf));
    for (let level = 0; level < depth; level++) {
        for (let i = 0; i < tree[level].length / 2; i++) {
            const left = tree[level][2 * i];
            const right = tree[level][2 * i + 1];
            const parent = mimcSponge.F.toString(mimcSponge.multiHash([left, right], 0));
            tree[level + 1][i] = parent;
        }
    }
    const root = tree[depth][0];

    // Compute Merkle path for leaf at index 0
    let index = 0;
    const pathElements = [];
    const pathIndices = [];
    for (let level = 0; level < depth; level++) {
        const siblingIndex = index ^ 1;
        pathElements.push(tree[level][siblingIndex].toString());
        pathIndices.push((index & 1).toString());
        index >>= 1;
    }

    // Compute nullifierHash
    const nullifier = bigInt('987654321');
    const nullifierHash = mimcSponge.F.toString(mimcSponge.multiHash([nullifier], 0));

    // Output input.json
    const input = {
        root: root.toString(),
        nullifierHash: nullifierHash.toString(),
        recipient: recipient.toString(),
        secret: secret.toString(),
        nullifier: nullifier.toString(),
        pathElements: pathElements,
        pathIndices: pathIndices
    };
    console.log(JSON.stringify(input, null, 2));

}

main().catch(console.error);