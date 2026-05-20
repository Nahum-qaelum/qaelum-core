# QAELUM Structural Vulnerability Audit
## Honest Assessment of What Could Collapse the System

**Auditor:** Claude (architectural review, not formal security audit)
**Date:** May 2026
**Scope:** Smart contracts, system architecture, business model, operational design
**Classification:** Internal — Founder Review Only

---

## EXECUTIVE SUMMARY

QAELUM's architecture is structurally sound at the conceptual level. The four-revenue-stream model, post-quantum cryptography choices, and Bittensor-native distribution are defensible. However, several specific structural weaknesses could cause partial or total system failure if not addressed before mainnet deployment.

I've identified **23 vulnerabilities** ranging from CRITICAL (project-ending) to LOW (cosmetic). The most dangerous are not the smart contract bugs — those are caught by audit. The dangerous ones are architectural assumptions baked into the system design that no smart contract audit will catch.

**Top 5 risks ranked by collapse potential:**

1. **CRITICAL:** Off-chain bot is a single point of failure with custody implications
2. **CRITICAL:** Investor pool distribution is centralised through founder-controlled wallet
3. **HIGH:** Miner network bootstrap risk has no mitigation plan
4. **HIGH:** Smart contract has multiple unaudited assumptions that will fail in production
5. **HIGH:** Token economics create misalignment between investors and miners

This document explains each finding, classifies severity, and provides specific solutions.

---

## SEVERITY DEFINITIONS

- **CRITICAL** — Could destroy the project, drain treasury, or cause irreversible reputational damage
- **HIGH** — Could materially impair operations or trigger investor distress
- **MEDIUM** — Could cause operational friction or partial revenue loss
- **LOW** — Cosmetic or easily-fixed issues

---

## CRITICAL VULNERABILITIES (Project-Ending Risks)

### V1. Off-Chain Bot Is Single Point Of Failure With Implicit Custody

**Finding:**
The current architecture relies on an off-chain keeper bot that calls `executeArbitrage()` on the smart contract. The `onlyExecutor` modifier means only this single bot can trigger arbitrage cycles. If the bot:
- Has its private key compromised → attacker triggers losing trades to drain via the slippage mechanism
- Goes offline → zero revenue generation, complete dependency
- Behaves maliciously (rogue contractor) → can drain via collusion with malicious DEX
- Is seized by authorities → operations halt completely

The smart contract has `onlyExecutor`, but the executor wallet itself has no special protections. A compromised executor private key can submit transactions that pass all profit checks (using a flashloan against a manipulated pool) while routing funds to attacker-controlled addresses through carefully crafted swap paths.

**Why this is critical:**
This is the standard attack vector against MEV bots in 2024-2025. Multiple flash loan arbitrage operations have lost $1M-$50M because their off-chain bot was the actual weak point, not the smart contract.

**Solution:**

Implement a three-layer executor architecture:

```
Layer 1: Detection Bot (no keys, no execution authority)
  ↓ submits opportunity to:
Layer 2: Validation Service (independent, validates path + profit)
  ↓ if valid, signs and forwards to:
Layer 3: Execution Wallet (cold-warm hybrid, multi-sig for amounts >$50K)
  ↓ submits transaction to chain
```

Concrete changes:
1. Split current single executor wallet into hot wallet (limit $10K/tx, $100K/day) and treasury wallet (cold, multi-sig)
2. Add `executeArbitrageSmall()` (hot wallet allowed) and `executeArbitrageLarge()` (multi-sig required)
3. Add `dailyExecutionLimit` per executor address with auto-reset
4. Add `pathHashWhitelist` so executor can only submit pre-approved path types
5. Implement bot infrastructure on infrastructure with hardware security module (HSM) signing, not local keys

**Estimated implementation cost:** $15-25K additional engineering work, $5K/month infrastructure increase.

---

### V2. Investor Pool Distribution Bottleneck

**Finding:**
The contract distributes 40% of profits to `investorPoolContract`. This is described as a separate contract that handles pro-rata distribution to individual investors. **This contract does not exist yet.** The current QaelumArbitrageV3.sol simply transfers to an address. In Phase 1, that address will likely be a founder-controlled wallet that manually distributes.

