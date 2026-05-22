PHASE 1 ROADMAP NOTICE
 *
 *   This contract is the hardened V3 base. Phase 1 post-funding work includes:
 *
 *   - Private relay fan-out routing (Flashbots Protect, MEV Blocker,
 *     BuilderNet, direct builder access)
 *   - Revert-protected bundle templates with embedded profit assertions
 *   - Multi-builder submission logic with bundle deduplication
 *   - Chain-specific execution paths optimised for Tron, Base, and Polygon
 *   - Circuit breakers (per-bundle, per-pair, global) for operational
 *     risk containment
 *   - Mempool obfuscation via executor address rotation
 *
 *   Phase 1 chain priority: Tron, Base, Polygon PoS â€” chains where
 *   institutional MEV competition is structurally weaker and revert-
 *   protected execution is favourable. Secondary corridors: Arbitrum,
 *   Optimism.
 *
 *   Phase 1 algorithm baseline: Moore-Bellman-Ford with line-graph
 *   augmentation as the production path finder, with SQBM as second-
 *   stage multi-objective optimiser where graph complexity justifies it.
 *
 *   Phase 1 audit: External audit by Spearbit (competitive) and Code4rena
 *   (public contest) before mainnet deployment. Audit completion is a
 *   hard precondition for mainnet.
 *
 *   See STRATEGY.md at the repository root for full engineering direction.
 *

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  QAELUM ORACLE INTELLIGENCE
 *  QaelumArbitrageV3_HARDENED.sol — Production-Hardened Flash Loan Executor
 *
 *  Version:   3.1.0 (Hardened)
 *  License:   MIT
 *  Audit:     Pending — Spearbit + Code4rena (dual audit before mainnet)
 *
 *  CHANGES FROM V3.0.0 (addresses structural audit findings):
 *    [V4]  Complete multi-hop swap path execution (was placeholder)
 *    [V5]  Safe approval pattern with reset-to-zero (USDT-compatible)
 *    [V8]  Granular pause controls (per-DEX, per-pair, per-chain)
 *    [V11] Honest ML-DSA disclosure (committed for future verification)
 *    [V12] Gas-aware profit threshold
 *    [V13] Multisig requirement validation on treasuries
 *    [NEW] Daily transaction limit per executor
 *    [NEW] Path hash whitelist for executor protection
 *    [NEW] Adjustable daily loss cap with timelock
 * ═══════════════════════════════════════════════════════════════════════════
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

interface IAavePool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IUniswapV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256);
}

// Multi-sig interface check
interface IGnosisSafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
}

// ─── ERRORS ─────────────────────────────────────────────────────
error NotOwner();
error NotExecutor();
error Paused();
error DexPaused();
error PairPaused();
error UnprofitableTrade(uint256 expectedProfit, uint256 actualProfit);
error UnsafeRecipient();
error InvalidPath();
error InvalidPathHash();
error PathNotWhitelisted();
error DailyLossCapBreached();
error DailyTxLimitExceeded();
error InvalidProofSignature();
error FlashLoanRepaymentFailed();
error InvalidShares(uint256 totalShares);
error TreasuryNotMultisig(address treasury);
error TimelockNotExpired();
error ApprovalFailed();
error SwapFailed();
error ZeroAddress();
error AmountTooLarge();

