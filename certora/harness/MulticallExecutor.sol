// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { LockstakeEngine } from "../../src/LockstakeEngine.sol";


contract MulticallExecutor {

    LockstakeEngine public engine;

    function hopeAndHope(address owner1, uint256 index1, address owner2, uint256 index2, address usr) public {

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("hope(address,uint256,address)", owner1, index1, usr);
        calls[1] = abi.encodeWithSignature("hope(address,uint256,address)", owner2, index2, usr);
        engine.multicall(calls);
    }
    
    function hopeAndNope(address owner, uint256 index, address usr) public {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("hope(address,uint256,address)", owner, index, usr);
        calls[1] = abi.encodeWithSignature("nope(address,uint256,address)", owner, index, usr);
        engine.multicall(calls);
    }

    function selectFarmAndLock(
        address owner,
        uint256 index,
        address farm,
        uint16  ref,
        uint256 wad
    ) public {

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature(
            "selectFarm(address,uint256,address,uint16)", owner, index, farm, ref
        );
        calls[1] = abi.encodeWithSignature(
            "lock(address,uint256,uint256,uint16)", owner, index, wad, ref
        );
        engine.multicall(calls);
    }
}
