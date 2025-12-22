// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IMultiAssetVault } from "./IMultiAssetVault.sol";

interface IReservoir is IMultiAssetVault {
    /* ========================== TYPES ========================== */

    enum AbsorptionCause {
        FEE,
        RETURN
    }

    /* ========================== FUNCTIONS ========================== */

    /**
     * @notice Absorbs assets into the reservoir.
     * @dev Can only be called by an authority and the given asset must be registered.
     * @param asset Address of the asset being absorbed.
     * @param assets Amount of assets absorbed.
     * @param cause Cause for the absorption.
     */
    function absorb(IERC20 asset, uint256 assets, AbsorptionCause cause) external;

    /**
     * @notice Disburses assets from the reservoir to a winner.
     * @dev Can only be called by an authority and the given asset must be registered.
     * @param asset Address of the asset being disbursed.
     * @param assets Amount of assets to disburse.
     * @param winner Address that is being disbursed assets.
     */
    function disburse(IERC20 asset, uint256 assets, address winner) external;

    /**
     * @notice Total Amount of fees accumulated.
     */
    function totalFees() external view returns (uint256);
}