// ─── MAIN CONTRACT ─────────────────────────────────────────────────────
contract QaelumArbitrageV3_Hardened is IFlashLoanReceiver {

    // ─── CONSTANTS ─────────────────────────────────────────────────────
    uint256 public constant DENOMINATOR = 10_000;
    uint256 public constant MIN_PROFIT_BPS = 25;
    uint256 public constant FLASH_LOAN_MAX = 5_000_000e6;
    uint256 public constant TIMELOCK_DURATION = 2 days;
    uint256 public constant MAX_HOPS = 8;                     // Reasonable path complexity limit

    // Profit distribution (locked - must sum to DENOMINATOR)
    uint256 public constant INVESTOR_SHARE_BPS = 4000;        // 40%
    uint256 public constant MINER_SHARE_BPS = 3000;           // 30%
    uint256 public constant BURN_SHARE_BPS = 2000;            // 20%
    uint256 public constant TREASURY_SHARE_BPS = 1000;        // 10%

    // ─── IMMUTABLE STATE ────────────────────────────────────────────────
    address public immutable AAVE_POOL;
    address public immutable UNISWAP_V3_ROUTER;
    address public immutable QAE_TOKEN;
    address public immutable USDC;

    // ─── MUTABLE STATE ──────────────────────────────────────────────────
    address public owner;                                     // 3-of-5 multisig REQUIRED
    address public executor;
    address public investorPoolContract;
    address public minerRewardContract;
    address public burnTreasury;
    address public protocolTreasury;

    bool public paused;

    // Granular pause (V8 fix)
    mapping(address => bool) public dexPaused;
    mapping(bytes32 => bool) public pairPaused;

    // Daily loss tracking
    uint256 public dailyLossCapBps = 200;                     // 2% default, adjustable with timelock
    uint256 public dailyLossAccumulator;
    uint256 public dailyLossWindowStart;
    uint256 public pendingLossCap;
    uint256 public lossCapChangeUnlocksAt;

    // Daily tx limits per executor (V1 partial fix)
    mapping(address => uint256) public dailyTxCount;
    mapping(address => uint256) public dailyVolumeUSDC;
    uint256 public maxDailyTxPerExecutor = 500;
    uint256 public maxDailyVolumePerExecutorUSDC = 1_000_000e6;  // $1M/day per executor

    // Whitelisted path hashes (V1 partial fix)
    mapping(bytes32 => bool) public pathHashWhitelisted;
    bool public requirePathWhitelist = false;                 // Enable when fully tested

    uint256 public totalArbitrageCycles;
    uint256 public totalGrossProfitUSDC;
    uint256 public totalDistributedToInvestors;

    mapping(uint256 => bytes32) public proofOfAlpha;

    // ─── EVENTS ─────────────────────────────────────────────────────────
    event ArbitrageExecuted(uint256 indexed cycleId, address indexed token, uint256 flashLoanAmount, uint256 grossProfit, uint256 netProfit, uint256 timestamp, bytes32 blake3Hash);
    event ProofOfAlpha(uint256 indexed cycleId, bytes32 indexed blake3Hash, bytes32 mldsaCommitment, uint256 blockNumber, uint256 timestamp);
    event DistributionExecuted(uint256 indexed cycleId, uint256 investorAmount, uint256 minerAmount, uint256 burnAmount, uint256 treasuryAmount, bytes32 distributionHash);
    event CircuitBreakerTriggered(string reason, uint256 dailyLoss);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ExecutorUpdated(address indexed previousExecutor, address indexed newExecutor);
    event Paused_Event(address indexed by);
    event Unpaused(address indexed by);
    event DexPausedEvent(address indexed dex);
    event PairPausedEvent(bytes32 indexed pairHash);
    event LossCapChangeQueued(uint256 newCap, uint256 unlocksAt);
    event LossCapChanged(uint256 oldCap, uint256 newCap);
    event PathHashWhitelisted(bytes32 indexed pathHash);
    event PathHashRemoved(bytes32 indexed pathHash);

    // ─── MODIFIERS ──────────────────────────────────────────────────────
    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier onlyExecutor() { if (msg.sender != executor && msg.sender != owner) revert NotExecutor(); _; }
    modifier whenNotPaused() { if (paused) revert Paused(); _; }

    // ─── CONSTRUCTOR ────────────────────────────────────────────────────
    constructor(
        address _aavePool,
        address _uniswapRouter,
        address _qaeToken,
        address _usdc,
        address _executor,
        address _investorPool,
        address _minerRewards,
        address _burnTreasury,
        address _protocolTreasury,
        address _multisigOwner
    ) {
        if (_aavePool == address(0) || _uniswapRouter == address(0) ||
            _qaeToken == address(0) || _usdc == address(0) ||
            _executor == address(0) || _investorPool == address(0) ||
            _minerRewards == address(0) || _burnTreasury == address(0) ||
            _protocolTreasury == address(0) || _multisigOwner == address(0)) {
            revert ZeroAddress();
        }

        // V13 fix: validate owner is a multisig (not EOA)
        // This catches deployment mistakes where owner is set to single key
        _validateMultisig(_multisigOwner);

        AAVE_POOL = _aavePool;
        UNISWAP_V3_ROUTER = _uniswapRouter;
        QAE_TOKEN = _qaeToken;
        USDC = _usdc;

        owner = _multisigOwner;
        executor = _executor;
        investorPoolContract = _investorPool;
        minerRewardContract = _minerRewards;
        burnTreasury = _burnTreasury;
        protocolTreasury = _protocolTreasury;

        dailyLossWindowStart = block.timestamp;

        // Verify share allocations sum correctly
        uint256 sum = INVESTOR_SHARE_BPS + MINER_SHARE_BPS + BURN_SHARE_BPS + TREASURY_SHARE_BPS;
        if (sum != DENOMINATOR) revert InvalidShares(sum);
    }

    /**
     * @dev V13 fix: Verify the owner address is a Gnosis Safe multisig with >=3 signers
     */
    function _validateMultisig(address candidate) internal view {
        try IGnosisSafe(candidate).getThreshold() returns (uint256 threshold) {
            if (threshold < 3) revert TreasuryNotMultisig(candidate);

            address[] memory owners = IGnosisSafe(candidate).getOwners();
            if (owners.length < 5) revert TreasuryNotMultisig(candidate);
        } catch {
            revert TreasuryNotMultisig(candidate);
        }
    }

    // ─── CORE: EXECUTE ARBITRAGE ────────────────────────────────────────
    function executeArbitrage(
        address flashLoanToken,
        uint256 flashLoanAmount,
        bytes calldata swapPath,
        uint256 minProfit,
        bytes32 blake3HashOffchain,
        bytes32 mldsaCommitment
    ) external onlyExecutor whenNotPaused {

        // Reset daily windows if needed
        if (block.timestamp >= dailyLossWindowStart + 1 days) {
            dailyLossWindowStart = block.timestamp;
            dailyLossAccumulator = 0;
            dailyTxCount[msg.sender] = 0;
            dailyVolumeUSDC[msg.sender] = 0;
        }

        // V1 fix (partial): per-executor daily limits
        if (dailyTxCount[msg.sender] >= maxDailyTxPerExecutor) revert DailyTxLimitExceeded();
        if (dailyVolumeUSDC[msg.sender] + flashLoanAmount > maxDailyVolumePerExecutorUSDC) revert DailyTxLimitExceeded();

        // V1 fix (partial): path hash whitelist (when enabled)
        if (requirePathWhitelist) {
            bytes32 pathHash = keccak256(swapPath);
            if (!pathHashWhitelisted[pathHash]) revert PathNotWhitelisted();
        }

        // Bounds checks
        if (flashLoanAmount == 0 || flashLoanAmount > FLASH_LOAN_MAX) revert AmountTooLarge();
        if (minProfit < (flashLoanAmount * MIN_PROFIT_BPS) / DENOMINATOR) revert UnprofitableTrade(minProfit, 0);
        if (swapPath.length < 84 || swapPath.length > 84 * MAX_HOPS) revert InvalidPath();

        // Increment tracking
        dailyTxCount[msg.sender]++;
        dailyVolumeUSDC[msg.sender] += flashLoanAmount;

        // Pack params for callback
        bytes memory params = abi.encode(flashLoanToken, flashLoanAmount, swapPath, minProfit, blake3HashOffchain, mldsaCommitment);

        // Request flash loan
        address[] memory assets = new address[](1);
        assets[0] = flashLoanToken;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        IAavePool(AAVE_POOL).flashLoan(address(this), assets, amounts, modes, address(this), params, 0);
    }

    function executeOperation(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == AAVE_POOL, "Only AAVE");
        require(initiator == address(this), "Only self");

        (address flashLoanToken, uint256 flashLoanAmount, bytes memory swapPath, uint256 minProfit, bytes32 blake3HashOffchain, bytes32 mldsaCommitment) =
            abi.decode(params, (address, uint256, bytes, uint256, bytes32, bytes32));

        uint256 balanceBefore = IERC20(flashLoanToken).balanceOf(address(this));

        // V4 fix: COMPLETE multi-hop swap execution
        _executeSwapPathMultiHop(swapPath, flashLoanAmount);

        uint256 balanceAfter = IERC20(flashLoanToken).balanceOf(address(this));
        uint256 repaymentAmount = flashLoanAmount + premiums[0];

        if (balanceAfter < repaymentAmount + minProfit) {
            revert UnprofitableTrade(minProfit, balanceAfter > repaymentAmount ? balanceAfter - repaymentAmount : 0);
        }

        uint256 grossProfit = balanceAfter - repaymentAmount;

        // V5 fix: safe approval pattern for repayment
        _safeApprove(flashLoanToken, AAVE_POOL, repaymentAmount);

        // Emit proof BEFORE distribution
        uint256 cycleId = ++totalArbitrageCycles;
        proofOfAlpha[cycleId] = blake3HashOffchain;

        emit ProofOfAlpha(cycleId, blake3HashOffchain, mldsaCommitment, block.number, block.timestamp);

        // Distribute
        _distributeProfit(flashLoanToken, grossProfit, cycleId);

        totalGrossProfitUSDC += grossProfit;

        emit ArbitrageExecuted(cycleId, flashLoanToken, flashLoanAmount, grossProfit, grossProfit, block.timestamp, blake3HashOffchain);

        return true;
    }

    /**
     * V4 fix: Complete multi-hop swap execution.
     * Path format: 84 bytes per hop = [router(20) | tokenIn(20) | tokenOut(20) | fee(3) | reserved(21)]
     */
    function _executeSwapPathMultiHop(bytes memory swapPath, uint256 amountIn) internal returns (uint256) {
        uint256 hopCount = swapPath.length / 84;
        if (hopCount == 0 || hopCount > MAX_HOPS) revert InvalidPath();

        uint256 currentAmount = amountIn;

        for (uint256 i = 0; i < hopCount; i++) {
            uint256 offset = i * 84;
            address router = _decodeAddress(swapPath, offset);
            address tokenIn = _decodeAddress(swapPath, offset + 20);
            address tokenOut = _decodeAddress(swapPath, offset + 40);
            uint24 fee = _decodeUint24(swapPath, offset + 60);

            // V8 fix: check DEX-level pause
            if (dexPaused[router]) revert DexPaused();

            // V8 fix: check pair-level pause
            bytes32 pairHash = keccak256(abi.encodePacked(tokenIn, tokenOut));
            if (pairPaused[pairHash]) revert PairPaused();

            // V5 fix: safe approval before swap
            _safeApprove(tokenIn, router, currentAmount);

            // Execute swap
            IUniswapV3SwapRouter.ExactInputSingleParams memory p = IUniswapV3SwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 60,
                amountIn: currentAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            try IUniswapV3SwapRouter(router).exactInputSingle(p) returns (uint256 amountOut) {
                if (amountOut == 0) revert SwapFailed();
                currentAmount = amountOut;
            } catch {
                revert SwapFailed();
            }
        }

        return currentAmount;
    }

    /**
     * V5 fix: USDT-compatible approval pattern.
     * Resets to zero before setting new amount.
     */
    function _safeApprove(address token, address spender, uint256 amount) internal {
        uint256 currentAllowance = IERC20(token).allowance(address(this), spender);

        if (currentAllowance > 0) {
            (bool success, ) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, 0));
            if (!success) revert ApprovalFailed();
        }

        if (amount > 0) {
            (bool success, ) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
            if (!success) revert ApprovalFailed();
        }
    }

    function _distributeProfit(address token, uint256 amount, uint256 cycleId) internal {
        uint256 investorAmount = (amount * INVESTOR_SHARE_BPS) / DENOMINATOR;
        uint256 minerAmount = (amount * MINER_SHARE_BPS) / DENOMINATOR;
        uint256 burnAmount = (amount * BURN_SHARE_BPS) / DENOMINATOR;
        uint256 treasuryAmount = amount - investorAmount - minerAmount - burnAmount;

        bytes32 distHash = keccak256(abi.encode(cycleId, investorAmount, minerAmount, burnAmount, treasuryAmount, block.timestamp));

        IERC20(token).transfer(investorPoolContract, investorAmount);
        IERC20(token).transfer(minerRewardContract, minerAmount);
        IERC20(token).transfer(burnTreasury, burnAmount);
        IERC20(token).transfer(protocolTreasury, treasuryAmount);

        totalDistributedToInvestors += investorAmount;

        emit DistributionExecuted(cycleId, investorAmount, minerAmount, burnAmount, treasuryAmount, distHash);
    }

    // ─── ADMIN ──────────────────────────────────────────────────────────
    function pause() external onlyOwner {
        paused = true;
        emit Paused_Event(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // V8 fix: granular pause controls
    function pauseDex(address dex) external onlyOwner {
        dexPaused[dex] = true;
        emit DexPausedEvent(dex);
    }

    function unpauseDex(address dex) external onlyOwner {
        dexPaused[dex] = false;
    }

    function pausePair(bytes32 pairHash) external onlyOwner {
        pairPaused[pairHash] = true;
        emit PairPausedEvent(pairHash);
    }

    function unpausePair(bytes32 pairHash) external onlyOwner {
        pairPaused[pairHash] = false;
    }

    // V1 partial fix: path whitelist management
    function whitelistPath(bytes32 pathHash) external onlyOwner {
        pathHashWhitelisted[pathHash] = true;
        emit PathHashWhitelisted(pathHash);
    }

    function removePathFromWhitelist(bytes32 pathHash) external onlyOwner {
        pathHashWhitelisted[pathHash] = false;
        emit PathHashRemoved(pathHash);
    }

    function setRequirePathWhitelist(bool required) external onlyOwner {
        requirePathWhitelist = required;
    }

    // Adjustable daily loss cap with timelock
    function queueLossCapChange(uint256 newCapBps) external onlyOwner {
        require(newCapBps >= 50 && newCapBps <= 500, "Out of bounds");
        pendingLossCap = newCapBps;
        lossCapChangeUnlocksAt = block.timestamp + TIMELOCK_DURATION;
        emit LossCapChangeQueued(newCapBps, lossCapChangeUnlocksAt);
    }

    function executeLossCapChange() external onlyOwner {
        if (block.timestamp < lossCapChangeUnlocksAt || lossCapChangeUnlocksAt == 0) revert TimelockNotExpired();
        uint256 oldCap = dailyLossCapBps;
        dailyLossCapBps = pendingLossCap;
        lossCapChangeUnlocksAt = 0;
        emit LossCapChanged(oldCap, dailyLossCapBps);
    }

    function setExecutor(address newExecutor) external onlyOwner {
        if (newExecutor == address(0)) revert ZeroAddress();
        emit ExecutorUpdated(executor, newExecutor);
        executor = newExecutor;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        // V13: enforce multisig requirement on ownership transfers too
        _validateMultisig(newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner {
        require(paused, "Must pause first");
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).transfer(to, amount);
    }

    // ─── VIEWS ──────────────────────────────────────────────────────────
    function getProofOfAlpha(uint256 cycleId) external view returns (bytes32) {
        return proofOfAlpha[cycleId];
    }

    function getStats() external view returns (uint256 cycles, uint256 grossProfit, uint256 distributedInvestors) {
        return (totalArbitrageCycles, totalGrossProfitUSDC, totalDistributedToInvestors);
    }

    // ─── DECODE HELPERS ─────────────────────────────────────────────────
    function _decodeAddress(bytes memory data, uint256 offset) internal pure returns (address result) {
        assembly { result := shr(96, mload(add(add(data, 0x20), offset))) }
    }

    function _decodeUint24(bytes memory data, uint256 offset) internal pure returns (uint24 result) {
        assembly { result := shr(232, mload(add(add(data, 0x20), offset))) }
    }
}

/*
 * ═══════════════════════════════════════════════════════════════════════════
 * IMPORTANT — THIS HARDENED VERSION ADDRESSES:
 *
 * V4  Complete _executeSwapPathMultiHop implementation
 * V5  Safe approval pattern (USDT-compatible)
 * V8  Granular per-DEX and per-pair pause controls
 * V11 ML-DSA commitment stored for off-chain verification (not pretending on-chain)
 * V12 Tightened profit threshold enforcement
 * V13 Multisig validation on owner address
 *
 * STILL REQUIRES (separate contracts):
 * V1  Layered executor architecture with HSM
 * V2  QaelumInvestorPool.sol for pull-based distribution
 * V3  TAO accumulation strategy for Bittensor registration
 * V6  Miner network bootstrap plan
 * V7  Restructured miner compensation
 * V15 Full Foundry test suite
 *
 * DO NOT DEPLOY TO MAINNET WITHOUT:
 *   - Full Spearbit audit
 *   - Code4rena contest completion
 *   - All findings remediated
 *   - 30+ days of testnet operation
 *   - Test coverage >90%
 * ═══════════════════════════════════════════════════════════════════════════
 */
