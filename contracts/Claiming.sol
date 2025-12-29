// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ClaimingErrors } from "./interfaces/Errors.sol";
import { IClaiming } from "./interfaces/IClaiming.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Claiming.
 * @author Game Team.
 * @notice Allows USDT tokens to be claimed after an unstake request has been requested.
 */
contract Claiming is ReentrancyGuard, ClaimingErrors, IClaiming, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @dev Seven days time in seconds.
    // uint256 private constant _SEVEN_DAYS_TIME = 7 days;
    uint256 private constant _SEVEN_DAYS_TIME = 2 minutes;

    /// @notice Address of the Tether USD token.
    IERC20 public immutable USDT;

    /// @notice Address of the game casino contract.
    address public immutable GAME_CASINO;

    /// @notice Number of request keys currently assigned.
    uint256 public totalRequests;

    /// @notice Unique key with respect to a unique request index.
    EnumerableSet.Bytes32Set private _requestKeys;

    /// @dev Claimer's claim request with respect to a unique key.
    mapping(bytes32 key => Request request) public requests;

    /* ========== STRUCTS ========== */

    struct Request {
        uint256 amount;
        /// @dev Time after which the claim request will be complete.
        uint256 claimRequestTime;
    }

    /* ========== EVENTS ========== */

    /// @dev Emitted when a claim request has been set.
    event RequestSet(address indexed claimer, uint256 index, uint256 amount, uint256 claimRequestTime);
    /// @dev Emitted when a claim request has been claimed.
    event RequestClaimed(address indexed claimer, uint256 index);
    /// @dev Emitted when multiple claim requests have been claimed.
    event MultipleRequestsClaimed(address indexed claimer, uint256[] indexes);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Constructor.
     * @param usdt_ Address of the USDT token contract.
     * @param gameCasino_ Address of the game casino contract.
     */
    constructor(IERC20 usdt_, address gameCasino_) Ownable(msg.sender) {
        if (address(usdt_) == address(0) || address(gameCasino_) == address(0)) {
            revert InvalidAddress();
        }

        USDT = usdt_;
        GAME_CASINO = gameCasino_;
    }

    /* ========== FUNCTIONS ========== */

    /**
     * @inheritdoc IClaiming
     */
    function setRequest(address claimer, uint256 amount) external nonReentrant {
        if (msg.sender != GAME_CASINO) {
            revert ClaimingUnauthorizedAccount(msg.sender);
        }

        if (claimer == address(0)) {
            revert InvalidAddress();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        uint256 index = totalRequests++;
        bytes32 key = _generateKey(claimer, index);
        _requestKeys.add(key);
        uint256 claimRequestTime = block.timestamp + _SEVEN_DAYS_TIME;
        requests[key] = Request({ amount: amount, claimRequestTime: claimRequestTime });

        emit RequestSet({ claimer: claimer, index: index, amount: amount, claimRequestTime: claimRequestTime });
    }

    /**
     * @inheritdoc IClaiming
     */
    function claimRequest(uint256 index) external nonReentrant {
        USDT.safeTransfer(msg.sender, _claimRequest(index));

        emit RequestClaimed({ claimer: msg.sender, index: index });
    }

    /**
     * @inheritdoc IClaiming
     */
    function claimMultipleRequests(uint256[] calldata indexes) external nonReentrant {
        uint256 indexesLength = indexes.length;

        if (indexesLength == 0) {
            revert ZeroLengthArray();
        }

        uint256 totalRequestAmount;

        for (uint256 i; i < indexesLength; ++i) {
            totalRequestAmount += _claimRequest(indexes[i]);
        }

        USDT.safeTransfer(msg.sender, totalRequestAmount);

        emit MultipleRequestsClaimed({ claimer: msg.sender, indexes: indexes });
    }

    /**
     *@notice Securely withdraw tokens, if stuck.
     *@param token The address of withdrawing token.
     *@param to The address of receiving account.
     *@param amount Amount to withdraw.
     */
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0) || to == address(0) || amount == 0) {
            revert InvalidAddress();
        }
        IERC20(token).transfer(to, amount);
    }

    /**
     * @inheritdoc IClaiming
     */
    function getRequest(uint256 index) external view returns (uint256, uint256) {
        Request memory request = requests[_requestKeys.at(index)];
        return (request.amount, request.claimRequestTime);
    }

    /**
     * @inheritdoc IClaiming
     */
    function getRequestKey(uint256 index) external view returns (bytes32) {
        return _requestKeys.at(index);
    }

    /**
     * @dev Implements logic for a completed claim request. DOES NOT transfer
     * claimable USDT tokens.
     * @return requestAmount Amount of USDT tokens in the claim request that
     * need to be processed.
     */
    function _claimRequest(uint256 index) private returns (uint256) {
        bytes32 key = _generateKey(msg.sender, index);
        Request memory request = requests[key];

        if (request.amount == 0) {
            revert InvalidClaimRequest();
        }

        if (block.timestamp < request.claimRequestTime) {
            revert ClaimRequestTimeNotReached();
        }

        _requestKeys.remove(key);
        delete requests[key];

        return request.amount;
    }

    /**
     * @notice Creates a unique key pertaining to the caller and the given
     * unique request index.
     * @param claimer Claimer who's tokens are being held.
     * @param index Request index to get the key for.
     * @return key Key that is present for the given request index.
     */
    function _generateKey(address claimer, uint256 index) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(claimer, index));
    }
}
