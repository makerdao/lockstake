// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.16;

interface PipLike {
    function read() external view returns (uint128);
}

contract StickyOracle {
    mapping (address => uint256) public wards;
    mapping (address => uint256) public buds;  // Whitelisted feed readers
    mapping (uint16  => uint256) accumulators; // daily (eod) sticky oracle price accumulators

    PipLike public immutable pip;

    uint96 public slope = uint96(RAY); // maximum allowable price growth rate from center of TWAP window to now (in RAY)
    uint8  public lo; // how many days ago should the TWAP window start (exclusive)
    uint8  public hi; // how many days ago should the TWAP window end (inclusive)

    uint128        val; // last poked price
    uint32  public age; // time of last poke

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event File(bytes32 indexed what, uint256 data);

    constructor(
        address _pip
    ) {
        pip = PipLike(_pip);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    modifier auth {
        require(wards[msg.sender] == 1, "StickyOracle/not-authorized");
        _;
    }

    modifier toll { 
        require(buds[msg.sender] == 1, "StickyOracle/not-whitelisted"); 
        _;
    }

    uint256 internal constant RAY = 10 ** 27;

    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    function kiss(address usr) external auth { buds[usr]  = 1; emit Kiss(usr); }
    function diss(address usr) external auth { buds[usr]  = 0; emit Diss(usr); }

    function file(bytes32 what, uint256 data) external auth {
        if (what == "slope") slope = uint96(data);
        if (what == "lo")    lo    = uint8(data);
        if (what == "hi")    hi    = uint8(data);
        else revert("StickyOracle/file-unrecognized-param");
        require(lo > hi && hi > 0, "StickyOracle/invalid-window");
        emit File(what, data);
    }

    function _getCap() internal view returns (uint128 cap) {
        uint16 today = uint16(block.timestamp / 1 days);
        (uint96 slope_, uint16 lo_, uint16 hi_) = (slope, lo, hi);
        uint256 acc_lo = accumulators[today - lo_];
        uint256 acc_hi = accumulators[today - hi_];

        if (acc_lo == 0 || acc_hi == 0) return pip.read(); // TODO: do something smarter (use partial window or extrapolate missing daily accs)
        uint256 cap_ = (acc_hi - acc_lo) * slope_ / (RAY * (lo_ - hi_) * 1 days);
        return cap_ < type(uint128).max ? uint128(cap_) : type(uint128).max;
    }

    function poke() public {
        uint128 cur = read();
        uint16 today = uint16(block.timestamp / 1 days);
        uint256 acc = accumulators[today];
        (uint128 val_, uint32 age_) = (val, age);
        uint256 newAcc;
        uint256 tmrTs = (today + 1) * 1 days; // timestamp on the first second of tomorrow
        if (acc == 0) { // first poke of the day
            if (age_ > 0) {
                uint16 prevDay = uint16(age_ / 1 days);
                uint256 bef = val_ * (block.timestamp - (prevDay + 1) * 1 days); // contribution to the accumulator from the previous value
                uint256 aft = cur * (tmrTs - block.timestamp); // contribution to the accumulator from the current value, optimistically assuming this will be the last poke of the day
                newAcc = accumulators[prevDay] + bef + aft;
            } else {
                newAcc = cur * 1 days; // optimistically assume this will be the last poke of the day
            }
        } else { // not the first poke of the day
            uint256 off = tmrTs - age_; // period during which the accumulator value needs to be adjusted 
            newAcc = acc + cur * off - val_ * off;
        }
        accumulators[today] = newAcc;
        val = cur;
        age = uint32(block.timestamp);
    }

    function read() public view toll returns (uint128) {
        uint128 cur = pip.read();
        uint128 cap = _getCap();
        return cur < cap ? cur : cap;
    }

    function peek() external view toll returns (uint128, bool) {
        uint128 cur = pip.read();
        uint128 cap = _getCap();
        return (cur < cap ? cur : cap, cur > 0);
    }
}
