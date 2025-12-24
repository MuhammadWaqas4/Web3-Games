// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title GenericErrors.
 * @author Game Team.
 * @notice Errors being used in more than one contract.
 */
interface Errors {
    /**
     * @dev Indicates a failure with the given address, for example,
     * `address(0)`.
     */
    error InvalidAddress();

    /**
     * @dev Indicates an error with the given argument amount. For example, `0`.
     */
    error InvalidAmount();

    /**
     * @dev Indicates an error if Eth is not transferrd.
     */
    error ETHTransferFailed();

    /**
     * @dev Indicates an error with the given argument's assignment. For example, `argument == stateVariable`.
     */
    error InvalidAssignment();

    /**
     * @dev Oracle request already processed.
     */
    error RoundAlreadyProcessed();

    /**
     * @dev Node is not authorized to perform the action.
     */
    error Unauthorized();
}

/**
 * @title ClaimingErrors.
 * @author Game Team.
 * @notice Errors being used only in {Claiming}.
 */
interface ClaimingErrors is Errors {
    /**
     * @dev Indicates an error when the caller, `account`, is not authorized.
     */
    error ClaimingUnauthorizedAccount(address account);

    /**
     * @dev Indicates an error related to claimer's claim request when the
     * claim request time has not yet passed.
     */
    error ClaimRequestTimeNotReached();

    /**
     * @dev Indicates an error related to claimer's claim request when the
     * amount of tokens in the request is `0`.
     */
    error InvalidClaimRequest();

    /**
     * @dev Indicates a failure with the given array's length, i.e. array's
     * length is `0`.
     */
    error ZeroLengthArray();
}

/**
 * @title GameCasinoErrors.
 * @author Game Team.
 * @notice Errors being used only in {GameCasino}.
 */
interface GameCasinoErrors is Errors {
    /**
     * @dev Indicates an insufficient balance for the requested operation.
     */
    error AmountExceedsDeposit();

    /**
     * @dev Indicates that the bet has already been resolved.
     */
    error BetAlreadyResolved();

    /**
     * @dev Indicates that contracts are not allowed to interact with this function.
     */
    error CallerIsNotEOA();

    /**
     * @dev Indicates that the maximum odds must be greater than the minimum odds.
     */
    error InsufficientMaximumOdds();

    /**
     * @dev Indicates that the minimum odds must be greater than zero.
     */
    error InsufficientMinimumOdds();

    /**
     * @dev Indicates that there is insufficient liquidity in the pool for the payout.
     */
    error InsufficientPool();

    /**
     * @dev Indicates that the provided bet parameters are invalid, e.g., amount too low, odds out of range.
     */
    error InvalidBetParameters();

    /**
     * @dev Indicates that the liquidity divider must be greater than one.
     */
    error InvalidLiquidityDivider();

    /**
     * @dev Indicates that the odds denominator must be greater than one.
     */
    error InvalidOddsDenominator();

    /**
     * @dev Indicates that there is no active bet for the caller.
     */
    error NoActiveBet();

    /**
     * @dev Indicates that the round is started or not.
     */
    error GameNotStarted();

    /**
     * @dev Indicates that an unresolved bet is still active, preventing a new bet from being placed.
     */
    error UnresolvedBetStillActive();
    /**
     * @notice Thrown when the crash round index does not match the current active round.
     */
    error CrashInvalidRoundIndex();

    /**
     * @notice Thrown when a crash round has already started.
     */
    error CrashRoundAlreadyStarted();

    /**
     * @notice Thrown when the bet amount is below the minimum allowed.
     */
    error CrashBetBelowMinimum();

    /**
     * @notice Thrown when a previous unresolved bet exists and the game is still active.
     */
    error CrashBetUnresolvedActive();

    /**
     * @notice Thrown when the bet amount exceeds the calculated max allowed bet.
     */
    error CrashBetExceedsMax();

    /**
     * @dev Indicates that the encrypted number is not verified.
     */
    error InvalidHash();

    /**
     * @dev Indicates that the encrypted number is not verified.
     */
    error PreviousRoundInProgress();
}
