# QAELUM Oracle Intelligence

**A Bittensor subnet for frontier-market intelligence.**

QAELUM is being built as the decentralized verification layer for markets that institutional data providers structurally cannot reach: ground-truth commodity data from miners on four continents, DEX execution signals across Tron and EVM chains, AI model licensing, and proprietary flash loan arbitrage — all running on shared Bittensor subnet infrastructure.

---

## ⚠️ Status: Pre-Mainnet · Pre-Audit

This repository contains architectural specifications, smart contract code, and supporting documentation for QAELUM Oracle Intelligence. The system is **in active development and has not yet been deployed to mainnet**. Smart contracts have not yet been audited. Forward-looking content represents founder intent rather than guarantees.

**Currently raising seed capital ($750K target) to fund Phase 1 build:** audit completion, testnet deployment, miner network bootstrap, and first mainnet revenue.

---

## What QAELUM Does

QAELUM coordinates four independent revenue streams sharing one Bittensor subnet:

| Stream | Description | Status |
|---|---|---|
| **QCIS** | Ground-truth commodity intelligence from human miners (cocoa, cotton, coffee, palm oil, lithium, crude) | Architecture documented · miner network in recruitment |
| **QAELUM-FIN** | Fine-tuned 7B parameter financial language model licensed to other subnets and institutions | Architecture documented · training corpus assembly underway |
| **QSIS / QFSS** | DEX execution signals and commodity futures predictions sold as institutional APIs | API specification documented · beta launch is Phase 1 deliverable |
| **QAE** | Proprietary atomic flash loan arbitrage across Tron, Arbitrum, Base, and Optimism | Smart contracts written · audit pending |

The intelligence platform anchors valuation. Arbitrage is a fourth revenue stream, not the headline.

---

## Architecture Overview

QAELUM operates as a three-layer system:

- **Off-chain execution engine** — keeper bot monitoring 66 DEX pairs across 5 chains via WebSocket, with SQBM (Simulated Quantum Bifurcation Machine) path optimization
- **On-chain settlement** — smart contracts on Arbitrum (Phase 1), Tron, Base, Optimism (Phase 2) handling flash loan acquisition, swap execution, profit validation, distribution
- **Bittensor consensus** — registered subnet with dual incentive mechanism (path discovery + commodity intelligence), Yuma Consensus aggregation, cryptographically verifiable proof commitments

### Cryptographic Foundation

- **ML-DSA (NIST FIPS 204)** — post-quantum signature commitments
- **BLAKE3** — cryptographic hashing for proof anchors
- **QRNG (ANU Quantum Optics)** — true quantum random number generation
- **ECDSA** — legacy compatibility for EVM contract interactions

---

## Repository Contents
