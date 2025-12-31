// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

library SignHelper {
    using MessageHashUtils for bytes32;

    /* ========================== FUNCTIONS ========================== */

    function typedSignHash(
        bytes32 domainSeparator,
        bytes32 functionTypeHash,
        address caller,
        uint256 cashoutTime,
        uint256 roundIndex
    ) external pure returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(functionTypeHash, caller, cashoutTime, roundIndex));
        bytes32 hash = domainSeparator.toTypedDataHash(structHash);

        return hash;
    }
}
