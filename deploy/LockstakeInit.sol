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
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.8.0;

import { DssInstance } from "dss-test/MCD.sol";
import { LockstakeInstance } from "./LockstakeInstance.sol";

interface LockstakeEngineLike {
    function vat() external view returns (address);
    function nstJoin() external view returns (address);
    function nst() external view returns (address);
    function ilk() external view returns (bytes32);
    function mkr() external view returns (address);
    function stkMkr() external view returns (address);
    function fee() external view returns (uint256);
    function mkrNgt() external view returns (address);
    function ngt() external view returns (address);
    function rely(address) external;
    function file(bytes32, address) external;
    function addFarm(address) external;
}

interface LockstakeClipperLike {
    function vat() external view returns (address);
    function dog() external view returns (address);
    function spotter() external view returns (address);
    function engine() external view returns (address);
    function ilk() external view returns (bytes32);
    function rely(address) external;
    function file(bytes32, address) external;
    function file(bytes32, uint256) external;
    function upchost() external;
}

interface CalcLike {
    function file(bytes32, uint256) external;
}

struct LockstakeConfig {
    bytes32   ilk;
    address   nstJoin;
    address   nst;
    address   mkr;
    address   stkMkr;
    address   mkrNgt;
    address   ngt;
    address[] farms;
    uint256   fee;
    uint256   line;
    uint256   duty;
    uint256   mat;
    uint256   buf;
    uint256   tail;
    uint256   cusp;
    uint256   chip;
    uint256   tip;
    uint256   stopped;
    uint256   chop;
    uint256   hole;
    uint256   tau;
    uint256   cut;
    uint256   step;
}

library LockstakeInit {
    function initLockstake(
        DssInstance        memory dss,
        LockstakeInstance  memory lockstakeInstance,
        LockstakeConfig    memory cfg
    ) internal {
        LockstakeEngineLike  engine  = LockstakeEngineLike(lockstakeInstance.engine);
        LockstakeClipperLike clipper = LockstakeClipperLike(lockstakeInstance.clipper);
        CalcLike calc                = CalcLike(lockstakeInstance.clipperCalc);

        // Sanity checks
        require(engine.vat()      == address(dss.vat),      "Engine vat mismatch");
        require(engine.nstJoin()  == cfg.nstJoin,           "Engine nstJoin mismatch");
        require(engine.nst()      == cfg.nst,               "Engine nst mismatch");
        require(engine.ilk()      == cfg.ilk,               "Engine ilk mismatch");
        require(engine.mkr()      == cfg.mkr,               "Engine mkr mismatch");
        require(engine.stkMkr()   == cfg.stkMkr,            "Engine stkMkr mismatch");
        require(engine.fee()      == cfg.fee,               "Engine fee mismatch");
        require(engine.mkrNgt()   == cfg.mkrNgt,            "Engine mkrNgt mismatch");
        require(engine.ngt()      == cfg.ngt,               "Engine ngt mismatch");
        require(clipper.ilk()     == cfg.ilk,               "Clipper ilk mismatch");
        require(clipper.vat()     == address(dss.vat),      "Clipper vat mismatch");
        require(clipper.engine()  == address(engine),       "Clipper engine mismatch");
        require(clipper.dog()     == address(dss.dog),      "Clipper dog mismatch");
        require(clipper.spotter() == address(dss.spotter),  "Clipper spotter mismatch");

        dss.vat.init(cfg.ilk);
        dss.vat.file(cfg.ilk, "line", cfg.line);
        dss.vat.file("Line", dss.vat.Line() + cfg.line);
        dss.vat.rely(address(engine));
        dss.vat.rely(address(clipper));

        dss.jug.init(cfg.ilk);
        dss.jug.file(cfg.ilk, "duty", cfg.duty);

        dss.spotter.file(cfg.ilk, "mat", cfg.mat);
        dss.spotter.file(cfg.ilk, "pip", lockstakeInstance.pip);
        dss.spotter.poke(cfg.ilk);

        dss.dog.file(cfg.ilk, "clip", address(clipper));
        dss.dog.file(cfg.ilk, "chop", cfg.chop);
        dss.dog.file(cfg.ilk, "hole", cfg.hole);
        dss.dog.rely(address(clipper));

        engine.file("jug", address(dss.jug));
        for (uint256 i = 0; i < cfg.farms.length; i++) {
            engine.addFarm(cfg.farms[i]);
        }
        engine.rely(address(clipper));

        clipper.file("buf",     cfg.buf);
        clipper.file("tail",    cfg.tail);
        clipper.file("cusp",    cfg.cusp);
        clipper.file("chip",    cfg.chip);
        clipper.file("tip",     cfg.tip);
        clipper.file("stopped", cfg.stopped);
        clipper.file("vow",     address(dss.vow));
        clipper.file("calc",    address(calc));
        clipper.upchost();
        clipper.rely(address(dss.dog));

        if (cfg.tau  > 0) calc.file("tau",  cfg.tau);
        if (cfg.cut  > 0) calc.file("cut",  cfg.cut);
        if (cfg.step > 0) calc.file("step", cfg.step);

        dss.chainlog.setAddress("LOCKSTAKE_ENGINE",    address(engine));
        dss.chainlog.setAddress("LOCKSTAKE_CLIP",      address(clipper));
        dss.chainlog.setAddress("LOCKSTAKE_CLIP_CALC", address(calc));
    }
}
