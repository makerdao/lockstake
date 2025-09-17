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

interface OsmLike {
    function stopped() external view returns (uint256);
    function src() external view returns (address);
    function hop() external view returns (uint16);
    function zzz() external view returns (uint64);
    function peek() external view returns (uint256, bool);
    function peep() external view returns (uint256, bool);
    function pass() external view returns (bool);
    function poke() external;
}

contract LockstakeCappedOsmWrapper {
    // --- storage variables ---

    mapping(address usr => uint256 allowed)     public wards;
    mapping(address usr => uint256 whitelisted) public bud;

    uint256 public cap;

    // --- immutables ---

    OsmLike immutable public osm;

    // --- events ---   

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event File(bytes32 indexed what, uint256 data);

    // --- modifiers ---

    modifier auth {
        require(wards[msg.sender] == 1, "LockstakeCappedOsmWrapper/not-authorized");
        _;
    }

    modifier toll {
        require(bud[msg.sender] == 1, "LockstakeCappedOsmWrapper/contract-not-whitelisted");
        _;
    }

    // --- compatibility functions ---

    function stopped() external view returns (uint256 stopped_) {
        stopped_ = osm.stopped();
    }

    function src() external view returns (address src_) {
        src_ = osm.src();
    }

    function hop() external view returns (uint16 hop_) {
        hop_ = osm.hop();
    }

    function zzz() external view returns (uint64 zzz_) {
        zzz_ = osm.zzz();
    }

    function pass() external view returns (bool ok) {
        ok = osm.pass();
    }

    function poke() external {
        osm.poke();
    }

    // --- constructor ---

    constructor(address osm_) {
        osm = OsmLike(osm_);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- internals ---

    function _min(uint256 x, uint256 y) internal pure returns (bytes32 z) {
        z = bytes32(x <= y ? x : y);
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

    function file(bytes32 what, uint256 data) external auth {
        if (what == "cap") {
            cap = data;
        } else revert("LockstakeCappedOsmWrapper/file-unrecognized-param");
        emit File(what, data);
    }

    // --- readers ---

    function peek() external view toll returns (bytes32, bool) {
        (uint256 val, bool has) = osm.peek();
        return (_min(val, cap), has);
    }

    function peep() external view toll returns (bytes32, bool) {
        (uint256 val, bool has) = osm.peep();
        return (_min(val, cap), has);
    }

    function read() external view toll returns (bytes32) {
        (uint256 val, bool has) = osm.peek();
        require(has, "LockstakeCappedOsmWrapper/no-current-value");
        return _min(val, cap);
    }
}
