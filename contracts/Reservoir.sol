// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { _AUTHORITY_ROLE, _OWNER_ROLE } from "./shared/Constants.sol";
import { InvalidAddress, InvalidAmount, InvalidAssignment } from "./shared/Errors.sol";
import { _revert } from "./shared/Globals.sol";

import { MultiAssetVaultUpgradeable } from "./utils/MultiAssetVaultUpgradeable.sol";

import { IClaiming } from "./interfaces/IClaiming.sol";
import { IReservoir } from "./interfaces/IReservoir.sol";

/**
 * @title Reservoir.
 * @author Game Team.
 * @notice Reservoir that holds the {GameCasino}'s reserve.
 */
contract Reservoir is IReservoir, UUPSUpgradeable, MultiAssetVaultUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    /* ========================== ERC7201 STORAGE ========================== */

    /// @custom:storage-location erc7201:gamecasino.storage.Reservoir
    struct ReservoirStorage {
        uint256 _totalFees;
        IClaiming _claiming;
    }

    // keccak256(abi.encode(uint256(keccak256("gamecasino.storage.Reservoir")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReservoirStorageLocation =
        0xb8b5498b0dd8c9bfa7fbcc6688ff729ba511f7b015dc8a9b092fee3551a62000;

    function _getReservoirStorage() private pure returns (ReservoirStorage storage $) {
        assembly {
            $.slot := ReservoirStorageLocation
        }
    }

    /**
     * @notice Total Amount of fees accumulated.
     */
    function totalFees() external view returns (uint256) {
        ReservoirStorage storage $ = _getReservoirStorage();

        return $._totalFees;
    }

    /**
     * @notice Address of the withdrawal claiming contract.
     */
    function claiming() public view returns (address) {
        ReservoirStorage storage $ = _getReservoirStorage();

        return address($._claiming);
    }

    /* ========================== EVENTS ========================== */

    /**
     * @dev Emitted when assets are absorbed into the reservoir.
     * @param asset Address of the asset being absorbed.
     * @param assets Amount of assets absorbed.
     * @param cause Cause for the absorption.
     */
    event Absorb(IERC20 asset, uint256 assets, AbsorptionCause cause);

    /**
     * @dev Emitted when assets are disbursed from the reservoir.
     * @param asset Address of the asset being disbursed.
     * @param assets Amount of assets to disburse.
     * @param winner Address that is being disbursed assets.
     */
    event Disburse(IERC20 asset, uint256 assets, address indexed winner);

    /**
     * @dev Emitted when the withdrawal claiming contract is changed.
     * @param newClaiming Address of the new withdrawal claiming contract.
     * @param oldClaiming Address of the old withdrawal claiming contract.
     */
    event UpdateClaiming(address indexed newClaiming, address indexed oldClaiming);

    /* ========================== ERRORS ========================== */

    /**
     * @dev Thrown when there are insufficient total assets to award a winner.
     */
    error InsufficientTotalAssets();

    /**
     * @dev Thrown when an operation faces more than expected slippage.
     */
    error Slippage();

    /* ========================== CONSTRUCTOR ========================== */

    /**
     * @dev Disables initializers for the implementation.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /* ========================== INITIALIZE ========================== */

    /**
     * @notice Initializes parent contracts and assigns roles.
     * @param assetsList_ List of asset addresses.
     * @param initialOwner_ Address to which ownership will be initially granted.
     */
    function initialize(IERC20[] calldata assetsList_, address initialOwner_) external initializer {
        __AccessControl_init();
        __MultiAssetVault_init(assetsList_);
        __UUPSUpgradeable_init();

        _setRoleAdmin(_OWNER_ROLE, _OWNER_ROLE);
        _setRoleAdmin(_AUTHORITY_ROLE, _OWNER_ROLE);

        _grantRole(_OWNER_ROLE, initialOwner_);
    }

    /* ========================== FUNCTIONS ========================== */

    /**
     * @notice Deposit assets with slippage protection.
     * @param asset Address of the asset.
     * @param assets Amount of assets to deposit.
     * @param receiver Address to receive shares.
     * @param minSharesOut Minimum shares expected.
     * @return shares Amount of shares minted.
     */
    function depositWithSlippage(
        IERC20 asset,
        uint256 assets,
        address receiver,
        uint256 minSharesOut
    ) external returns (uint256 shares) {
        shares = deposit(asset, assets, receiver);

        if (shares < minSharesOut) {
            _revert(Slippage.selector);
        }

        return shares;
    }

    /**
     * @notice Mint shares with slippage protection.
     * @param asset Address of the asset.
     * @param shares Amount of shares to mint.
     * @param receiver Address to receive shares.
     * @param maxAssetsIn Maximum assets willing to spend.
     * @return assets Amount of assets deposited.
     */
    function mintWithSlippage(
        IERC20 asset,
        uint256 shares,
        address receiver,
        uint256 maxAssetsIn
    ) external returns (uint256 assets) {
        assets = mint(asset, shares, receiver);

        if (assets > maxAssetsIn) {
            _revert(Slippage.selector);
        }

        return assets;
    }

    /**
     * @notice Withdraw assets with slippage protection.
     * @param asset Address of the asset.
     * @param assets Amount of assets to withdraw.
     * @param receiver Address to receive assets.
     * @param maxSharesIn Maximum shares willing to burn.
     * @return shares Amount of shares burned.
     */
    function withdrawWithSlippage(
        IERC20 asset,
        uint256 assets,
        address receiver,
        uint256 maxSharesIn
    ) external returns (uint256 shares) {
        shares = withdraw(asset, assets, receiver);

        if (shares > maxSharesIn) {
            _revert(Slippage.selector);
        }

        return shares;
    }

    /**
     * @notice Redeem shares with slippage protection.
     * @param asset Address of the asset.
     * @param shares Amount of shares to redeem.
     * @param receiver Address to receive assets.
     * @param minAssetsOut Minimum assets expected.
     * @return assets Amount of assets received.
     */
    function redeemWithSlippage(
        IERC20 asset,
        uint256 shares,
        address receiver,
        uint256 minAssetsOut
    ) external returns (uint256 assets) {
        assets = redeem(asset, shares, receiver);

        if (assets < minAssetsOut) {
            _revert(Slippage.selector);
        }

        return assets;
    }

    /**
     * @notice Updates the withdrawal claiming contract.
     * @dev Can only be called by an owner.
     * @param newClaiming Address of the new withdrawal claiming contract.
     */
    function updateClaiming(IClaiming newClaiming) external onlyRole(_OWNER_ROLE) {
        ReservoirStorage storage $ = _getReservoirStorage();

        if (address(newClaiming) == address(0)) {
            _revert(InvalidAddress.selector);
        }

        address oldClaiming = claiming();

        if (address(newClaiming) == oldClaiming) {
            _revert(InvalidAssignment.selector);
        }

        emit UpdateClaiming({ newClaiming: address(newClaiming), oldClaiming: oldClaiming });

        $._claiming = newClaiming;
    }

    /**
     * @notice Absorbs assets into the reservoir.
     * @dev Can only be called by an authority and only if the given asset is registered.
     * @param asset Address of the asset being absorbed.
     * @param assets Amount of assets absorbed.
     * @param cause Cause for the absorption.
     */
    function absorb(
        IERC20 asset,
        uint256 assets,
        AbsorptionCause cause
    ) external validateAsset(asset) onlyRole(_AUTHORITY_ROLE) {
        ReservoirStorage storage $ = _getReservoirStorage();

        if (cause == AbsorptionCause.FEE) {
            $._totalFees += assets;
        }

        emit Absorb({ asset: asset, assets: assets, cause: cause });
    }

    /**
     * @notice Disburses assets from the reservoir to a winner.
     * @dev Can only be called by an authority and the given asset must be registered.
     * @param asset Address of the asset being disbursed.
     * @param assets Amount of assets to disburse.
     * @param winner Address that is being disbursed assets.
     */
    function disburse(
        IERC20 asset,
        uint256 assets,
        address winner
    ) external validateAsset(asset) onlyRole(_AUTHORITY_ROLE) {
        if (winner == address(0)) {
            _revert(InvalidAddress.selector);
        }

        if (assets == 0) {
            _revert(InvalidAmount.selector);
        }

        if (assets > totalAssets(asset)) {
            _revert(InsufficientTotalAssets.selector);
        }

        asset.safeTransfer(winner, assets);

        emit Disburse({ asset: asset, assets: assets, winner: winner });
    }

    /**
     * @inheritdoc MultiAssetVaultUpgradeable
     * @dev Overridden to add withdrawal claiming logic.
     */
    function _withdraw(IERC20 asset, address receiver, uint256 assets, uint256 shares) internal override {
        ReservoirStorage storage $ = _getReservoirStorage();

        super._withdraw(asset, address($._claiming), assets, shares);
        $._claiming.setRequest(receiver, assets);
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Overridden so that it can only be called by an owner.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(_OWNER_ROLE) {
        if (newImplementation == address(0)) {
            _revert(InvalidAddress.selector);
        }
    }
}
