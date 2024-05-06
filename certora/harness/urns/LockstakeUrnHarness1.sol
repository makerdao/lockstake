// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import {LockstakeUrn} from "../../../src/LockstakeUrn.sol";

contract LockstakeUrnHarness1 is LockstakeUrn {
    
    constructor(address vat_, address stkMkr_) LockstakeUrn(vat_, stkMkr_) {
    }
}
