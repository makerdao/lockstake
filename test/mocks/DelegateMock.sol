// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

interface GemLike {
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}

contract DelegateFactoryMock {
    mapping(address => uint256) public created;
    address immutable public gov;

    constructor(address _gov) {
        gov = _gov;
    }

    function create() external returns (address delegate) {
        delegate = address(new DelegateMock(gov));
        require(delegate != address(0), "DelegateFactory/creation-failed");
        created[delegate] = 1;
    }
}

contract DelegateMock {
    mapping(address => uint256) public stake;

    GemLike immutable public gov;

    constructor(address gov_) {
        gov = GemLike(gov_);
    }

    // --- NGT owner functions

    function lock(uint256 wad) external {
        gov.transferFrom(msg.sender, address(this), wad);
        stake[msg.sender] = stake[msg.sender] + wad;
    }

    function free(uint256 wad) external {
        stake[msg.sender] -= wad;
        gov.transfer(msg.sender, wad);
    }
}
