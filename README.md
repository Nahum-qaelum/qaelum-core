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
- `contracts/` — smart contracts (QaelumProofOfAlpha.sol for testnet, QaelumArbitrageV3.sol for production, QaelumInvestorPool.sol for distribution)
- `docs/` — whitepaper v2.2, roadmap v1.1, structural audit
- `LICENSE` — MIT
- `SECURITY.md` — responsible disclosure policy

---

## Smart Contract Security

The smart contracts in this repository have undergone an internal structural audit identifying 23 findings across critical, high, medium, and low severity. **External audit is a Phase 1 priority** and will be performed by Spearbit + Code4rena before mainnet deployment.

**Do not use these contracts in production until external audit is complete.**

### Engineered Safety Properties

- Atomic flash loan execution (failed cycles revert; only gas lost)
- Daily loss cap with auto-pause (2% treasury threshold)
- 3-of-5 multisig ownership requirement
- Two-step emergency withdraw (pause + withdraw, never single action)
- USDT-compatible approval pattern (reset-to-zero before set)
- Granular pause controls (per-DEX, per-pair, per-chain)
- BLAKE3 proof commitment before fund distribution

---

## Roadmap

| Phase | Months | Key Milestones |
|---|---|---|
| **Phase 0 — Foundation** | Pre-seed | Seed round close · UAE Freezone entity · Founding miner cohort |
| **Phase 1 — Ship It** | 1–6 | Audit · Testnet · 20+ verified miners · Mainnet contract · First arbitrage cycle |
| **Phase 2 — Scale What Works** | 7–14 | Multi-chain expansion · Institutional API customers · Bittensor mainnet · QAELUM-FIN v1 |
| **Phase 3 — Category Definition** | 15–24 | Series A · VASP licensing · Full-time team · Tier 1 CEX listing |

---

## Why This Cannot Be Easily Replicated

Smart contract code can be forked in a weekend. What cannot be forked:

1. **The ground-truth miner network** — verified contributors across West Africa, Southeast Asia, and Latin America take 18-24 months to recruit and validate
2. **The proprietary training corpus** — 5+ years of operational arbitrage logs and commodity ground-truth data
3. **Frontier-market operational knowledge** — institutional providers cannot operate in these jurisdictions
4. **The reputation scoring system** — four-layer verification takes time to mature

---

## Founder

**Nahum Enebong** — Founder & Chief Architect

In crypto since 2020. Five years of hands-on arbitrage research across emerging-market corridors and DEX execution patterns. Crypto futures trader. Former crypto advisor to Lee Johnson, Director at Aspray UK. Independent infrastructure researcher building decentralised verification systems for markets institutional providers cannot reach.

- LinkedIn: [Nahum Enebong](https://www.linkedin.com/in/nahum-enebong-a262201b7)
- X / Twitter: [@Qaelumoracle](https://x.com/Qaelumoracle)
- Email: qaelumoracleintelligence@gmail.com
- Website: [qaelum.netlify.app](https://qaelum.netlify.app/)

---

## Contact

**For investor inquiries:** qaelumoracleintelligence@gmail.com  
**For technical questions:** open an Issue in this repository  
**For security disclosures:** see `SECURITY.md`

---

## License

This repository is released under the **MIT License**. See `LICENSE` for full terms.

---

## Important Disclosures

QAELUM Oracle Intelligence is a pre-revenue, pre-deployment project. Capital invested at seed stage is at risk of total loss. Forward-looking statements represent founder intent, not guarantees. Token allocations, revenue projections, and valuation pathways are scenario-based modelling, not promises.

QAELUM does not provide investment advice and is not registered as an investment fund or securities issuer in any jurisdiction.

---

*Last updated: November 2025*
