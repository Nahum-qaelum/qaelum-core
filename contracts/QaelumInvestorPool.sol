// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  QAELUM ORACLE INTELLIGENCE
 *  QaelumInvestorPool.sol — Pull-Based Investor Distribution
 *
 *  Version:   1.0.0
 *  License:   MIT
 *  Audit:     REQUIRED before any SAFE is signed
 *
 *  PURPOSE:
 *  Addresses Audit Finding V2 — eliminates founder custody risk by implementing
 *  pull-based withdrawal pattern. Investors call withdraw() themselves; founder
 *  cannot push funds to or away from specific investors.
 *
 *  KEY PROPERTIES:
 *    1. PULL-BASED       Investors withdraw their own funds. No founder pushing.
 *    2. SNAPSHOT-BASED   Profits accrue to share ratios at time of receipt.
 *    3. CLIFF + VEST     On-chain enforcement of vesting schedule per investor.
 *    4. REGISTRATION     Only during seed close window. Permanently locked after.
 *    5. NO ADMIN DRAIN   Founder cannot withdraw investor funds under any case.
 *
 *  WORKFLOW:
 *    Seed Close Period (Months 0-3):
 *      - Each investor signs SAFE off-chain
 *      - Founder calls registerInvestor() with their address + USD invested
 *      - When period closes, lockRegistration() makes the registry permanent
 *
 *    Phase 1+ (after first arbitrage cycle):
 *      - QaelumArbitrageV3 transfers 40% profit to this contract
 *      - Each investor can call withdraw() to claim their pro-rata share
 *      - Withdrawal is gated by their cliff and vesting schedule
 * ═══════════════════════════════════════════════════════════════════════════
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// ─── ERRORS ─────────────────────────────────────────────────────
error NotOwner();
error NotArbitrageContract();
error RegistrationLocked();
error RegistrationNotLocked();
error InvestorAlreadyRegistered();
error InvestorNotRegistered();
error BeforeCliff(uint256 cliffEnd, uint256 currentTime);
error NothingToWithdraw();
error ZeroAddress();
error ZeroAmount();
error InvalidVestingSchedule();
error TransferFailed();

