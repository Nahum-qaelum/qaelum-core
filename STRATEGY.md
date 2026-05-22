QAELUM Strategic Direction
This document outlines the strategic and engineering direction for QAELUM Oracle Intelligence as of May 2026. It is intended as a public reference for contributors, evaluators, and investors reviewing this repository.
Project Status
QAELUM is pre-mainnet, pre-audit, pre-launch. The repository contains contract design, internal audit findings, whitepaper, and roadmap documents. Production deployment is contingent on external audit completion and Bittensor-native protocol engineering work scheduled for Phase 1 post-funding.
Phase 1 Chain Priority
QAELUM's atomic flash-loan cross-DEX arbitrage operates across six chains. Phase 1 deployment prioritises chains where institutional MEV competition is structurally weaker and where revert-protected bundle execution is favourable:
Tron — No public mempool; round-robin Super Representative block production; "hidden alpha" environment relative to Ethereum L1 / Arbitrum
Base — 200ms Flashblocks via Rollup-Boost with native revert protection (since July 2025)
Polygon PoS — Lower institutional MEV competition than Ethereum-aligned L2s
Secondary chains (Arbitrum, Optimism) are deployed selectively rather than as primary corridors, given documented institutional capture of Arbitrum Timeboost express-lane auctions.
Win Rate Target Methodology
QAELUM targets a 96 percent or higher bundle landed rate — defined as the percentage of arbitrage bundles submitted to private relays that get included on-chain without revert. This is a specific and engineered metric, not an aspirational gross-profit metric.
Achievability is contingent on:
Private relay fan-out routing (Flashbots Protect, MEV Blocker, BuilderNet, direct builder access)
Revert-protected bundle templates
Chain selection that avoids institutional MEV competition zones
Multi-builder submission with bundle deduplication
Phase 1 Revenue Architecture
Phase 1 operates two complementary revenue streams on shared smart contract infrastructure:
Atomic cross-DEX cyclic arbitrage (primary)
Liquidation arbitrage on Aave V3, Aave V4, Compound V3, and Morpho (secondary)
Both streams use the same flash-loan smart contract scaffolding. Liquidation arbitrage provides uncorrelated revenue and capital efficiency, particularly on smaller positions where institutional liquidation bots are under-served.
Phase 2 Expansion
Phase 2 (months 7-18 post-funding) expands to:
Cross-chain bridge arbitrage via Across Protocol, Stargate, and inventory-based variants
LST and LRT spread arbitrage including stETH, wstETH, weETH, ezETH, and rETH corridors
Bittensor subnet token arbitrage — Subtensor native AMMs ↔ Solana DEXs via Wormhole wTAO (infrastructure activated May 2026 via SN106 VoidAI) ↔ Ethereum L2 wrapped variants
The Bittensor subnet token arbitrage opportunity is genuine whitespace as of May 2026 — no existing subnet bridges these venues.
Phase 3 Expansion
Phase 3 (months 19-36 post-funding, Series A-funded) introduces:
Statistical arbitrage on correlated DeFi pairs — the production use case for SQBM-based optimisation
Restaking yield differential arbitrage across EigenLayer, Symbiotic, and Karak
Frontier-market commodity-linked DEX pairs powered by the QCIS data layer
Engineering Roadmap
Phase 1 Engineering Workstreams
Protocol layer (Bittensor-native) — Yuma weight setting, commit-reveal scheme, ActivityCutoff configuration, validator scoring code. Phase 1 priority hire is a Bittensor-native engineer for this workstream.
Smart contract layer — QaelumArbitrageV3 hardened contract enhancements: private relay fan-out router, revert-protected bundle templates, multi-builder submission logic, chain-specific execution paths, circuit breakers.
Algorithm layer — Moore-Bellman-Ford with line-graph augmentation as the production baseline path finder. SQBM (Simulated Quantum Bifurcation Machine) as a second-stage multi-objective optimizer where graph complexity justifies it.
Off-chain infrastructure — Keeper bot, RPC node infrastructure, mempool state caching, multi-region failover, HSM-based key management.
Verification layer (QCIS) — Four-dimensional miner scoring system, anchor source integration (COCOBOD, ICCO, NACOTAN, ICO Composite, MPOB, GAPKI, Benchmark Mineral Intelligence, Fastmarkets, LME, SMM, LBMA, COMEX), anomaly override rule, behavioural fingerprinting.
Phase 1 Hiring Priority
Bittensor-native protocol engineer (first hire). A founder-led design then validated and reworked by an engineer with prior subnet experience produces materially better launch quality than founder-only design committed to mainnet.
Audit Strategy
Phase 1 includes external audit by tier-one Solidity audit firms (Spearbit competitive audit plus Code4rena public contest). Approximately 13 percent of seed proceeds allocated to audit costs. Internal structural audit (23 findings, published in doc/QAELUM_Structural_Audit.md) addresses pre-audit hardening but does not substitute for external audit.
Mainnet deployment is contingent on external audit completion. This is a hard precondition.
Competitive Positioning
QAELUM's defensible moat operates on three layers:
Information asymmetry — QCIS ground-truth commodity data from frontier markets that institutional data providers (Bloomberg, Refinitiv) structurally cannot replicate
Chain selection — Deployment on chains where institutional MEV competition is structurally weaker
Operational discipline — Revert-protected bundles, multi-builder fan-out, circuit breakers, behavioural verification
Algorithm sophistication (SQBM, quantum-inspired optimisation) is an engineering optimisation layer, not the primary moat.
What This Repository Will Contain Through Phase 1
Smart contracts (current: testnet POC, hardened production contract, investor pool)
External audit reports (Phase 1 deliverable)
Foundry test suite with 90 percent or higher coverage (Phase 1 deliverable)
Validator code, miner code, and Bittensor subnet integration (Phase 1 deliverable)
Deployment guides and operational runbooks (Phase 1 deliverable)
Architecture decision records (ADRs) documenting protocol-level design decisions
What This Repository Will Not Contain
Proprietary path optimisation parameters
Private mempool routing logic with sensitive endpoint configuration
Internal pricing models or specific win-rate parameters by chain
QCIS miner identities or regional partner relationships
Detailed revenue projections
These are operational details retained internally and shared with investors under standard NDA.
Document Versions
README.md — General project overview
STRATEGY.md — This document; strategic and engineering direction
SECURITY.md — Responsible disclosure policy
doc/QAELUM_Whitepaper_v2.2.pdf — Full technical and investment whitepaper
doc/QAELUM_Honest_Profit_Roadmap_v1.1.pdf — Three-scenario revenue projections
doc/QAELUM_Structural_Audit.md — Internal vulnerability assessment
Contact
Email: qaelumoracleintelligence@gmail.com
Website: qaelum.netlify.app
GitHub: github.com/Nahum-qaelum/qaelum-core
Document version 1.0 · May 2026 · QAELUM Oracle Intelligence
