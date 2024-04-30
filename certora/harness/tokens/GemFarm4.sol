// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import {GemMock} from "../../../test/mocks/GemMock.sol";

contract GemFarm4 is GemMock {
    
    constructor(uint256 initialSupply) GemMock(initialSupply) {
    }
}
