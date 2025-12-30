// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IPermit2 } from "@uniswap/permit2/src/interfaces/IPermit2.sol";

import { IUniversalRouter } from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import { Commands } from "@uniswap/universal-router/contracts/libraries/Commands.sol";

import { IERC20Burnable } from "./interfaces/IERC20Burnable.sol";

import { _AUTHORITY_ROLE, _OWNER_ROLE } from "./shared/Constants.sol";
import { InvalidAddress } from "./shared/Errors.sol";
import { _revert } from "./shared/Globals.sol";

import { ITreasury } from "./interfaces/ITreasury.sol";

/**
 * @title Treasury.
 * @author Game Team.
 * @notice Treasury contract to hold assets and allow burning of the protocol token when required.
 */
contract Treasury is ITreasury, UUPSUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    /* ========================== STATE VARIABLES ========================== */

    // keccak256("Manager")
    /// @dev Manager role.
    bytes32 private constant _MANAGER_ROLE = 0x6d439300980e333f0256d64be2c9f67e86f4493ce25f82498d6db7f4be3d9e6f;

    /// @dev Address of the wrapped eth token.
    address private constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    /// @dev Address of the allowance transfer contract.
    IPermit2 private constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    /// @dev Address of the uniswap universal router.
    IUniversalRouter private constant _UNIVERSAL_ROUTER = IUniversalRouter(0x5E325eDA8064b456f4781070C0738d849c824258);

    /* ========================== ERC7201 STORAGE ========================== */

    /// @custom:storage-location erc7201:gamecasino.storage.Treasury
    struct TreasuryStorage {
        IERC20Burnable _protocolToken;
    }

    // keccak256(abi.encode(uint256(keccak256("gamecasino.storage.Treasury")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TreasuryStorageLocation =
        0xe47fe241e8f264231ac9be1e244e43b1f612647709d8927b1ffa5feec6ec4300;

    function _getTreasuryStorage() private pure returns (TreasuryStorage storage $) {
        assembly {
            $.slot := TreasuryStorageLocation
        }
    }

    /**
     * @notice Address of the protocol token.
     */
    function protocolToken() public view returns (address) {
        TreasuryStorage storage $ = _getTreasuryStorage();

        return address($._protocolToken);
    }

    /* ========================== EVENTS ========================== */

    /**
     * @dev Emitted when assets are deposited into the treasury.
     * @param asset Address of the asset being deposited.
     * @param assets Amount of assets deposited.
     */
    event Deposit(address asset, uint256 assets);

    /**
     * @dev Emitted when the protocol token is bought back and burned.
     * @param boughtBack Amount of primary asset used to buyback.
     * @param burned Amount of protocol tokens burned.
     */
    event BuybackAndBurn(uint256 boughtBack, uint256 burned);

    /* ========================== ERRORS ========================== */

    /**
     * @dev Thrown when a low level call fails.
     */
    error CallFailed();

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
     * @notice Initializes parent contracts, assigns roles and initializes state variables.
     * @param initialOwner_ Address to which ownership will be initially granted.
     * @param manager_ Address which will be granted the manager role.
     * @param protocolToken_ Address of the protocol token.
     */
    function initialize(address initialOwner_, address manager_, IERC20Burnable protocolToken_) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        TreasuryStorage storage $ = _getTreasuryStorage();

        if (initialOwner_ == address(0) || manager_ == address(0) || address(protocolToken_) == address(0)) {
            _revert(InvalidAddress.selector);
        }

        _setRoleAdmin(_OWNER_ROLE, _OWNER_ROLE);
        _setRoleAdmin(_AUTHORITY_ROLE, _OWNER_ROLE);
        _setRoleAdmin(_MANAGER_ROLE, _OWNER_ROLE);

        _grantRole(_OWNER_ROLE, initialOwner_);
        _grantRole(_MANAGER_ROLE, manager_);

        $._protocolToken = protocolToken_;
    }

    /* ========================== FUNCTIONS ========================== */

    /**
     * @inheritdoc ITreasury
     */
    function deposit(IERC20 asset, uint256 assets /**, bool toBuybackAndBurn */) external onlyRole(_AUTHORITY_ROLE) {
        emit Deposit({ asset: address(asset), assets: assets });

        if (true) {
            _buybackAndBurn(asset);
        }
    }

    /**
     * @inheritdoc ITreasury
     */
    function buybackAndBurn(IERC20 primaryAsset, Call[] calldata calls) external onlyRole(_MANAGER_ROLE) {
        uint256 callsLength = calls.length;

        for (uint256 i; i < callsLength; ++i) {
            Call calldata call = calls[i];

            (bool success, ) = call.to.call{ value: call.value }(call.data);

            if (!success) {
                _revert(CallFailed.selector);
            }
        }

        _buybackAndBurn(primaryAsset);
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

    /**
     * @dev Implements {buybackAndBurn} logic.
     * @param primaryAsset Asset to buyback the protocol token with.
     */
    function _buybackAndBurn(IERC20 primaryAsset) private {
        IERC20Burnable burnToken = IERC20Burnable(protocolToken());

        uint256 primaryAssetAmount = primaryAsset.balanceOf(address(this));

        if (primaryAssetAmount > 1e6) {
            // Approving token to permit2 and permit2 to universal router.
            primaryAsset.approve(address(_PERMIT2), primaryAssetAmount);
            _PERMIT2.approve(
                address(primaryAsset),
                address(_UNIVERSAL_ROUTER),
                uint160(primaryAssetAmount),
                uint48(block.timestamp)
            );

            // Structuring commands.
            bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));

            // Path for v3.
            bytes memory path = abi.encodePacked(primaryAsset, uint24(3000), _WETH, uint24(100), burnToken);

            // Structuring inputs.
            bytes[] memory inputs = new bytes[](1);
            inputs[0] = abi.encode(address(this), primaryAssetAmount, 0, path, true);

            // Swapping.
            try _UNIVERSAL_ROUTER.execute(commands, inputs, block.timestamp) {} catch {}

            uint256 burnAmount = burnToken.balanceOf(address(this));
            burnToken.burn(burnAmount);

            emit BuybackAndBurn({ boughtBack: primaryAssetAmount, burned: burnAmount });
        }
    }
}
