// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "token-tests/TokenChecks.sol";
import { LockstakeMkr } from "src/LockstakeMkr.sol";

contract LockstakeMkrTest is TokenChecks {
    address internal lockstakeMkr = address(new LockstakeMkr());

    function testBulkMintBurn() public {
        checkBulkMintBurn(lockstakeMkr, "LockstakeMkr");
    }

    function testBulkERC20() public {
        checkBulkERC20(lockstakeMkr, "LockstakeMkr", "LockstakeMkr", "LSMKR", "1", 18);
    }
}
