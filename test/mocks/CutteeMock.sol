// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

interface ClipperLike {
    function Due() external view returns (uint256);
}

contract CutteeMock {
    mapping (address => uint256) public wards;

    bool    public dripCalled;
    bool    public cutCalled;
    uint256 public cutValue;
    uint256 public DueValue;

    constructor() {
        wards[msg.sender] = 1;
    }

    modifier auth {
        require(wards[msg.sender] == 1, "not-authorized");
        _;
    }

    function rely(address usr) external auth {
        wards[usr] = 1;
    }

    function drip() external {
        dripCalled = true;
    }

    function cut(uint256 value) external auth {
        cutCalled = true;
        cutValue = value;
        DueValue = ClipperLike(msg.sender).Due();
    }
}
