// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IERC20Burnable } from "../contracts/interfaces/IERC20Burnable.sol";
import { _AUTHORITY_ROLE } from "../contracts/shared/Constants.sol";

import { GameCasino } from "../contracts/Game.sol";
import { Reservoir } from "../contracts/Reservoir.sol";
import { Treasury } from "../contracts/Treasury.sol";

import { SignHelper } from "./helpers/SignHelper.sol";

import { MockRandomNumberService } from "./mocks/MockRandomNumberService.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract GameCasinoTest is Test {
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _CASHOUT_TYPEHASH =
        keccak256("Cashout(uint256 index, uint256 cashOutTime, bytes memory signature)");

    MockERC20 public usdt;

    MockRandomNumberService public service;
    GameCasino public gameCasino;
    Reservoir public reservoir;
    Treasury public treasury;

    bytes32 public domainSeparator;

    address public owner = address(0xBEEF);
    address public manager = address(0xCAFE);
    IERC20Burnable public placeholderTokenAddress = IERC20Burnable(address(0xFEED));
    uint256 public signerPrivateKey = 1111;
    address public signer = vm.addr(signerPrivateKey);

    function setUp() external {
        usdt = new MockERC20("Tether USD", "USDT", 1_000_000_000 * 1e6);

        Treasury treasuryImplementation;
        Reservoir reservoirImplementation;
        GameCasino gameCasinoImplementation;
        bytes memory data;
        ERC1967Proxy proxy;
        IERC20[] memory assetsList = new IERC20[](1);
        assetsList[0] = usdt;

        // Deploying RandomNumberService.
        service = new MockRandomNumberService();
        // Deploying Reservoir.
        reservoirImplementation = new Reservoir();
        data = abi.encodeWithSelector(Reservoir.initialize.selector, assetsList, owner);
        proxy = new ERC1967Proxy(address(reservoirImplementation), data);
        reservoir = Reservoir(address(proxy));
        // Deploying Treasury.
        treasuryImplementation = new Treasury();
        data = abi.encodeWithSelector(Treasury.initialize.selector, owner, manager, placeholderTokenAddress);
        proxy = new ERC1967Proxy(address(treasuryImplementation), data);
        treasury = Treasury(address(proxy));
        // Deploying GameCasino.
        gameCasinoImplementation = new GameCasino();
        data = abi.encodeWithSelector(
            GameCasino.initialize.selector,
            1,
            94,
            95,
            5,
            signer,
            "AAAA",
            "BBBB",
            "CCCC",
            address(usdt),
            address(service),
            address(reservoir),
            address(treasury)
        );
        proxy = new ERC1967Proxy(address(gameCasinoImplementation), data);
        gameCasino = GameCasino(address(proxy));

        domainSeparator = keccak256(
            abi.encode(
                _TYPE_HASH,
                keccak256(bytes("GameCasino")),
                keccak256(bytes("1")),
                block.chainid,
                address(gameCasinoImplementation)
            )
        );

        vm.startPrank(owner);

        reservoir.grantRole(_AUTHORITY_ROLE, address(gameCasino));
        treasury.grantRole(_AUTHORITY_ROLE, address(gameCasino));

        vm.stopPrank();

        uint256 toDeposit = 1_000_000 * 1e6;
        usdt.approve(address(reservoir), toDeposit);
        reservoir.deposit(usdt, toDeposit, address(this));

        vm.label(address(usdt), "USDT");
        vm.label(address(service), "Service");
        vm.label(address(gameCasino), "GameCasino");
        vm.label(address(reservoir), "Reservoir");
        vm.label(address(treasury), "Treasury");
        vm.label(owner, "Owner");
        vm.label(manager, "Manager");
        vm.label(address(placeholderTokenAddress), "GameToken");
        vm.label(signer, "Signer");
    }

    function test_Cashout_Crash() external {
        uint256 roundIndex = 0;

        usdt.approve(address(gameCasino), 1_000_000_000 * 1e6);
        gameCasino.placeCrashBet(10 * 1e6, roundIndex, 0, "");

        uint256 blockTimestamp = vm.getBlockTimestamp();
        vm.warp(blockTimestamp + 5);

        vm.prank(address(service));
        gameCasino.fulfillRandomHash(bytes32(uint256(1)), bytes32(uint256(2)));

        blockTimestamp = vm.getBlockTimestamp();
        vm.warp(blockTimestamp + 20);

        uint256 cashoutTime = vm.getBlockTimestamp();
        bytes32 hash = SignHelper.typedSignHash(domainSeparator, _CASHOUT_TYPEHASH, address(this), cashoutTime, 0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        gameCasino.cashout(roundIndex, cashoutTime, signature);
    }
}
