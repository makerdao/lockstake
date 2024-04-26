// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

interface GemLike {
    function burn(address, uint256) external;
    function mint(address, uint256) external;
}

contract MkrNgtMock {
    GemLike public immutable mkr;
    GemLike public immutable ngt;
    uint256 public immutable rate;

    constructor(address mkr_, address ngt_, uint256 rate_) {
        mkr  = GemLike(mkr_);
        ngt  = GemLike(ngt_);
        rate = rate_;
    }

    function mkrToNgt(address usr, uint256 mkrAmt) external {
        mkr.burn(msg.sender, mkrAmt);
        uint256 ngtAmt = mkrAmt * rate;
        ngt.mint(usr, ngtAmt);
    }

    function ngtToMkr(address usr, uint256 ngtAmt) external {
        ngt.burn(msg.sender, ngtAmt);
        uint256 mkrAmt = ngtAmt / rate;
        mkr.mint(usr, mkrAmt);
    }
}
