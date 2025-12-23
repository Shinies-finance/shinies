// SPDX-License-Identifier: MIT
/**
 * @title IShinyToken - Interface for SHINY Reward Token
 * @notice Interface for the SHINY ERC20 deflationary reward token featuring Bitcoin-style
 *         halving emissions, transfer locks, and perfect 1:1 ETH backing correlation.
 * 
 * @dev Defines the complete API for SHINY token interactions including:
 *      - Reward minting (restricted to Shinies NFT contract)
 *      - Team allocation claiming (one-time, post-week 12)
 *      - Emission rate queries (view functions for current state)
 *      - Transfer unlock status (12-week lock period)
 *      - Backing calculations (includes pending team allocation)
 * 
 * Standard ERC20 functions (transfer, approve, balanceOf, etc.) are inherited
 * from the base ERC20 contract and not redeclared in this interface.
 */

pragma solidity ^0.8.28;

interface IShinyToken {
    
    // ===== ERRORS =====
    
    error TransfersLocked();
    error UnauthorizedMinter();
    error TeamAlreadyMinted();
    error TooEarly();
    error AirdropAlreadyStarted();
    
    // ===== EVENTS =====
    
    event RewardsMinted(address indexed recipient, uint256 amount, uint256 ethAmount, uint256 week);
    event TeamAllocationMinted(address indexed team, uint256 amount);
    event TransfersUnlocked(uint256 timestamp);
    
    // ===== FUNCTIONS =====
    
    /**
     * @notice Mints rewards based on ETH amount spent
     * @param recipient Address to receive the minted tokens
     * @param ethAmount Amount of ETH spent (for calculating rewards)
     */
    function mintRewards(address recipient, uint256 ethAmount, bool isLegacyMint) external;
    
    /**
     * @notice Mints team allocation (40% of total minted) after week 12
     */
    function mintTeamAllocation() external;
    
    /**
     * @notice Gets the current week's emission rate
     * @return Emission rate (SHINY per 1 ETH)
     */
    function getCurrentWeekRate() external view returns (uint256);
    
    /**
     * @notice Gets the current week number
     * @return Current week number
     */
    function getCurrentWeek() external view returns (uint256);
    
    /**
     * @notice Checks if transfers are unlocked
     * @return True if transfers are allowed
     */
    function transfersUnlocked() external view returns (bool);

    /**
     * @notice Sets the deployment time
     */
    function setDeploymentTime() external;
    
    
    // Note: Standard ERC20 functions (totalSupply, balanceOf, transfer, etc.) 
    // are inherited from ERC20 contract, not declared in interface
}


