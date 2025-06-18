// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

contract CutteeMock {
    bool    public dripCalled;
    bool    public cutCalled;
    uint256 public cutValue;

    function drip() external {
        dripCalled = true;
    }

    function cut(uint256 value) external {
        cutCalled = true;
        cutValue = value;
    }
}
