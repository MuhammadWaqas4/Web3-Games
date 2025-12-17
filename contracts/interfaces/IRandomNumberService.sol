// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

/**
 * @title Generic errors.
 * @author Game Team.
 * @notice Errors being used in more than one contract.
 */
interface IRandomNumberService {
    /**
     * @notice Requests a random number from an oracle service (e.g., Chainlink).
     * @dev Initiates an HTTP GET request to the provided URL and extracts hashed number using the specified path.
     * @param url The API endpoint to request randomness from (e.g., a server endpoint).
     * @param path The JSON path to extract the random value's hash from the response.
     * @param jobId The Job ID associated with this request.
     * @param player The address of the player for whom the random number is requested.
     * @return requestId The ID of the Chainlink request.
     */
    function requestEncryptedNumber(
        string memory url,
        string memory path,
        string memory jobId,
        address player
    ) external returns (bytes32 requestId);

    /**
     * @notice Requests random words from the Chainlink VRF coordinator.
     * @dev This method interacts with the Chainlink VRF to obtain verifiable randomness.
     * @param player The address of the player initiating the request.
     * @return requestId The ID associated with the VRF request.
     */
    function requestVRF(address player) external returns (uint256 requestId);
}