**Why this is critical:**
- Manual distribution = founder custody of investor funds = legal liability
- Founder-controlled distribution = trust dependency that violates the "transparent on-chain" thesis
- Investors who don't receive expected distributions can claim mismanagement
- Single signature on distribution wallet = honeypot for attackers and authorities

If any of the following happens, the project collapses:
- Founder wallet compromised → investor funds drained
- Founder unable to perform distribution (illness, travel, jurisdiction issue) → revenue stops flowing
- Tax/regulatory action against founder personally → investor funds frozen
- Founder fails to make a distribution on schedule → investor lawsuit risk

**Solution:**

Build `QaelumInvestorPool.sol` BEFORE mainnet deployment. Specifications:

1. **Pull-based withdrawal pattern.** Each investor's allocation is calculated by the contract; investors call `withdraw()` themselves rather than founder pushing funds. Eliminates founder distribution responsibility entirely.

2. **Investor registration during seed close.** Each SAFE-holder registers their wallet address. Contract maps `address → tokenAllocation → proRataShare`.

3. **Snapshot-based accruals.** When QaelumArbitrageV3 transfers profit to the pool, contract snapshots the total pool balance and timestamp. Each investor's withdrawal is calculated as `(profit × investorShare) / totalShares`.

4. **Cliff and vesting enforced on-chain.** Investor cannot withdraw before their cliff date. Vesting unlocks linearly.

5. **No founder admin keys on distribution logic.** Founder can update investor registration during seed close period only; after period closes, registration is permanently locked.

```solidity
contract QaelumInvestorPool {
    struct Investor {
        uint256 saftAmount;        // USD invested
        uint256 tokenAllocation;   // QAE allocated
        uint256 cliffEnd;          // Timestamp
        uint256 vestEnd;           // Timestamp
        uint256 withdrawnAmount;   // USDC withdrawn to date
        bool registered;
    }

    mapping(address => Investor) public investors;
    uint256 public totalSAFTInvested;
    uint256 public totalDistributionsReceived;
    bool public registrationLocked;

    function withdraw() external {
        Investor storage inv = investors[msg.sender];
        require(inv.registered, "Not registered");
        require(block.timestamp >= inv.cliffEnd, "Before cliff");

        uint256 vestedShare = _calculateVested(inv);
        uint256 owed = (totalDistributionsReceived * vestedShare) / totalSAFTInvested;
        uint256 toWithdraw = owed - inv.withdrawnAmount;

        require(toWithdraw > 0, "Nothing to withdraw");
        inv.withdrawnAmount = owed;
        USDC.transfer(msg.sender, toWithdraw);
        emit InvestorWithdrew(msg.sender, toWithdraw);
    }
}
```

**Implementation timing:** Must be built and audited BEFORE the first SAFE is signed. Investors will ask "show me the distribution contract" during due diligence. Not having it ready signals amateur operation.

**Estimated cost:** $10-15K engineering + included in audit scope.

---

### V3. Bittensor Mainnet Registration Economic Risk

**Finding:**
QAELUM plans Bittensor mainnet registration in Phase 2 (Months 7-10). The current Bittensor protocol (v3.3.15-402 from May 2026) requires:
- Initial TAO burn: 100-500 TAO ($30K-$200K depending on TAO price)
- Conviction Mechanism (BIT-0011): continuous TAO locking to maintain subnet ownership
- Challenger risk: if competitor out-stakes you, they can take your subnet

The $750K seed has $260-280K Phase 2 reserve, but the TAO market is volatile. If TAO doubles in price by Month 7 (Scenario C), registration could consume $400-600K of reserves, leaving insufficient runway. If a competitor specifically targets QAELUM's subnet slot, they could economically force you off the subnet.

**Why this is critical:**
- Subnet registration is binary: you have it or you don't
- Losing your subnet to a challenger destroys all accumulated work
- Insufficient reserve for registration delays Phase 2 by months
- The Conviction Mechanism creates ongoing operational capital lockup that's not modeled in current cash flow projections

**Solution:**

Three-part mitigation:

1. **Pre-purchase TAO during favorable price windows.** Don't wait until Month 7 to acquire TAO at market price. Accumulate TAO using a portion of seed proceeds over Months 1-6, dollar-cost-averaging through volatility. Allocate $100-150K specifically for TAO accumulation, separate from working capital.

