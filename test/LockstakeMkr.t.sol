// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "token-tests/TokenChecks.sol";
import { LockstakeMkr } from "src/LockstakeMkr.sol";

contract LockstakeMkrTest is TokenChecks {
    address internal lockstakeMkr = address(new LockstakeMkr());

    // ************************************************************************************************************
    // Mint/Burn
    // ************************************************************************************************************

    function testTokenAuth() public {
        checkTokenAuth(lockstakeMkr, "LockstakeMkr");
    }
    function testTokenModifiers() public {
        checkTokenModifiers(lockstakeMkr, "LockstakeMkr");
    }
    function testMint() public {
        checkMint(lockstakeMkr);
    }
    function testBurn() public {
        checkBurn(lockstakeMkr);
    }
    function testBurnDifferentFrom() public {
        checkBurnDifferentFrom(lockstakeMkr);
    }
    function testMintBadAddress() public {
        checkMintBadAddress(lockstakeMkr, "LockstakeMkr");
    }
    function testBurnInsufficientBalance() public {
        checkBurnInsufficientBalance(lockstakeMkr, "LockstakeMkr");
    }

    // ************************************************************************************************************
    // ERC20
    // ************************************************************************************************************

    function testMetadata() public {
        checkMetadata(lockstakeMkr, "LockstakeMkr", "LSMKR", "1", 18);
    }
    function testApprove() public {
        checkApprove(lockstakeMkr);
    }
    function testTransfer() public {
        checkTransfer(lockstakeMkr);
    }
    function testTransferBadAddress() public {
        checkTransferBadAddress(lockstakeMkr, "LockstakeMkr");
    }
    function testTransferInsufficientBalance() public {
        checkTransferInsufficientBalance(lockstakeMkr, "LockstakeMkr");
    }
    function testTransferFrom() public {
        checkTransferFrom(lockstakeMkr);
    }
    function testInfiniteApproveTransferFrom() public {
        checkInfiniteApproveTransferFrom(lockstakeMkr);
    }
    function testTransferFromBadAddress() public {
        checkTransferFromBadAddress(lockstakeMkr, "LockstakeMkr");
    }
    function testTransferFromInsufficientAllowance() public {
        checkTransferFromInsufficientAllowance(lockstakeMkr, "LockstakeMkr");
    }
    function testTransferFromInsufficientBalance() public {
        checkTransferFromInsufficientBalance(lockstakeMkr, "LockstakeMkr");
    }
}
