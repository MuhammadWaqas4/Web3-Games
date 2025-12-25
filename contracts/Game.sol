// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { GameCasinoErrors } from "./interfaces/Errors.sol";
import { IRandomNumberService } from "./interfaces/IRandomNumberService.sol";
import { IReservoir } from "./interfaces/IReservoir.sol";
import { ITreasury } from "./interfaces/ITreasury.sol";

/**
 * @title GameCasino.
 * @author Game Team.
 * @notice Decentralized betting platform where users can place bets, provide liquidity, and earn rewards.
 */
contract GameCasino is
    GameCasinoErrors,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    EIP712Upgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using Math for uint256;

    /// @notice Minimum amount of usdt required to place a bet (1 usdt).
    uint256 public constant MIN_BET = 1e6;

    /// @notice Denominator for all percentage calculations (i.e., 100% = 10000).
    uint256 public constant FEE_DENOMINATOR = 100_000;

    /// @notice Precision factor used for reward calculation.
    uint256 public constant PRECISION = 1e12;

    /// @notice Percentage of amount allocated to LPs.
    uint256 public constant LP_FEE_PERCENT = 3000;

    /// @notice Percentage of amount allocated to the jackpot.
    uint256 public constant JACKPOT_FEE_PERCENT = 500;

    /// @notice Percentage of amount allocated to buyback and burn.
    uint256 public constant BUYBACK_FEE_PERCENT = 1500;

    /// @notice K constant to calculate time passed in a game round.
    uint256 public constant K = 3900; // x 100_000

    /// @notice Start timer delay, after the fulfillRandomWord functions is called.
    uint256 private constant START_DELAY = 4 seconds;

    /// @dev EIP712 type hash.
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @dev Cashout type hash.
    bytes32 private constant _CASHOUT_TYPEHASH =
        keccak256("Cashout(uint256 index, uint256 cashOutTime, bytes memory signature)");

    /// @dev EIP712 domain separator.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    bytes32 private immutable _DOMAIN_SEPARATOR =
        keccak256(
            abi.encode(_TYPE_HASH, keccak256(bytes("GameCasino")), keccak256(bytes("1")), block.chainid, address(this))
        );

    /// @notice Total of all placed bets.
    uint256 public totalVolume;

    /// @notice Total won.
    uint256 public totalWinnings;

    /// @notice Total lost.
    uint256 public totalLost;

    /// @notice Total earned fee.
    uint256 public totalRewards;

    /// @notice Accumulated jackpot from bets.
    uint256 public jackpot;

    /// @notice Accumulated tokens reserved for buyback and burn.
    uint256 public buyBackAndBurnAmount;

    /// @notice Minimum allowed odds for a bet.
    uint256 public minOdds;

    /// @notice Maximum allowed odds for a bet.
    uint256 public maxOdds;

    /// @notice Maximum odds used to calculate betting ratio.
    uint256 public oddsDenominator;

    /// @notice Divider to scale down the max bet relative to liquidity and odds.
    uint256 public liquidityDivider;

    /// @notice Index of the current crash game round.
    uint256 public currentIndex;

    /// @notice Total bets placed amount in a round.
    uint256 public currentRoundLp;

    /// @notice Signer address.
    address public signer;

    /// @notice Address of the Tether USD token, used for betting and LP staking.
    IERC20 public usdt;

    /// @notice Address of the random number service contract.
    IRandomNumberService public rng;

    /// @notice Address of the asset reservoir.
    IReservoir public reservoir;

    /// @notice Treasury address to collect buyback and burn fee.
    ITreasury public treasury;

    /// @notice Http url.
    string public url;

    /// @notice path Json path.
    string public path;

    /// @notice Oracle job id.
    string public jobId;

    /// @notice Current round's encrypted number.
    bytes32 public encryptedNumber;

    /// @notice Tracks the VRF request status.
    mapping(uint256 requestId => RequestStatus requestStatus) public s_requests;

    /// @notice Tracks whether a specific crash round has started.
    mapping(uint256 => bool) public roundStarted;

    /// @notice Mapping of player address and round index to their crash bet.
    mapping(uint256 => Round) public rounds;

    /// @notice Mapping of player address and round index to their crash bet.
    mapping(address => mapping(uint256 => CrashBet)) public crashPendingBets;

    /// @dev To authorize random number service.
    mapping(address => bool) public isAuthorizedSender;

    /**
     * @dev Struct representing an individual bet.
     */
    struct Bet {
        bool resolved;
        uint256 amount;
        uint256 odds;
        uint256 blockPlaced;
        uint256 timestampPlaced;
        uint256 requestId;
    }

    /**
     * @dev Struct reperesenting the result from VRF.
     */
    struct RequestStatus {
        bool fulfilled;
        address player;
        uint256 randomWord;
    }

    /**
     * @notice Represents a crash-game round.
     */
    struct Round {
        bytes32 requestId;
        uint256 startTime;
        bytes32 crashDelay;
    }

    /**
     * @notice Represents a bet data in a crash round.
     */
    struct CrashBet {
        uint256 amount;
        uint256 blockPlaced;
        uint256 timestampPlaced;
        bool resolved;
        bool cashedOut;
    }

    /**
     * @dev Emitted when chainlink return random words.
     * @param randomWords random numbers.
     */
    event ReturnedRandomness(uint256 randomWords);

    /**
     * @dev Emitted when the claiming contract is updated.
     * @param oldClaiming previous claiming contract.
     * @param newClaiming updated claiming contract.
     */
    event ClaimingUpdated(address indexed oldClaiming, address indexed newClaiming);

    /**
     * @dev Emitted when a user deposits usdt into the LP pool.
     * @param user Address of the LP.
     * @param amount Amount deposited.
     */
    event Deposited(address indexed user, uint256 amount);

    /**
     *  @dev Emitted when a user withdraws usdt from the LP pool.
     *  @param user Address of the LP.
     *  @param amount Amount withdrawn.
     */
    event Withdrawn(address indexed user, uint256 amount);

    /**
     * @dev Emitted when a user places a bet.
     * @param player Address of the bettor.
     * @param amount Bet amount.
     * @param odds Bet odds.
     */
    event BetPlaced(address indexed player, uint256 amount, uint256 odds, uint256 requestId);

    /**
     * @dev Emitted when a user's bet is resolved.
     * @param player Address of the bettor.
     * @param won Whether the user won.
     * @param odds Odd number.
     * @param payout Amount paid out if won.
     * @param random Random number generated for the bet.
     * @param jackpot Jackpot amount if won the jackpot.
     * @param requestId VRF request id.
     */
    event BetResolved(
        address indexed player,
        bool won,
        uint256 amount,
        uint256 odds,
        uint256 payout,
        uint256 random,
        uint256 jackpot,
        uint256 requestId
    );

    /**
     * @dev Emitted when a user claims their LP rewards.
     * @param user Address of the user.
     * @param amount Amount claimed.
     */
    event RewardClaimed(address indexed user, uint256 amount);

    /**
     * @dev Emitted when fees are burnt.
     * @param amount Amount of game burnt.
     */
    event TokenBurned(uint256 amount);

    /**
     * @dev Emitted when the minimum odds are updated.
     * @param oldMinOdds Previous minimum odds.
     * @param newMinOdds Updated minimum odds.
     */
    event MinOddsUpdated(uint256 oldMinOdds, uint256 newMinOdds);

    /**
     * @dev Emitted when the maximum odds are updated.
     * @param oldMaxOdds Previous maximum odds.
     * @param newMaxOdds Updated maximum odds.
     */
    event MaxOddsUpdated(uint256 oldMaxOdds, uint256 newMaxOdds);

    /**
     * @dev Emitted when the odds denominator is updated.
     * @param oldOddsDenominator Previous odds denominator.
     * @param newOddsDenominator Updated odds denominator.
     */
    event OddsDenominatorUpdated(uint256 oldOddsDenominator, uint256 newOddsDenominator);

    /**
     * @dev Emitted when the liquidity divider is updated.
     * @param oldLiquidityDivider Previous liquidity divider.
     * @param newLiquidityDivider Updated liquidity divider.
     */
    event LiquidityDividerUpdated(uint256 oldLiquidityDivider, uint256 newLiquidityDivider);

    /**
     * @notice Emitted when a user places a bet.
     * @param requestId Bet VRF id.
     * @param currentIndex Bet index.
     */
    event RoundStartRequest(bytes32 indexed requestId, uint256 currentIndex);

    /**
     * @notice Emitted when a user places a bet.
     * @param requestId Bet VRF id.
     * @param currentIndex Bet index.
     * @param startTime Game start time.
     * @param encryptedNumber Game end time.
     */
    event GameStarted(bytes32 indexed requestId, uint256 currentIndex, uint256 startTime, bytes32 encryptedNumber);

    /**
     * @notice Emitted when a user places a bet.
     * @param player Address of the bettor.
     * @param amount Bet amount.
     * @param index Bet round id.
     */
    event CrashBetPlaced(address indexed player, uint256 amount, uint256 index);

    /**
     * @notice Emitted when a user's bet is resolved.
     * @param player Address of the bettor.
     * @param won Whether the user won.
     * @param payout Amount paid out if won.
     * @param timepassed Time passed since the bet was placed.
     * @param cashOutTime Time at which the bet is bet is resolved.
     * @param amount The bet placed amount.
     * @param index Bet round id.
     */
    event CrashBetResolved(
        address indexed player,
        bool won,
        uint256 payout,
        uint256 timepassed,
        uint256 cashOutTime,
        uint256 amount,
        uint256 index
    );

    /**
     * @dev Emitted when we verify a random number.
     * @param indexId Round id.
     * @param rng Verified random number in last round.
     */
    event PreviousRound(uint256 indexed indexId, uint256 indexed rng);

    /**
     * @dev prevents non-authorized addresses from calling this method
     */
    modifier validateAuthorizedSender() {
        _validateAuthorizedSender();
        _;
    }

    /**
     * @dev Constructor.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with core configuration parameters.
     */
    function initialize(
        uint256 _minOdds,
        uint256 _maxOdds,
        uint256 _oddsDenominator,
        uint256 _liquidityDivider,
        address _signer,
        string memory _url,
        string memory _path,
        string memory _jobId,
        address _usdt,
        address _rng,
        address _reservoir,
        address _treasury
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __EIP712_init("GameCasino", "1");
        __ReentrancyGuard_init();

        minOdds = _minOdds;
        maxOdds = _maxOdds;
        oddsDenominator = _oddsDenominator;
        liquidityDivider = _liquidityDivider;

        signer = _signer;

        url = _url;
        path = _path;
        jobId = _jobId;

        usdt = IERC20(_usdt);
        rng = IRandomNumberService(_rng);
        reservoir = IReservoir(_reservoir);
        treasury = ITreasury(_treasury);

        isAuthorizedSender[_rng] = true;
    }

    /**
     * @notice Update request parameters.
     * @param newURL New request url.
     * @param newPath New request path.
     * @param newJobId New request jobId.
     */
    function updateRequestParams(
        string memory newURL,
        string memory newPath,
        string memory newJobId
    ) external onlyOwner {
        url = newURL;
        path = newPath;
        jobId = newJobId;
    }

    /**
     * @notice Updates the callback gas limit for chainlink vrf callback function.
     * @param newSigner Signer address.
     */
    function updateSigner(address newSigner) external onlyOwner {
        signer = newSigner;
    }

    /**
     * @notice Updates the minimum allowed odds for placing a bet.
     * @param newMinOdds The new minimum odds value.
     */
    function updateMinOdds(uint256 newMinOdds) external onlyOwner {
        if (newMinOdds == 0) {
            revert InsufficientMinimumOdds();
        }

        emit MinOddsUpdated({ oldMinOdds: minOdds, newMinOdds: newMinOdds });

        minOdds = newMinOdds;
    }

    /**
     * @notice Updates the maximum allowed odds for placing a bet.
     * @param newMaxOdds The new maximum odds value.
     */
    function updateMaxOdds(uint256 newMaxOdds) external onlyOwner {
        if (newMaxOdds <= minOdds) {
            revert InsufficientMaximumOdds();
        }

        emit MaxOddsUpdated({ oldMaxOdds: maxOdds, newMaxOdds: newMaxOdds });

        maxOdds = newMaxOdds;
    }

    /**
     * @notice Updates the odds denominator used for max bet calculation.
     * @param newOddsDenominator The new odds denominator (typically 94 or 95).
     */
    function updateOddsDenominator(uint256 newOddsDenominator) external onlyOwner {
        if (newOddsDenominator <= 1) {
            revert InvalidOddsDenominator();
        }

        emit OddsDenominatorUpdated({ oldOddsDenominator: oddsDenominator, newOddsDenominator: newOddsDenominator });

        oddsDenominator = newOddsDenominator;
    }

    /**
     * @notice Updates the liquidity divider used to scale the max bet relative to liquidity.
     * @param newLiquiditydivider The new liquidity divider value.
     */
    function updateLiquidityDivider(uint256 newLiquiditydivider) external onlyOwner {
        if (newLiquiditydivider <= 1) {
            revert InvalidLiquidityDivider();
        }

        emit LiquidityDividerUpdated({
            oldLiquidityDivider: liquidityDivider,
            newLiquidityDivider: newLiquiditydivider
        });

        liquidityDivider = newLiquiditydivider;
    }

    /**
     * @notice Start new round, can be called by owner only.
     * @param previousRandom Previous round's random number.
     * @param previousSuffix Previous round's salt.
     */
    function startRound(uint16 previousRandom, string memory previousSuffix) external whenNotPaused onlyOwner {
        _startRound(previousRandom, previousSuffix);
    }

    /**
     * @notice Places a bet with given amount in current round.
     * @param amount Bet amount.
     * @param index Round index.
     * @param previousRandom Previous round's random number.
     * @param previousSuffix Previous round's salt.
     */
    function placeCrashBet(
        uint256 amount,
        uint256 index,
        uint16 previousRandom,
        string memory previousSuffix
    ) external whenNotPaused nonReentrant {
        if (currentIndex != index) {
            revert CrashInvalidRoundIndex();
        }

        if (!roundStarted[index]) {
            _startRound(previousRandom, previousSuffix);
        }

        Round memory currentRound = rounds[index];
        CrashBet memory existingBet = crashPendingBets[msg.sender][index];

        if (currentRound.startTime != 0) {
            revert CrashRoundAlreadyStarted();
        }

        uint256 maxBet = ((reservoir.totalAssets(usdt) - reservoir.totalFees()) / oddsDenominator) / liquidityDivider;

        if (amount < MIN_BET || amount > maxBet) {
            revert InvalidBetParameters();
        }

        if (existingBet.amount > 0 && !existingBet.resolved) {
            revert UnresolvedBetStillActive();
        }

        uint256 lpFee = (amount * LP_FEE_PERCENT) / FEE_DENOMINATOR;
        uint256 buybackFee = (amount * BUYBACK_FEE_PERCENT) / FEE_DENOMINATOR;
        uint256 jackpotFee = (amount * JACKPOT_FEE_PERCENT) / FEE_DENOMINATOR;
        uint256 bet = amount - (lpFee + buybackFee + jackpotFee);

        usdt.safeTransferFrom(msg.sender, address(reservoir), lpFee);
        reservoir.absorb(usdt, lpFee, IReservoir.AbsorptionCause.FEE);

        usdt.safeTransferFrom(msg.sender, address(treasury), buybackFee);
        treasury.deposit(usdt, buybackFee);

        usdt.safeTransferFrom(msg.sender, address(this), bet + jackpotFee);
        jackpot += jackpotFee;

        totalRewards += lpFee;
        buyBackAndBurnAmount += buybackFee;
        totalVolume += amount;
        jackpot += jackpotFee;
        currentRoundLp += bet;

        crashPendingBets[msg.sender][index] = CrashBet({
            amount: bet,
            blockPlaced: block.number,
            timestampPlaced: block.timestamp,
            resolved: false,
            cashedOut: false
        });

        emit CrashBetPlaced(msg.sender, amount, index);
    }

    function _sqrt(uint256 num) internal pure returns (uint256) {
        num = num * 1e6;
        uint256 value = num.sqrt();
        value = value * num;
        return value / 1e6;
    }

    /**
     * @notice Cashes out a placed crash bet based on signed time.
     * @param index The round index for the player's bet.
     * @param cashOutTime The time at which player wants to cash out.
     * @param signature The EIP712 signature to validate crashOutTime.
     * @dev Emits a {CrashBetResolved} event.
     */
    function cashout(
        uint256 index,
        uint256 cashOutTime,
        bytes memory signature
    ) external nonReentrant returns (uint256) {
        Round memory currentRound = rounds[index];
        CrashBet memory bet = crashPendingBets[msg.sender][index];

        delete crashPendingBets[msg.sender][index];

        if (currentRound.startTime == 0) {
            revert GameNotStarted();
        }

        _validateSignature(_CASHOUT_TYPEHASH, cashOutTime, index, msg.sender, signature);

        if (bet.amount == 0) {
            revert NoActiveBet();
        }

        if (bet.resolved) {
            revert BetAlreadyResolved();
        }

        if (bet.cashedOut) {
            revert BetAlreadyResolved();
        }

        bet.resolved = true;

        uint256 t = (cashOutTime - currentRound.startTime);

        if (t > 93) {
            revert InvalidAmount();
        }

        uint256 payout;

        if (t <= 10) {
            t = (t * 1e6) / 10 + 1e6;
            payout = (bet.amount * t) / 1e6;
        } else if (t > 10 && t <= 20) {
            t = (t * 1e6) / 5;
            payout = (bet.amount * t) / 1e6;
        } else {
            uint256 val = t - 20;
            val = _sqrt(val);
            t = 4 * (1 + (K * val) / FEE_DENOMINATOR / 1e3);
            payout = (bet.amount * t);
        }

        reservoir.disburse(usdt, payout, msg.sender);

        totalWinnings += payout;

        emit CrashBetResolved(msg.sender, true, payout, t, cashOutTime, bet.amount, index);

        return t;
    }

    /**
     * @notice Verifies the authenticity of the EIP712 off-chain signature.
     * @param typeHash The EIP712 type hash.
     * @param time The cashout time signed off-chain.
     * @param round The crash round index.
     * @param sender The address that signed the message.
     * @param signature The signature to validate.
     * @dev Reverts if signature is invalid.
     */
    function _validateSignature(
        bytes32 typeHash,
        uint256 time,
        uint256 round,
        address sender,
        bytes memory signature
    ) internal view {
        bytes32 structHash = keccak256(abi.encode(typeHash, sender, time, round));
        bytes32 hash = _DOMAIN_SEPARATOR.toTypedDataHash(structHash);

        if (signer != hash.recover(signature)) {
            revert InvalidAddress();
        }
    }

    /**
     * @notice Verifies the previous round's prevRandom.
     * @dev Reverts if hash is not verified.
     * @param previousRandom Previous round's random number.
     * @param previousSuffix Previous round's salt.
     */
    function _validatePrevRound(uint16 previousRandom, string memory previousSuffix) internal {
        bytes memory encoded = abi.encode(previousRandom, previousSuffix);
        bytes32 hash = keccak256(encoded);
        if (currentIndex > 0) {
            emit PreviousRound({ indexId: currentIndex - 1, rng: previousRandom });

            if (encryptedNumber != hash) {
                revert InvalidHash();
            }
        }
    }

    /**
     * @notice Callback function used by chainlink node.
     * @param requestId Id of the request.
     * @param encrypted Hashed number from Node.
     */
    function fulfillRandomHash(bytes32 requestId, bytes32 encrypted) public validateAuthorizedSender {
        encryptedNumber = encrypted;

        rounds[currentIndex] = Round({
            requestId: requestId,
            startTime: block.timestamp + START_DELAY,
            crashDelay: encrypted
        });

        emit GameStarted({
            requestId: requestId,
            currentIndex: currentIndex,
            startTime: block.timestamp + START_DELAY,
            encryptedNumber: encrypted
        });

        currentIndex++;
    }

    /**
     * @notice Meant to rescue jackpot in the case of a fault.
     * @dev Can only be called when all bets are paused so as to avoid user's funds from being stuck.
     */
    function rescue() external whenPaused onlyOwner {
        usdt.safeTransfer(msg.sender, jackpot);
    }

    /**
     * @notice Pauses bets.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses bets.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Internal function to start a new round.
     * @param previousRandom Previous round's random number.
     * @param previousSuffix Previous round's salt.
     */
    function _startRound(uint16 previousRandom, string memory previousSuffix) internal {
        _validatePrevRound(previousRandom, previousSuffix);

        usdt.safeTransfer(address(reservoir), currentRoundLp);
        reservoir.absorb(usdt, currentRoundLp, IReservoir.AbsorptionCause.RETURN);
        currentRoundLp = 0;

        bytes32 requestId = rng.requestEncryptedNumber(url, path, jobId, msg.sender);
        roundStarted[currentIndex] = true;

        emit RoundStartRequest({ requestId: requestId, currentIndex: currentIndex });
    }

    /**
     * @dev Internal function to convert string to bytes32.
     */
    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @notice Authorizes contract upgrades to a new implementation address.
     * @dev Overrides `_authorizeUpgrade` from UUPSUpgradeable and restricts upgrades to the `owner`.
     * @param newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        if (newImplementation == address(0)) {
            revert InvalidAddress();
        }
    }

    function _validateAuthorizedSender() private view {
        if (!isAuthorizedSender[msg.sender]) {
            revert Unauthorized();
        }
    }

    uint256[50] private __gap;
}
