const bigInt = require("big-integer");
const circomlibjs = require("circomlibjs");

async function main() {
    const mimc7 = await circomlibjs.buildMimc7();

    const FIELD_PRIME = bigInt("21888242871839275222246405745257275088548364400416034343698204186575808495617");

    // Хешируем два значения MiMC7, возвращаем bigInt
    function mimcHash(left, right) {
        const hashBytes = mimc7.hash(left.toString(), right.toString());
        const hex = Buffer.from(hashBytes).toString("hex");
        return bigInt(hex, 16).mod(FIELD_PRIME);
    }

    // Строим Merkle дерево из массива листьев (bigInt)
    function buildMerkleTree(leaves) {
        let tree = [leaves];
        while (tree[tree.length - 1].length > 1) {
            const currentLevel = tree[tree.length - 1];
            const nextLevel = [];
            for (let i = 0; i < currentLevel.length; i += 2) {
                const left = currentLevel[i];
                const right = (i + 1 < currentLevel.length) ? currentLevel[i + 1] : currentLevel[i];
                const parent = mimcHash(left, right);
                nextLevel.push(parent);
            }
            tree.push(nextLevel);
        }
        return tree;
    }

    // Получаем pathElements и pathIndices для листа leafIndex
    function getMerklePath(tree, leafIndex) {
        const pathElements = [];
        const pathIndices = [];
        let index = leafIndex;

        for (let level = 0; level < tree.length - 1; level++) {
            const levelNodes = tree[level];
            let siblingIndex = index % 2 === 0 ? index + 1 : index - 1;
            if (siblingIndex >= levelNodes.length) siblingIndex = index; // дубль если нет соседа
            pathElements.push(levelNodes[siblingIndex]);
            pathIndices.push(index % 2);
            index = Math.floor(index / 2);
        }
        return { pathElements, pathIndices };
    }

    const depth = 10;
    const leafCount = 2 ** depth;

    // Генерируем фиктивные данные: секреты, получатели, нулификаторы
    const secrets = [];
    const recipients = [];
    const nullifiers = [];

    for (let i = 0; i < leafCount; i++) {
        secrets.push(bigInt(i + 1));
        recipients.push(bigInt((i + 1) * 2));
        nullifiers.push(bigInt((i + 1) * 3));
    }

    // commitments = mimcHash(secret, recipient)
    const commitments = secrets.map((s, i) => mimcHash(s, recipients[i]));

    // Строим дерево
    const tree = buildMerkleTree(commitments);

    // Выбираем лист для proof
    const leafIndex = 5;

    // Формируем путь для листа
    const { pathElements, pathIndices } = getMerklePath(tree, leafIndex);

    // Корень дерева
    const root = tree[tree.length - 1][0];

    // nullifierHash = mimcHash(nullifier, 0)
    const nullifierHashBytes = mimc7.hash(nullifiers[leafIndex].toString(), "0");
    const nullifierHash = bigInt(Buffer.from(nullifierHashBytes).toString("hex"), 16).mod(FIELD_PRIME);

    // Формируем input
    const input = {
        root: root.toString(),
        nullifierHash: nullifierHash.toString(),
        recipient: recipients[leafIndex].toString(),
        secret: secrets[leafIndex].toString(),
        nullifier: nullifiers[leafIndex].toString(),
        pathElements: pathElements.map(e => e.toString()),
        pathIndices: pathIndices,
    };

    console.log(JSON.stringify(input, null, 2));
}

main();
