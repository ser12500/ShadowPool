// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Field} from "lib/poseidon2-evm/src/Field.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";

contract Incremental {
    uint256 public constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // the "zero" element is the default value for the Merkle tree, it is used to fill in empty nodes keccak256("cyfrin") % FIELD_SIZE
    bytes32 public constant ZERO_ELEMENT = bytes32(0x95df45ff7dced88619ca1eaf11fcbdb025c5251896fd8494a3c0ab913dfd493d);
    Poseidon2 public immutable i_hasher; // instance of the contract which has the Poseidon hash logic

    uint32 public immutable i_depth; // the depth of the Merkle tree, i.e. the number of levels in the tree

    // the following variables are made public for easier testing and debugging and
    // are not supposed to be accessed in regular code

    // s_cachedSubtrees and roots could be bytes32[size], but using mappings makes it cheaper because
    // it removes index range check on every interaction
    mapping(uint256 => bytes32) public s_cachedSubtrees; // subtrees for already stored commitments
    mapping(uint256 => bytes32) public s_roots; // ROOT_HISTORY_SIZE roots for the Merkle tree
    uint32 public constant ROOT_HISTORY_SIZE = 30; // the number of roots stored to compare proofs against
    uint32 public s_currentRootIndex = 0; // where in ROOT_HISTORY_SIZE the current root is stored in the roots array
    uint32 public s_nextLeafIndex = 0; // the index of the next leaf index to be inserted into the tree

    error IncrementalMerkleTree__LeftValueOutOfRange(bytes32 left);
    error IncrementalMerkleTree__RightValueOutOfRange(bytes32 right);
    error IncrementalMerkleTree__LevelsShouldBeGreaterThanZero(uint32 depth);
    error IncrementalMerkleTree__LevelsShouldBeLessThan32(uint32 depth);
    error IncrementalMerkleTree__MerkleTreeFull(uint32 nextIndex);
    error IncrementalMerkleTree__IndexOutOfBounds(uint256 index);

    constructor(uint32 _depth, Poseidon2 _hasher) {
        if (_depth == 0) {
            revert IncrementalMerkleTree__LevelsShouldBeGreaterThanZero(_depth);
        }
        if (_depth >= 32) {
            revert IncrementalMerkleTree__LevelsShouldBeLessThan32(_depth);
        }
        i_depth = _depth;
        i_hasher = _hasher;

        s_roots[0] = zeros(_depth);
    }

    /**
     * @dev Hash 2 tree leaves, returns Poseidon(_left, _right)
     */
    function hashLeftRight(bytes32 _left, bytes32 _right) public view returns (bytes32) {
        // these checks aren't needed since the hash function will return a valid value
        if (uint256(_left) >= FIELD_SIZE) {
            revert IncrementalMerkleTree__LeftValueOutOfRange(_left);
        }
        if (uint256(_right) >= FIELD_SIZE) {
            revert IncrementalMerkleTree__RightValueOutOfRange(_right);
        }

        return Field.toBytes32(i_hasher.hash_2(Field.toField(_left), Field.toField(_right)));
    }

    function _insert(bytes32 _leaf) internal returns (uint32 index) {
        uint32 _nextLeafIndex = s_nextLeafIndex;
        if (_nextLeafIndex == uint32(2) ** i_depth) {
            revert IncrementalMerkleTree__MerkleTreeFull(_nextLeafIndex);
        }
        uint32 currentIndex = _nextLeafIndex; // the index of the current node starting with the leaf and working up
        bytes32 currentHash = _leaf; // the actual value of the current node starting with the leaf and working up
        bytes32 left; // the node that needs to be on the left side of the hash
        bytes32 right; // the node that needs to be on the right side of the hash

        for (uint32 i = 0; i < i_depth; i++) {
            // check if the index is even
            if (currentIndex % 2 == 0) {
                // if even, the current node is the left child and the right child is a zero subtree of depth = the current depth we are at i
                left = currentHash;
                right = zeros(i);
                // cache the calculated hash as a sebtree root
                s_cachedSubtrees[i] = currentHash;
            } else {
                // if odd, the current node is the right child and the left child is a cached subtree of depth = the current depth we are at i
                left = s_cachedSubtrees[i];
                right = currentHash;
            }
            // calculate the hash of the left and right nodes
            currentHash = hashLeftRight(left, right);
            // go up a level by halving the index (this is easier to see if you visualize the tree)
            currentIndex /= 2;
        }

        // at this point we have calculated the root of the tree, so we can store it in the roots array
        // calculate the next index in the array
        uint32 newRootIndex = (s_currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        // store the index of the new root we are adding
        s_currentRootIndex = newRootIndex;
        // store the new root in the roots array
        s_roots[newRootIndex] = currentHash;
        // store the index of the next leaf to be inserted ready for the next deposit
        s_nextLeafIndex = _nextLeafIndex + 1;
        // return the index of the leaf we just inserted to be passed to the deposit event
        return _nextLeafIndex;
    }

    /**
     * @dev Whether the root is present in the root history
     */
    function isKnownRoot(bytes32 _root) public view returns (bool) {
        // check if they are trying to bypass the check by passing a zero root which is the defualt value
        if (_root == bytes32(0)) {
            return false;
        }
        uint32 _currentRootIndex = s_currentRootIndex; // cash the result so we don't have to read it multiple times
        uint32 i = _currentRootIndex; // show the diagram:)
        do {
            if (_root == s_roots[i]) {
                return true; // the root is present in the history
            }
            if (i == 0) {
                i = ROOT_HISTORY_SIZE; // we have got to the end of the array and need to wrap around
            }
            i--;
        } while (i != _currentRootIndex); // once we get back to the current root index, we are done
        return false; // the root is not present in the history
    }

    /**
     * @dev Returns the latest root
     */
    function getLatestRoot() public view returns (bytes32) {
        return s_roots[s_currentRootIndex];
    }

    // NOTE: change when you know the hash function to use
    /// @notice Returns the root of a subtree at the given depth
    /// @param i The depth of the subtree root to return
    /// @return The root of the given subtree
    function zeros(uint256 i) public pure returns (bytes32) {
        if (i == 0) return bytes32(0x95df45ff7dced88619ca1eaf11fcbdb025c5251896fd8494a3c0ab913dfd493d);
        else if (i == 1) return bytes32(0x24a78fffe3de1bcfb9bebef9440c8eb8f6b7963f7aa0af2946976b4c960e1339);
        else if (i == 2) return bytes32(0x109765c20fbbdb6885d1841c46b09d4233292ef98bd12b7fcccd15f15bf1980f);
        else if (i == 3) return bytes32(0x1ddae69c181f5e303cf7c7bac00f36a1aa3f3efe31dbcf139259d56e591858df);
        else if (i == 4) return bytes32(0x1d14a7fa15ef92e7795fc3f306d989f475e1ff9f5ecbc9b13d729ffc6fd90959);
        else if (i == 5) return bytes32(0x190bf7090129e28155e8dc0b80b3cdac9aebd595e999522a13ee61f407ef41b5);
        else if (i == 6) return bytes32(0x2a1b41a7fe160518b2bc2bed35d85bd7d4513a739617e7131fe958feb4b7030b);
        else if (i == 7) return bytes32(0x168fe1e0c7c9f07c7c37b180a6c42e9608c6bd1fe7f80dd1bc61c249743aece6);
        else if (i == 8) return bytes32(0x03d0dc8c92e2844abcc5fdefe8cb67d93034de0862943990b09c6b8e3fa27a86);
        else if (i == 9) return bytes32(0x1d51ac275f47f10e592b8e690fd3b28a76106893ac3e60cd7b2a3a443f4e8355);
        else if (i == 10) return bytes32(0x16b671eb844a8e4e463e820e26560357edee4ecfdbf5d7b0a28799911505088d);
        else if (i == 11) return bytes32(0x115ea0c2f132c5914d5bb737af6eed04115a3896f0d65e12e761ca560083da15);
        else if (i == 12) return bytes32(0x139a5b42099806c76efb52da0ec1dde06a836bf6f87ef7ab4bac7d00637e28f0);
        else if (i == 13) return bytes32(0x0804853482335a6533eb6a4ddfc215a08026db413d247a7695e807e38debea8e);
        else if (i == 14) return bytes32(0x2f0b264ab5f5630b591af93d93ec2dfed28eef017b251e40905cdf7983689803);
        else if (i == 15) return bytes32(0x170fc161bf1b9610bf196c173bdae82c4adfd93888dc317f5010822a3ba9ebee);
        else if (i == 16) return bytes32(0x0b2e7665b17622cc0243b6fa35110aa7dd0ee3cc9409650172aa786ca5971439);
        else if (i == 17) return bytes32(0x12d5a033cbeff854c5ba0c5628ac4628104be6ab370699a1b2b4209e518b0ac5);
        else if (i == 18) return bytes32(0x1bc59846eb7eafafc85ba9a99a89562763735322e4255b7c1788a8fe8b90bf5d);
        else if (i == 19) return bytes32(0x1b9421fbd79f6972a348a3dd4721781ec25a5d8d27342942ae00aba80a3904d4);
        else if (i == 20) return bytes32(0x087fde1c4c9c27c347f347083139eee8759179d255ec8381c02298d3d6ccd233);
        else if (i == 21) return bytes32(0x1e26b1884cb500b5e6bbfdeedbdca34b961caf3fa9839ea794bfc7f87d10b3f1);
        else if (i == 22) return bytes32(0x09fc1a538b88bda55a53253c62c153e67e8289729afd9b8bfd3f46f5eecd5a72);
        else if (i == 23) return bytes32(0x14cd0edec3423652211db5210475a230ca4771cd1e45315bcd6ea640f14077e2);
        else if (i == 24) return bytes32(0x1d776a76bc76f4305ef0b0b27a58a9565864fe1b9f2a198e8247b3e599e036ca);
        else if (i == 25) return bytes32(0x1f93e3103fed2d3bd056c3ac49b4a0728578be33595959788fa25514cdb5d42f);
        else if (i == 26) return bytes32(0x138b0576ee7346fb3f6cfb632f92ae206395824b9333a183c15470404c977a3b);
        else if (i == 27) return bytes32(0x0745de8522abfcd24bd50875865592f73a190070b4cb3d8976e3dbff8fdb7f3d);
        else if (i == 28) return bytes32(0x2ffb8c798b9dd2645e9187858cb92a86c86dcd1138f5d610c33df2696f5f6860);
        else if (i == 29) return bytes32(0x2612a1395168260c9999287df0e3c3f1b0d8e008e90cd15941e4c2df08a68a5a);
        else if (i == 30) return bytes32(0x10ebedce66a910039c8edb2cd832d6a9857648ccff5e99b5d08009b44b088edf);
        else if (i == 31) return bytes32(0x213fb841f9de06958cf4403477bdbff7c59d6249daabfee147f853db7c808082);
        else revert IncrementalMerkleTree__IndexOutOfBounds(i);
    }
}
