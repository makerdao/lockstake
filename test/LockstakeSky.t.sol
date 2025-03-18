// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "token-tests/TokenChecks.sol";
import { LockstakeSky } from "src/LockstakeSky.sol";

contract LockstakeSkyTest is TokenChecks {
    address internal lockstakeSky = address(new LockstakeSky());

    function testBulkMintBurn() public {
        checkBulkMintBurn(lockstakeSky, "LockstakeSky");
    }

    function testBulkERC20() public {
        checkBulkERC20(lockstakeSky, "LockstakeSky", "LockstakeSky", "lsSKY", "1", 18);
    }
}
