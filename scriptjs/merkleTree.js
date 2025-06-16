import { Barretenberg, Fr } from '@aztec/bb.js';

async function hashLeftRight(left, right) {
    const bb = await Barretenberg.new();
    const frLeft = Fr.fromString(left);
    const frRight = Fr.fromString(right);
    const hash = await bb.poseidon2Hash([frLeft, frRight]);
    return hash.toString();
}

export class PoseidonTree {
    constructor(levels, zeros) {
        if (zeros.length < levels + 1) {
            throw new Error("Not enough zero values provided for the given tree height.");
        }
        this.levels = levels;
        this.hashLeftRight = hashLeftRight;
        this.storage = new Map();
        this.zeros = zeros;
        this.totalLeaves = 0;
    }

    async init(defaultLeaves = []) {
        if (defaultLeaves.length > 0) {
            this.totalLeaves = defaultLeaves.length;

            defaultLeaves.forEach((leaf, index) => {
                this.storage.set(PoseidonTree.indexToKey(0, index), leaf);
            });

            for (let level = 1; level <= this.levels; level++) {
                const numNodes = Math.ceil(this.totalLeaves / (2 ** level));
                for (let i = 0; i < numNodes; i++) {
                    const left = this.storage.get(PoseidonTree.indexToKey(level - 1, 2 * i)) || this.zeros[level - 1];
                    const right = this.storage.get(PoseidonTree.indexToKey(level - 1, 2 * i + 1)) || this.zeros[level - 1];
                    const node = await this.hashLeftRight(left, right);
                    this.storage.set(PoseidonTree.indexToKey(level, i), node);
                }
            }
        }
    }

    static indexToKey(level, index) {
        return `${level}-${index}`;
    }

    getIndex(leaf) {
        for (const [key, value] of this.storage.entries()) {
            if (value === leaf && key.startsWith('0-')) {
                return parseInt(key.split('-')[1]);
            }
        }
        return -1;
    }

    root() {
        return this.storage.get(PoseidonTree.indexToKey(this.levels, 0)) || this.zeros[this.levels];
    }

    proof(index) {
        const leaf = this.storage.get(PoseidonTree.indexToKey(0, index));
        if (!leaf) throw new Error("leaf not found");

        const pathElements = [];
        const pathIndices = [];

        this.traverse(index, (level, currentIndex, siblingIndex) => {
            const sibling = this.storage.get(PoseidonTree.indexToKey(level, siblingIndex)) || this.zeros[level];
            pathElements.push(sibling);
            pathIndices.push(currentIndex % 2);
        });

        return {
            root: this.root(),
            pathElements,
            pathIndices,
            leaf,
        };
    }

    async insert(leaf) {
        const index = this.totalLeaves;
        await this.update(index, leaf, true);
        this.totalLeaves++;
    }

    async update(index, newLeaf, isInsert = false) {
        if (!isInsert && index >= this.totalLeaves) {
            throw Error("Use insert method for new elements.");
        } else if (isInsert && index < this.totalLeaves) {
            throw Error("Use update method for existing elements.");
        }

        const keyValueToStore = [];
        let currentElement = newLeaf;

        await this.traverseAsync(index, async (level, currentIndex, siblingIndex) => {
            const sibling = this.storage.get(PoseidonTree.indexToKey(level, siblingIndex)) || this.zeros[level];
            const [left, right] = currentIndex % 2 === 0 ? [currentElement, sibling] : [sibling, currentElement];
            keyValueToStore.push({ key: PoseidonTree.indexToKey(level, currentIndex), value: currentElement });
            currentElement = await this.hashLeftRight(left, right);
        });

        keyValueToStore.push({ key: PoseidonTree.indexToKey(this.levels, 0), value: currentElement });
        keyValueToStore.forEach(({ key, value }) => this.storage.set(key, value));
    }

    traverse(index, fn) {
        let currentIndex = index;
        for (let level = 0; level < this.levels; level++) {
            const siblingIndex = currentIndex % 2 === 0 ? currentIndex + 1 : currentIndex - 1;
            fn(level, currentIndex, siblingIndex);
            currentIndex = Math.floor(currentIndex / 2);
        }
    }

    async traverseAsync(index, fn) {
        let currentIndex = index;
        for (let level = 0; level < this.levels; level++) {
            const siblingIndex = currentIndex % 2 === 0 ? currentIndex + 1 : currentIndex - 1;
            await fn(level, currentIndex, siblingIndex);
            currentIndex = Math.floor(currentIndex / 2);
        }
    }
}

const ZERO_VALUES = [
    "0x034f996155f0d9b1a838977011b06a385e8701d10aae926876c9c8a6fa69bf18",
    "0x2a06a72b1f2b24364e5e4120849b4692bbf91c4bcad66845a399e67022e9f0d9",
    "0x059c8070788f7308bbda9246ef2d321ad1bf81cda0edfe01399652ff34c53da4",
    "0x27d1ecbd5115efbbda09f8d68eaeabd0a9f28debb8f211c85234ac5bb3f332c2",
    "0x1b4fbca11bb4821fc5f3264debc386ff9b7081458ca4725ba5386b1774f665e4",
    "0x189af983b17956b1997302f93059af4d2414a2d19deea6743e8484e3e9213b9d",
    "0x2d61566878b72076d8ccf4bb2211272cd24b352b27285088383c85b4ea19180c",
    "0x16c3503aebf8d918c9771d683e335b2a62547fb8e86e5d0d6cb898c14fb5d396",
    "0x1a5de8d583ecaaa9e3d684145c0410976a66ce979f7e92cd5c0fdbaa2ac1af5a",
    "0x28e3f0b5fd188614cf8c2825ba0263ed70153e1a453f0662baedaeab12a66ef8",
    "0x16b671eb844a8e4e463e820e26560357edee4ecfdbf5d7b0a28799911505088d",
    "0x115ea0c2f132c5914d5bb737af6eed04115a3896f0d65e12e761ca560083da15",
    "0x139a5b42099806c76efb52da0ec1dde06a836bf6f87ef7ab4bac7d00637e28f0",
    "0x0804853482335a6533eb6a4ddfc215a08026db413d247a7695e807e38debea8e",
    "0x2f0b264ab5f5630b591af93d93ec2dfed28eef017b251e40905cdf7983689803",
    "0x170fc161bf1b9610bf196c173bdae82c4adfd93888dc317f5010822a3ba9ebee",
    "0x0b2e7665b17622cc0243b6fa35110aa7dd0ee3cc9409650172aa786ca5971439",
    "0x12d5a033cbeff854c5ba0c5628ac4628104be6ab370699a1b2b4209e518b0ac5",
    "0x1bc59846eb7eafafc85ba9a99a89562763735322e4255b7c1788a8fe8b90bf5d",
    "0x1b9421fbd79f6972a348a3dd4721781ec25a5d8d27342942ae00aba80a3904d4",
    "0x087fde1c4c9c27c347f347083139eee8759179d255ec8381c02298d3d6ccd233"
];

export async function merkleTree(leaves) {
    const TREE_HEIGHT = 20;
    const tree = new PoseidonTree(TREE_HEIGHT, ZERO_VALUES);

    // Initialize tree with no leaves (all zeros)
    await tree.init();

    // Insert some leaves (from input)
    for (const leaf of leaves) {
        await tree.insert(leaf);
    }

    return tree;
}









