// SPDX-License-Identifier: BUSL-1.1
/**
 * @title GluedToolsERC20Min - ERC20 Glue Protocol Utilities
 * @author Glue Finance
 * @notice Minimal utility library for ERC20-specific Glue Protocol interactions,
 *         designed to complement StickyAsset without duplicating functionality.
 * @dev Contains helper functions for:
 *      - ERC20 glue balance queries
 *      - Total supply calculations for glued tokens
 *      - Glue compatibility checking
 *      
 *      This library excludes functions already present in StickyAsset to prevent
 *      constant conflicts and maintain a clean inheritance structure.
 */

pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGlueStickERC20, IGlueERC20} from "../../../tools/contracts/interfaces/IGlueERC20.sol";

abstract contract GluedToolsERC20Min {
    
    // Note: PRECISION, GLUE_STICK constants inherited from StickyAsset
    // Access _md512 from parent StickyAsset
    
    function getGlueBalances(address stickyAsset, address[] memory collaterals) internal view returns (uint256[] memory balances) {
        (bool isSticky, address glue) = _isSticky(stickyAsset);

        if (!isSticky) {
            balances = new uint256[](collaterals.length);
            for (uint256 i = 0; i < collaterals.length; i++) {
                balances[i] = 0;
            }
            return balances;
        }
        
        balances = new uint256[](collaterals.length);
        for (uint256 i = 0; i < collaterals.length; i++) {
            if (collaterals[i] == address(0)) {
                balances[i] = address(glue).balance;
            } else {
                balances[i] = IERC20(collaterals[i]).balanceOf(glue);
            }
        }
    }

    function _isSticky(address stickyAsset) private view returns (bool isSticky, address glue) {
        (isSticky, glue) = IGlueStickERC20(0x0ddE8dda9f486a4EC5eece60a59248bD28144dFf).isStickyAsset(stickyAsset);
        return (isSticky, glue);
    }
}

