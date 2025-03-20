// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "../../src/LockstakeEngine.sol";

contract LockstakeEngineV1Mock is LockstakeEngine {
    constructor(
        address voteDelegateFactory_,
        address usdsJoin_,
        bytes32 ilk_,
        address mkr_,
        address lsmkr_,
        uint256 fee_
    ) LockstakeEngine(voteDelegateFactory_, usdsJoin_, ilk_, mkr_, lsmkr_, fee_) {
    }
}
