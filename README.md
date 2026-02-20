# EVM Yield Farming Protocol

A complete Solidity-based yield farming vault protocol inspired by Yearn Finance's yield vaults. This protocol enables users to deposit assets into vaults that automatically optimize yields through pluggable strategies, earning rewards while the vault handles the complexity of yield farming.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Deployment](#deployment)
- [Contact](#contact)

## ✨ Features

### Core Functionality

- **Vault Deposits/Withdrawals**: Deposit underlying tokens to receive vault shares (ERC-20), withdraw shares for underlying plus accrued yield
- **Automated Yield Optimization**: Pluggable strategies automatically deploy assets to generate yield
- **Share-Based Accounting**: Vault shares represent proportional ownership, price per share increases with yield
- **Performance Fees**: 20% fee on profits (configurable)
- **Management Fees**: 2% annual fee (configurable)
- **Harvesting**: Automated reward collection from strategies
- **Strategy Migration**: Ability to migrate between strategies
- **Emergency Shutdown**: Emergency withdrawal mechanism

### Technical Features

- **UUPS Upgradeable**: Vault contract uses UUPS proxy pattern for upgrades
- **Access Control**: Role-based access (GOVERNANCE, KEEPER, STRATEGIST)
- **Pausability**: Emergency pause functionality
- **Reentrancy Protection**: Guards on all external calls
- **Slippage Protection**: Minimum amount out for withdrawals

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Users / Depositors                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Controller (Manages Vaults)                    │
│  - setStrategy()                                            │
│  - harvest()                                                │
│  - migrateStrategy()                                        │
└──────┬──────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│              Vault (UUPS Proxy)                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  - deposit() → mint shares                         │    │
│  │  - withdraw() → burn shares                        │    │
│  │  - harvest() → collect fees                        │    │
│  │  - pricePerShare() → calculate value               │    │
│  └─────────────────────────────────────────────────────┘    │
└──────┬──────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│              Strategy (BaseStrategy)                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  - deposit() → deploy assets                       │    │
│  │  - withdraw() → retrieve assets                    │    │
│  │  - harvest() → collect rewards                     │    │
│  │  - balanceOf() → total assets                      │    │
│  └─────────────────────────────────────────────────────┘    │
└──────┬──────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│         MockLendingStrategy / External Protocols             │
│  (Generates yield via lending, farming, etc.)                │
└─────────────────────────────────────────────────────────────┘
```

### Contract Components

1. **Vault**: Main vault contract (upgradeable) that issues shares and manages deposits/withdrawals
2. **Controller**: Manages multiple vaults and their strategies
3. **BaseStrategy**: Abstract base contract for strategies
4. **MockLendingStrategy**: Example strategy that simulates yield generation
5. **Mock Tokens**: MockDAI, MockRewardToken for testing

### How It Works

1. **Deposit**: User deposits underlying tokens → receives vault shares
2. **Strategy Deployment**: Vault deploys assets to strategy → strategy generates yield
3. **Yield Accrual**: Strategy accrues yield over time
4. **Harvest**: Keeper calls harvest → rewards collected, fees deducted
5. **Withdraw**: User burns shares → receives underlying + accrued yield

## 📁 Project Structure

```
evm-yield-farming-protocol/
├── contracts/
│   ├── interfaces/
│   │   ├── IVault.sol
│   │   ├── IStrategy.sol
│   │   └── IController.sol
│   ├── vaults/
│   │   └── Vault.sol
│   ├── core/
│   │   └── Controller.sol
│   ├── strategies/
│   │   ├── BaseStrategy.sol
│   │   └── MockLendingStrategy.sol
│   └── mocks/
│       ├── MockUnderlying.sol
│       ├── MockDAI.sol
│       └── MockRewardToken.sol
├── scripts/
│   └── deploy.js
├── test/
│   └── Vault.test.js
├── hardhat.config.js
├── helper-config.js
├── package.json
└── README.md
```

## 🚀 Setup

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Git

### Installation

1. Navigate to the project directory:
```bash
cd evm-yield-farming-smart-contract
```

2. Install dependencies:
```bash
npm install
# or
yarn install
```

3. Create a `.env` file (optional, for testnet deployment):
```bash
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

4. Compile the contracts:
```bash
npx hardhat compile
```

## 🚢 Deployment

### Local Network

1. Start a local Hardhat node:
```bash
npx hardhat node
```

2. In another terminal, deploy to localhost:
```bash
npx hardhat run scripts/deploy.js --network localhost
```

### Testnet Deployment (Sepolia)

1. Ensure your `.env` file is configured with:
   - `PRIVATE_KEY`: Your wallet private key
   - `SEPOLIA_RPC_URL`: Sepolia RPC endpoint
   - `ETHERSCAN_API_KEY`: Etherscan API key (for verification)

2. Deploy to Sepolia:
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

3. Verify contracts (optional):
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## 📧 Contact

- Telegram: https://t.me/rouncey
- Twitter: https://x.com/rouncey_
