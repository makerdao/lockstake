// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import { LockstakeEngine } from "../../src/LockstakeEngine.sol";


/// @title For testing the `LockstakeEngine.multicall` function
contract MuticallTest {

    LockstakeEngine public engine;

    /// @dev Make two `hope` calls using the `multicall` function
    function makeMulticallHope(address urn1, address urn2, address usr) public {

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("hope(address,address)", urn1, usr);
        calls[1] = abi.encodeWithSignature("hope(address,address)", urn2, usr);
        engine.multicall(calls);
    }
    
    /// @dev `hope` followed by `nope` call
    function hopeThenNope(address urn, address usr) public {

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("hope(address,address)", urn, usr);
        calls[1] = abi.encodeWithSignature("nope(address,address)", urn, usr);
        engine.multicall(calls);
    }

    /// @dev Standard multicall sequence
    function standardMulticall(
        address urn,
        address farm,
        uint16 ref,
        uint256 wad
    ) public {

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature(
            "selectFarm(address,address,uint16)", urn, farm, ref
        );
        calls[1] = abi.encodeWithSignature(
            "lock(address,uint256,uint16)", urn, wad, ref
        );
        engine.multicall(calls);
    }
}
