// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockChainlinkOperator {
    address public requester;

    function requestData(
        string memory url,
        string memory path,
        string memory jobId,
        address player
    ) external returns (bytes32 requestId) {
        requester = msg.sender;
        requestId = keccak256(abi.encode(url, path, jobId, player, block.timestamp));
        return requestId;
    }

    function fulfillRandomWord(bytes32 requestId, bytes32 encryptedNumber) external {
        (bool success, ) = requester.call(
            abi.encodeWithSignature("fulfillRandomWord(bytes32,bytes32)", requestId, encryptedNumber)
        );
        require(success, "Callback failed");
    }
}
