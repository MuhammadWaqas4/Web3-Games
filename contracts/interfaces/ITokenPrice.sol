// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ITokenPrice {
    /**
     * @dev Gives sqrtPriceX96 price
     * @return requestId The ID of the Chainlink request.
    */
    function getPrice() external view returns (uint256);

    /**
     * @dev Gives the price scaled to 18 decimals
     * @return requestId The ID of the Chainlink request.
     */
    function getScaledPrice() external view returns (uint256);
}
