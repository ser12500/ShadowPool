# 🌟 ShadowPool - Decentralized Anonymous Mixer with Governance

[![Solidity](https://img.shields.io/badge/Solidity-0.8.30-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-✓-green.svg)](https://getfoundry.sh/)
[![Noir](https://img.shields.io/badge/Noir-ZK%20Proofs-purple.svg)](https://noir-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Next-generation privacy-preserving DeFi infrastructure with decentralized governance and cross-chain capabilities**

## 🚀 Overview

ShadowPool is a revolutionary decentralized mixer that combines zero-knowledge proofs, anonymous governance, and cross-chain functionality to provide unprecedented privacy and security in DeFi transactions. Built with cutting-edge cryptographic primitives and modern smart contract architecture.

### ✨ Key Features

- 🔐 **Multi-Currency Support**: Mix ETH and any ERC20 tokens seamlessly
- 🕵️ **Zero-Knowledge Privacy**: Powered by Noir zk-proofs for complete anonymity
- 🏛️ **Decentralized Governance**: Anonymous voting system with DAO governance
- 🌉 **Cross-Chain Functionality**: Operate across multiple blockchain networks
- 💰 **Dynamic Fee System**: Adaptive fees based on pool size and anonymity levels
- 🛡️ **Advanced Security**: Reentrancy protection, flash loan resistance, and timelock controls
- 📊 **Multi-Deposit Support**: Batch multiple deposits in single transactions
- 🎯 **Merkle Tree Integration**: 20-level Merkle trees for efficient proof verification

## 🏗️ Architecture

### Core Components

```
ShadowPool/
├── 📄 ShadowPool.sol          # Main mixer contract
├── 🏛️ ShadowPoolDAO.sol       # Decentralized governance
├── 🌉 CrossChainShadowPool.sol # Cross-chain functionality
├── 🗳️ AnonymousVoting.sol     # Anonymous voting system
├── 🪙 ShadowPoolGovernanceToken.sol # Governance token
├── 🔧 Incremental.sol         # Merkle tree management
├── noir/                      # Zero-knowledge circuits
│   ├── src/main.nr           # Multi-currency deposit circuit
│   └── src/merkle_tree.nr    # Merkle tree operations
└── Verifier/                 # Noir-generated verifiers
```

### Smart Contract Architecture

- **ShadowPool**: Core mixing functionality with multi-currency support
- **ShadowPoolDAO**: Governance system with proposal lifecycle management
- **AnonymousVoting**: Privacy-preserving voting mechanism
- **CrossChainShadowPool**: Bridge functionality for cross-chain operations
- **Incremental**: Efficient Merkle tree management with Poseidon2 hashing

## 🛠️ Technology Stack

- **Smart Contracts**: Solidity 0.8.30 with OpenZeppelin contracts
- **Development Framework**: Foundry for testing and deployment
- **Zero-Knowledge Proofs**: Noir language for zk-circuit development
- **Cryptographic Primitives**: Poseidon2 hash function
- **Governance**: Timelock controller with anonymous voting
- **Security**: ReentrancyGuard, SafeERC20, comprehensive error handling

## 📦 Installation & Setup

### Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- [Node.js](https://nodejs.org/) (v18+)
- [Git](https://git-scm.com/)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/your-username/ShadowPool.git
cd ShadowPool

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test

# Run tests with verbose output
forge test -vvv
```

### Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Configure your environment variables
# Add your private keys, RPC URLs, and API keys
```

## 🧪 Testing

### Run All Tests
```bash
forge test
```

### Run Specific Test Files
```bash
# Test main mixer functionality
forge test --match-contract ShadowPool

# Test governance system
forge test --match-contract ShadowPoolDAO

# Test cross-chain functionality
forge test --match-contract CrossChainShadowPool
```

### Run Tests with Gas Reporting
```bash
forge test --gas-report
```

### Fuzz Testing
```bash
# Run fuzz tests with increased runs
forge test --fuzz-runs 1000
```

## 🔧 Development

### Compile Contracts
```bash
forge build
```

### Deploy to Local Network
```bash
# Start local node
anvil

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Deploy to Testnet
```bash
# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

### Generate Documentation
```bash
# Generate NatSpec documentation
forge doc --build
```

## 🔐 Security Features

### Privacy Protection
- **Zero-Knowledge Proofs**: All transactions are verified using zk-proofs
- **Nullifier System**: Prevents double-spending while maintaining anonymity
- **Commitment Scheme**: Poseidon2-based commitments for efficient verification

### Security Measures
- **Reentrancy Protection**: Comprehensive reentrancy guards
- **Flash Loan Resistance**: Protection against flash loan attacks
- **Timelock Controls**: Delayed execution for critical operations
- **Access Control**: Role-based permissions and DAO governance
- **Input Validation**: Extensive parameter validation and error handling

### Anonymity Levels
- **Low Anonymity**: 10+ deposits required
- **Medium Anonymity**: 50+ deposits required  
- **High Anonymity**: 100+ deposits required

## 🏛️ Governance System

### Proposal Lifecycle
1. **Proposal Creation**: Token holders can create proposals
2. **Voting Period**: Anonymous voting with snapshot mechanism
3. **Execution**: Timelock-controlled execution with quorum requirements
4. **Implementation**: Automatic parameter updates

### Anonymous Voting
- **Zero-Knowledge Voting**: Vote privacy through zk-proofs
- **Snapshot Mechanism**: Voting power captured at proposal creation
- **Flash Loan Protection**: Prevents vote manipulation

## 🌉 Cross-Chain Functionality

### Supported Networks
- Ethereum Mainnet
- Polygon
- Arbitrum
- Optimism
- Base

### Bridge Features
- **Unified Interface**: Consistent API across networks
- **Atomic Operations**: Cross-chain transactions with rollback capability
- **Fee Optimization**: Gas-efficient cross-chain transfers

## 📊 Performance & Optimization

### Gas Optimization
- **Optimizer Settings**: 50,000 runs for maximum efficiency
- **Yul Optimization**: Advanced compiler optimizations
- **Batch Operations**: Multi-deposit support for cost reduction

### Scalability Features
- **Incremental Merkle Trees**: Efficient tree updates
- **Poseidon2 Hashing**: Fast cryptographic operations
- **Parallel Processing**: Concurrent deposit handling

## 🤝 Contributing

We welcome contributions from the community! Please read our contributing guidelines before submitting pull requests.

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards
- Follow Solidity style guide
- Write comprehensive tests
- Add NatSpec documentation
- Ensure security best practices

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🐛 Bug Reports

If you discover any bugs, please create an issue with:
- Detailed description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details

## 🔗 Links

- **Documentation**: [docs.shadowpool.io](https://docs.shadowpool.io)
- **Discord**: [Join our community](https://discord.gg/shadowpool)
- **Twitter**: [@ShadowPoolDAO](https://twitter.com/ShadowPoolDAO)
- **Blog**: [Medium](https://medium.com/@shadowpool)

## 🙏 Acknowledgments

- **OpenZeppelin**: For secure smart contract libraries
- **Noir Team**: For zero-knowledge proof framework
- **Foundry Team**: For excellent development tools
- **Poseidon2 Team**: For efficient hash function implementation

---

**Built with ❤️ by the ShadowPool team**

*Empowering privacy in DeFi through decentralized governance and zero-knowledge technology.*
