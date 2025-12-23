// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IMultiAssetVault.
 * @author Game Team.
 * @dev Interface for the multi asset vault abstract contract.
 */
interface IMultiAssetVault {
    /* ========================== EVENTS ========================== */

    /**
     * @dev Emitted when an asset's registration state is changed.
     * @param asset Address of the asset.
     * @param state Registration state for the asset.
     */
    event UpdateAsset(address asset, bool state);

    /* ========================== ERRORS ========================== */

    /**
     * @dev Thrown when the asset being used is not registered.
     */
    error AssetNotRegistered();

    /**
     * @dev Thrown when amount to deposit is more than the max amount.
     */
    error ExceededMaxDeposit();

    /**
     * @dev Thrown when amount to mint is more than the max amount.
     */
    error ExceededMaxMint();

    /**
     * @dev Thrown when amount to withdraw is more than the max amount.
     */
    error ExceededMaxWithdraw();

    /**
     * @dev Thrown when amount to redeem is more than the max amount.
     */
    error ExceededMaxRedeem();

    /* ========================== FUNCTIONS ========================== */

    /**
     * @notice Whether or not the given asset is registered.
     * @param asset Address of the asset.
     * @return status Registration status of the asset.
     */
    function isAsset(IERC20 asset) external view returns (bool);

    /**
     * @dev Returns the decimals places of the underlying shares of the given asset.
     * @param asset Address of the asset.
     * @return decimals Decimal points of the underlying shares.
     */
    function decimals(IERC20 asset) external view returns (uint8);

    /**
     * @notice Total supply of the underlying shares of the given asset.
     * @param asset Address of the asset.
     * @return totalSupply Total supply of the underlying shares.
     */
    function totalSupply(IERC20 asset) external view returns (uint256);

    /**
     * @notice Balance of the owner of the underlying shares of the given asset.
     * @param asset Address of the asset.
     * @return totalSupply Total supply of the underlying shares.
     */
    function balanceOf(IERC20 asset, address owner) external view returns (uint256);

    /**
     * @notice Mints shares to receiver by depositing exactly amount of underlying asset.
     * @param asset Address of the asset.
     * @param assets Amount of assets to deposit.
     * @param receiver Address of the recipient.
     * @return shares Amount of shares minted.
     */
    function deposit(IERC20 asset, uint256 assets, address receiver) external returns (uint256);

    /**
     * @notice Mints exactly shares to receiver by depositing amount of underlying asset.
     * @param asset Address of the asset.
     * @param shares Amount of shares to mint.
     * @param receiver Address of the recipient.
     * @return assets Amount of assets deposited.
     */
    function mint(IERC20 asset, uint256 shares, address receiver) external returns (uint256);

    /**
     * @notice Redeems shares from caller and sends exactly amount of underlying asset to receiver.
     * @param asset Address of the asset.
     * @param assets Amount of assets to withdraw.
     * @param receiver Address of the recipient.
     * @return shares Amount of shares burned.
     */
    function withdraw(IERC20 asset, uint256 assets, address receiver) external returns (uint256);

    /**
     * @notice Redeems exactly shares from caller and sends amount of underlying asset to receiver.
     * @param asset Address of the asset.
     * @param shares Amount of shares to redeem.
     * @param receiver Address of the recipient.
     * @return assets Amount of assets received.
     */
    function redeem(IERC20 asset, uint256 shares, address receiver) external returns (uint256);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     *
     * @param asset Address of the asset.
     * @return totalAssets Total amount of a given asset inside the vault.
     */
    function totalAssets(IERC20 asset) external view returns (uint256);

    /**
     * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and from.
     *
     * @param asset Address of the asset.
     * @param assets Amount of assets to convert.
     * @return shares Amount of converted shares.
     */
    function convertToShares(IERC20 asset, uint256 assets) external view returns (uint256);

    /**
     * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and from.
     *
     * @param asset Address of the asset.
     * @param shares Amount of shares to convert.
     * @return assets Amount of converted assets.
     */
    function convertToAssets(IERC20 asset, uint256 shares) external view returns (uint256);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     *
     * @return maxDeposit Max amount that can be deposited.
     */
    function maxDeposit(address) external view returns (uint256);

    /**
     * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
     * - MUST return a limited value if receiver is subject to some mint limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     * - MUST NOT revert.
     *
     * @return maxMint Max amount that can be minted.
     */
    function maxMint(address) external view returns (uint256);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST NOT revert.
     *
     * @param asset Address of the asset.
     * @param owner Address of the share owner.
     * @return maxWithdraw Max amount that can be withdrawn.
     */
    function maxWithdraw(IERC20 asset, address owner) external view returns (uint256);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     *
     * @param asset Address of the asset.
     * @param owner Address of the share owner.
     * @return maxRedeem Max amount that can be redeemed.
     */
    function maxRedeem(IERC20 asset, address owner) external view returns (uint256);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit
     *   call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called
     *   in the same transaction.
     * - MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the
     *   deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     *
     * @param asset Address of the asset.
     * @param assets Amount of assets to deposit.
     * @return shares Amount of shares to receive.
     */
    function previewDeposit(IERC20 asset, uint256 assets) external view returns (uint256);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call
     *   in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the
     *   same transaction.
     * - MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint
     *   would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     *
     * @param asset Address of the asset.
     * @param shares Amount of shares to receive.
     * @return assets Amount of assets to deposit.
     */
    function previewMint(IERC20 asset, uint256 shares) external view returns (uint256);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     *   call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if
     *   called
     *   in the same transaction.
     * - MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though
     *   the withdrawal would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     *
     * @param asset Address of the asset.
     * @param assets Amount of assets to receive.
     * @return shares Amount of shares to deposit.
     */
    function previewWithdraw(IERC20 asset, uint256 assets) external view returns (uint256);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redemption at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call
     *   in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the
     *   same transaction.
     * - MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     *   redemption would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     *
     * @param asset Address of the asset.
     * @param shares Amount of shares to deposit.
     * @return assets Amount of assets to receive.
     */
    function previewRedeem(IERC20 asset, uint256 shares) external view returns (uint256);
}
