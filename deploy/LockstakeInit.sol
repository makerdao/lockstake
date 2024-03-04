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
    function delegateFactory() external view returns (address);
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

interface PipLike {
    function kiss(address) external;
}

interface CalcLike {
    function file(bytes32, uint256) external;
}

interface AutoLineLike {
    function rely(address) external;
    function setIlk(bytes32, uint256, uint256, uint256) external;
}

interface LineMomLike {
    function addIlk(bytes32) external;
}

interface ClipperMomLike {
    function setPriceTolerance(address, uint256) external;
}

interface IlkRegistryLike {
    function put(
        bytes32 _ilk,
        address _join,
        address _gem,
        uint256 _dec,
        uint256 _class,
        address _pip,
        address _xlip,
        string memory _name,
        string memory _symbol
    ) external;
}

interface AutoMaxLineLike {
    function vat() external view returns (address);
    function jug() external view returns (address);
    function spotter() external view returns (address);
    function autoLine() external view returns (address);
    function lpOwner() external view returns (address);
    function ilk() external view returns (bytes32);
    function nst() external view returns (address);
    function pair() external view returns (address);
    function pip() external view returns (address);
    function file(bytes32, uint256) external;
}

struct LockstakeConfig {
    bytes32   ilk;
    address   delegateFactory;
    address   nstJoin;
    address   nst;
    address   mkr;
    address   stkMkr;
    address   mkrNgt;
    address   ngt;
    address[] farms;
    uint256   fee;
    uint256   maxLine;
    uint256   gap;
    uint256   ttl;
    uint256   dust;
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
    bool      lineMom;
    uint256   tolerance;
    string    name;
    string    symbol;
}

struct AutoMaxLineConfig {
    bytes32 ilk;
    address nst;
    address pair;
    address pip;
    uint256 duty;
    uint256 windDownDuty;
    uint256 lpFactor;
}

