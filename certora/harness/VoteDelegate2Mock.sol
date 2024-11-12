// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import {VoteDelegateMock} from "../../test/mocks/VoteDelegateMock.sol";

contract VoteDelegate2Mock is VoteDelegateMock {
    
    constructor(address gov) VoteDelegateMock(gov) {
    }
}
