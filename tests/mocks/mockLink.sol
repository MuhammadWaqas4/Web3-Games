// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./ERC677.sol";
import "./ITypeAndVersion.sol";

/// @dev LinkToken, an ERC20/ERC677 Chainlink token with 1 billion supply
contract LinkToken is ITypeAndVersion, ERC20, ERC677 {
    uint private constant TOTAL_SUPPLY = 10 ** 27;

    constructor() ERC20("LINK", "LINK") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice versions:
     *
     * - LinkToken 0.0.3: added versioning, update name
     * - LinkToken 0.0.2: upgraded to solc 0.6
     * - LinkToken 0.0.1: initial release solc 0.4
     *
     * @inheritdoc ITypeAndVersion
     */
    function typeAndVersion() external pure virtual override returns (string memory) {
        return "LinkToken 0.0.3";
    }
}
