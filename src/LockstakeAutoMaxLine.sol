// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
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

pragma solidity ^0.8.16;

import { Babylonian } from "src/Babylonian.sol";

interface VatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface JugLike {
    function ilks(bytes32) external view returns (uint256, uint256);
    function drip(bytes32) external returns (uint256);
    function file(bytes32, bytes32, uint256) external;
}

interface SpotLike {
    function par() external view returns (uint256);
}

interface AutoLineLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint48, uint48, uint48);
    function setIlk(bytes32, uint256, uint256, uint256) external;
}

interface PairLike {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function sync() external;
}

interface PipLike {
    function read() external view returns (uint256);
}

interface GemLike {
    function decimals() external view returns (uint8);
}

contract LockstakeAutoMaxLine {

    // --- storage variables ---

    mapping(address => uint256) public wards;
    uint256                     public duty;         // [ray]
    uint256                     public windDownDuty; // [ray]
    uint256                     public lpFactor;     // [ray]

    // --- constants ---

    uint256 constant WAD = 10**18;
    uint256 constant RAY = 10**27;

    // --- immutables ---

    VatLike      public immutable vat;
    JugLike      public immutable jug;
    SpotLike     public immutable spotter;
    AutoLineLike public immutable autoLine;
    bytes32      public immutable ilk;
    address      public immutable nst;
    PairLike     public immutable pair;
    PipLike      public immutable pip;
    address      public immutable lpOwner;
    bool         public immutable nstFirst;

    // --- events ---

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event Exec(uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty);

    // --- modifiers ---

    modifier auth {
        require(wards[msg.sender] == 1, "LockstakeAutoMaxLine/not-authorized");
        _;
    }

    constructor(
        address vat_,
        address jug_,
        address spotter_,
        address autoLine_,
        bytes32 ilk_,
        address nst_,
        address pair_,
        address pip_,
        address lpOwner_
    ) {
        vat      = VatLike(vat_);
        jug      = JugLike(jug_);
        spotter  = SpotLike(spotter_);
        autoLine = AutoLineLike(autoLine_);
        ilk      = ilk_;
        nst      = nst_;
        pair     = PairLike(pair_);
        pip      = PipLike(pip_);
        lpOwner  = lpOwner_;

        nstFirst = pair.token0() == nst;
        address gem = nstFirst ? pair.token1() : pair.token0();
        require(GemLike(gem).decimals() == 18, "LockstakeAutoMaxLine/gem-decimals-not-18");

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
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

    function file(bytes32 what, uint256 data) external auth {
        if      (what == "duty")                 duty = data;
        else if (what == "windDownDuty") windDownDuty = data;
        else if (what == "lpFactor")         lpFactor = data;
        else revert("LockstakeAutoMaxLine/file-unrecognized-param");
        emit File(what, data);
    }

    // --- internals ---

    // Based on https://github.com/makerdao/univ2-lp-oracle/blob/874a59d74d847909cc4a31f0d38ee6b020f6525f/src/UNIV2LPOracle.sol#L261
    // Modified to return a price in NST terms
    function _seek() internal returns (uint256 quote) {
        // Sync up reserves of uniswap liquidity pool
        pair.sync();

        // Get reserves of uniswap liquidity pool
        (uint112 r0, uint112 r1,) = pair.getReserves();
        require(r0 > 0 && r1 > 0, "LockstakeAutoMaxLine/invalid-reserves");

        uint256 pGem = pip.read() * RAY / spotter.par();  // Gem price from oracle converted to NST reference (WAD)
        require(pGem != 0, "LockstakeAutoMaxLine/invalid-oracle-price");

        // Prices against NST
        (uint256 p0, uint256 p1) = nstFirst ? (WAD, pGem) : (pGem, WAD);

        // This calculation should be overflow-resistant even for tokens with very high or very
        // low prices, as the nst value of each reserve should lie in a fairly controlled range
        // regardless of the token prices.
        uint256 value0 = p0 * uint256(r0) / WAD;
        uint256 value1 = p1 * uint256(r1) / WAD;
        quote = 2 * WAD * Babylonian.sqrt(value0 * value1) / pair.totalSupply();
    }

    // --- user function ---

    function exec() external returns (
        uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty
    ) {
        uint256 gap;
        uint48 ttl;
        (oldMaxLine, gap, ttl,,) = autoLine.ilks(ilk);
        require(oldMaxLine != 0 && gap != 0 && ttl != 0, "LockstakeAutoMaxLine/auto-line-not-enabled");

        uint256 uniswapLps = pair.balanceOf(lpOwner);
        if (uniswapLps > 0) {
            newMaxLine = (uniswapLps * _seek() / WAD) * lpFactor;
        } else {
            // Avoid the calculation (which also prevents calling _seek() when pair.totalSupply() is 0)
            newMaxLine = 0;
        }

        // Due to the following validation maxLine can not be 0:
        // https://github.com/makerdao/dss-auto-line/blob/bff7e6cc43dbd7d9a054dd359ef18a1b4d06b6f5/src/DssAutoLine.sol#L83
        // This also avoids hitting auto-line-not-enabled in case newMaxLine was calculated as 0 in a previous exec.
        if (newMaxLine == 0) newMaxLine = 1 wei;
        autoLine.setIlk(ilk, newMaxLine, gap, ttl);

        uint256 duty_         = duty;
        uint256 windDownDuty_ = windDownDuty;
        require(duty_ != 0 && windDownDuty_ != 0, "LockstakeAutoMaxLine/missing-duty");

        (uint256 Art, uint256 rate,,,) = vat.ilks(ilk);
        debt = Art * rate;

        (oldDuty,) = jug.ilks(ilk);
        newDuty = (debt > newMaxLine) ? windDownDuty_ : duty_;
        if (newDuty != oldDuty) {
            jug.drip(ilk);
            jug.file(ilk, "duty", newDuty);
        }

        emit Exec(oldMaxLine, newMaxLine, debt, oldDuty, newDuty);
    }
}
