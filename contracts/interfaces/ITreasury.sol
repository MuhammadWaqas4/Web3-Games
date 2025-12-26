// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasury {
    /* ========================== TYPES ========================== */

    /// @dev Struct to define low level calls.
    struct Call {
        address to;
        bytes data;
        uint256 value;
    }

    /* ========================== FUNCTIONS ========================== */

    /**
     * @notice Emits an event signifying that an authority has deposited assets to the treasury.
     * @dev Can only be called by an authority.
     * @param asset Address of the asset being deposited.
     * @param assets Amount of assets deposited.
     * param toBuybackAndBurn Whether to buyback and burn on deposit.
     */
    function deposit(IERC20 asset, uint256 assets /**, bool toBuybackAndBurn */) external;

    /**
     * @notice Executes buyback multicalls the burns the protocol token acquired from the aforementioned calls.
     * @dev Can only be called by a manager.
     * @param primaryAsset Address of the primary asset being swapped to.
     * @param calls Multicall array specifying transactions to perform before burning the protocol token.
     */
    function buybackAndBurn(IERC20 primaryAsset, Call[] calldata calls) external;
}
