// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { RandomNumberService } from "../contracts/RandomNumberService.sol";
import { TokenPrice } from "../contracts/libraries/TokenPriceFeed.sol";
import { ITokenPrice } from "../contracts/interfaces/ITokenPrice.sol";

import { MockVRFCoordinator } from "./mocks/MockVRFCoordinator.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockChainlinkOperator } from "./mocks/MockChainlinkOperator.sol";
import { MockUniswapV3Pool } from "./mocks/MockUniswapV3Pool.sol";
import { RandomConsumer } from "./mocks/MockConsumer.sol";
import { LinkToken } from "./mocks/MockLink.sol";

contract RandomNumberServiceTest is Test {
    RandomNumberService public randomService;
    MockVRFCoordinator public vrfCoordinator;
    MockChainlinkOperator public oracle;
    RandomConsumer public consumer;

    // price feed
    MockUniswapV3Pool public mockPool;
    TokenPrice public tokenPrice;

    uint32 _callbackgaslimit = 500000;
    uint256 _vrfFee = 50000;

    // address _linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    LinkToken _linkToken = new LinkToken();

    uint256 _s_subscriptionId = 40374753366250789027179048010660087383234015108886007881528175225773216830170;
    bytes32 _s_keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address _Fee_Wallet = 0x82389495Bb548E00e901F8AC82E9761152898834;
    MockERC20 _Fee_Token;
    uint16 _s_requestConfirmations = 3;
    uint32 _s_numWords = 2;
    uint256 _oracle_payment = 10;
    address public _s_oracle = 0xa3947A3D9E01bC71655f160680b36D5438Ea0C7b; // actully a node wallet.

    address player = address(0xBEEF);

    function setUp() public {
        vrfCoordinator = new MockVRFCoordinator();
        oracle = new MockChainlinkOperator();

        // Deploy fee token with large supply to this test contract
        _Fee_Token = new MockERC20("Fee Token", "FEE", 1_000_000 ether);

        mockPool = new MockUniswapV3Pool(79228162514264337593543950336, address(_Fee_Token), address(_linkToken));
        tokenPrice = new TokenPrice(address(mockPool));

        RandomNumberService impl = new RandomNumberService();

        bytes memory initData = abi.encodeWithSelector(
            RandomNumberService.initialize.selector,
            _callbackgaslimit,
            _vrfFee,
            address(_linkToken),
            _s_subscriptionId,
            _s_keyHash,
            _Fee_Wallet,
            IERC20(address(_Fee_Token)),
            _s_requestConfirmations,
            _s_numWords,
            _oracle_payment,
            _s_oracle
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);

        randomService = RandomNumberService(address(proxy));

        randomService.setCoordinator(address(vrfCoordinator));
        randomService.setTokenPrice(ITokenPrice(address(tokenPrice)));

        randomService.setAuthorizedSender(_s_oracle, true);

        // Mint to player
        _Fee_Token.mint(player, 500_000 ether);
        // Mint to randomService contract
        _Fee_Token.mint(address(randomService), 500_000 ether);

        vm.prank(player);
        _Fee_Token.approve(address(randomService), type(uint256).max); // unlimited allowance
        consumer = new RandomConsumer(address(randomService));
        randomService.setWhitelistedConsumer(address(consumer), true);
        _linkToken.mint(address(randomService), 5_000 ether);
    }

    function testRequestVRF() public {
        // Call VRF request
        vm.prank(player);
        uint256 reqId = consumer.callVRFRequest();

        // Simulate VRF callback
        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] = uint256(123);
        randomWords[1] = uint256(456);

        vrfCoordinator.fulfillRandomWords(reqId, address(randomService), randomWords);
        // solhint-disable-next-line no-console
        console.log("000::reqIddd:", reqId);

        // Verify the state change
        (, , , uint256[] memory storedWords, ) = randomService.getRequestStatus(reqId);

        assertEq(storedWords[0], 123, "First random word should be stored correctly");

        uint256 consumerWord = consumer.randomWord(reqId);
        assertTrue(consumerWord > 0, "Consumer word should be set");
    }

    function testRequestEncryptedNumber() public {
        // consumer
        bytes32 reqId = consumer.callEncryptedNumberRequest("http://api.com", "data.hash", "job123", player);

        // Simulate Oracle callback
        bytes32 fakeHash = keccak256(abi.encodePacked("mocked"));
        vm.prank(_s_oracle);
        randomService.fulfillRandomWord(reqId, fakeHash);

        // solhint-disable-next-line no-console
        console.logBytes32(fakeHash);

        // Verify hash is stored
        uint256 requestId = uint256(reqId);
        (, , , , bytes32 storedHash) = randomService.getRequestStatus(requestId);

        // solhint-disable-next-line no-console
        console.logBytes32(storedHash);

        assertEq(storedHash, fakeHash, "Hash should be stored correctly");

        bytes32 consumerHash = consumer.encryptedWord(reqId);
        assertEq(consumerHash, fakeHash, "Hash should be stored correctly");
    }
}
