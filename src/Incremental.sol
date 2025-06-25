// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Field} from "lib/poseidon2-evm/src/Field.sol";
import {Poseidon2} from "lib/poseidon2-evm/src/Poseidon2.sol";

/**
 * @title Incremental
 * @notice Incremental Merkle tree implementation using Poseidon2 hashing.
 * @dev Provides efficient Merkle tree operations for commitment management in mixers and privacy protocols.
 * @author Sergey Kerhet
 */
contract Incremental {
    /// @notice Field size for the Merkle tree (BN254 curve prime)
    uint256 public constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    /// @notice The "zero" element used to fill empty nodes in the Merkle tree
    bytes32 public constant ZERO_ELEMENT = bytes32(0x034f996155f0d9b1a838977011b06a385e8701d10aae926876c9c8a6fa69bf18);
    /// @notice Maximum depth for Merkle tree (0-31)
    uint32 public constant MAX_MERKLE_TREE_DEPTH = 31;

    /// @notice Instance of the contract which has the Poseidon hash logic
    Poseidon2 public immutable i_hasher;
    /// @notice The depth of the Merkle tree (number of levels)
    uint32 public immutable i_depth;

    /// @notice Mapping for cached subtrees (for efficient updates)
    mapping(uint256 => bytes32) public s_cachedSubtrees;
    /// @notice Mapping for Merkle tree roots (history)
    mapping(uint256 => bytes32) public s_roots;
    /// @notice Number of roots stored to compare proofs against
    uint32 public constant ROOT_HISTORY_SIZE = 30;
    /// @notice Index in ROOT_HISTORY_SIZE where the current root is stored
    uint32 public s_currentRootIndex = 0;
    /// @notice Index of the next leaf to be inserted into the tree
    uint32 public s_nextLeafIndex = 0;

    /// @notice Error: left value out of field range
    error IncrementalMerkleTree__LeftValueOutOfRange(bytes32 left);
    /// @notice Error: right value out of field range
    error IncrementalMerkleTree__RightValueOutOfRange(bytes32 right);
    /// @notice Error: tree depth must be greater than zero
    error IncrementalMerkleTree__LevelsShouldBeGreaterThanZero(uint32 depth);
    /// @notice Error: tree depth must be less than 32
    error IncrementalMerkleTree__LevelsShouldBeLessThan32(uint32 depth);
    /// @notice Error: Merkle tree is full
    error IncrementalMerkleTree__MerkleTreeFull(uint32 nextIndex);
    /// @notice Error: index out of bounds
    error IncrementalMerkleTree__IndexOutOfBounds(uint256 index);

    /**
     * @notice Constructor to initialize the Merkle tree with specified depth and hasher
     * @param _depth The depth of the Merkle tree (must be between 1 and 31)
     * @param _hasher Address of the Poseidon2 hasher contract
     */
    constructor(uint32 _depth, Poseidon2 _hasher) {
        if (_depth == 0) {
            revert IncrementalMerkleTree__LevelsShouldBeGreaterThanZero(_depth);
        }
        if (_depth >= MAX_MERKLE_TREE_DEPTH) {
            revert IncrementalMerkleTree__LevelsShouldBeLessThan32(_depth);
        }
        i_depth = _depth;
        i_hasher = _hasher;
        s_roots[0] = zeros(_depth);
    }

    /**
     * @notice Hash two tree leaves using Poseidon2
     * @dev Returns Poseidon(_left, _right)
     * @param _left The left leaf value
     * @param _right The right leaf value
     * @return The hash of the two leaves
     */
    function hashLeftRight(bytes32 _left, bytes32 _right) public view returns (bytes32) {
        if (uint256(_left) >= FIELD_SIZE) {
            revert IncrementalMerkleTree__LeftValueOutOfRange(_left);
        }
        if (uint256(_right) >= FIELD_SIZE) {
            revert IncrementalMerkleTree__RightValueOutOfRange(_right);
        }
        return Field.toBytes32(i_hasher.hash_2(Field.toField(_left), Field.toField(_right)));
    }

    /**
     * @notice Insert a new leaf into the Merkle tree
     * @dev Updates the root and caches subtrees for efficient future insertions
     * @param _leaf The leaf value to insert
     * @return index The index of the inserted leaf
     */
    function _insert(bytes32 _leaf) internal returns (uint32 index) {
        uint32 _nextLeafIndex = s_nextLeafIndex;
        if (_nextLeafIndex == uint32(2) ** i_depth) {
            revert IncrementalMerkleTree__MerkleTreeFull(_nextLeafIndex);
        }
        uint32 currentIndex = _nextLeafIndex;
        bytes32 currentHash = _leaf;
        bytes32 left;
        bytes32 right;

        for (uint32 i = 0; i < i_depth; i++) {
            // If index is even, current node is left child, right child is zero subtree
            if (currentIndex % 2 == 0) {
                left = currentHash;
                right = zeros(i);
                // aderyn-ignore-next-line(costly-loop)
                // Cache the calculated hash as a subtree root
                s_cachedSubtrees[i] = currentHash;
            } else {
                // If odd, current node is right child, left child is cached subtree
                left = s_cachedSubtrees[i];
                right = currentHash;
            }
            // Calculate the hash of the left and right nodes
            currentHash = hashLeftRight(left, right);
            // Go up a level by halving the index
            currentIndex /= 2;
        }

        // Store the new root in the roots array
        uint32 newRootIndex = (s_currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        s_currentRootIndex = newRootIndex;
        s_roots[newRootIndex] = currentHash;
        s_nextLeafIndex = _nextLeafIndex + 1;
        return _nextLeafIndex;
    }

    /**
     * @notice Check whether the root is present in the root history
     * @param _root The root to check
     * @return True if the root is known, false otherwise
     */
    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == bytes32(0)) {
            return false;
        }
        uint32 _currentRootIndex = s_currentRootIndex;
        uint32 i = _currentRootIndex;
        do {
            if (_root == s_roots[i]) {
                return true;
            }
            if (i == 0) {
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    /**
     * @notice Returns the latest root of the Merkle tree
     * @return The current root value
     */
    function getLatestRoot() public view returns (bytes32) {
        return s_roots[s_currentRootIndex];
    }

    /**
     * @notice Returns the root of a subtree at the given depth
     * @param i The depth of the subtree root to return
     * @return The root of the given subtree
     */
    function zeros(uint256 i) public pure returns (bytes32) {
        if (i == 0) return bytes32(0x034f996155f0d9b1a838977011b06a385e8701d10aae926876c9c8a6fa69bf18);
        else if (i == 1) return bytes32(0x2a06a72b1f2b24364e5e4120849b4692bbf91c4bcad66845a399e67022e9f0d9);
        else if (i == 2) return bytes32(0x059c8070788f7308bbda9246ef2d321ad1bf81cda0edfe01399652ff34c53da4);
        else if (i == 3) return bytes32(0x27d1ecbd5115efbbda09f8d68eaeabd0a9f28debb8f211c85234ac5bb3f332c2);
        else if (i == 4) return bytes32(0x1b4fbca11bb4821fc5f3264debc386ff9b7081458ca4725ba5386b1774f665e4);
        else if (i == 5) return bytes32(0x189af983b17956b1997302f93059af4d2414a2d19deea6743e8484e3e9213b9d);
        else if (i == 6) return bytes32(0x2d61566878b72076d8ccf4bb2211272cd24b352b27285088383c85b4ea19180c);
        else if (i == 7) return bytes32(0x16c3503aebf8d918c9771d683e335b2a62547fb8e86e5d0d6cb898c14fb5d396);
        else if (i == 8) return bytes32(0x1a5de8d583ecaaa9e3d684145c0410976a66ce979f7e92cd5c0fdbaa2ac1af5a);
        else if (i == 9) return bytes32(0x28e3f0b5fd188614cf8c2825ba0263ed70153e1a453f0662baedaeab12a66ef8);
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
