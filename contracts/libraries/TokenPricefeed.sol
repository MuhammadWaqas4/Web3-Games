// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


interface IUniswapV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
    function token0() external view returns (address);
    function token1() external view returns (address);


}


contract TokenPrice is Ownable2Step {
    IUniswapV3Pool public pool;

    /**
     * @notice Emitted when the pool is update.
     * @param prevPool Previous price pool address.
     * @param newPool New price pool address.
     */
    event pricePoolUpdated(address indexed prevPool, address newPool);

    constructor(address _pool) Ownable(msg.sender) {
        pool = IUniswapV3Pool(_pool);
    }

    function getPrice() external view returns (uint256 priceX96) {
        (uint160 sqrtPriceX96,, , , , ,) = pool.slot0();
        return uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
    }

    function getPoolTokens() public view returns (address tokenA, address tokenB) {
        tokenA = pool.token0();
        tokenB = pool.token1();
    }

    function getScaledPrice() external view returns (uint256) {
        (uint160 sqrtPriceX96,, , , , ,) = pool.slot0();
        (address token0, address token1) = getPoolTokens();
        uint256 priceX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        return Math.mulDiv(
            priceX192 * (10 ** IERC20(token0).decimals()),
            1e18,
            (2 ** 192) * (10 ** IERC20(token1).decimals())
        );
    }

    function setPool(address _newPool) external onlyOwner {
        require(_newPool != address(0), "Zero address not allowed");

        emit pricePoolUpdated(address(pool), _newPool);
        pool = IUniswapV3Pool(_newPool);
    }
}