contract QaelumInvestorPool {

    // ─── STRUCTS ────────────────────────────────────────────────────────
    struct Investor {
        uint256 usdInvested;          // Original SAFE amount in USD (6 decimals USDC)
        uint256 cliffEnd;             // Timestamp when first withdrawal allowed
        uint256 vestEnd;              // Timestamp when fully vested
        uint256 withdrawn;            // Cumulative USDC withdrawn to date
        bool registered;
    }

    // ─── STATE ──────────────────────────────────────────────────────────
    address public owner;                       // Multisig
    address public arbitrageContract;           // Only contract authorized to send profit
    address public immutable USDC;

    mapping(address => Investor) public investors;
    address[] public investorList;              // For enumeration

    uint256 public totalUSDInvested;            // Sum of all investor SAFE amounts
    uint256 public totalProfitReceived;         // Cumulative USDC received from arbitrage
    uint256 public totalWithdrawn;              // Cumulative USDC withdrawn by investors

    bool public registrationLocked;
    uint256 public registrationLockedAt;

    // ─── EVENTS ─────────────────────────────────────────────────────────
    event InvestorRegistered(address indexed investor, uint256 usdInvested, uint256 cliffEnd, uint256 vestEnd);
    event RegistrationFinalLocked(uint256 timestamp, uint256 totalInvestors, uint256 totalUSD);
    event ProfitReceived(uint256 amount, uint256 newTotal);
    event InvestorWithdrew(address indexed investor, uint256 amount, uint256 cumulativeWithdrawn);
    event ArbitrageContractSet(address indexed contractAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ─── MODIFIERS ──────────────────────────────────────────────────────
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyArbitrageContract() {
        if (msg.sender != arbitrageContract) revert NotArbitrageContract();
        _;
    }

    // ─── CONSTRUCTOR ────────────────────────────────────────────────────
    constructor(address _usdc, address _multisigOwner) {
        if (_usdc == address(0) || _multisigOwner == address(0)) revert ZeroAddress();
        USDC = _usdc;
        owner = _multisigOwner;
    }

    /**
     * @notice Connect this pool to the arbitrage contract. Can only be set once.
     * @dev After arbitrageContract is set, only that contract can call receiveProfit().
     */
    function setArbitrageContract(address _arbitrageContract) external onlyOwner {
        if (_arbitrageContract == address(0)) revert ZeroAddress();
        require(arbitrageContract == address(0), "Already set");
        arbitrageContract = _arbitrageContract;
        emit ArbitrageContractSet(_arbitrageContract);
    }

    /**
     * @notice Register an investor with their SAFE terms.
     * @dev Can only be called before registrationLocked.
     * @param investor Investor's wallet address (where they'll withdraw to)
     * @param usdInvested USD amount invested via SAFE (6 decimals)
     * @param cliffMonths Months from now until withdrawals can begin
     * @param vestMonths Total months until fully vested
     */
    function registerInvestor(
        address investor,
        uint256 usdInvested,
        uint256 cliffMonths,
        uint256 vestMonths
    ) external onlyOwner {
        if (registrationLocked) revert RegistrationLocked();
        if (investor == address(0)) revert ZeroAddress();
        if (usdInvested == 0) revert ZeroAmount();
        if (vestMonths < cliffMonths) revert InvalidVestingSchedule();
        if (investors[investor].registered) revert InvestorAlreadyRegistered();

        uint256 cliffEnd = block.timestamp + (cliffMonths * 30 days);
        uint256 vestEnd = block.timestamp + (vestMonths * 30 days);

        investors[investor] = Investor({
            usdInvested: usdInvested,
            cliffEnd: cliffEnd,
            vestEnd: vestEnd,
            withdrawn: 0,
            registered: true
        });

        investorList.push(investor);
        totalUSDInvested += usdInvested;

        emit InvestorRegistered(investor, usdInvested, cliffEnd, vestEnd);
    }

    /**
     * @notice Permanently lock investor registration.
     * @dev After this is called, no new investors can be added and no existing
     *      investor's terms can be modified. This is the trust commitment to
     *      seed investors that their share won't be diluted post-close.
     */
    function lockRegistration() external onlyOwner {
        if (registrationLocked) revert RegistrationLocked();
        registrationLocked = true;
        registrationLockedAt = block.timestamp;
        emit RegistrationFinalLocked(block.timestamp, investorList.length, totalUSDInvested);
    }

    /**
     * @notice Receive arbitrage profit from the arbitrage contract.
     * @dev Only the arbitrage contract can call this. USDC must be approved first.
     */
    function receiveProfit(uint256 amount) external onlyArbitrageContract {
        if (amount == 0) revert ZeroAmount();
        if (!registrationLocked) revert RegistrationNotLocked();

        bool success = IERC20(USDC).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        totalProfitReceived += amount;
        emit ProfitReceived(amount, totalProfitReceived);
    }

    /**
     * @notice Investor withdraws their vested pro-rata share.
     * @dev Pull-based. Investor calls this directly. Calculates owed amount,
     *      enforces cliff and vesting, transfers USDC to investor.
     */
    function withdraw() external {
        Investor storage inv = investors[msg.sender];
        if (!inv.registered) revert InvestorNotRegistered();
        if (block.timestamp < inv.cliffEnd) revert BeforeCliff(inv.cliffEnd, block.timestamp);

        uint256 vestedFraction = _calculateVestedFraction(inv);
        uint256 totalOwed = (totalProfitReceived * inv.usdInvested * vestedFraction) / (totalUSDInvested * 1e18);
        uint256 toWithdraw = totalOwed - inv.withdrawn;

        if (toWithdraw == 0) revert NothingToWithdraw();

        inv.withdrawn = totalOwed;
        totalWithdrawn += toWithdraw;

        bool success = IERC20(USDC).transfer(msg.sender, toWithdraw);
        if (!success) revert TransferFailed();

        emit InvestorWithdrew(msg.sender, toWithdraw, totalOwed);
    }

    /**
     * @dev Calculate vested fraction at current time, scaled to 1e18.
     *      Returns 0 if before cliff, 1e18 if fully vested, linear in between.
     */
    function _calculateVestedFraction(Investor memory inv) internal view returns (uint256) {
        if (block.timestamp < inv.cliffEnd) return 0;
        if (block.timestamp >= inv.vestEnd) return 1e18;

        uint256 vestDuration = inv.vestEnd - inv.cliffEnd;
        uint256 elapsed = block.timestamp - inv.cliffEnd;
        return (elapsed * 1e18) / vestDuration;
    }

    // ─── VIEWS ──────────────────────────────────────────────────────────
    function getWithdrawableAmount(address investor) external view returns (uint256) {
        Investor memory inv = investors[investor];
        if (!inv.registered || block.timestamp < inv.cliffEnd) return 0;

        uint256 vestedFraction = _calculateVestedFraction(inv);
        uint256 totalOwed = (totalProfitReceived * inv.usdInvested * vestedFraction) / (totalUSDInvested * 1e18);

        if (totalOwed <= inv.withdrawn) return 0;
        return totalOwed - inv.withdrawn;
    }

    function getInvestorCount() external view returns (uint256) {
        return investorList.length;
    }

    function getInvestorAt(uint256 index) external view returns (address) {
        return investorList[index];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/*
 * ═══════════════════════════════════════════════════════════════════════════
 * DEPLOYMENT WORKFLOW:
 *
 * 1. Deploy QaelumInvestorPool with multisig owner address
 * 2. Deploy QaelumArbitrageV3_Hardened with this pool's address as investorPoolContract
 * 3. Call setArbitrageContract(arbitrageContract) on this pool ONCE
 * 4. As each seed investor signs SAFE, call registerInvestor() with their terms
 * 5. When seed round closes, call lockRegistration() to make it permanent
 * 6. Arbitrage profits automatically flow to this pool
 * 7. Investors call withdraw() at any time after their cliff
 *
 * AUDIT NOTES:
 * - This contract has NO functions that allow owner to drain investor funds
 * - The only "admin" action post-lock is failed; nothing can change registry
 * - Owner can never call withdraw() or change investor balances after lock
 * - The lockRegistration() is the trust commitment — once done, irreversible
 *
 * INVESTOR FRIENDLY PROPERTIES:
 * - Pull-based: investors don't depend on founder pushing payments
 * - Snapshot-based: each profit deposit benefits all locked investors pro-rata
 * - Cliff + vest: standard SAFE terms enforced on-chain
 * - Withdrawn tracking: no double-claiming possible
 * - Permanent registry: seed terms cannot be diluted by later investors
 * ═══════════════════════════════════════════════════════════════════════════
 */