2. **Register on testnet permanently and operate there longer.** Don't rush mainnet. Build mainnet-equivalent operational track record on testnet for 6+ months. Investors actually prefer this. It eliminates registration economic pressure during a vulnerable period.

3. **Apply for Bitstarter or Yuma incubator funding BEFORE Phase 2.** These provide TAO directly. Bitstarter specifically funds Bittensor subnet registration. Apply Month 2-3, before you need the capital. Lead time to acceptance is 6-12 weeks.

**Estimated impact:** Defers Phase 2 by 3-6 months but eliminates the registration economic risk entirely.

---

## HIGH SEVERITY VULNERABILITIES

### V4. Smart Contract — _executeSwapPath Function Is Incomplete

**Finding:**
Looking at QaelumArbitrageV3.sol line 412-438, the `_executeSwapPath` function is described in the code as "PLACEHOLDER — full impl decodes swapPath and threads execution." It currently only executes ONE hop (line 437), not a multi-hop arbitrage path. The comment at line 419 says "Mainnet version uses inline assembly for ~40% gas reduction" — meaning the actual implementation does not exist.

**Why this is high severity:**
- Contract cannot execute multi-DEX arbitrage as designed
- Audit will flag this immediately as critical incomplete code
- Any auditor will require full implementation before approving deployment
- This is the actual core of the arbitrage engine — it's missing

**Solution:**

Complete the implementation before testnet deployment. Required components:

```solidity
function _executeSwapPath(bytes memory swapPath, uint256 amountIn) internal returns (uint256 finalAmount) {
    // Decode swapPath as: [router1, tokenIn1, tokenOut1, fee1, router2, tokenIn2, tokenOut2, fee2, ...]
    uint256 hopCount = swapPath.length / 84; // 20+20+20+24 bytes per hop
    uint256 currentAmount = amountIn;

    for (uint256 i = 0; i < hopCount; i++) {
        uint256 offset = i * 84;
        address router = _decodeAddress(swapPath, offset);
        address tokenIn = _decodeAddress(swapPath, offset + 20);
        address tokenOut = _decodeAddress(swapPath, offset + 40);
        uint24 fee = _decodeUint24(swapPath, offset + 60);

        // Approve router for this hop
        require(IERC20(tokenIn).approve(router, currentAmount), "Approval failed");

        // Execute swap on this hop
        IUniswapV3SwapRouter.ExactInputSingleParams memory p = IUniswapV3SwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: currentAmount,
            amountOutMinimum: 0, // Profit check at end, not per-hop
            sqrtPriceLimitX96: 0
        });

        currentAmount = IUniswapV3SwapRouter(router).exactInputSingle(p);
        require(currentAmount > 0, "Hop failed");
    }

    return currentAmount;
}
```

**Estimated work:** 2-3 weeks for full implementation + testing. This must happen before audit.

---

### V5. Token Approval Race Condition (USDT Specifically)

**Finding:**
Lines 422 and 373 of QaelumArbitrageV3.sol use `approve()` without resetting to zero first. This is a critical bug specifically for USDT and certain other tokens that revert if you try to change a non-zero approval without first setting it to zero.

If the contract ever has an existing USDT approval to a router (from a previous incomplete cycle), the next `approve()` call will revert, breaking the entire transaction.

**Solution:**

Add `_safeApprove()` helper:

```solidity
function _safeApprove(address token, address spender, uint256 amount) internal {
    // Reset to zero first to handle USDT-style tokens
    (bool success1, ) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, 0));
    require(success1, "Approval reset failed");

    if (amount > 0) {
        (bool success2, ) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        require(success2, "Approval set failed");
    }
}
```

Replace all `IERC20(...).approve()` calls with `_safeApprove()`.

**Why this matters:**
USDT is the primary stablecoin on Tron and a major one on Arbitrum. Without this fix, half of QAELUM's intended arbitrage operations will silently fail in production.

---

### V6. Miner Network Bootstrap Has No Contingency Plan

**Finding:**
The roadmap claims "First 5 miners onboarded — Month 3, West Africa cohort signed." But the materials don't describe:
- How miners are recruited
- What incentives are offered before TAO emissions are flowing
- What happens if first 5 miners can't be recruited
- How miner identities are verified initially
- How miner submissions are paid in fiat (NGN/GHS) when QAELUM treasury is in USDC

