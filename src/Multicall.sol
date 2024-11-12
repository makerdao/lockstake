// SPDX-License-Identifier: GPL-2.0-or-later

// Based on https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/base/Multicall.sol

pragma solidity ^0.8.21;

// Enables calling multiple methods in a single call to the contract
abstract contract Multicall  {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                if (result.length == 0) revert("multicall failed");
                assembly ("memory-safe") {
                    revert(add(32, result), mload(result))
                }
            }

            results[i] = result;
        }
    }
}
