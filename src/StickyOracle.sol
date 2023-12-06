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
    function read() external view returns (uint128); // TODO: shouldn't this (and our function) return bytes32? https://github.com/makerdao/osm/blob/e36c874b4e14fba860e48c0cf99cd600c0c59efa/src/osm.sol#L150C49-L150C56
    function peek() external view returns (uint128, bool); // TODO: shouldn't this (and our function) return (bytes32, bool)? https://github.com/makerdao/osm/blob/e36c874b4e14fba860e48c0cf99cd600c0c59efa/src/osm.sol#L142
}
// TODO: should we implement peep as well? (even if a dummy implementation) Scribe does - https://github.com/chronicleprotocol/scribe/blob/41f25a8a40f1a1d2ef62d6a073f98a3c57d23579/src/Scribe.sol#L276.

contract StickyOracle {
    mapping (address => uint256) public wards;
    mapping (address => uint256) public buds;       // whitelisted feed readers

    mapping (uint256 => Accumulator ) accumulators; // daily sticky oracle price accumulators
    uint128 cap;                                    // max allowed price
    uint128 pokePrice;                              // last price at which poke() was called
    uint256 pokeDay;                                // last day at which poke() was called

    uint96 public slope = uint96(RAY); // maximum allowable price growth factor from center of TWAP window to now (in RAY such that slope = (1 + {max growth rate}) * RAY)
    uint8  public lo; // how many days ago should the TWAP window start (exclusive), should be more than hi
    uint8  public hi; // how many days ago should the TWAP window end (inclusive), should be less than lo and more than 0

    PipLike public immutable pip;

    struct Accumulator {
        uint256 val;
        uint32  ts;
    }

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event Init(uint256 days_, uint128 pokePrice_);
    event Poke(uint256 indexed day, uint128 cap, uint128 pokePrice_);

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

    function _calcCap() internal view returns (uint128 cap_) {
        uint256 today = block.timestamp / 1 days;
        (uint96 slope_, uint8 lo_, uint8 hi_) = (slope, lo, hi);
        require(hi_ > 0 && lo_ > hi_, "StickyOracle/invalid-window");

        Accumulator memory acc_lo = accumulators[today - lo_];
        Accumulator memory acc_hi = accumulators[today - hi_];

        return (acc_lo.val > 0 && acc_hi.val > 0) ?
            uint128((acc_hi.val - acc_lo.val) * slope_ / (RAY * (acc_hi.ts - acc_lo.ts))) :
            0;
    }

    // days_ is the number of daily samples to initialize on top of the current one
    // days_ == N will fill up a window corresponding to [lo == N, hi == 1] along with the current day
    // days_ should be selected carefully as too many iterations can cause the transaction to run out of gas
    // if the initiated timespan is shorter than the [lo, hi] window the initial cap will just be used for longer
    function init(uint256 days_) external auth {
        require(cap == 0, "StickyOracle/already-init");

        uint128 pokePrice_ = pokePrice = cap = pip.read(); // TODO: should this use peek() and return true/false instead of reverting? it will be called from a spell so we don't want it to revert
        uint256 pokeDay_ = pokeDay = block.timestamp / 1 days;
        uint256 accumulatedVal = 0;
        uint32  accumulatedTs  = uint32(block.timestamp - days_ * 1 days);

        for (uint256 day = pokeDay_ - days_; day <= pokeDay_;) {
            accumulators[day].val = accumulatedVal;
            accumulators[day].ts  = accumulatedTs;

            accumulatedVal += pokePrice_ * 1 days;
            accumulatedTs  += 1 days;
            unchecked { ++day; }
        }

        emit Init(days_, pokePrice_);
    }

    function poke() external {
        uint256 today = block.timestamp / 1 days;
        require(accumulators[today].val == 0, "StickyOracle/already-poked-today");

        // calculate new cap if possible, otherwise use the current one
        uint128 cap_ = _calcCap();
        if (cap_ > 0) cap = cap_;
        else cap_ = cap;

        // update accumulator
        accumulators[today].val = accumulators[pokeDay].val + pokePrice * (block.timestamp - accumulators[pokeDay].ts);
        accumulators[today].ts = uint32(block.timestamp);

        // store for next accumulator calc
        uint128 pokePrice_ = pokePrice = _min(pip.read(), cap_);
        pokeDay = today;

        emit Poke(today, cap, pokePrice_);
    }

    // TODO: should we add stop functionality? the stop can set the cap to 0 and then we need to make sure poke() doesn't ovreride it

    function read() external view toll returns (uint128) {
        uint128 cap_ = cap;
        require(cap_ > 0, "StickyOracle/cap-not-set");  // TODO: decide if we need the cap_ require
        return _min(pip.read(), cap);
    }

    function peek() external view toll returns (uint128, bool) {
        uint128 cap_ = cap;
        (uint128 cur,) = pip.peek();
        return (_min(cur, cap_), cur > 0 && cap_ > 0); // TODO: decide if we need the cap_ condition
    }
}
