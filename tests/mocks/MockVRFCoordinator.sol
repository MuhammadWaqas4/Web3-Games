// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import { VRFV2PlusClient } from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import { VRFConsumerBaseV2PlusUpgradeable } from "../../contracts/libraries/VRFConsumerBaseV2PlusUpgradeable.sol";

contract MockVRFCoordinator {
    function fulfillRandomWords(uint256 requestId, address consumer, uint256[] memory randomWords) external {
        (bool success, ) = consumer.call(
            abi.encodeWithSelector(
                VRFConsumerBaseV2PlusUpgradeable.rawFulfillRandomWords.selector,
                requestId,
                randomWords
            )
        );
        require(success, "Callback failed");
    }

    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata req
    ) external view returns (uint256 requestId) {
        requestId = uint256(keccak256(abi.encode(req.keyHash, req.subId, block.timestamp)));
    }
}

contract MockOracle {
    function fulfillRandomWord(bytes32 requestId, address consumer, bytes32 encryptedNumber) external {
        (bool success, ) = consumer.call(
            abi.encodeWithSignature("fulfillRandomWord(bytes32,bytes32)", requestId, encryptedNumber)
        );
        require(success, "Callback failed");
    }
}
