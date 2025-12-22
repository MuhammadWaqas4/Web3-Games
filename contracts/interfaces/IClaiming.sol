// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title IClaiming.
 * @author Rain Team.
 * @notice Interface for the Claiming contract.
 */
interface IClaiming {
    /**
     * @notice Set a request to claim USDT tokens being unstaked from the Staking
     * contract. Only `staking` can call this function.
     * @param claimer Claimer who's USDT tokens are being held.
     * @param amount Amount of USDT tokens being unstaked.
     */
    function setRequest(address claimer, uint256 amount) external;

    /**
     * @notice Claim USDT tokens following the completion of a claim request.
     * @param index Claimer's index to claim request against.
     */
    function claimRequest(uint256 index) external;

    /**
     * @notice Claim USDT tokens following the completion of multiple claim
     * requests.
     * @param indexes List of claimer's indexes to claim requests against.
     */
    function claimMultipleRequests(uint256[] calldata indexes) external;

    /**
     * @notice Gives the request pertaining to the given unique request index.
     * @param index Request index to get the key for.
     * @return amount Amount of USDT tokens requested.
     * @return claimRequestTime Time after which requested USDT tokens will be
     * claimable.
     */
    function getRequest(uint256 index) external view returns (uint256, uint256);

    /**
     * @notice Gives a unique key pertaining to the given unique request index.
     * @param index Request index to get the key for.
     * @return key Key that is present for the given request index.
     */
    function getRequestKey(uint256 index) external view returns (bytes32);
}
