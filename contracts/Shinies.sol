// SPDX-License-Identifier: MIT
/**
 *
 *    ░██████╗██╗░░██╗██╗███╗░░██╗██╗███████╗░██████╗
 *    ██╔════╝██║░░██║██║████╗░██║██║██╔════╝██╔════╝
 *    ╚█████╗░███████║██║██╔██╗██║██║█████╗░░╚█████╗░
 *    ░╚═══██╗██╔══██║██║██║╚████║██║██╔══╝░░░╚═══██╗
 *    ██████╔╝██║░░██║██║██║░╚███║██║███████╗██████╔╝
 *    ╚═════╝░╚═╝░░╚═╝╚═╝╚═╝░░╚══╝╚═╝╚══════╝╚═════╝░
 *
 *    ✨ Mint 'Em All ✨
 *
 * Welcome to Shinies - where ordinary NFTs transform into extraordinary yield-bearing assets.
 * 
 * In the world of digital collectibles, there exists a tier beyond rare - a chromatic 
 * variant so valuable, so desirable, that collectors will search endlessly to find one.
 * Shinies represents this concept: wrap your blue-chip NFTs and receive gleaming variants
 * backed by the original asset PLUS accumulated yield from a revolutionary bonding curve.
 *
 * Each Shiny NFT is more than a wrapper - it's an evolution. Your NFT doesn't just sit
 * idle; it generates value through dynamic pricing mechanics, ecosystem fees, and dual-token
 * rewards. The longer the ecosystem thrives, the more valuable your Shiny becomes.
 *
 * @title Shinies - Multi-Collection NFT Vault with Dynamic Bonding Curve
 * @notice Transform blue-chip NFTs into yield-bearing Shiny variants with quadratic pricing
 *         and dual-token rewards. Each Shiny NFT is backed by the original asset plus 
 *         proportional ETH collateral and SHINY token emissions.
 *
 * @dev ARCHITECTURE OVERVIEW:
 *
 *      🎯 CORE MECHANICS:
 *      - Deposit whitelisted NFT → Mint Shiny NFT + Earn SHINY tokens
 *      - Burn Shiny NFT → Redeem original NFT + Proportional ETH/WETH from vault
 *      - Dynamic bonding curve adjusts price based on supply and collateral
 *      - Supply-based margin protects holders as collection grows
 *
 *      💰 ECONOMIC MODEL:
 *      - Base price: ~0.000054 ETH (accessible entry point)
 *      - Dynamic pricing adapts to market conditions and supply
 *      - Mint fee: 5% (50% to SHINY backing, 50% to treasury)
 *      - Burn fee: 10% (10% to SHINY backing, 50% to NFT vault, 40% to treasury)
 *      - All fees reinvested to strengthen ecosystem backing
 *
 *      🎁 DUAL-TOKEN REWARDS:
 *      - SHINY token: Deflationary reward token with Bitcoin-style halving
 *      - Emission schedule: 100K SHINY/ETH → halves weekly for 12 weeks → ÷10 forever
 *      - Team allocation: 40% of community minted (one-time, post-week 12)
 *      - Transfer lock: 12 weeks (ensures fair distribution phase)
 *      - Perfect backing: Each SHINY correlates 1:1 with ETH added to its vault
 *
 *      🏛️ GOVERNANCE & WHITELIST:
 *      - Initial: CryptoPunks + up to 9 owner-selected collections
 *      - Community requests: Stake 2% of SHINY supply to propose new collections
 *      - Owner approval process:
 *        · Accept: Collection whitelisted, stake handled per glue compatibility
 *        · Reject: Full stake refunded to requester
 *      - Glue-compatible collections receive bonus token allocations
 *      - Supports both enumerable and non-enumerable NFTs
 *      - Native CryptoPunks integration (custom transfer mechanism)
 *
 *      🔒 SECURITY FEATURES:
 *      - Glue Protocol integration for battle-tested collateral management
 *      - Reentrancy protection on all state-changing functions
 *      - Post-transfer ownership verification for all NFT operations
 *      - Atomic hook-based redemption ensures consistent state
 *      - Self-regulating bonding curve prevents manipulation
 *
 *      📊 BONDING CURVE MECHANICS:
 *      - Profit target dynamically calculated from mint/burn fees
 *      - Supply-based margin: Higher supply = Lower margin = Better holder protection
 *      - Round-trip efficiency accounts for ecosystem fee structure
 *      - Dilution factor compensates for supply growth
 *      - Minimum base price floor prevents price collapse
 *
 */

pragma solidity ^0.8.28;

/**
 * @dev Core OpenZeppelin contracts for ERC721 functionality and security
 */
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC4906.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {GluedToolsMin} from "./libraries/GluedToolsMin.sol";
import {StickyAsset} from "@glue-finance/expansions-pack/contracts/base/StickyAsset.sol";
import {IStickyAsset} from "@glue-finance/expansions-pack/contracts/interfaces/IStickyAsset.sol";
import {IShinies} from "./interfaces/IShinies.sol";
import {IShinyToken} from "./interfaces/IShinyToken.sol";
import {ICryptoPunks} from "./interfaces/ICryptoPunks.sol";

/**
 * @title Shinies - The Ultimate Multi-Collection NFT Vault
 * @notice Deposit blue-chip NFTs, receive Shiny NFTs backed by ETH + original NFT + SHINY rewards
 * @dev Implements quadratic bonding curve with Glue Protocol integration and dual-token economics
 *      Supports EIP-4906 for automatic marketplace metadata refresh
 */
