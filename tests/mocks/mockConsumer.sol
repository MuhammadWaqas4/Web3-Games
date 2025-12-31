// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/interfaces/IRandomNumberService.sol";

/**
 * @title RandomConsumer
 * @notice Example consumer contract that interacts with RandomNumberService to request
 *         VRF-based random numbers and oracle-based encrypted numbers.
 * @dev Stores the results returned from RandomNumberService in state variables.
 */
contract RandomConsumer {
    /// @notice Instance of RandomNumberService
    IRandomNumberService public randomService;

    /// @notice Last VRF random number stored
    uint256 public lastRandomWords;

    /// @notice Last encrypted number stored
    bytes32 public lastEncryptedNumber;

    /// @notice Stores the random word generated for each request.
    /// @dev The mapping key is the requestId, and the value is the corresponding random word.
    mapping(uint256 => uint256) public randomWord;

    mapping(bytes32 => bytes32) public encryptedWord;

    /// @notice Event emitted when a VRF request is initiated
    event VRFRequested(uint256 requestId);

    /// @notice Event emitted when an Oracle request is initiated
    event OracleRequested(bytes32 requestId);

    /// @notice Event emitted when a VRF result is stored
    event VRFResultStored(uint256 randomWords);

    /// @notice Event emitted when an Oracle result is stored
    event OracleResultStored(bytes32 encryptedNumber);

    /**
     * @param _randomService Address of deployed RandomNumberService contract
     */
    constructor(address _randomService) {
        randomService = IRandomNumberService(_randomService);
    }

    /**
     * @notice Calls RandomNumberService to request a VRF random number
     * @dev Transfers fee tokens from msg.sender inside RandomNumberService
     * @return requestId The Chainlink VRF requestId
     */
    function callVRFRequest() external returns (uint256 requestId) {
        // solhint-disable-next-line no-console
        console.log("111:::requestor msg.sender::::", msg.sender);
        requestId = randomService.requestVRF(msg.sender);
        emit VRFRequested(requestId);
    }

    /**
     * @notice Calls RandomNumberService to request an encrypted number from Oracle
     * @param url The API URL for Chainlink Oracle request
     * @param path The JSON path in response
     * @param jobId The Chainlink node Job ID
     * @return requestId The Oracle request ID
     */
    function callEncryptedNumberRequest(
        string memory url,
        string memory path,
        string memory jobId,
        address player
    ) external returns (bytes32 requestId) {
        requestId = randomService.requestEncryptedNumber(url, path, jobId, player);
        emit OracleRequested(requestId);
    }

    /**
     * @notice Callback function to store the random word for a given request.
     * @dev This function is expected to be called by the VRF Coordinator or an authorized oracle.
     * @param requestId The unique identifier of the randomness request.
     * @param randomWords The random word provided for the given requestId.
     */
    function fulfillRandomWord(uint256 requestId, uint256 randomWords) external {
        randomWord[requestId] = randomWords;
        emit VRFResultStored(randomWords);
    }

    /**
     * @notice Callback function to store the random word for a given request.
     * @param requestId The unique identifier of the randomness request.
     * @param encrypted The encrypted random word provided for the given requestId.
     */
    function fulfillRandomHash(bytes32 requestId, bytes32 encrypted) external {
        encryptedWord[requestId] = encrypted;
        emit OracleResultStored(encrypted);
    }
}
