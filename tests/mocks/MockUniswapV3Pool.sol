// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockUniswapV3Pool {
    uint160 private _sqrtPriceX96;
    address private _token0;
    address private _token1;

    constructor(uint160 sqrtPriceX96_, address token0_, address token1_) {
        _sqrtPriceX96 = sqrtPriceX96_;
        _token0 = token0_;
        _token1 = token1_;
    }

    function setSqrtPriceX96(uint160 newSqrtPriceX96) external {
        _sqrtPriceX96 = newSqrtPriceX96;
    }

    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool) {
        return (_sqrtPriceX96, 0, 0, 0, 0, 0, true);
    }

    function token0() external view returns (address) {
        return _token0;
    }

    function token1() external view returns (address) {
        return _token1;
    }
}
