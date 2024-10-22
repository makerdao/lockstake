// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

interface GemLike {
    function burn(address, uint256) external;
    function mint(address, uint256) external;
}

contract MkrSkyMock {
    GemLike public immutable mkr;
    GemLike public immutable sky;
    uint256 public immutable rate;

    constructor(address mkr_, address sky_, uint256 rate_) {
        mkr  = GemLike(mkr_);
        sky  = GemLike(sky_);
        rate = rate_;
    }

    function mkrToSky(address usr, uint256 mkrAmt) external {
        mkr.burn(msg.sender, mkrAmt);
        uint256 skyAmt = mkrAmt * rate;
        sky.mint(usr, skyAmt);
    }

    function skyToMkr(address usr, uint256 skyAmt) external {
        sky.burn(msg.sender, skyAmt);
        uint256 mkrAmt = skyAmt / rate;
        mkr.mint(usr, mkrAmt);
    }
}
