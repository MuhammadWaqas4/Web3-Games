// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title IConsumer.
 * @author Game Team.
 * @notice Interface of the chainlink consumer.
 */
interface IConsumer {
    /**
     * @notice Callback function used by game casino node.
     * @param requestId Id of the request.
     * @param encrypted Hashed number from Node.
     */
    function fulfillRandomHash(bytes32 requestId, bytes32 encrypted) external;

    /**
     * @notice Callback function used by chainlink node.
     * @param requestId Id of the request.
     * @param randomWord Random word from Node.
     */
    function fulfillRandomWord(uint256 requestId, uint256 randomWord) external;
}
