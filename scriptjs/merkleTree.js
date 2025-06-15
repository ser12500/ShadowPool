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
    "0x95df45ff7dced88619ca1eaf11fcbdb025c5251896fd8494a3c0ab913dfd493d",
    "0x24a78fffe3de1bcfb9bebef9440c8eb8f6b7963f7aa0af2946976b4c960e1339",
    "0x109765c20fbbdb6885d1841c46b09d4233292ef98bd12b7fcccd15f15bf1980f",
    "0x1ddae69c181f5e303cf7c7bac00f36a1aa3f3efe31dbcf139259d56e591858df",
    "0x1d14a7fa15ef92e7795fc3f306d989f475e1ff9f5ecbc9b13d729ffc6fd90959",
    "0x190bf7090129e28155e8dc0b80b3cdac9aebd595e999522a13ee61f407ef41b5",
    "0x2a1b41a7fe160518b2bc2bed35d85bd7d4513a739617e7131fe958feb4b7030b",
    "0x168fe1e0c7c9f07c7c37b180a6c42e9608c6bd1fe7f80dd1bc61c249743aece6",
    "0x03d0dc8c92e2844abcc5fdefe8cb67d93034de0862943990b09c6b8e3fa27a86",
    "0x1d51ac275f47f10e592b8e690fd3b28a76106893ac3e60cd7b2a3a443f4e8355",
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









