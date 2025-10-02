// SPDX-FileCopyrightText: © 2025 Dai Foundation <www.daifoundation.org>
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
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.21;

interface OracleLike {
    function peek() external view returns (uint256, bool);
}

contract LockstakeStickyOsm {
    // --- storage variables ---

    mapping(address usr => uint256 allowed)     public wards;
    mapping(address usr => uint256 whitelisted) public bud;
    mapping(address usr => uint256 capped)      public capped;

    uint256 public stopped;
    uint128 public hop;
    uint128 public zzz;
    uint256 public cap;     // [wad]
    uint256 public alpha;   // >= 0 and <= 1 [wad]
    uint256 public top;     // >= 1 [wad]
    uint256 public ewma;    // [wad]

    struct Feed {
        uint128 val; // [wad]
        uint128 has;
    }

    Feed fCur; // Free Current Price
    Feed fNxt; // Free Next Price
    Feed lCur; // Limited Current Price
    Feed lNxt; // Limited Next Price

    // --- immutables ---

    OracleLike public immutable  src;

    // --- constants ---

    uint256 public constant WAD = 10**18;

    // --- events ---   

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event Lock(address indexed usr);
    event Free(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event LogValue(bytes32 val);

    // --- modifiers ---

    modifier auth {
        require(wards[msg.sender] == 1, "LockstakeStickyOsm/not-authorized");
        _;
    }

    modifier toll {
        require(bud[msg.sender] == 1, "LockstakeStickyOsm/contract-not-whitelisted");
        _;
    }

    modifier stoppable {
        require(stopped == 0, "LockstakeStickyOsm/is-stopped");
        _;
    }

    // --- constructor ---

    constructor(address src_) {
        src = OracleLike(src_);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- internals ---

    function _min(uint256 w, uint256 x, uint256 y) internal pure returns (uint256 z) {
        uint256 a = w < x ? w : x;
        z = a < y ? a : y;
    }

    // --- administration ---

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function kiss(address usr) external auth {
        bud[usr] = 1;
        emit Kiss(usr);
    }

    function diss(address usr) external auth {
        bud[usr] = 0;
        emit Diss(usr);
    }

    // function kiss(address[] calldata a) external auth {
    //     for(uint256 i = 0; i < a.length; i++) {
    //         require(a[i] != address(0), "LockstakeStickyOsm/no-contract-0");
    //         bud[a[i]] = 1;
    //     }
    // }

    // function diss(address[] calldata a) external auth {
    //     for(uint256 i = 0; i < a.length; i++) {
    //         bud[a[i]] = 0;
    //     }
    // }

    function lock(address usr) external auth {
        capped[usr] = 1;
        emit Lock(usr);
    }

    function free(address usr) external auth {
        capped[usr] = 0;
        emit Free(usr);
    }

    function file(bytes32 what, uint256 data) external auth {
        if (what == "hop") {
            require(data > 0 && data <= type(uint128).max, "LockstakeStickyOsm/hop-out-boundaries");
            hop = uint128(data);
        } else if (what == "cap") {
            cap = data;
        } else if (what == "alpha") {
            require (data <= WAD, "LockstakeStickyOsm/alpha-out-boundaries");
            alpha = data;
        } else if (what == "top") {
            require (data >= WAD, "LockstakeStickyOsm/top-out-boundaries");
            top = data;
        } else if (what == "ewma") {
            ewma = data;
        } else revert("LockstakeStickyOsm/file-unrecognized-param");
        emit File(what, data);
    }

    function stop() external auth {
        stopped = 1;
    }

    function start() external auth {
        stopped = 0;
    }

    function _prev(uint256 ts) internal view returns (uint64) {
        require(hop != 0, "LockstakeStickyOsm/hop-is-zero");
        return uint64(ts - ts % hop);
    }

    function step(uint16 ts) external auth {
        require(ts > 0, "LockstakeStickyOsm/ts-is-zero");
        hop = ts;
    }

    function void() external auth {
        fCur = fNxt = lCur = lNxt = Feed(0, 0);
        stopped = 1;
    }

    function pass() public view returns (bool ok) {
        return block.timestamp >= zzz + hop;
    }

    // --- setter ---

    function poke() external stoppable {
        require(pass(), "LockstakeStickyOsm/not-passed");
        (uint256 wut, bool ok) = OracleLike(src).peek();
        require(wut <= type(uint128).max, "LockstakeStickyOsm/overflow");
        if (ok) {
            fCur = fNxt;
            fNxt = Feed(uint128(wut), 1);
            lCur = lNxt;
            ewma = (alpha * wut + (WAD - alpha) * ewma) / WAD;
            lNxt = Feed(uint128(_min(wut, ewma * top / WAD, cap)), 1);
            zzz = _prev(block.timestamp);
            emit LogValue(bytes32(uint256(fCur.val)));
        }
    }

    function peek() external view toll returns (uint256, bool) {
        return capped[msg.sender] == 1
               ? (lCur.val, lCur.has == 1)
               : (fCur.val, fCur.has == 1);
    }

    function peep() external view toll returns (uint256, bool) {
        return capped[msg.sender] == 1
               ? (lNxt.val, lNxt.has == 1)
               : (fNxt.val, fNxt.has == 1);
    }

    function read() external view toll returns (uint256) {
        if (capped[msg.sender] == 1) {
            require(lCur.has == 1, "LockstakeStickyOsm/no-current-value");
            return lCur.val;
        } else {
            require(fCur.has == 1, "LockstakeStickyOsm/no-current-value");
            return fCur.val;
        }
    }

    function fPeek() external view toll returns (uint256, bool) {
        return (fCur.val, fCur.has == 1);
    }

    function fPeep() external view toll returns (uint256, bool) {
        return (fNxt.val, fNxt.has == 1);
    }

    function fRead() external view toll returns (uint256) {
        require(fCur.has == 1, "LockstakeStickyOsm/no-current-value");
        return fCur.val;
    }

    function lPeek() external view toll returns (uint256, bool) {
        return (lCur.val, lCur.has == 1);
    }

    function lPeep() external view toll returns (uint256, bool) {
        return (lNxt.val, lNxt.has == 1);
    }

    function lRead() external view toll returns (uint256) {
        require(lCur.has == 1, "LockstakeStickyOsm/no-current-value");
        return lCur.val;
    }
}