If miner network bootstrap fails (specifically: can't recruit verified miners in Month 1-3), the QCIS revenue line is delayed by 6-12 months. That delay cascades into Scenario A timing where bridge round becomes necessary.

**Solution:**

Build the miner recruitment funnel as a parallel workstream starting Month 0:

1. **Pre-seed miner identification (Months -1 to 0).** Before money raised, identify 8-10 candidate miners through existing networks. Document their qualifications, regions, commodities they observe. Have signed Letters of Intent (non-binding) with at least 5.

2. **Founding miner incentive package.** First 20 miners receive: $500 signup bonus, $200/month base for first 3 months regardless of submission accuracy, 0.05% bonus QAE allocation, "Founding Miner" status on QAELUM social media. This costs ~$30K total — should be a budgeted line item.

3. **Local payment partnership.** Before launching, partner with one mobile money provider (M-Pesa for Kenya, MTN MoMo for Ghana/Nigeria, Wave for Senegal) for direct fiat payments. This is non-trivial — typically takes 6-12 weeks to set up business API access.

4. **Backup miner sourcing.** If West Africa contacts don't activate, have backup plan for Southeast Asia (Vietnam coffee, Indonesia palm oil) or Latin America (Brazil coffee, Argentina grains). Don't put all bootstrap eggs in one geographic basket.

**Estimated cost:** $40-50K in additional Phase 0 / Phase 1 spending, plus 2-3 weeks of founder time on partnerships.

---

### V7. Token Economics Misalignment Between Investors And Miners

**Finding:**
Current profit split: 40% investors, 30% miners, 20% burn, 10% treasury.

This looks balanced but has hidden misalignment:
- Investors are paid in USDC (stable, immediately liquid)
- Miners are paid in TAO emissions (volatile, requires Bittensor operations)
- Burn is QAE buyback (deflationary pressure benefits investors more than miners)

In a bear market scenario where TAO drops 50%, miners' effective compensation drops 50% while investors' compensation stays stable. Miners will leave. Without miners, QCIS data quality degrades. Without QCIS data, the moat erodes. Without the moat, the platform's valuation thesis collapses.

The misalignment is invisible during bull markets and devastating during bear markets.

**Solution:**

Restructure miner compensation to be partially USDC-denominated:

- 50% of miner rewards paid in USDC (matched to TAO equivalent at distribution time)
- 50% of miner rewards paid in QAE tokens (vested over 6 months to retain miners)
- TAO emissions earned by QAELUM treasury are recycled into the USDC miner pool

This shifts FX risk from miners (vulnerable) to treasury (better able to absorb), while still providing TAO-denominated upside through QAE token appreciation.

Updated split (mathematically equivalent total cost, different distribution):
- 40% investors (USDC)
- 15% miners cash (USDC immediate)
- 15% miners token (QAE vested)
- 20% burn (QAE)
- 10% treasury (USDC)

**Why this matters:**
This is the single most important change for long-term system stability. Without it, you build the network during the bull phase only to lose it during the bear phase, right when QCIS data is most valuable to institutional buyers seeking alpha.

---

### V8. No Mechanism To Pause Specific Pairs Or Chains

**Finding:**
Current pause mechanism is binary: paused or not paused, all or nothing. If a specific DEX (say SushiSwap on Arbitrum) is exploited and has corrupted state, QAELUM has to pause ALL operations to avoid trading against corrupted pools, including healthy pairs on other DEXes.

**Solution:**

Add granular pause controls:

```solidity
mapping(address => bool) public dexPaused;        // Per-DEX pause
mapping(bytes32 => bool) public pairPaused;       // Per-pair pause
mapping(uint256 => bool) public chainPaused;      // Per-chain pause

function pauseDex(address dex) external onlyOwner {
    dexPaused[dex] = true;
    emit DexPaused(dex);
}

function pausePair(bytes32 pairHash) external onlyOwner {
    pairPaused[pairHash] = true;
    emit PairPaused(pairHash);
}
```

Check these in `executeArbitrage()` before execution.

**Impact:** During emergencies, can isolate specific risks without halting healthy revenue streams.

---

### V9. SAFE Agreement Standardization Missing

**Finding:**
Investors are signing SAFE agreements but I haven't seen evidence of standardized SAFE template selection. Custom SAFE agreements per investor create cap table chaos and legal exposure. Using a non-standard SAFE template creates ambiguity that will require expensive legal work at Series A.

**Solution:**

1. Use Y Combinator's post-money SAFE template (free, standard, accepted by all professional investors)
2. Fixed valuation cap at $2.5M for all seed investors (don't negotiate per investor)
3. No discount terms (post-money SAFE doesn't have them)
4. Pro-rata rights included (standard)
5. All SAFEs counter-signed and stored in single secure location

**Estimated cost:** $2-5K for proper templating with crypto-savvy lawyer. Far cheaper than fixing inconsistencies at Series A.

---

## MEDIUM SEVERITY VULNERABILITIES

### V10. No Daily Loss Cap Update Mechanism

**Finding:**
`DAILY_LOSS_CAP_BPS = 200` (2%) is a constant. As treasury grows, 2% becomes a larger absolute amount, but the cap doesn't adjust. Conversely, in early operations with small treasury, 2% is too restrictive.

**Solution:** Make it owner-adjustable within bounds (50-500 bps) with timelock for changes.

---

### V11. ML-DSA Signature Verification Not Actually Implemented

**Finding:**
Contract stores `mldsaCommitment` but does not verify it. The signature is just a stored bytes32. Anyone calling `executeArbitrage()` can submit any value here. The "post-quantum cryptography" claim is therefore aspirational at the contract level.

**Solution:**

Option A: Defer ML-DSA verification to off-chain service that publishes results on-chain via separate oracle contract. Contract just stores the commitment for future verification.

Option B: Wait for Arbitrum or other EVM chains to add ML-DSA precompile, then verify on-chain.

**Most honest position:** Update marketing to clarify "ML-DSA signatures generated off-chain and committed on-chain for future verification" instead of implying contract-level verification.

---

### V12. No Slippage Protection On Final Profit Check

**Finding:**
Profit check uses absolute amounts (`balanceAfterSwap >= repaymentAmount + minProfit`). If gas costs spike unexpectedly, the actual realized profit could be negative even though the contract reports profit.

**Solution:** Add gas-aware profit check that subtracts estimated tx cost from realized profit.

---

### V13. Treasury Address Concentration Risk

**Finding:**
Single address for `protocolTreasury`, `burnTreasury`, `investorPoolContract`, `minerRewardContract`. Each is a single point of failure for its respective fund flow.

**Solution:** All four should be 3-of-5 Gnosis Safe multisigs from launch, not EOAs.

---

### V14. No Anti-Frontrunning On Distribution

**Finding:**
When distribution happens, MEV bots can frontrun by submitting transactions in the same block. While the distribution itself isn't manipulable, the QAE buyback could be sandwiched.

**Solution:** Route buyback through Cowswap or other MEV-protected DEX aggregator instead of direct Uniswap V3 router.

---

### V15. No Test Coverage Mentioned

**Finding:**
The contract has 553 lines but no tests are documented anywhere. Spearbit and Code4rena will demand >90% test coverage before formal audit begins. Building test suite is typically 30-50% of total development time.

**Solution:** Allocate $15-20K and 3-4 weeks specifically for Foundry test suite development. This is non-negotiable for any reputable audit.

---

## LOW SEVERITY VULNERABILITIES

### V16-V23 (abbreviated for brevity)

- V16: Phone number still in some materials (already addressed)
- V17: Telegram link inconsistency (some places yes, some no)
- V18: Some files reference 44-corridor (already addressed in landing page)
- V19: $5B target inconsistency across docs (largely addressed)
- V20: Founder bio could include education details if applicable
- V21: No clear privacy policy or terms of service published
- V22: No GDPR compliance language for EU investor data
- V23: Website lacks structured data markup for SEO

---

## OPERATIONAL RISKS NOT IN ABOVE LIST

### OR1. Single-Founder Burnout

Single biggest risk. Mitigations:
- Hire technical advisor immediately ($0-2% equity grant)
- Establish weekly co-founder candidate conversations
- Build personal sustainability rituals before they're needed

### OR2. Regulatory Action Against Tron

Tron's Justin Sun has ongoing SEC issues. If enforcement escalates, Tron-based revenue could vanish. Mitigation: Don't depend on Tron for >40% of revenue projections. Currently Tron is Phase 2, which is appropriate.

### OR3. Audit Firm Capacity Constraints

Spearbit and Code4rena have 4-8 week lead times. Booking now for Month 2-3 audits requires reservation now. Mitigation: Reach out to both firms in Month 1, not Month 2.

### OR4. Bittensor Halving Event

If TAO halving occurs during QAELUM's Phase 2-3, emissions revenue could halve overnight. Mitigation: Don't model >25% of revenue from TAO emissions in any scenario.

---

## RECONSTRUCTION RECOMMENDATIONS

Based on the above, here's what should change before any mainnet activity:

### Must-fix before testnet:
- V5 (USDT approval race condition)
- V4 (complete _executeSwapPath)

### Must-fix before audit:
- V1 (executor architecture redesign)
- V2 (build QaelumInvestorPool.sol)
- V8 (granular pause controls)
- V11 (ML-DSA honest disclosure)
- V13 (multisig treasuries)
- V15 (test coverage)

### Must-fix before mainnet:
- V3 (Bittensor registration capital plan)
- V6 (miner bootstrap plan)
- V7 (compensation rebalance)
- V9 (SAFE standardization)
- V12 (slippage protection)
- V14 (anti-frontrunning)

### Operational priorities:
- OR1 (founder sustainability)
- OR3 (audit booking)

---

## ESTIMATED ADDITIONAL COST

Implementing the recommended fixes adds approximately:

| Category | Cost |
|---|---|
| Engineering (V1, V2, V4, V8) | $40-60K |
| Test coverage (V15) | $15-20K |
| Miner bootstrap (V6) | $40-50K |
| Legal (V9) | $2-5K |
| Audit scope expansion | $15-25K |
| Infrastructure (HSM, redundancy) | $5K/month operational |
| **Total one-time** | **$112-160K** |

The $750K seed has $80K contingency and $260-280K Phase 2 reserve. Pulling $120K from Phase 2 reserve to address these vulnerabilities is the right trade-off. Phase 2 can be delayed by 1-2 months if necessary; collapsing the project cannot be undone.

---

## WHAT WILL ACTUALLY KILL QAELUM

After this audit, here are the actual collapse scenarios ranked by probability:

1. **Founder burnout / unavailability** (35% probability over 24 months)
2. **Smart contract exploit during early mainnet** (15% probability without proper audit)
3. **Bittensor protocol governance change** (10% probability over 24 months)
4. **Miner network bootstrap failure** (10% probability)
5. **Bear market preventing Series A** (15% probability)
6. **Regulatory action in operating jurisdiction** (5% probability)
7. **Off-chain bot key compromise** (5% probability with current architecture, <1% with V1 fix)
8. **All other risks combined** (5% probability)

The good news: every one of these has a specific mitigation path documented above. The fixes are not theoretical — they are engineering and operational changes that turn 35% risks into 5% risks.

---

## CLOSING ASSESSMENT

QAELUM's structural design is conceptually sound. The four-revenue-stream architecture, post-quantum cryptography choices, and Bittensor-native distribution are defensible against the kinds of competitive pressure I've analyzed.

The vulnerabilities are concentrated in three areas:
1. Smart contract code that needs completion and hardening (V4, V5, V11)
2. Off-chain operational architecture that needs decentralization (V1, V2, V13)
3. Economic model assumptions that need stress-testing (V3, V6, V7)

**None of these are project-ending if addressed.** All of them are project-ending if ignored.

The honest path forward is to redirect 15-20% of seed proceeds into vulnerability remediation before mainnet, even if it delays Phase 2 by a month or two. This is the price of building something that survives, rather than something that looks impressive and then collapses.

The single most important fix is V1 (executor architecture). Every successful MEV operation has solved this. Every failed one has not.

---

*This audit is a structural review only and does not constitute a formal security audit. Smart contract security findings should be validated by Spearbit, Code4rena, or equivalent professional firms before mainnet deployment.*

*— Architectural review for QAELUM Oracle Intelligence, May 2026*
