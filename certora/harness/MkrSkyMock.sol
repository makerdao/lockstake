// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface GemLike {
    function burn(address, uint256) external;
    function mint(address, uint256) external;
}

contract MkrSkyMock {
    uint256 public rate;
    GemLike public mkr;
    GemLike public sky;

    function mkrToSky(address usr, uint256 mkrAmt) external {
        mkr.burn(msg.sender, mkrAmt);
        sky.mint(usr, mkrAmt * rate);
    }
}
