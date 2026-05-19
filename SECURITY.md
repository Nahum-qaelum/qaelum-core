# Security Policy

QAELUM Oracle Intelligence takes security seriously. This document explains how to report security issues and what our security commitments are.

## Project Status

QAELUM is **pre-mainnet, pre-audit**. The smart contracts in this repository have NOT yet undergone formal third-party audit. They should be considered experimental and not used in production environments.

**Do not deposit real funds into these contracts before formal audit completion.**

## Supported Versions

| Contract | Version | Status | Audit |
|----------|---------|--------|-------|
| QaelumProofOfAlpha.sol | 1.0.0 | Testnet only | Not required (POC) |
| QaelumArbitrageV3_Hardened.sol | 3.1.0 | Pre-deployment | Spearbit + Code4rena planned |
| QaelumInvestorPool.sol | 1.0.0 | Pre-deployment | Required before SAFE execution |

## Audit Roadmap

External audit is a Phase 1 priority funded by seed proceeds:

1. **Spearbit competitive audit** — comprehensive review by elite Solidity auditors (~$45-60K, 3-4 weeks)
2. **Code4rena contest** — public bug bounty competition (~$30-40K prize pool, 1 week)
3. **Immunefi ongoing bounty** — post-mainnet continuous monitoring (~$15K initial reserve)

All audit reports will be published in `audits/` directory of this repository upon completion.

## Reporting a Vulnerability

If you discover a security vulnerability, please follow responsible disclosure practices.

### DO

- Email **qaelumoracleintelligence@gmail.com** with the subject line: `[SECURITY] Brief description`
- Include detailed steps to reproduce the issue
- Provide your suggested fix if you have one
- Give us reasonable time to respond and remediate before public disclosure

### DO NOT

- Open a public GitHub Issue for security vulnerabilities
- Post about the vulnerability on social media before disclosure
- Attempt to exploit the vulnerability on mainnet (when deployed)
- Demand payment in exchange for disclosure

## Response Timeline

We commit to the following response timeline:

- **Within 48 hours:** Acknowledgment of your report
- **Within 7 days:** Initial assessment and severity classification
- **Within 30 days:** Remediation plan or fix deployment
- **Within 90 days:** Public disclosure (coordinated with reporter)

## Severity Classification

We use the following severity tiers:

| Severity | Description | Examples |
|----------|-------------|----------|
| **Critical** | Direct loss of user funds, full contract drain | Reentrancy in withdraw, broken access control |
| **High** | Significant fund loss, partial drain, frozen funds | Logic errors in profit calculation, locked funds |
| **Medium** | Loss of profit but not principal, griefing attacks | Front-running vectors, DoS attacks |
| **Low** | Best practice violations, gas optimization | Missing events, suboptimal patterns |
| **Informational** | Code quality, documentation, style | Naming consistency, comment clarity |

## Bug Bounty (Post-Audit)

Following completion of formal audit and mainnet deployment, QAELUM will establish a public bug bounty program via Immunefi with rewards aligned to severity:

- Critical: up to $50,000
- High: up to $15,000
- Medium: up to $3,000
- Low: up to $500

These amounts are subject to revision based on treasury size and total value secured.

## Internal Structural Audit

Prior to external audit, the founder conducted a comprehensive internal structural audit identifying 23 findings across all severity levels. The hardened contracts in this repository address findings V4, V5, V8, V11, V12, and V13 directly. Remaining findings require separate contracts or operational changes documented in the project whitepaper.

This internal audit is for transparency purposes only and does NOT substitute for external formal audit by qualified third-party security firms.

## Contact

- **Email:** qaelumoracleintelligence@gmail.com
- **Website:** https://qaelum.netlify.app
- **Founder:** Nahum Enebong

---

*This security policy is effective as of May 2026 and will be updated as the project matures through audit and mainnet deployment.*