contract Shinies is ERC721, ERC721Enumerable, GluedToolsMin, Ownable, StickyAsset, IShinies {
    
    // CryptoPunks contract address (Ethereum mainnet)
    address private constant CRYPTOPUNKS = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    
    // Fee structure (in 1e18 precision - PRECISION constant)
    uint256 private constant ECOSYSTEM_FEE_MINT = 5e16;        // 5% fee on mints
    uint256 private constant ECOSYSTEM_FEE_BURN = 1e17;        // 10% fee on burns
    uint256 private constant SHINY_GLUE_FEE = 5e17;            // 50% of mint fees to SHINY vault
    uint256 private constant SHINY_GLUE_FEE_BURN = 1e17;       // 10% of burn fees to SHINY vault
    
    // Supply parameters
    uint256 private constant BASE_MAX_SUPPLY = 1000;           // Base max supply: 1000 NFTs
    uint256 private WASTED_SUPPLY;                             // Counter for burned token IDs (never reused)
    uint256 private constant SUPPLY_BONUS_PER_COLLECTION = 100; // +100 max supply per additional collection
    uint256 private constant BASE_PRICE = 5494535415571705;   // Minimum mint price
    
    // Dynamic margin calculation based on supply distance from max
    // Provides automatic holder protection as collection approaches capacity
    // Higher supply = Lower margin = Better redemption rates for holders
    // uint256 private immutable marginBasisPoints; // Removed - now calculated dynamically
    
    // Initial whitelist capacity (owner can add up to this many collections directly)
    uint256 private constant INITIAL_COLLECTIONS_COUNT = 10;

    address private immutable WETH; // WETH
    
    // SHINY token and its GLUE
    address private SHINY_TOKEN;
    address private SHINY_GLUE;

    address private fee_receiver; // Fee receiver address

    string private baseURI; // Base URI for token metadata

    bool private TEST_ENDED; // TESTING PHASE ONLY

    // Whitelisted collections (1-indexed to match INITIAL_COLLECTIONS_COUNT semantic)
    address[] private whitelistedCollections; // Array of whitelisted collection addresses (index 0 unused)
    mapping(address => bool) private isWhitelisted; // Quick lookup for whitelist status
    mapping(address => uint256) private collectionId; // Collection address => ID (1-indexed)
    
    // Community whitelist governance
    uint256 private constant STAKE_PERCENTAGE = 2e16; // Required stake: 2% of SHINY total supply
    
    // Structs defined in IShinies interface - referenced with IShinies. prefix
    mapping(address => IShinies.WhitelistRequest) private whitelistRequests;
    uint256 private whitelistRequestsCount;
    mapping(uint256 => IShinies.OriginalNFT) private originalNFTs;

    // Events and errors are declared in IShinies interface
    
    /**
     * @notice Initializes the Shinies NFT contract with Glue Protocol integration
     * @dev Sets up the contract with CryptoPunks as the only initial whitelisted collection
     *      Additional collections can be added via addToWhitelist() or community requests
     *      SHINY token address must be set separately via setShinyToken()
     * 
     * @param nftBaseURI Base URI for Shiny NFT metadata (e.g., "ipfs://QmHash/")
     * @param nftContractURI ERC-7572 contract-level metadata URI
     * @param _WETH WETH contract address for the deployment network
     * @param feeReceiver Treasury address for ecosystem fees (address(0) defaults to deployer)
     */
    constructor(
        string memory nftBaseURI,
        string memory nftContractURI,
        address _WETH,
        address feeReceiver
        // uint256 _marginBasisPoints
        ) 
        ERC721("Shinies", "SHINIES")
        Ownable(msg.sender)
        StickyAsset(nftContractURI, [false, true])
    {
        WETH = _WETH;
        
        // SHINY Token address will be set post-deployment via setShinyToken()
        // This allows independent contract deployment and verification
        SHINY_TOKEN = address(0);
        SHINY_GLUE = address(0);

        // Initialize whitelist with 1-based indexing
        // Index 0 is dummy, collections start at ID 1
        whitelistedCollections.push(address(0));
        
        // Whitelist CryptoPunks as the only initial collection
        // Additional collections added via addToWhitelist() or community requests
        whitelistedCollections.push(CRYPTOPUNKS);
        isWhitelisted[CRYPTOPUNKS] = true;
        collectionId[CRYPTOPUNKS] = 1;

        // Set metadata URIs
        baseURI = nftBaseURI;

        // Set treasury address (defaults to deployer if not specified)
        fee_receiver = feeReceiver == address(0) ? msg.sender : feeReceiver;

        // Set airdrop start time
        TEST_ENDED = false; // Set to false to disable airdrop
    }

    /**
    * @notice Mints a Shiny NFT by depositing a whitelisted NFT + paying the bonding curve price
    * @dev Complete minting process:
    *      1. Validates collection is whitelisted and max supply not reached
    *      2. Calculates current mint price from bonding curve
    *      3. Collects payment and distributes fees (5% to SHINY vault + treasury)
    *      4. Transfers original NFT to vault (handles CryptoPunks specially)
    *      5. Mints new Shiny NFT with unique ID (burned IDs are never reused)
    *      6. Emits SHINY token rewards based on amount sent to SHINY vault
    * 
    * @param collection The whitelisted NFT collection address
    * @param originalTokenId The token ID from the original collection to wrap
    * @param recipient The address to receive the Shiny NFT (address(0) defaults to msg.sender)
    */
    function mint(address collection, uint256 originalTokenId, address recipient) external payable nnrtnt {
        // Validate collection is whitelisted
        if (!isWhitelisted[collection]) revert lol();

        if (collection == address(0)) revert lol();

        // Validate max supply not exceeded
        if (totalSupply() >= _getMaxSupply()) revert lol();

        // Default recipient to caller if not specified
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        // Calculate current mint price from bonding curve
        uint256 mintPrice;

        // TESTING: If airdrop is not started, set mint price to price * 1,000,000
        if (!TEST_ENDED) {
            if (msg.sender != owner()) revert lol();
            mintPrice = _md512(_getCurrentMintPrice(), 1, 1000000);
        } else {
            mintPrice = _getCurrentMintPrice();
        }

        // Validate sufficient payment
        if (msg.value < mintPrice) revert lol();

        // Calculate ecosystem fee (5% of mint price)
        uint256 totalFee = _md512(mintPrice, ECOSYSTEM_FEE_MINT, PRECISION);
        uint256 amountToGlue = mintPrice - totalFee;
        uint256 toShinyGlue = 0;
        uint256 toTeam = 0;

        // Distribute mint fees: 50% to SHINY vault, 50% to treasury
        if (totalFee > 0) {
            toShinyGlue = _md512(totalFee, SHINY_GLUE_FEE, PRECISION);
            toTeam = totalFee - toShinyGlue;
            
            // Send 50% of fee to SHINY token vault (increases backing + mints rewards)
            if (toShinyGlue > 0) {
                transferAsset(address(0), SHINY_GLUE, toShinyGlue, new uint256[](0), true);
                if (TEST_ENDED) {
                    IShinyToken(SHINY_TOKEN).mintRewards(msg.sender, toShinyGlue, false);
                }
            }
            
            // Send remaining 50% to treasury (or NFT vault if treasury not set)
            if (toTeam > 0) {
                if (fee_receiver != address(0)) {
                    transferAsset(address(0), fee_receiver, toTeam, new uint256[](0), true);
                } else {
                    transferAsset(address(0), GLUE, toTeam, new uint256[](0), true);
                }
            }
        }

        // Send remaining 95% of mint price to Shinies NFT vault
        if (amountToGlue > 0) {
            transferAsset(address(0), GLUE, amountToGlue, new uint256[](0), true);
        }

        // Refund any excess payment
        if (msg.value > mintPrice) {
            transferAsset(address(0), msg.sender, msg.value - mintPrice, new uint256[](0), true);
        }

        // Attempt to read metadata URI from original collection
        string memory originalBaseURI;
        if (collection == CRYPTOPUNKS) {
            originalBaseURI = ""; // CryptoPunks use image endpoint, not tokenURI
        } else {
            originalBaseURI = _getCollectionBaseURI(collection);
        }

        // Transfer original NFT to vault (CryptoPunks require special handling)
        if (collection == CRYPTOPUNKS) {
            // CryptoPunks use legacy buyPunk() mechanism instead of ERC721
            // Validate punk is offered to this contract at zero price
            if (!_isPunkReady(originalTokenId)) revert lol();
            
            // Execute punk transfer via buyPunk()
            ICryptoPunks(CRYPTOPUNKS).buyPunk(originalTokenId);
            
            // Verify ownership transferred successfully
            address punkOwner = ICryptoPunks(CRYPTOPUNKS).punkIndexToAddress(originalTokenId);
            if (punkOwner != address(this)) revert lol();
        } else {
            // Standard ERC721 transfer
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = originalTokenId;
            transferFromAsset(collection, msg.sender, address(this), 0, tokenIds, false);
            
            // Verify ownership transferred successfully
            address nftOwner = getNFTOwner(collection, originalTokenId);
            if (nftOwner != address(this)) revert lol();
        }

        // Mint Shiny NFT to recipient with unique ID (burned IDs are never reused)
        uint256 shinyTokenId = _mintSingleWithTracking(recipient, collection, originalTokenId);

        // Emit mint event with original NFT details
        emit Minted(shinyTokenId, recipient, collection, originalTokenId, originalBaseURI, toShinyGlue, amountToGlue);
        
        // Emit metadata update event for marketplace refresh (EIP-4906)
        emit MetadataUpdate(shinyTokenId);
    }

    /**
     * @notice Attempts to extract the base metadata URI from an NFT collection
     * @param collection The address of the NFT collection to query
     * @return The base URI string, or empty string if unavailable
     * @dev Uses try-catch pattern to gracefully handle:
     *      - Collections without tokenURI implementation
     *      - Non-existent token IDs
     *      - Non-standard metadata endpoints
     */
    function _getCollectionBaseURI(address collection) internal view returns (string memory) {
        // Attempt tokenURI(1) first (most common pattern)
        try IERC721Metadata(collection).tokenURI(1) returns (string memory uri) {
            return _extractBaseURI(uri);
        } catch {
            // Fallback to tokenURI(0) for zero-indexed collections
            try IERC721Metadata(collection).tokenURI(0) returns (string memory uri) {
                return _extractBaseURI(uri);
            } catch {
                // Return empty if collection doesn't support metadata
                return "";
            }
        }
    }

    /**
     * @notice Extracts base URI by removing token ID suffix from full metadata URI
     * @param fullURI The complete token URI (e.g., "ipfs://QmHash/123")
     * @return The base URI without token ID (e.g., "ipfs://QmHash/")
     * @dev Finds last '/' character and returns everything up to and including it
     *      Returns full URI if no slash found or slash is at the end
     */
    function _extractBaseURI(string memory fullURI) internal pure returns (string memory) {
        bytes memory uriBytes = bytes(fullURI);
        if (uriBytes.length == 0) return "";
        
        // Scan backwards to find last slash separator
        uint256 lastSlash = 0;
        for (uint256 i = uriBytes.length; i > 0; i--) {
            if (uriBytes[i - 1] == bytes1('/')) {
                lastSlash = i - 1;
                break;
            }
        }
        
        // Return full URI if no slash or slash at end (no token ID segment)
        if (lastSlash == 0 || lastSlash == uriBytes.length - 1) {
            return fullURI;
        }
        
        // Extract base URI including trailing slash
        bytes memory baseBytes = new bytes(lastSlash + 1);
        for (uint256 i = 0; i <= lastSlash; i++) {
            baseBytes[i] = uriBytes[i];
        }
        
        return string(baseBytes);
    }

    /**
    * @notice Calculates what percentage of collateral to redirect through our fee hook
    * @dev Returns ECOSYSTEM_FEE_BURN (10%) for ETH/WETH, 0% for other assets
    *      Glue Protocol uses this to determine fee routing during burns:
    *      - 10% redirected to _processCollateralHook() for fee distribution
    *      - 90% sent directly to user
    * 
    * @param asset The collateral token address being withdrawn (address(0) for ETH)
    * @param amount The total collateral amount user is redeeming
    * @return The percentage (in PRECISION format) to route through fee hook
    */
    function _calculateCollateralHookSize(address asset, uint256 amount) internal view override returns (uint256) {
        // Safety check: return 0 if no amount (matches StickyAsset standard pattern)
        if (amount == 0) return 0;

        if (asset == ETH_ADDRESS || asset == WETH) {
            // Return 10% - Glue will calculate: hookAmount = amount × ECOSYSTEM_FEE / PRECISION
            return ECOSYSTEM_FEE_BURN;
        }
        
        return 0; 
    }

    /**
    * @notice Returns original NFTs to users when Shiny NFTs are burned
    * @dev Called automatically by Glue Protocol during unglue (burn) operations
    *      This hook ensures the original deposited NFT is returned to the redeemer
    *      alongside their proportional share of vault collateral (handled by Glue)
    * 
    * Process flow:
    * 1. User calls unglue() on their Shiny NFT
    * 2. Glue Protocol burns the Shiny NFT and triggers this hook
    * 3. Hook transfers original NFT back to user
    * 4. Glue distributes proportional ETH/WETH collateral to user
    * 5. Ecosystem fees are processed via collateral hook
    * 
    * @param amount Number of NFTs being burned (informational only)
    * @param tokenIds Array of Shiny token IDs being burned
    * @param recipient Address receiving the original NFTs and collateral
    */
    function _processStickyHook(uint256 amount, uint256[] memory tokenIds, address recipient) internal override {
        // Return original NFTs to recipient for each burned Shiny NFT
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IShinies.OriginalNFT memory original = originalNFTs[tokenIds[i]];
            
            // Skip if no original NFT stored (defensive check)
            if (original.collection == address(0)) continue;
            
            // Transfer original NFT back to user (CryptoPunks require special handling)
            if (original.collection == CRYPTOPUNKS) {
                // Use CryptoPunks legacy transferPunk() method
                ICryptoPunks(CRYPTOPUNKS).transferPunk(recipient, original.tokenId);
            } else {
                // Standard ERC721 transfer
                uint256[] memory originalTokenIds = new uint256[](1);
                originalTokenIds[0] = original.tokenId;
                transferAsset(original.collection, recipient, 0, originalTokenIds, false);
            }
            
            // Clear storage to reclaim gas
            delete originalNFTs[tokenIds[i]];
        }
    }

    /**
    * @notice Processes and distributes collateral fees from burn operations
    * @dev Called by Glue Protocol when users burn Shiny NFTs to redeem collateral
    *      Glue sends hookAmount (10% of user's collateral share) to this function
    *      Remaining 90% is sent directly to user by Glue Protocol
    * 
    * Fee distribution breakdown:
    * - 10% → SHINY token vault (increases SHINY backing + triggers reward minting)
    * - 50% → Shinies NFT vault (compounds value for remaining holders)
    * - 40% → Treasury (protocol sustainability)
    * 
    * @param asset The collateral token address (address(0) for ETH, otherwise token address)
    * @param amount The fee amount (10% of total collateral) received from Glue
    * @param isETH Boolean indicating if collateral is native ETH
    * @param recipient The address redeeming their Shiny NFT
    */
    function _processCollateralHook(address asset, uint256 amount, bool isETH, address recipient) internal override {
        // No fees to process
        if (amount == 0) {
            return;
        }
        
        // Split the 10% burn fee: 10% to SHINY vault, 50% to NFT vault, 40% to treasury
        uint256 toShinyGlue = _md512(amount, SHINY_GLUE_FEE_BURN, PRECISION);
        uint256 toCollectionGlue = _md512(amount, SHINY_GLUE_FEE, PRECISION);
        uint256 toTeam = amount - toShinyGlue - toCollectionGlue;
        
        // Mint SHINY rewards for ETH/WETH going to SHINY vault
        // Creates 1:1 correlation: SHINY minted = ETH backing added
        if ((isETH || asset == WETH) && toShinyGlue > 0 && TEST_ENDED) {
            try IShinyToken(SHINY_TOKEN).mintRewards(recipient, toShinyGlue, false) {
                // Rewards minted successfully
            } catch {
                // Gracefully continue if minting fails
            }
        }
        
        // Route 10% of fee to SHINY token vault (increases SHINY backing)
        if (toShinyGlue > 0) {
            transferAsset(asset, SHINY_GLUE, toShinyGlue, new uint256[](0), true);
        }
        
        // Route 50% of fee to Shinies NFT vault (compounds holder value)
        if (toCollectionGlue > 0) {
            transferAsset(asset, GLUE, toCollectionGlue, new uint256[](0), true);
        }
        
        // Route remaining 40% to treasury (or NFT vault if treasury not set)
        if (toTeam > 0) {
            if (fee_receiver != address(0)) {
                transferAsset(asset, fee_receiver, toTeam, new uint256[](0), true);
            } else {
                transferAsset(asset, GLUE, toTeam, new uint256[](0), true);
            }
        }
    }

    /**
     * @notice Internal minting function with original NFT tracking
     * @param recipient The address to receive the newly minted Shiny NFT
     * @param originalCollection The original NFT collection address
     * @param originalTokenId The original NFT token ID
     * @return shinyTokenId The minted Shiny NFT token ID
     * @dev Mints new sequential ID accounting for wasted (burned) IDs to ensure uniqueness
     *      Formula: totalSupply() + WASTED_SUPPLY + 1
     *      This ensures burned IDs are never reused, maintaining true uniqueness
     *      Note: Max supply is validated in mint() before calling this function
     */
    function _mintSingleWithTracking(
        address recipient,
        address originalCollection,
        uint256 originalTokenId
    ) private returns (uint256 shinyTokenId) {
        
        // Calculate new unique ID: current supply + wasted IDs + 1
        // This ensures burned IDs are never reused
        // Token IDs can exceed _getMaxSupply() because they account for burned tokens
        // The actual supply limit is enforced in mint() via totalSupply() check
        shinyTokenId = totalSupply() + WASTED_SUPPLY + 1;
        
        // Store original NFT metadata for burn redemption
        originalNFTs[shinyTokenId] = IShinies.OriginalNFT({
            collection: originalCollection,
            tokenId: originalTokenId
        });
        
        // Execute mint
        _mint(recipient, shinyTokenId);
        
        return shinyTokenId;
    }

    /**
     * @notice Calculates the dynamic max supply based on whitelisted collections
     * @return The current maximum supply
     * @dev Base supply + (additional collections * bonus per collection)
     * Formula: BASE_MAX_SUPPLY + ((current collections - initial collections) * SUPPLY_BONUS_PER_COLLECTION)
     * Note: whitelistedCollections.length includes dummy at index 0, so actual count is length - 1
     */
    function _getMaxSupply() internal view returns (uint256) {
        // Actual count excludes dummy element at index 0
        uint256 currentCollectionsCount = whitelistedCollections.length - 1;
        
        // If current collections <= initial, return base supply
        if (currentCollectionsCount <= INITIAL_COLLECTIONS_COUNT) {
            return BASE_MAX_SUPPLY;
        }
        
        // Calculate additional supply: +100 per additional collection
        uint256 additionalCollections = currentCollectionsCount - INITIAL_COLLECTIONS_COUNT;
        uint256 bonusSupply = additionalCollections * SUPPLY_BONUS_PER_COLLECTION;
        
        return BASE_MAX_SUPPLY + bonusSupply;
    }

    /**
     * @notice Calculates the dynamic profit target based on fees and supply position
     * @param supply Current token supply
     * @return Profit target multiplier in PRECISION (e.g., 1.05e18 = 5% profit margin)
     * @dev Dynamically adapts to ecosystem state:
     *      - ECOSYSTEM_FEE_MINT and ECOSYSTEM_FEE_BURN (maintains fee awareness)
     *      - Supply-based margin (distance from max supply)
     *      
     * Break-even calculation:
     * - Minimum multiplier to maintain constant vault value
     * - Formula: 1 / (1 - mint_fee)
     * - Example: With 5% mint fee → 1/0.95 ≈ 1.0526 (5.26% minimum)
     * 
     * Dynamic margin adjustment:
     * - Margin = (maxSupply - currentSupply) basis points
     * - Early mints: High margin → Stronger vault growth
     * - Near capacity: Low margin → Better holder redemption rates
     * - Automatic rebalancing as ecosystem matures
     * 
     * This ensures vault always grows while providing progressive holder protection.
     */
    function _calculateProfitTarget(uint256 supply) internal view returns (uint256) {
        // Calculate break-even multiplier (minimum to maintain constant vault value)
        uint256 toBackingRate = PRECISION - ECOSYSTEM_FEE_MINT; // 95% after 5% mint fee
        uint256 breakEven = _md512(PRECISION, PRECISION, toBackingRate); // 1/0.95 ≈ 1.0526

        // Dynamic margin based on supply position (distance from max supply)
        uint256 maxSupply = _getMaxSupply() + 1;
        uint256 marginBasisPoints = maxSupply - supply;
        
        // Apply dynamic margin to break-even: breakEven × (1 + margin/10000)
        // Early mints: High margin (stronger vault growth)
        // Near capacity: Low margin (better holder protection)
        uint256 marginMultiplier = PRECISION + _md512(PRECISION, marginBasisPoints, 10000);
        return _md512(breakEven, marginMultiplier, PRECISION);
    }

    /**
     * @notice Calculates the current mint price using dynamic bonding curve
     * @return The current price in wei to mint the next NFT
     * @dev Price adapts dynamically to multiple ecosystem factors:
     *      - Current collateral: Total ETH/WETH held in vault (includes all earnings)
     *      - Supply position: Distance from max supply affects margin calculation
     *      - Fee structure: Accounts for mint and burn fees in pricing
     *      - Dilution compensation: Adjusts for impact of new mint on existing holders
     *      
     * Formula: Price = (Collateral/Supply) × [profit_target × dilution_factor] / round_trip_efficiency
     * 
     * This ensures vault value grows while maintaining fair pricing for all participants.
     */
    function _getCurrentMintPrice() internal view returns (uint256) {
        uint256 supply = totalSupply();

        // Bootstrap pricing: First mint pays base price (no collateral exists yet)
        if (supply == 0) {
            return BASE_PRICE;
        }

        // Dynamic pricing based on current vault collateral
        // All accumulated value (mints, burns, royalties) benefits existing holders
        uint256 collateral = _getTotalCollateralInGlue();
        
        // === BONDING CURVE FORMULA ===
        // Price = (Collateral/Supply) × [profit_target × dilution_factor] / round_trip_efficiency
        //
        // Components:
        // 1. Backing per token (C/S) - Current collateral divided by current supply
        // 2. Profit target - Dynamic margin based on supply position (auto-adjusting)
        // 3. Dilution factor - (S+1)/S - Compensates existing holders for supply increase
        // 4. Round-trip efficiency - Accounts for mint and burn fees in pricing
        
        // Calculate current backing per token
        uint256 backingPerToken = _md512(collateral, 1, supply);
        
        // Calculate round-trip efficiency from fee structure
        uint256 toBackingRate = PRECISION - ECOSYSTEM_FEE_MINT;      // 95% (after 5% mint fee)
        uint256 extractableRate = PRECISION - ECOSYSTEM_FEE_BURN;    // 90% (after 10% burn fee)
        uint256 roundTripEfficiency = _md512(toBackingRate, extractableRate, PRECISION);
        
        // Calculate dilution compensation factor
        uint256 nextSupply = supply + 1;
        uint256 dilutionFactor = _md512(nextSupply, PRECISION, supply);
        
        // Calculate dynamic profit target (decreases as supply approaches max)
        uint256 profitTarget = _calculateProfitTarget(supply);
        
        // Combine all factors into final multiplier
        uint256 numerator = _md512(profitTarget, dilutionFactor, PRECISION);
        uint256 multiplier = _md512(numerator, PRECISION, roundTripEfficiency);
        
        // Apply multiplier to backing to get mint price
        uint256 price = _md512(backingPerToken, multiplier, PRECISION);

        // Enforce price floor to prevent underflow edge cases
        return price > BASE_PRICE ? price : BASE_PRICE;
    }

    /**
     * @notice Gets total ETH + WETH collateral in the GLUE contract
     * @return Total collateral in 18 decimals
     * @dev Uses GluedTools to read balances from GLUE
     */
    function _getTotalCollateralInGlue() internal view returns (uint256) {
        // Prepare collateral addresses array (ETH and WETH)
        address[] memory collaterals = new address[](2);
        collaterals[0] = address(0); // ETH
        collaterals[1] = WETH;
        
        // Get balances using GluedTools
        uint256[] memory balances = getGlueBalances(address(this), collaterals, false);
        
        // ETH balance (already 18 decimals)
        uint256 ethBalance = balances[0];
        
        // WETH balance (adjust decimals if needed - WETH is also 18 decimals)
        uint256 wethBalance = balances[1];
        
        // Return total
        return ethBalance + wethBalance;
    }

     /**
     * @notice Allows the contract to receive ETH
     * @dev Required for handling ETH transfers and refunds
     */
    receive() external payable {}

    /**
     * @notice Updates token ownership with Glue Protocol restrictions
     * @param to The address receiving the token
     * @param tokenId The ID of the token being transferred
     * @param auth The address authorizing the transfer
     * @return The previous owner's address
     * @dev Prevents ungluing except during burn process
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override(ERC721, ERC721Enumerable) returns (address) {

        // Update the token
        return super._update(to, tokenId, auth);
    }


    /**
     * @notice Burns a Shiny NFT - only callable by GLUE during unglue process
     * @param tokenId The ID of the token to burn
     * @dev Restricted to GLUE to ensure proper hook execution and collateral distribution
     *      Users should call unglue() instead of burn() directly
     *      Increments WASTED_SUPPLY to ensure burned IDs are never reused
     */
    function burn(uint256 tokenId) public virtual onlyGlue {
        // Increment wasted supply counter - burned IDs are never reused
        WASTED_SUPPLY++;
        
        // Burn the token
        _burn(tokenId);

        // Emit the Burned event
        emit Burned(tokenId);
    }

    /**
     * @notice Increases the token balance of an account
     * @param account The address to increase balance for
     * @param amount The amount to increase by
     * @dev Required override for ERC721Enumerable compatibility
     */
    function _increaseBalance(address account, uint128 amount)
        internal
        virtual
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, amount);
    }

    /**
     * @notice Checks if the contract supports a given interface
     * @param interfaceId The interface identifier to check
     * @return bool True if the interface is supported
     * @dev Combines support for ERC721, ERC721Enumerable, and IERC4906 interfaces
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        // EIP-4906: Metadata Update Extension (type(IERC4906).interfaceId == 0x49064906)
        return interfaceId == type(IERC4906).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @notice Sets the fee receiver address
     * @param _fee_receiver The new fee receiver address
     * @dev Can only be called by owner
     */
    function setFeeReceiver(address _fee_receiver) external {

        // Check if the caller is the current fee receiver
        if (msg.sender != fee_receiver) revert lol();

        // Update the fee receiver address
        fee_receiver = _fee_receiver;
    }

    /**
     * OWNER PERMISSIONS
     */

    /**
     * @notice Sets the SHINY Token address and its GLUE
     * @param _shinyToken Address of the SHINY Token contract
     * @dev Can only be called once by owner
     */
    function setShinyToken(address _shinyToken) external onlyOwner {
        if (SHINY_TOKEN != address(0)) revert lol();
        if (_shinyToken == address(0)) revert lol();
        
        SHINY_TOKEN = _shinyToken;
        SHINY_GLUE = initializeGlue(SHINY_TOKEN, true);
        
        emit ShinyTokenSet(_shinyToken, SHINY_GLUE);
    }

    /**
     * @notice Starts the airdrop
     * @dev Can only be called by owner
     */
    function endTest() external onlyOwner {
        if (TEST_ENDED) revert lol();
        TEST_ENDED = true;
        IShinyToken(SHINY_TOKEN).setDeploymentTime();
    }

    /**
     * @notice Sets the contract URI
     * @param newURI The new URI to set
     * @dev Can only be called by owner
     */
    function setContractURI(string memory newURI) external onlyOwner {

        // Call the parent contract's method to update the URI
        _updateContractURI(newURI);

        // Emit the contract URI updated event
        emit ContractURIUpdated(newURI);
    } 

    /**
     * @notice Sets the base URI for token metadata
     * @param newBaseURI The new base URI to set
     * @dev Can only be called by owner and before URI is locked
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {

        // Set the base URI
        baseURI = newBaseURI;

        // Emit the base URI updated event
        emit BaseURIUpdated(newBaseURI);
        
        // Emit EIP-4906 batch metadata update (all tokens affected by base URI change)
        // From token 1 to highest minted ID (current supply + wasted IDs)
        uint256 maxTokenId = totalSupply() + WASTED_SUPPLY;
        if (maxTokenId > 0) {
            emit BatchMetadataUpdate(1, maxTokenId);
        }
    }

    /**
     * @notice Returns the base URI for computing token URIs
     * @dev Overrides ERC721's _baseURI() to use our state variable
     *      Token URIs are constructed as: baseURI + tokenId
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /**
     * WHITELIST MANAGEMENT
     */

    /**
     * @notice Removes a collection from the whitelist
     * @param collection The address of the NFT collection to remove
     * @dev Can only be called by owner. Uses 1-indexed array (index 0 is dummy)
     */
    function removeFromWhitelist(address collection) external onlyOwner {
        if (!isWhitelisted[collection]) revert lol();

        // Get the ID (1-indexed) of the collection to remove
        uint256 id = collectionId[collection];
        uint256 lastIndex = whitelistedCollections.length - 1;

        // If not the last element, swap with the last one
        if (id != lastIndex) {
            address lastCollection = whitelistedCollections[lastIndex];
            whitelistedCollections[id] = lastCollection;
            collectionId[lastCollection] = id;
        }

        // Remove the last element
        whitelistedCollections.pop();

        // Update mappings
        isWhitelisted[collection] = false;
        delete collectionId[collection];

        emit CollectionRemovedFromWhitelist(collection);
    }

    /**
     * @notice Submits a community request to whitelist a new NFT collection
     * @param collection The NFT collection address to propose for whitelisting
     * @dev Governance mechanism requiring economic commitment:
     *      - Requester must stake 2% of SHINY total supply
     *      - Owner reviews and accepts/rejects the proposal
     *      - On accept: Stake handled per glue compatibility (50% to collection, 50% burned)
     *      - On reject: Full stake refunded to requester
     */
    function requestWhitelist(address collection) external {
        // Validate request parameters
        if (collection == address(0)) revert lol();
        if (isWhitelisted[collection]) revert lol();
        if (whitelistRequests[collection].active) revert lol();
        
        // Calculate required stake (2% of SHINY total supply)
        uint256 shinyTotalSupply = getTotalSupply(SHINY_TOKEN, true);
        uint256 requiredStake = _md512(shinyTotalSupply, STAKE_PERCENTAGE, PRECISION);
        if (requiredStake == 0) revert lol();
        
        // Transfer stake from requester to contract
        uint256[] memory emptyTokenIds = new uint256[](0);
        uint256 actualStaked = transferFromAsset(
            SHINY_TOKEN,
            msg.sender,
            address(this),
            requiredStake,
            emptyTokenIds,
            true
        );
        
        // Validate stake transfer succeeded with exact amount
        if (actualStaked == 0) revert lol();
        if (actualStaked != requiredStake) revert lol();
        
        // Record whitelist request
        whitelistRequests[collection] = IShinies.WhitelistRequest({
            requester: msg.sender,
            collection: collection,
            stakedAmount: actualStaked,
            active: true
        });

        whitelistRequestsCount++;
        
        emit WhitelistRequested(msg.sender, collection, actualStaked);
    }

    /**
     * @notice Processes a whitelist request (accept or reject)
     * @param collection The collection address
     * @param accept True to accept (add to whitelist & handle stake), False to reject (refund stake)
     * @dev Only owner can call. Uses 1-indexed collection IDs
     *      When accepting with successful glue: 50% to collection glue, 50% burned
     *      When accepting with failed glue: 100% burned
     */
    function processWhitelistRequest(address collection, bool accept) external onlyOwner {
        IShinies.WhitelistRequest memory request = whitelistRequests[collection];
        if (!request.active) revert lol();

        address collectionGlue;
        
        if (accept) {
            // Validate not already whitelisted
            if (isWhitelisted[collection]) revert lol();
            
            // Attempt to initialize glue for the collection
            collectionGlue = tryInitializeGlue(collection, false);
            
            // Whitelist collection (glue compatibility not required)
            whitelistedCollections.push(collection);
            isWhitelisted[collection] = true;
            collectionId[collection] = whitelistedCollections.length - 1;
            
            // Distribute staked SHINY tokens based on glue compatibility
            if (request.stakedAmount > 0) {
                uint256[] memory emptyTokenIds = new uint256[](0);
                
                if (collectionGlue != address(0)) {
                    // Glue-compatible: Split stake 50/50 (incentivizes quality collections)
                    uint256 halfStake = _md512(request.stakedAmount, 2, PRECISION);
                    uint256 remainder = request.stakedAmount - halfStake;
                    
                    // 50% to collection's vault (rewards compatible collections)
                    if (halfStake > 0) {
                        transferAsset(SHINY_TOKEN, collectionGlue, halfStake, emptyTokenIds, true);
                    }
                    
                    // 50% burned to SHINY vault (reduces circulating supply)
                    if (remainder > 0) {
                        transferAsset(SHINY_TOKEN, SHINY_GLUE, remainder, emptyTokenIds, true);
                    }
                } else {
                    // Non-glue-compatible: Burn full stake
                    transferAsset(SHINY_TOKEN, SHINY_GLUE, request.stakedAmount, emptyTokenIds, true);
                }
            }
            
            emit WhitelistRequestAccepted(collection, request.requester, request.stakedAmount);
            emit CollectionWhitelisted(collection);
        } else {
            // Rejection: Refund full stake to requester
            if (request.stakedAmount > 0 && request.requester != address(0)) {
                uint256[] memory emptyTokenIds = new uint256[](0);
                transferAsset(SHINY_TOKEN, request.requester, request.stakedAmount, emptyTokenIds, true);
            }
        }

        whitelistRequestsCount--;
        
        // Clear request from storage
        delete whitelistRequests[collection];
    }

    /**
     * @notice Adds a collection to whitelist (owner only, for initial phase)
     * @param collection The collection address to whitelist
     * @dev Only allows additions up to INITIAL_COLLECTIONS_COUNT (10 collections)
     *      After that, collections must be added via community request system
     *      Uses 1-indexed collection IDs (array[0] is dummy, collections start at ID 1)
     *      Tries to initialize glue for the collection and mints 1M SHINY tokens if successful
     */
    function addToWhitelist(address collection) external onlyOwner {
        // Check if already whitelisted
        if (isWhitelisted[collection]) revert lol();
        
        // length includes dummy at index 0, so actual count is length - 1
        // Allow adding only if current count < INITIAL_COLLECTIONS_COUNT
        if (whitelistedCollections.length - 1 >= INITIAL_COLLECTIONS_COUNT) {
            revert lol(); // Use lol for consistency
        }

        // Declare collectionGlue before the conditional block
        address collectionGlue;
        
        if (collection != CRYPTOPUNKS) {
            // Try to initialize glue for the collection (NFT = false for fungible param)
            collectionGlue = tryInitializeGlue(collection, false);
        } else {
            collectionGlue = address(0);
        }
        
        // Add to whitelist regardless of glue success
        whitelistedCollections.push(collection);
        isWhitelisted[collection] = true;
        collectionId[collection] = whitelistedCollections.length - 1; // Assigns 1-based ID
        
        // Mint 100,000 SHINY tokens (18 decimals) to the collection's glue ONLY if glue was successful
        if (TEST_ENDED) {
            if (collectionGlue != address(0) && SHINY_TOKEN != address(0)) {
                IShinyToken(SHINY_TOKEN).mintRewards(collectionGlue, 0, true);
            }
        }
        
        emit WhitelistRequestAccepted(collection, msg.sender, 0);
    }

    /**
     * @notice Renounces ownership of the contract
     * @dev Only the owner can renounce ownership
     */
    function renounceOwnership() public override onlyOwner {

        // Renounce ownership
        super.renounceOwnership();

        // Emit the OwnershipRenounced event
        emit OwnershipRenounced();
    }

    function transferOwnership(address newOwner) public override onlyOwner {

        // Check if the new owner is not the zero address
        if (newOwner == address(0)) revert lol();
        if (newOwner == owner()) revert lol();

        // Transfer the ownership
        super.transferOwnership(newOwner);

        // Emit the OwnershipTransferred event
        emit OwnershipTransferred(msg.sender, newOwner);
    }


    /**
     * @notice Returns the current dynamic maximum supply
     * @return The current maximum supply based on whitelisted collection count
     * @dev Formula: BASE_MAX_SUPPLY (1000) + 100 per collection beyond initial 10
     *      Incentivizes community to expand ecosystem while maintaining scarcity
     */
    function getCurrentMaxSupply() external view returns (uint256) {
        return _getMaxSupply();
    }

    /**
     * @notice Returns the count of burned/wasted token IDs
     * @return The number of tokens that have been burned and will never be reused
     * @dev Useful for calculating the highest possible token ID: totalSupply() + wastedSupply
     */
    function getWastedSupply() external view returns (uint256) {
        return WASTED_SUPPLY;
    }

    /**
     * @notice Returns the current mint price for the next NFT
     * @return The price in wei required to mint the next Shiny NFT
     * @dev Uses dynamic bonding curve that accounts for collateral, supply, and fees
     */
    function getCurrentMintPrice() external view returns (uint256) {
        return _getCurrentMintPrice();
    }

    /**
     * @notice Checks if a collection is whitelisted
     * @param collection The address to check
     * @return True if the collection is whitelisted
     */
    function isCollectionWhitelisted(address collection) external view returns (bool) {
        return isWhitelisted[collection];
    }

    /**
     * @notice Returns all whitelisted collections
     * @return Array of whitelisted collection addresses (excludes dummy at index 0)
     * @dev Returns collections starting from index 1 (1-indexed storage)
     */
    function getWhitelistedCollections() external view returns (address[] memory) {
        // Calculate actual count (excluding dummy at index 0)
        uint256 count = whitelistedCollections.length > 0 ? whitelistedCollections.length - 1 : 0;
        
        // Create result array with actual collections only
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = whitelistedCollections[i + 1]; // Skip index 0 (dummy)
        }
        
        return result;
    }

    /**
     * @notice Returns all whitelist requests
     * @return Array of whitelist requests
     * @dev Returns requests starting from index 1 (1-indexed storage)
     */
    function getWhitelistRequests() external view returns (IShinies.WhitelistRequest[] memory) {
        IShinies.WhitelistRequest[] memory requests = new IShinies.WhitelistRequest[](whitelistRequestsCount);
        for (uint256 i = 0; i < whitelistRequestsCount; i++) {
            requests[i] = whitelistRequests[whitelistedCollections[i + 1]];
        }
        return requests;
    }

    function getWhitelistRequest(address collection) external view returns (IShinies.WhitelistRequest memory) {
        return whitelistRequests[collection];
    }

    /**
     * @notice Returns the amount of whitelisted collections
     * @return The amount of whitelisted collections
     * @dev Returns the amount of whitelisted collections
     */
    function getWhitlistedAmount() external view returns (uint256) {
        return whitelistedCollections.length - 1;
    }

    /**
     * @notice Returns the original NFT information for a Shiny token ID
     * @param shinyTokenId The Shiny NFT token ID
     * @return collection The original collection address
     * @return tokenId The original token ID
     */
    function getOriginalNFT(uint256 shinyTokenId) external view returns (address collection, uint256 tokenId) {
        IShinies.OriginalNFT memory original = originalNFTs[shinyTokenId];
        return (original.collection, original.tokenId);
    }

    /**
     * @notice Calculates current ETH backing per SHINY token from Shinies perspective
     * @return Wei of ETH backing per 1 SHINY token (18 decimals)
     * @dev Accounts for:
     *      1. Minted SHINY supply
     *      2. Pending team allocation (40% of minted, if not yet claimed)
     *      3. Pending collection rewards (100K per unminted collection up to 10 total)
     *      
     *      Formula: (Total ETH + WETH in SHINY vault) ÷ (Effective total SHINY supply)
     *      
     *      Effective supply includes all future mints to maintain accurate backing value
     */
    function getShinyBackingPerToken() external view returns (uint256) {
        if (SHINY_TOKEN == address(0)) return 0;
        
        // Query SHINY vault collateral (ETH + WETH)
        address[] memory collaterals = new address[](2);
        collaterals[0] = address(0); // Native ETH
        collaterals[1] = WETH;        // Wrapped ETH
        
        uint256[] memory balances = getGlueBalances(SHINY_TOKEN, collaterals, true);
        uint256 totalBacking = balances[0] + balances[1];
        
        // Get current minted SHINY supply
        uint256 effectiveTotalSupply = getTotalSupply(SHINY_TOKEN, true);
        
        if (effectiveTotalSupply == 0) return 0;
        
        // Add pending team allocation if not yet minted (after week 12)
        try IShinyToken(SHINY_TOKEN).getCurrentWeek() returns (uint256 week) {
            if (week >= 12) {
                // Team gets 40% of community supply: (supply × 0.4) / (1 - 0.4)
                // Only add if not yet minted (we can't check directly, so always add)
                uint256 teamPercentage = 4e17; // 40% in 1e18 precision
                uint256 pendingTeamAllocation = _md512(effectiveTotalSupply, teamPercentage, PRECISION - teamPercentage);
                effectiveTotalSupply += pendingTeamAllocation;
            }
        } catch {
            // If call fails, skip team allocation adjustment
        }
        
        // Add pending collection rewards (100K SHINY per collection up to 10 total)
        // whitelistedCollections.length - 1 = actual count (index 0 is dummy)
        uint256 currentCollectionCount = whitelistedCollections.length - 1;
        if (currentCollectionCount < INITIAL_COLLECTIONS_COUNT) {
            // Calculate how many collections can still be added
            uint256 remainingCollections = INITIAL_COLLECTIONS_COUNT - currentCollectionCount;
            // Each collection receives 100,000 SHINY tokens (100000 * 1e18)
            uint256 pendingCollectionRewards = remainingCollections * 100000 * 1e18;
            effectiveTotalSupply += pendingCollectionRewards;
        }
        
        // Calculate backing per token
        return _md512(totalBacking, PRECISION, effectiveTotalSupply);
    }

    /**
     * CRYPTOPUNKS HELPERS
     */

    /**
     * @notice Internal validation for CryptoPunk offer status
     * @param punkIndex The punk ID to check
     * @return isValid True if punk offer is valid
     */
    function _isPunkReady(
        uint256 punkIndex
    ) internal view returns (bool isValid) {
        (bool isForSale, , address seller, uint256 minValue, address onlySellTo) = 
            ICryptoPunks(CRYPTOPUNKS).punksOfferedForSale(punkIndex);
        
        if (!isForSale) {
            return false;
        }
        if (seller != msg.sender) {
            return false;
        }
        if (onlySellTo != address(this)) {
            return false;
        }
        if (minValue != 0) {
            return false;
        }
        
        return true;
    }

    /**
     * @notice Checks if a CryptoPunk is properly offered for minting
     * @param punkIndex The punk ID to check
     * @return isReady True if punk can be minted
     * @dev Users must call CryptoPunks.offerPunkForSaleToAddress(punkId, 0, thisContract) first
     */
    function isPunkReadyForMint(uint256 punkIndex) external view returns (bool isReady) {
        return _isPunkReady(punkIndex);
    }

    
}