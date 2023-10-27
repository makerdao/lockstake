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
    function peek() external view returns (uint128, bool);
}

contract StickyOracle {
    mapping (address => uint256) public wards;
    mapping (address => uint256) public buds;  // Whitelisted feed readers
    mapping (uint256  => uint256) accumulators; // daily (eod) sticky oracle price accumulators

    PipLike public immutable pip;

    uint96 public slope = uint96(RAY); // maximum allowable price growth factor from center of TWAP window to now (in RAY such that slope = (1 + {max growth rate}) * RAY)
    uint8  public lo; // how many days ago should the TWAP window start (exclusive)
    uint8  public hi; // how many days ago should the TWAP window end (inclusive)

    uint128        val; // last poked price
    uint32  public age; // time of last poke

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event File(bytes32 indexed what, uint256 data);

    constructor(address _pip) {
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
        if      (what == "slope") slope = uint96(data);
        else if (what == "lo")       lo = uint8(data);
        else if (what == "hi")       hi = uint8(data);
        else revert("StickyOracle/file-unrecognized-param");
        emit File(what, data);
    }

    function _min(uint128 a, uint128 b) internal pure returns (uint128 min) {
        return a < b ? a : b;
    }

    function _getCap() internal view returns (uint128 cap) {
        uint256 today = block.timestamp / 1 days;
        (uint96 slope_, uint8 lo_, uint8 hi_) = (slope, lo, hi);
        require(hi_ > 0 && lo_ > hi_, "StickyOracle/invalid-window");

        uint256 acc_lo = accumulators[today - lo_];
        uint256 acc_hi = accumulators[today - hi_];

        if (acc_lo > 0 && acc_hi > 0) {
            return uint128((acc_hi - acc_lo) * slope_ / (RAY * (lo_ - hi_) * 1 days));
        }

        uint256 val_ = val;
        require(val_ > 0, "StickyOracle/not-init");
        return uint128(val_ * slope_ / RAY); // fallback for missing accumulators
    }

    function init(uint256 days_) external auth {
        require(val == 0, "StickyOracle/already-init");
        uint128 cur = pip.read();
        uint256 start = block.timestamp / 1 days - days_ - 1; // day before the first initiated day
        uint256 day;
        for(uint256 i = 1; i <= days_ + 1;) {
            unchecked { day = start + i; }
            accumulators[day] = cur * i * 1 days;
            unchecked { ++i; }
        }
        val = cur;
        age = uint32(block.timestamp);
    }

    function fix(uint256 day) external {
        uint256 today = block.timestamp / 1 days;
        require(day < today, "StickyOracle/too-soon");
        require(accumulators[day] == 0, "StickyOracle/nothing-to-fix");
        
        uint256 acc1; uint256 acc2;
        uint i; uint j;
        for(i = 1; (acc1 = accumulators[day - i]) == 0; ++i) {}
        for(j = i + 1; (acc2 = accumulators[day - j]) == 0; ++j) {}

        accumulators[day] = acc1 + (acc1 - acc2) * i / (j - i);
    }

    function poke() external {
        uint128 cur = _min(pip.read(), _getCap());
        uint256 today = block.timestamp / 1 days;
        uint256 acc = accumulators[today];
        (uint128 val_, uint32 age_) = (val, age);
        uint256 newAcc;
        uint256 tmrTs = (today + 1) * 1 days; // timestamp on the first second of tomorrow
        if (acc == 0) { // first poke of the day
            uint256 prevDay = age_ / 1 days;
            uint256 bef = val_ * (block.timestamp - (prevDay + 1) * 1 days); // contribution to the accumulator from the previous value
            uint256 aft = cur * (tmrTs - block.timestamp); // contribution to the accumulator from the current value, optimistically assuming this will be the last poke of the day
            newAcc = accumulators[prevDay] + bef + aft;
        } else { // not the first poke of the day
            uint256 off = tmrTs - block.timestamp; // period during which the accumulator value needs to be adjusted 
            newAcc = acc + cur * off - val_ * off;
        }
        accumulators[today] = newAcc;
        val = cur;
        age = uint32(block.timestamp);
    }

    function read() external view toll returns (uint128) {
        return _min(pip.read(), _getCap());
    }

    function peek() external view toll returns (uint128, bool) {
        (uint128 cur,) = pip.peek();
        return (_min(cur, _getCap()), cur > 0);
    }
}
