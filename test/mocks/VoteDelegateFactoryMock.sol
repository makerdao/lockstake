// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import {VoteDelegateMock} from  "./VoteDelegateMock.sol";

contract VoteDelegateFactoryMock {
    mapping(address => uint256) public created;
    address immutable private gov;

    constructor(address _gov) {
        gov = _gov;
    }

    function create() external returns (address voteDelegate) {
        voteDelegate = address(new VoteDelegateMock(gov));
        created[voteDelegate] = 1;
    }
}
