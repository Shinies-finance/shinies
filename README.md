# ✨ Shinies Protocol

```
    ░██████╗██╗░░██╗██╗███╗░░██╗██╗███████╗░██████╗
    ██╔════╝██║░░██║██║████╗░██║██║██╔════╝██╔════╝
    ╚█████╗░███████║██║██╔██╗██║██║█████╗░░╚█████╗░
    ░╚═══██╗██╔══██║██║██║╚████║██║██╔══╝░░░╚═══██╗
    ██████╔╝██║░░██║██║██║░╚███║██║███████╗██████╔╝
    ╚═════╝░╚═╝░░╚═╝╚═╝╚═╝░░╚══╝╚═╝╚══════╝╚═════╝░
    
                    Mint 'Em All ✨
```

> **Transform your blue-chip NFTs into yield-bearing Shiny variants.**

In the world of digital collectibles, there exists a tier beyond rare — a chromatic variant so valuable that collectors search endlessly to find one. **Shinies** brings this concept on-chain: wrap your NFTs and receive gleaming variants backed by the original asset PLUS accumulated yield from a revolutionary bonding curve.

---

## 🌐 Deployed Contracts (Ethereum L1)

| Contract | Address | Etherscan |
|----------|---------|-----------|
| **Shinies NFT** | `0xb134a87250c12443cdb9f317ebc2fd831d951363` | [View ↗](https://etherscan.io/address/0xb134a87250c12443cdb9f317ebc2fd831d951363) |
| **Shinies GLUE** | `0x04aE2FC32aAF59f3d4A76caBc0A551a94571d599` | [View ↗](https://etherscan.io/address/0x04aE2FC32aAF59f3d4A76caBc0A551a94571d599) |
| **SHINY Token** | `0x492752ff44479a97016b1ef1721c5f2b0459d9a5` | [View ↗](https://etherscan.io/address/0x492752ff44479a97016b1ef1721c5f2b0459d9a5) |
| **SHINY GLUE** | `0x40fFF715AB8Ef0E801c386d2d4692E0f31894735` | [View ↗](https://etherscan.io/address/0x40fFF715AB8Ef0E801c386d2d4692E0f31894735) |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SHINIES PROTOCOL                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌───────────────┐         ┌───────────────┐                   │
│   │  Your NFT     │────────▶│  Shiny NFT    │                   │
│   │  (CryptoPunk, │  MINT   │  (ERC721)     │                   │
│   │   BAYC, etc)  │◀────────│               │                   │
│   └───────────────┘  BURN   └───────────────┘                   │
│          │                          │                           │
│          ▼                          ▼                           │
│   ┌─────────────────────────────────────────────────────┐       │
│   │              GLUE PROTOCOL (StickyAsset)            │       │
│   │  ┌─────────────────┐    ┌─────────────────┐         │       │
│   │  │  Shinies GLUE   │    │   SHINY GLUE    │         │       │
│   │  │  (ETH/WETH)     │    │   (ETH/WETH)    │         │       │
│   │  │  NFT Backing    │    │  Token Backing  │         │       │
│   │  └─────────────────┘    └─────────────────┘         │       │
│   └─────────────────────────────────────────────────────┘       │
│                           │                                     │
│                           ▼                                     │
│                  ┌─────────────────┐                            │
│                  │  SHINY Token    │                            │
│                  │  (ERC20)        │                            │
│                  │  Rewards        │                            │
│                  └─────────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📜 Smart Contracts

### `Shinies.sol` — Multi-Collection NFT Vault

The core NFT contract that transforms blue-chip NFTs into yield-bearing Shiny variants.

**Key Features:**
- 🎨 **Multi-Collection Support** — CryptoPunks, BAYC, Pudgy Penguins, and community-requested collections
- 📈 **Dynamic Bonding Curve** — Price adapts to supply and collateral levels
- 💎 **Triple-Backed Value** — Original NFT + ETH Collateral + SHINY Rewards
- 🏛️ **Community Governance** — Propose new collections with 2% SHINY stake
- 🦧 **Native CryptoPunks** — Full support for legacy transfer mechanism

**Interfaces:**
- [`IShinies.sol`](./interfaces/IShinies.sol) — Complete API definition

---

### `ShinyToken.sol` — Deflationary Reward Token

```
    ░██████╗██╗░░██╗██╗███╗░░██╗██╗░░░██╗
    ██╔════╝██║░░██║██║████╗░██║╚██╗░██╔╝
    ╚█████╗░███████║██║██╔██╗██║░╚████╔╝░
    ░╚═══██╗██╔══██║██║██║╚████║░░╚██╔╝░░
    ██████╔╝██║░░██║██║██║░╚███║░░░██║░░░
    ╚═════╝░╚═╝░░╚═╝╚═╝╚═╝░░╚══╝░░░╚═╝░░░
    
          The Rarest Token in the Ecosystem ⭐
```

ERC20 reward token with Bitcoin-style halving emissions.

**Emission Schedule:**
| Week | SHINY per ETH |
|------|---------------|
| 0-1  | 100,000       |
| 1-2  | 50,000        |
| 2-3  | 25,000        |
| 3-4  | 12,500        |
| ...  | ÷2 each week  |
| 11-12| ~48.8         |
| 12+  | ~4.88 (÷10, forever) |

**Key Features:**
- 🔒 **12-Week Transfer Lock** — Ensures fair distribution period
- 👥 **Team Allocation** — 40% of community supply (claimable after week 12)
- 💰 **1:1 ETH Backing** — Every SHINY correlates with ETH in the vault

**Interfaces:**
- [`IShinyToken.sol`](./interfaces/IShinyToken.sol) — Complete API definition

---

## 💰 Economic Model

### Fee Structure

**On Mint (5% of bonding curve price):**
```
50% ──▶ SHINY Glue (increases SHINY backing + mints rewards)
50% ──▶ Team Treasury (protocol sustainability)
```

**On Burn (10% of collateral redeemed):**
```
10% ──▶ SHINY Glue (increases SHINY backing + mints rewards)
50% ──▶ Shinies NFT Glue (compounds holder value)
40% ──▶ Team Treasury (protocol sustainability)
```

### Bonding Curve

The mint price is dynamically calculated using:

```
Price = (Collateral/Supply) × [profit_target × dilution_factor] / round_trip_efficiency
```

**Components:**
- **Backing per token** — Current collateral divided by supply
- **Profit target** — Dynamic margin based on supply position
- **Dilution factor** — Compensates existing holders
- **Round-trip efficiency** — Accounts for mint/burn fees

---


## 🔒 Security Features

| Feature | Implementation |
|---------|----------------|
| **Reentrancy Guard** | `nnrtnt` modifier using EIP-1153 transient storage |
| **Collateral Management** | Glue Protocol integration |
| **Ownership Verification** | Post-transfer checks on all NFT operations |
| **Atomic Redemption** | Hook-based system ensures consistent state |
| **Bonding Curve Protection** | Self-regulating prevents manipulation |

---

## 📁 Project Structure

```
contracts/sticky/contracts/
├── Shinies.sol              # Main NFT vault contract
├── ShinyToken.sol           # Deflationary reward token
├── interfaces/
│   ├── IShinies.sol         # Shinies interface
│   ├── IShinyToken.sol      # ShinyToken interface
│   └── ICryptoPunks.sol     # CryptoPunks legacy interface
└── libraries/
    ├── GluedToolsMin.sol    # Glue Protocol utilities (NFT)
    └── GluedToolsERC20Min.sol # Glue Protocol utilities (ERC20)
```

---


## 🔗 Powered by Glue Protocol

Shinies is built on [**Glue Protocol**](https://glue.finance) using the `StickyAsset` standard.

- **Glue Protocol**: [https://glue.finance](https://glue.finance)
- **Documentation**: [https://docs.glue.finance](https://wiki.glue.finance)
- **Glue Expansions Pack**: [@glue-finance/expansions-pack](https://wiki.glue.finance/Expansions-Pack-202725d5136c80d4a65bd5dcb1c95c98)

---

<p align="center">
  <strong>Built with 🧪 by the Shinies Team</strong>
  <br/>
  <em>Powered by <a href="https://glue.finance">Glue Protocol</a></em>
</p>
