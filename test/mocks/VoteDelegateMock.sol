// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

interface GemLike {
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}

contract VoteDelegateMock {
    mapping(address => uint256) public stake;

    GemLike immutable public gov;

    constructor(address gov_) {
        gov = GemLike(gov_);
    }

    // --- GOV owner functions

    function lock(uint256 wad) external {
        gov.transferFrom(msg.sender, address(this), wad);
        stake[msg.sender] += wad;
    }

    function free(uint256 wad) external {
        stake[msg.sender] -= wad;
        gov.transfer(msg.sender, wad);
    }
}
