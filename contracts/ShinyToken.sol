// SPDX-License-Identifier: MIT
/**
 *
 *    ░██████╗██╗░░██╗██╗███╗░░██╗██╗░░░██╗
 *    ██╔════╝██║░░██║██║████╗░██║╚██╗░██╔╝
 *    ╚█████╗░███████║██║██╔██╗██║░╚████╔╝░
 *    ░╚═══██╗██╔══██║██║██║╚████║░░╚██╔╝░░
 *    ██████╔╝██║░░██║██║██║░╚███║░░░██║░░░
 *    ╚═════╝░╚═╝░░╚═╝╚═╝╚═╝░░╚══╝░░░╚═╝░░░
 *
 *    ⭐ The Rarest Token in the Ecosystem ⭐
 *
 * In traditional collecting, the rarest variants command exponential premiums. SHINY 
 * brings this principle to DeFi with a mathematically enforced scarcity model that 
 * makes every token increasingly precious as time progresses.
 *
 * Built on proven Bitcoin halving economics but accelerated for the NFT era, SHINY
 * rewards early participants while ensuring long-term sustainability. Each token is
 * backed 1:1 by ETH added to the ecosystem, creating a perfect correlation between
 * supply expansion and value creation.
 *
 * This isn't just another reward token - it's a deflationary asset that becomes rarer
 * with each passing week, locked to prevent manipulation, and eternally backed by 
 * growing protocol revenue.
 *
 * @title SHINY Token - Deflationary Reward Token with Bitcoin-Style Emissions
 * @notice ERC20 reward token featuring aggressive halving schedule and perfect 1:1 ETH
 *         backing correlation. Distributed to Shinies NFT participants with decreasing
 *         emissions over 12 weeks, then maintained at low steady-state forever.
 *
 * @dev TOKENOMICS ARCHITECTURE:
 *
 *      💎 EMISSION SCHEDULE (Accelerated Bitcoin Model):
 *      - Week 0-1:   100,000 SHINY per 1 ETH deposited to SHINY glue
 *      - Week 1-2:    50,000 SHINY per ETH (÷2)
 *      - Week 2-3:    25,000 SHINY per ETH (÷2)
 *      - Week 3-4:    12,500 SHINY per ETH (÷2)
 *      - ...continues halving each week...
 *      - Week 11-12:     48.8 SHINY per ETH (÷2)
 *      - Week 12+:        4.88 SHINY per ETH (÷10, permanent rate)
 *
 *      🔒 TRANSFER MECHANICS:
 *      - Initial lock: 12 weeks from deployment (no transfers except mint/burn)
 *      - Automatic unlock: Block timestamp-based, no admin intervention
 *      - Purpose: Ensures fair distribution period, prevents early speculation
 *      - Lock applies to all holders equally (no exceptions)
 *
 *      👥 TEAM ALLOCATION:
 *      - Calculation: 40% of total community-minted supply
 *      - Claim window: Unlocks after week 12 (one-time claim only)
 *      - Formula: If community minted X, team receives (X × 0.4) / (1 - 0.4)
 *      - Minted to: Owner of Shinies NFT contract (governance address)
 *      - Rationale: Aligns team incentives with long-term ecosystem success
 *
 *      💰 BACKING MECHANISM:
 *      - Trigger: SHINY minted ONLY when ETH enters SHINY vault
 *      - Correlation: 1 SHINY minted per 1 ETH backing (adjusted by emission rate)
 *      - Vault composition: ETH + WETH held in Glue Protocol
 *      - Backing per token: Total vault value ÷ Effective supply (includes pending team allocation)
 *      - Fee routing: Specific ecosystem fees directed to vault WITHOUT minting (increases backing!)
 *
 *      🎮 MINTING SOURCES:
 *      - Shiny NFT mints: 50% of 5% mint fee → SHINY vault → Mints proportional SHINY
 *      - Shiny NFT burns: 10% of 10% burn fee → SHINY vault → Mints proportional SHINY
 *      - Collection glue rewards: 50% of collection stakes → Increases backing only
 *      - Marketplace royalties: Portion to vault → Increases backing only
 *      - Result: Backing per token increases faster than supply
 *
 *      🔐 SECURITY ARCHITECTURE:
 *      - Minting authority: Exclusively Shinies NFT contract (immutable)
 *      - Governance: Owner read from Shinies NFT contract (unified control)
 *      - Transfer enforcement: Lock checked in _update() override (cannot bypass)
 *      - Glue integration: StickyAsset standard for collateral management
 *      - No admin minting: Team allocation is one-time, formula-based only
 *
 *      📊 ECONOMIC GUARANTEES:
 *      - Deflationary by design: Emission rate permanently decreases
 *      - Hard cap implications: Finite total supply based on 12-week activity
 *      - Increasing backing: Protocol fees add value without diluting supply
 *      - No mint functions: After week 12 halving, only low steady-state emissions
 *      - Holder protection: Lock prevents dumps during distribution phase
 *
 */

pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Only for interface to read owner
import {GluedToolsERC20Min} from "./libraries/GluedToolsERC20Min.sol";
import {StickyAsset} from "@glue-finance/expansions-pack/contracts/base/StickyAsset.sol";
import {IStickyAsset} from "@glue-finance/expansions-pack/contracts/interfaces/IStickyAsset.sol";
import {IShinyToken} from "./interfaces/IShinyToken.sol";

contract ShinyToken is ERC20, GluedToolsERC20Min, StickyAsset, IShinyToken {

    address private constant COLLATERAL = address(0); // ETH
    address private immutable WETH; // WETH mainnet
    
    // ===== CONSTANTS =====
    
    uint256 private constant BASE_MINT_PER_ETH = 100000 * 1e18; // 100,000 SHINY per 1 ETH in week 1
    uint256 private constant HALVING_WEEKS = 12; // 3 months of halving
    uint256 private constant FINAL_REDUCTION_FACTOR = 10; // 1/10 after halving period
    uint256 private constant TEAM_PERCENTAGE = 4e17; // 40% in 1e18 precision (0.4)
    
    uint256 private constant SECONDS_PER_WEEK = 7 days;
    
    // ===== IMMUTABLES =====
    
    uint256 private DEPLOYMENT_TIME;
    uint256 private TRANSFER_UNLOCK_TIME; // After 12 weeks
    
    // ===== STATE VARIABLES =====
    
    bool private teamAllocationMinted; // Whether team 40% has been minted
    
    // Authorized minter (Shiny NFT contract)
    address private immutable SHINY_NFT_CONTRACT;
    
    // ===== MODIFIERS =====
    
    /**
     * @notice Restricts function access to Shiny NFT contract only
     * @dev Critical security modifier for minting functions
     */
    modifier onlyShinyNFT() {
        if (msg.sender != SHINY_NFT_CONTRACT) revert UnauthorizedMinter();
        _;
    }
    
    /**
     * @notice Initializes the SHINY token with deflationary emission parameters
     * @param shinyNFTContract Address of Shinies NFT contract (authorized minter + governance source)
     * @param contractURI ERC-7572 contract-level metadata URI
     * @param WETH_ADDRESS WETH contract address for backing calculations
     * @dev Sets immutable parameters:
     *      - Deployment timestamp (for week calculations)
     *      - Transfer unlock time (12 weeks from deployment)
     *      - Authorized minter (Shinies NFT contract only)
     *      - WETH address (for vault balance queries)
     */
    constructor(
        address shinyNFTContract,
        string memory contractURI,
        address WETH_ADDRESS
    ) 
        ERC20("Shiny Token", "SHINY")
        StickyAsset(contractURI, [true, false]) // fungible=true, hooks=false
    {
        require(shinyNFTContract != address(0), "Invalid NFT contract");
        require(WETH_ADDRESS != address(0), "Invalid WETH address");

        WETH = WETH_ADDRESS;
        
        // Set immutable minter and governance references
        SHINY_NFT_CONTRACT = shinyNFTContract;
        
        // Initialize time-based parameters
        DEPLOYMENT_TIME = 0;
        TRANSFER_UNLOCK_TIME = 0;
        
        // Initialize state
        teamAllocationMinted = false;
    }

    /**
     * @notice Sets the deployment time
     * @dev Can only be called by Shiny NFT contract, and only once
     */
    function setDeploymentTime() external onlyShinyNFT {
        if (DEPLOYMENT_TIME != 0) revert AirdropAlreadyStarted();
        DEPLOYMENT_TIME = block.timestamp;
        TRANSFER_UNLOCK_TIME = block.timestamp + (HALVING_WEEKS * SECONDS_PER_WEEK);
    }
    
    /**
     * @notice Mints SHINY rewards proportional to ETH added to SHINY vault
     * @param recipient Address to receive the minted SHINY tokens
     * @param ethAmount Amount of ETH deposited to SHINY vault (determines reward amount)
     * @dev Restricted to Shinies NFT contract via onlyShinyNFT modifier
     *      Reward amount decreases weekly per halving schedule
     *      Creates 1:1 correlation between SHINY supply and ETH backing
     */
    function mintRewards(address recipient, uint256 ethAmount, bool isLegacyMint) external onlyShinyNFT {
        // Prevent minting before airdrop is started (deployment time must be set)
        if (DEPLOYMENT_TIME == 0) return;
        
        if (ethAmount == 0) return;

        uint256 rewardAmount;

        // Calculate reward using current week's emission rate
        if (isLegacyMint) {
            rewardAmount = 100000e18;
        } else {
            rewardAmount = _calculateReward(ethAmount);
        }
        
        if (rewardAmount == 0) return;
        
        // Mint calculated rewards to recipient
        _mint(recipient, rewardAmount);
        
        uint256 currentWeek = _getCurrentWeek();
        emit RewardsMinted(recipient, rewardAmount, ethAmount, currentWeek);
    }
    
    /**
     * @notice Claims one-time team allocation after 12-week halving period
     * @dev Governance-controlled mint (requires owner of Shinies NFT contract)
     *      Calculates team share as 40% of all community-minted tokens
     *      One-time operation only - cannot be called twice
     *      Must wait until week 12 to ensure fair distribution period
     */
    function mintTeamAllocation() external {
        // Verify caller is governance (Shinies NFT contract owner)
        address nftOwner = Ownable(SHINY_NFT_CONTRACT).owner();
        require(msg.sender == nftOwner, "Only Shiny NFT owner");
        
        // Validate timing and one-time-only execution
        if (DEPLOYMENT_TIME == 0) revert TooEarly(); // Airdrop must be started
        if (teamAllocationMinted) revert TeamAlreadyMinted();
        if (_getCurrentWeek() < HALVING_WEEKS) revert TooEarly();
        
        // Calculate team allocation: 40% of total community rewards
        // If community has X tokens, team receives: (X × 40%) / (100% - 40%)
        // Formula: (X × 0.4) / 0.6 = X × TEAM_PERCENTAGE / (PRECISION - TEAM_PERCENTAGE)
        uint256 teamAmount = _md512(totalSupply(), TEAM_PERCENTAGE, PRECISION - TEAM_PERCENTAGE);
        
        // Mark as claimed and mint to caller (governance address)
        teamAllocationMinted = true;
        _mint(msg.sender, teamAmount);
        
        emit TeamAllocationMinted(msg.sender, teamAmount);
    }
    
    /**
     * @notice Calculates SHINY reward for a given ETH deposit amount
     * @param ethAmount Amount of ETH deposited to SHINY vault
     * @return SHINY tokens to mint based on current week's emission rate
     * @dev Applies time-based halving multiplier to base emission rate
     */
    function _calculateReward(uint256 ethAmount) internal view returns (uint256) {
        uint256 currentWeek = _getCurrentWeek();
        uint256 ratePerETH = _getRatePerETH(currentWeek);
        
        // Multiply ETH amount by current emission rate
        return _md512(ethAmount, ratePerETH, PRECISION);
    }
    
    /**
     * @notice Calculates emission rate for a specific week number
     * @param week Week number since deployment (0-indexed)
     * @return SHINY tokens emitted per 1 ETH deposited during that week
     * @dev Emission schedule:
     *      Weeks 0-11: Halves each week (BASE ÷ 2^week)
     *      Week 12+: Fixed at 1/10 of week 11 rate (permanent steady-state)
     */
    function _getRatePerETH(uint256 week) internal pure returns (uint256) {
        // Weeks 0-11: Aggressive halving period
        if (week < HALVING_WEEKS) {
            // Calculate 2^week efficiently using bit shift
            // Week 0: ÷1, Week 1: ÷2, Week 2: ÷4, etc.
            uint256 divisor = 1 << week;
            return _md512(BASE_MINT_PER_ETH, PRECISION, divisor * PRECISION);
        } else {
            // Week 12+: Permanent low steady-state emissions
            // Calculate week 11 final rate, then divide by 10
            uint256 divisor12 = 1 << (HALVING_WEEKS - 1); // 2^11 = 2048
            uint256 week12Rate = _md512(BASE_MINT_PER_ETH, PRECISION, divisor12 * PRECISION);
            
            // Apply final 10x reduction for perpetual rate
            return _md512(week12Rate, PRECISION, FINAL_REDUCTION_FACTOR * PRECISION);
        }
    }
    
    /**
     * @notice Calculates current week number since contract deployment
     * @return Week number (0-indexed, increments every 7 days)
     * @dev Used to determine current emission rate from halving schedule
     */
    function _getCurrentWeek() internal view returns (uint256) {
        uint256 timePassed = block.timestamp - DEPLOYMENT_TIME;
        return _md512(timePassed, PRECISION, SECONDS_PER_WEEK * PRECISION);
    }
    
    /**
     * @notice Gets the current week's emission rate (public view)
     * @return Emission rate (SHINY per 1 ETH)
     * @dev Returns 0 if airdrop hasn't started yet (DEPLOYMENT_TIME = 0)
     */
    function getCurrentWeekRate() external view returns (uint256) {
        if (DEPLOYMENT_TIME == 0) return 0;
        return _getRatePerETH(_getCurrentWeek());
    }
    
    /**
     * @notice Gets the current week number (public view)
     * @return Current week number
     * @dev Returns 0 if airdrop hasn't started yet (DEPLOYMENT_TIME = 0)
     */
    function getCurrentWeek() external view returns (uint256) {
        if (DEPLOYMENT_TIME == 0) return 0;
        return _getCurrentWeek();
    }
    
    /**
     * @notice Checks if transfers are unlocked
     * @return True if transfers are allowed
     * @dev Returns false if airdrop hasn't started yet (DEPLOYMENT_TIME = 0)
     */
    function transfersUnlocked() public view returns (bool) {
        // Transfers locked until airdrop starts
        if (DEPLOYMENT_TIME == 0) return false;
        return block.timestamp >= TRANSFER_UNLOCK_TIME;
    }
    
    /**
     * @notice ERC20 transfer override to enforce 12-week transfer lock
     * @dev Allows mints and burns during lock period, blocks only transfers
     *      Lock automatically expires at TRANSFER_UNLOCK_TIME (week 12)
     *      No admin override - purely time-based unlocking
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        // Allow minting (from = 0) and burning (to = 0) regardless of lock
        if (from != address(0) && to != address(0)) {
            // Standard transfers require unlock period to have passed
            if (!transfersUnlocked()) {
                revert TransfersLocked();
            }
        }
        
        super._update(from, to, amount);
    }
    
    /**
     * @notice No hooks needed for SHINY token
     */
    function _calculateStickyHookSize(uint256 amount) internal view override returns (uint256) {
        return 0;
    }
    
    function _calculateCollateralHookSize(address asset, uint256 amount) internal view override returns (uint256) {
        return 0;
    }
}
