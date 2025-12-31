// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

contract MockRandomNumberService {
    function requestEncryptedNumber(
        string memory,
        string memory,
        string memory,
        address
    ) external pure returns (bytes32) {
        return bytes32(uint256(1));
    }
}
