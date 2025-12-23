// SPDX-License-Identifier: MIT
/**
 * @title ICryptoPunks
 * @notice Interface for CryptoPunks contract
 * @dev CryptoPunks use a custom transfer mechanism, not ERC721
 */

pragma solidity ^0.8.28;

interface ICryptoPunks {
    
    struct Offer {
        bool isForSale;
        uint256 punkIndex;
        address seller;
        uint256 minValue;
        address onlySellTo;
    }
    
    /**
     * @notice Get the owner of a punk
     */
    function punkIndexToAddress(uint256 punkIndex) external view returns (address);
    
    /**
     * @notice Get the current offer for a punk
     */
    function punksOfferedForSale(uint256 punkIndex) external view returns (
        bool isForSale,
        uint256 punkIndex_,
        address seller,
        uint256 minValue,
        address onlySellTo
    );
    
    /**
     * @notice Buy a punk that's offered for sale to you
     */
    function buyPunk(uint256 punkIndex) external payable;
    
    /**
     * @notice Transfer a punk you own to another address
     */
    function transferPunk(address to, uint256 punkIndex) external;
    
    /**
     * @notice Offer a punk for sale to a specific address
     */
    function offerPunkForSaleToAddress(uint256 punkIndex, uint256 minSalePriceInWei, address toAddress) external;
}

