// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    
    constructor() ERC20("USDT", "USDT") {}

    // Override
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function mintBatch(address[] memory recipients, uint256[] memory amounts) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }

    function burn(address account, uint256 value) public {
        _burn(account, value);
    }
}
