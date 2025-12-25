// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import { IMultiAssetVault } from "../interfaces/IMultiAssetVault.sol";

import { InvalidAddress, InvalidArrayLength, InvalidAssignment } from "../shared/Errors.sol";
import { _revert } from "../shared/Globals.sol";

/**
 * @title MultiAssetVaultUpgradeable.
 * @author Game Team.
 * @dev Multi asset vault based on ERC-4626 "Tokenized Vault Standard". This implementation is neither ERC-20
 * nor ERC-4626 compliant and builds upon the latter to achieve the specific goal of having multiple assets in one vault
 * without the tokenization of shares.
 */
abstract contract MultiAssetVaultUpgradeable is IMultiAssetVault, Initializable, ContextUpgradeable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /* ========================== ERC7201 STORAGE ========================== */

    /// @custom:storage-location erc7201:gamecasino.storage.MultiAssetVault
    struct MultiAssetVaultStorage {
        mapping(IERC20 asset => bool isAsset) _isAsset;
        mapping(IERC20 asset => uint8 underlyingDecimals) _underlyingDecimals;
        mapping(IERC20 asset => uint256 totalSupply) _totalSupply;
        mapping(IERC20 asset => mapping(address owner => uint256 balance)) _balances;
    }

    // keccak256(abi.encode(uint256(keccak256("gamecasino.storage.MultiAssetVault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MultiAssetVaultStorageLocation =
        0x39c309a110dd22495d81d1b2ab0e1847f4145957f48825546ead22a758749000;

    function _getMultiAssetVaultStorage() private pure returns (MultiAssetVaultStorage storage $) {
        assembly {
            $.slot := MultiAssetVaultStorageLocation
        }
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function isAsset(IERC20 asset) public view virtual returns (bool) {
        MultiAssetVaultStorage storage $ = _getMultiAssetVaultStorage();

        return $._isAsset[asset];
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function decimals(IERC20 asset) public view virtual returns (uint8) {
        MultiAssetVaultStorage storage $ = _getMultiAssetVaultStorage();

        return $._underlyingDecimals[asset] + _decimalsOffset();
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function totalSupply(IERC20 asset) public view virtual returns (uint256) {
        MultiAssetVaultStorage storage $ = _getMultiAssetVaultStorage();

        return $._totalSupply[asset];
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function balanceOf(IERC20 asset, address owner) public view virtual returns (uint256) {
        MultiAssetVaultStorage storage $ = _getMultiAssetVaultStorage();

        return $._balances[asset][owner];
    }

    /* ========================== EVENTS ========================== */

    event Deposit(
        address indexed asset,
        address indexed depositor,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed asset,
        address indexed withdrawer,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    /* ========================== MODIFIERS ========================== */

    /**
     * @dev Validates whether an asset is registered or not.
     * @param asset Address of the asset.
     */
    modifier validateAsset(IERC20 asset) {
        _validateAsset(asset);
        _;
    }

    /* ========================== INIT ========================== */

    /**
     * @dev Initializes state variables.
     * @param assetsList_ List of asset addresses.
     */
    function __MultiAssetVault_init(IERC20[] calldata assetsList_) internal onlyInitializing {
        __MultiAssetVault_init_unchained(assetsList_);
    }

    function __MultiAssetVault_init_unchained(IERC20[] calldata assetsList_) internal onlyInitializing {
        uint256 assetsListLength = assetsList_.length;

        if (assetsListLength == 0) {
            _revert(InvalidArrayLength.selector);
        }

        for (uint256 i; i < assetsListLength; ++i) {
            IERC20 asset = assetsList_[i];

            _updateAsset(asset, true);
        }
    }

    /* ========================== FUNCTIONS ========================== */

    /**
     * @inheritdoc IMultiAssetVault
     */
    function deposit(IERC20 asset, uint256 assets, address receiver) public virtual returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);

        if (assets > maxAssets) {
            _revert(ExceededMaxDeposit.selector);
        }

        uint256 shares = previewDeposit(asset, assets);
        _deposit(asset, receiver, assets, shares);

        return shares;
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function mint(IERC20 asset, uint256 shares, address receiver) public virtual returns (uint256) {
        uint256 maxShares = maxMint(receiver);

        if (shares > maxShares) {
            _revert(ExceededMaxMint.selector);
        }

        uint256 assets = previewMint(asset, shares);
        _deposit(asset, receiver, assets, shares);

        return assets;
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function withdraw(IERC20 asset, uint256 assets, address receiver) public virtual returns (uint256) {
        uint256 maxAssets = maxWithdraw(asset, _msgSender());

        if (assets > maxAssets) {
            _revert(ExceededMaxWithdraw.selector);
        }

        uint256 shares = previewWithdraw(asset, assets);
        _withdraw(asset, receiver, assets, shares);

        return shares;
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function redeem(IERC20 asset, uint256 shares, address receiver) public virtual returns (uint256) {
        uint256 maxShares = maxRedeem(asset, _msgSender());

        if (shares > maxShares) {
            _revert(ExceededMaxRedeem.selector);
        }

        uint256 assets = previewRedeem(asset, shares);
        _withdraw(asset, receiver, assets, shares);

        return assets;
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function totalAssets(IERC20 asset) public view virtual returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function convertToShares(IERC20 asset, uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(asset, assets, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function convertToAssets(IERC20 asset, uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(asset, shares, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function maxWithdraw(IERC20 asset, address owner) public view virtual returns (uint256) {
        return _convertToAssets(asset, balanceOf(asset, owner), Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function maxRedeem(IERC20 asset, address owner) public view virtual returns (uint256) {
        return balanceOf(asset, owner);
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function previewDeposit(IERC20 asset, uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(asset, assets, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function previewMint(IERC20 asset, uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(asset, shares, Math.Rounding.Ceil);
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function previewWithdraw(IERC20 asset, uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(asset, assets, Math.Rounding.Ceil);
    }

    /**
     * @inheritdoc IMultiAssetVault
     */
    function previewRedeem(IERC20 asset, uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(asset, shares, Math.Rounding.Floor);
    }

    /**
     * @dev Implements asset registeration/deregistration logic.
     * @param asset Address of the asset.
     * @param state Registration state for the asset.
     */
    function _updateAsset(IERC20 asset, bool state) internal virtual {
        MultiAssetVaultStorage storage $ = _getMultiAssetVaultStorage();

        if (address(asset) == address(0)) {
            _revert(InvalidAddress.selector);
        }

        if (isAsset(asset) == state) {
            _revert(InvalidAssignment.selector);
        }

        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset);

        $._isAsset[asset] = state;
        $._underlyingDecimals[asset] = success ? assetDecimals : 18;

        emit UpdateAsset({ asset: address(asset), state: state });
    }

    /**
     * @dev Implements {deposit} and {mint} common logic.
     * @param asset Address of the asset.
     * @param receiver Address of the recipient.
     * @param assets Amount of assets to deposit.
     * @param shares Amount of shares to receive.
     */
    function _deposit(IERC20 asset, address receiver, uint256 assets, uint256 shares) internal virtual {
        MultiAssetVaultStorage storage $ = _getMultiAssetVaultStorage();

        // If asset() is ERC-777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer, calls
        // the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the assets
        // are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        asset.safeTransferFrom(_msgSender(), address(this), assets);
        $._totalSupply[asset] += shares;
        $._balances[asset][receiver] += shares;

        emit Deposit({
            asset: address(asset),
            depositor: _msgSender(),
            receiver: receiver,
            assets: assets,
            shares: shares
        });
    }

    /**
     * @dev Implements {withdraw} and {redeem} common logic.
     * @param asset Address of the asset.
     * @param receiver Address of the recipient.
     * @param assets Amount of assets to receive.
     * @param shares Amount of shares to deposit.
     */
    function _withdraw(IERC20 asset, address receiver, uint256 assets, uint256 shares) internal virtual {
        MultiAssetVaultStorage storage $ = _getMultiAssetVaultStorage();

        // If asset() is ERC-777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the shares
        // are burned and after the assets are transferred, which is a valid state.
        $._totalSupply[asset] -= shares;
        $._balances[asset][_msgSender()] -= shares;
        asset.safeTransfer(receiver, assets);

        emit Withdraw({
            asset: address(asset),
            withdrawer: _msgSender(),
            receiver: receiver,
            assets: assets,
            shares: shares
        });
    }

    /**
     * @dev Converts assets to shares with support for rounding direction.
     * @param asset Address of the asset.
     * @param assets Amount of assets to convert.
     * @param rounding Rounding type.
     * @return shares Amount of converted shares.
     */
    function _convertToShares(
        IERC20 asset,
        uint256 assets,
        Math.Rounding rounding
    ) internal view virtual validateAsset(asset) returns (uint256) {
        return assets.mulDiv(totalSupply(asset) + 10 ** _decimalsOffset(), totalAssets(asset) + 1, rounding);
    }

    /**
     * @dev Converts shares to assets with support for rounding direction.
     * @param asset Address of the asset.
     * @param shares Amount of shares to convert.
     * @param rounding Rounding type.
     * @return assets Amount of converted assets.
     */
    function _convertToAssets(
        IERC20 asset,
        uint256 shares,
        Math.Rounding rounding
    ) internal view virtual validateAsset(asset) returns (uint256) {
        return shares.mulDiv(totalAssets(asset) + 1, totalSupply(asset) + 10 ** _decimalsOffset(), rounding);
    }

    /**
     * @dev Offset to add to the underlying decimals for each asset. Simulates `10 ** {_decimalsOffset}` of virtual
     * assets.
     * @return decimalsOffset Offset to add to the underlying decimals.
     */
    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }

    /**
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     * @param asset Address of the asset.
     * @return success Whether the decimal fetch attempt was a success or not.
     * @return assetDecimals Decimals of the given asset if the decimal fetch attempt succeeded.
     */
    function _tryGetAssetDecimals(IERC20 asset) private view returns (bool, uint8) {
        (bool success, bytes memory encodedDecimals) = address(asset).staticcall(
            abi.encodeCall(IERC20Metadata.decimals, ())
        );

        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));

            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }

        return (false, 0);
    }

    /**
     * @dev Implements {validateAsset} logic.
     * @param asset Address of the asset.
     */
    function _validateAsset(IERC20 asset) private view {
        if (!isAsset(asset)) {
            _revert(AssetNotRegistered.selector);
        }
    }
}
