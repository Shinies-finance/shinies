// SPDX-License-Identifier: MIT
/**
 * 
 *    ███████╗██╗  ██╗██╗███╗   ██╗██╗███████╗███████╗
 *    ██╔════╝██║  ██║██║████╗  ██║██║██╔════╝██╔════╝
 *    ███████╗███████║██║██╔██╗ ██║██║█████╗  ███████╗
 *    ╚════██║██╔══██║██║██║╚██╗██║██║██╔══╝  ╚════██║
 *    ███████║██║  ██║██║██║ ╚████║██║███████╗███████║
 *    ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝╚══════╝╚══════╝
 * 
 * @title IShinies - Interface for Shinies NFT Collection
 * @notice Interface for multi-collection NFT vault with dynamic bonding curve and 
 *         dual-token reward system. Defines the complete API for wrapping blue-chip
 *         NFTs into yield-bearing Shiny variants.
 * 
 * @dev Core Protocol Interface:
 * 
 * Shinies enables users to deposit NFTs from whitelisted collections and receive
 * Shiny NFTs backed by three value components:
 * 
 * 1. Original Asset: The deposited NFT (redeemable on burn)
 * 2. ETH Collateral: Proportional share of accumulated ETH/WETH in protocol vault
 * 3. SHINY Rewards: Deflationary token with Bitcoin-style halving emissions
 * 
 * Protocol Features:
 * - Dynamic bonding curve: Price adapts to supply and collateral levels
 * - Multi-collection: Supports CryptoPunks, BAYC, Pudgy Penguins, and community requests
 * - Glue Protocol: Battle-tested collateral management via StickyAsset standard
 * - Deflationary rewards: 100K SHINY/ETH → halving weekly for 12 weeks → ÷10 forever
 * - Community governance: Propose collections with 2% SHINY stake
 * - Native CryptoPunks: Full support for legacy transfer mechanism
 * 
 * Economic Structure:
 * - Mint fee: 5% of bonding curve price
 *   · 50% → SHINY token backing (increases SHINY vault)
 *   · 50% → Treasury (protocol sustainability)
 * 
 * - Burn fee: 10% of collateral redeemed
 *   · 10% → SHINY token backing (increases SHINY vault)
 *   · 50% → Shinies NFT vault (compounds holder value)
 *   · 40% → Treasury (protocol sustainability)
 * 
 * - Collection incentives:
 *   · Owner-added: 100,000 SHINY to collection vault (if glue-compatible)
 *   · Community-requested: 50% of stake to collection vault, 50% burned (if glue-compatible)
 *   · Non-glue collections: Stake fully burned, no bonus allocation
 */

pragma solidity ^0.8.28;

interface IShinies {
    
    // ===== STRUCTS =====
    
    struct OriginalNFT {
        address collection;
        uint256 tokenId;
    }
    
    struct WhitelistRequest {
        address requester;
        address collection;
        uint256 stakedAmount;
        bool active;
    }
    
    // ===== EVENTS =====
    
    event Minted(uint256 indexed shinyTokenId, address indexed recipient, address indexed originalCollection, uint256 originalTokenId, string originalBaseURI, uint256 toShinyGlue, uint256 amountToGlue);
    event Burned(uint256 tokenId);
    
    /// @dev EIP-4906: Metadata Update events (matching IERC4906 interface)
    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    
    event CollectionWhitelisted(address indexed collection);
    event CollectionRemovedFromWhitelist(address indexed collection);
    
    event WhitelistRequested(address indexed requester, address indexed collection, uint256 stakedAmount);
    event WhitelistRequestAccepted(address indexed collection, address indexed requester, uint256 stakedAmount);
        
    event ContractURIUpdated(string newURI);
    event FeeReceiverUpdated(address newFeeReceiver);
    event BaseURIUpdated(string newBaseURI);
    event ShinyTokenSet(address indexed shinyToken, address indexed shinyGlue);
    
    event OwnershipRenounced();
    
    // ===== ERRORS =====
    
    error lol();
    
    // ===== CORE FUNCTIONS =====
    
    function mint(address collection, uint256 originalTokenId, address recipient) external payable;
    function burn(uint256 tokenId) external;
    
    // ===== PRICING & SUPPLY =====
    
    function getCurrentMintPrice() external view returns (uint256);
    function getCurrentMaxSupply() external view returns (uint256);
    function getWhitlistedAmount() external view returns (uint256);
    function getWhitelistRequests() external view returns (IShinies.WhitelistRequest[] memory);
    
    // ===== WHITELIST MANAGEMENT =====
    // Note: Collections use 1-indexed IDs (1-10 for initial collections, not 0-9)
    // Owner can directly add up to INITIAL_COLLECTIONS_COUNT (10) collections
    // Beyond that, collections must go through community request system
    
    function requestWhitelist(address collection) external;
    function processWhitelistRequest(address collection, bool accept) external;
    function removeFromWhitelist(address collection) external;
    
    function isCollectionWhitelisted(address collection) external view returns (bool);
    function getWhitelistedCollections() external view returns (address[] memory);
    function addToWhitelist(address collection) external;
    
    // ===== NFT INFO =====
    
    function getOriginalNFT(uint256 shinyTokenId) external view returns (address collection, uint256 tokenId);
    
    // ===== SHINY TOKEN BACKING =====
    
    function getShinyBackingPerToken() external view returns (uint256);
    
    // ===== CRYPTOPUNKS HELPERS =====
    
    function isPunkReadyForMint(uint256 punkIndex) external view returns (bool isReady);

    // ===== TESTING FUNCTIONS =====

    function endTest() external;
    
    // ===== ADMIN FUNCTIONS =====
    
    function setShinyToken(address _shinyToken) external;
    function setFeeReceiver(address _fee_receiver) external;
    function setContractURI(string memory newURI) external;
    function setBaseURI(string memory newBaseURI) external;

}