library LockstakeInit {
    uint256 constant internal RATES_ONE_HUNDRED_PCT = 1000000021979553151239153027;
    uint256 constant internal WAD = 10**18;
    uint256 constant internal RAY = 10**27;

    function initLockstake(
        DssInstance        memory dss,
        LockstakeInstance  memory lockstakeInstance,
        LockstakeConfig    memory cfg
    ) internal {
        LockstakeEngineLike  engine  = LockstakeEngineLike(lockstakeInstance.engine);
        LockstakeClipperLike clipper = LockstakeClipperLike(lockstakeInstance.clipper);
        CalcLike calc                = CalcLike(lockstakeInstance.clipperCalc);

        // Sanity checks
        require(engine.delegateFactory() == cfg.delegateFactory,   "Engine delegateFactory mismatch");
        require(engine.vat()             == address(dss.vat),      "Engine vat mismatch");
        require(engine.nstJoin()         == cfg.nstJoin,           "Engine nstJoin mismatch");
        require(engine.nst()             == cfg.nst,               "Engine nst mismatch");
        require(engine.ilk()             == cfg.ilk,               "Engine ilk mismatch");
        require(engine.mkr()             == cfg.mkr,               "Engine mkr mismatch");
        require(engine.stkMkr()          == cfg.stkMkr,            "Engine stkMkr mismatch");
        require(engine.fee()             == cfg.fee,               "Engine fee mismatch");
        require(engine.mkrNgt()          == cfg.mkrNgt,            "Engine mkrNgt mismatch");
        require(engine.ngt()             == cfg.ngt,               "Engine ngt mismatch");
        require(clipper.ilk()            == cfg.ilk,               "Clipper ilk mismatch");
        require(clipper.vat()            == address(dss.vat),      "Clipper vat mismatch");
        require(clipper.engine()         == address(engine),       "Clipper engine mismatch");
        require(clipper.dog()            == address(dss.dog),      "Clipper dog mismatch");
        require(clipper.spotter()        == address(dss.spotter),  "Clipper spotter mismatch");

        require(cfg.dust <= cfg.hole, "dust greater than hole");
        require(cfg.duty >= RAY && cfg.duty <= RATES_ONE_HUNDRED_PCT, "duty out of boundaries");
        require(cfg.mat >= RAY && cfg.mat < 10 * RAY, "mat out of boundaries");
        require(cfg.buf >= RAY && cfg.buf < 10 * RAY, "buf out of boundaries");
        require(cfg.cusp < RAY, "cusp negative drop value");
        require(cfg.chip < WAD, "chip equal or greater than 100%");
        require(cfg.chop >= WAD && cfg.chop < 2 * WAD, "chop out of boundaries");
        require(cfg.tolerance < RAY, "tolerance equal or greater than 100%");

        dss.vat.init(cfg.ilk);
        dss.vat.file(cfg.ilk, "line", cfg.gap);
        dss.vat.file("Line", dss.vat.Line() + cfg.gap);
        dss.vat.file(cfg.ilk, "dust", cfg.dust);
        dss.vat.rely(address(engine));
        dss.vat.rely(address(clipper));

        AutoLineLike(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE")).setIlk(cfg.ilk, cfg.maxLine, cfg.gap, cfg.ttl);

        dss.jug.init(cfg.ilk);
        dss.jug.file(cfg.ilk, "duty", cfg.duty);

        address pip = dss.chainlog.getAddress("PIP_MKR");
        address clipperMom = dss.chainlog.getAddress("CLIPPER_MOM");
        PipLike(pip).kiss(address(dss.spotter));
        PipLike(pip).kiss(address(clipper));
        PipLike(pip).kiss(clipperMom);
        PipLike(pip).kiss(address(dss.end));
        // TODO: If a sticky oracle wrapper is implemented we will need to also kiss the source to it
        // If an osm is implemented instead we also need the source to kiss the osm and add the OsmMom permissions

        dss.spotter.file(cfg.ilk, "mat", cfg.mat);
        dss.spotter.file(cfg.ilk, "pip", pip);
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
        clipper.rely(address(dss.end));
        clipper.rely(clipperMom);

        if (cfg.tau  > 0) calc.file("tau",  cfg.tau);
        if (cfg.cut  > 0) calc.file("cut",  cfg.cut);
        if (cfg.step > 0) calc.file("step", cfg.step);

        if (cfg.lineMom) {
            LineMomLike(dss.chainlog.getAddress("LINE_MOM")).addIlk(cfg.ilk);
        }

        if (cfg.tolerance > 0) {
            ClipperMomLike(clipperMom).setPriceTolerance(address(clipper), cfg.tolerance);
        }

        IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY")).put(
            cfg.ilk,
            address(0),
            cfg.mkr,
            18,
            7, // New class
            pip,
            address(clipper),
            cfg.name,
            cfg.symbol
        );

        dss.chainlog.setAddress("LOCKSTAKE_ENGINE",    address(engine));
        dss.chainlog.setAddress("LOCKSTAKE_CLIP",      address(clipper));
        dss.chainlog.setAddress("LOCKSTAKE_CLIP_CALC", address(calc));
    }

    function initAutoMaxLine(
        DssInstance       memory dss,
        address                  autoMaxLine_,
        AutoMaxLineConfig memory cfg
    ) internal {
        AutoMaxLineLike autoMaxLine = AutoMaxLineLike(autoMaxLine_);

        // Sanity checks
        require(address(autoMaxLine.vat())     == address(dss.vat),     "AutoMaxLine vat mismatch");
        require(address(autoMaxLine.jug())     == address(dss.jug),     "AutoMaxLine jug mismatch");
        require(address(autoMaxLine.spotter()) == address(dss.spotter), "AutoMaxLine spotter mismatch");

        address autoLine = address(autoMaxLine.autoLine());
        require(autoLine              == dss.chainlog.getAddress("MCD_IAM_AUTO_LINE"), "AutoMaxLine auto line mismatch");
        require(autoMaxLine.lpOwner() == dss.chainlog.getAddress("MCD_PAUSE_PROXY"),   "AutoMaxLine lp owner mismatch");

        require(autoMaxLine.ilk()           == cfg.ilk,  "AutoMaxLine ilk mismatch");
        require(autoMaxLine.nst()           == cfg.nst,  "AutoMaxLine nst mismatch");
        require(address(autoMaxLine.pair()) == cfg.pair, "AutoMaxLine pair mismatch");
        require(address(autoMaxLine.pip())  == cfg.pip,  "AutoMaxLine pip mismatch");

        require(cfg.duty         >= RAY && cfg.duty         <= RATES_ONE_HUNDRED_PCT, "duty out of boundaries");
        require(cfg.windDownDuty >= RAY && cfg.windDownDuty <= RATES_ONE_HUNDRED_PCT, "windDownDuty out of boundaries");
        require(cfg.lpFactor     <= RAY , "lpFactor larger than 100%");

        // Configurations
        dss.jug.rely(autoMaxLine_);
        AutoLineLike(autoLine).rely(autoMaxLine_);
        PipLike(cfg.pip).kiss(autoMaxLine_);

        autoMaxLine.file("duty",         cfg.duty);
        autoMaxLine.file("windDownDuty", cfg.windDownDuty);
        autoMaxLine.file("lpFactor",     cfg.lpFactor);

        // Chainlog
        dss.chainlog.setAddress("LOCKSTAKE_AUTO_MAX_LINE", autoMaxLine_);
    }
}
