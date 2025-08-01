// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";
import "dss-interfaces/Interfaces.sol";
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit, LockstakeConfig, LockstakeInstance } from "deploy/LockstakeInit.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { CutteeMock } from "test/mocks/CutteeMock.sol";

interface UsdsLike {
    function allowance(address, address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
}

interface CalcFabLike {
    function newLinearDecrease(address) external returns (address);
}

interface LineMomLike {
    function ilks(bytes32) external view returns (uint256);
}

interface ClipperMomLike {
    function tolerance(address) external view returns (uint256);
}

interface OldClipperSales {
    function sales(uint256) external view returns (uint256,uint256,uint256,uint256,address,uint96,uint256);
}

contract LockstakeClipperUpdateTest is DssTest {
    DssInstance         dss;
    address             pauseProxy;
    IlkRegistryAbstract ilkRegistry;
    ClipperMomLike      clipperMom;
    OsmAbstract         pip;
    bytes32             ilk;
    DSTokenAbstract     sky;
    address             lssky;
    LockstakeEngine     engine;
    LockstakeClipper    clip;
    LockstakeClipper    newClip;
    address             calc;
    CutteeMock          cuttee;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function _setMedianPrice(uint256 price) internal {
        vm.store(pip.src(), bytes32(uint256(4)), bytes32(abi.encodePacked(uint32(block.timestamp), uint96(0), uint128(price))));
        vm.warp(block.timestamp + 1 hours);
        pip.poke();
        vm.warp(block.timestamp + 1 hours);
        pip.poke();
        assertEq(uint256(pip.read()), price);
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dss = MCD.loadFromChainlog(LOG);

        sky = DSTokenAbstract(dss.chainlog.getAddress("SKY"));
        lssky = dss.chainlog.getAddress("LOCKSTAKE_SKY");
        engine = LockstakeEngine(dss.chainlog.getAddress("LOCKSTAKE_ENGINE"));
        clip = LockstakeClipper(dss.chainlog.getAddress("LOCKSTAKE_CLIP"));
        calc = dss.chainlog.getAddress("LOCKSTAKE_CLIP_CALC");
        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        ilkRegistry = IlkRegistryAbstract(dss.chainlog.getAddress("ILK_REGISTRY"));
        pip = OsmAbstract(dss.chainlog.getAddress("PIP_SKY"));
        clipperMom = ClipperMomLike(dss.chainlog.getAddress("CLIPPER_MOM"));
        newClip = LockstakeClipper(LockstakeDeploy.deployClipper(address(this), pauseProxy));
        cuttee = new CutteeMock();
        cuttee.rely(pauseProxy);

        ilk = engine.ilk();

        vm.label(address(sky), "sky");
        vm.label(lssky, "lssky");
        vm.label(address(engine), "engine");
        vm.label(address(clip), "clip");
        vm.label(calc, "calc");
        vm.label(pauseProxy, "pauseProxy");
        vm.label(address(pip), "pip");
        vm.label(address(clipperMom), "clipperMom");
        vm.label(address(newClip), "newClip");
        vm.label(address(cuttee), "cuttee");

        vm.prank(pauseProxy); pip.kiss(address(this));
        _setMedianPrice(0.08 * 10**18);
        dss.spotter.poke(ilk);
    }

    function _clip(bytes32 ilk_) internal view returns (address clipV) {
        (clipV,,,) = dss.dog.ilks(ilk_);
    }

    uint256 clipperMomToleranceClipper;
    string nameV; string symbolV; uint256 classV; uint256 decV; address gemV; address pipV; address joinV;

    function testValuesAndPermissions() public {
        assertEq(dss.vat.wards(address(clip)), 1);
        assertEq(dss.vat.wards(address(newClip)), 0);
        assertEq(pip.bud(address(clip)), 1);
        assertEq(pip.bud(address(newClip)), 0);
        assertEq(_clip(ilk), address(clip));
        assertEq(dss.dog.wards(address(clip)), 1);
        assertEq(dss.dog.wards(address(newClip)), 0);
        assertEq(engine.wards(address(clip)), 1);
        assertEq(engine.wards(address(newClip)), 0);
        assertEq(newClip.buf(), RAY);
        assertEq(newClip.tail(), 0);
        assertEq(newClip.cusp(), 0);
        assertEq(newClip.chip(), 0);
        assertEq(newClip.tip(), 0);
        assertEq(newClip.stopped(), 0);
        assertEq(newClip.vow(), address(0));
        assertEq(address(newClip.calc()), address(0));
        assertEq(newClip.cuttee(), address(0));
        assertEq(newClip.chost(), 0);
        assertEq(clip.wards(address(dss.dog)), 1);
        assertEq(newClip.wards(address(dss.dog)), 0);
        assertEq(clip.wards(address(dss.end)), 1);
        assertEq(newClip.wards(address(dss.end)), 0);
        assertEq(clip.wards(address(clipperMom)), 0);
        assertEq(newClip.wards(address(clipperMom)), 0);
        clipperMomToleranceClipper = clipperMom.tolerance(address(clip));
        assertEq(clipperMom.tolerance(address(newClip)), 0);
        nameV = ilkRegistry.name(ilk);
        symbolV = ilkRegistry.symbol(ilk);
        classV = ilkRegistry.class(ilk);
        decV = ilkRegistry.dec(ilk);
        gemV = ilkRegistry.gem(ilk);
        pipV = ilkRegistry.pip(ilk);
        joinV = ilkRegistry.join(ilk);
        assertEq(ilkRegistry.xlip(ilk), address(clip));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP"), address(clip));

        vm.startPrank(pauseProxy);
        LockstakeInit.updateClipper(dss, address(newClip), address(cuttee));
        vm.stopPrank();

        assertEq(dss.vat.wards(address(clip)), 0);
        assertEq(dss.vat.wards(address(newClip)), 1);
        assertEq(pip.bud(address(clip)), 0);
        assertEq(pip.bud(address(newClip)), 1);
        assertEq(_clip(ilk), address(newClip));
        assertEq(dss.dog.wards(address(clip)), 0);
        assertEq(dss.dog.wards(address(newClip)), 1);
        assertEq(engine.wards(address(clip)), 0);
        assertEq(engine.wards(address(newClip)), 1);
        assertEq(newClip.buf(), clip.buf());
        assertEq(newClip.tail(), clip.tail());
        assertEq(newClip.cusp(), clip.cusp());
        assertEq(newClip.chip(), clip.chip());
        assertEq(newClip.tip(), clip.tip());
        assertEq(newClip.stopped(), 3);
        assertEq(newClip.vow(), clip.vow());
        assertEq(address(newClip.calc()), address(clip.calc()));
        assertEq(newClip.cuttee(), address(cuttee));
        assertEq(newClip.chost(), clip.chost());
        assertEq(clip.wards(address(dss.dog)), 0);
        assertEq(newClip.wards(address(dss.dog)), 1);
        assertEq(clip.wards(address(dss.end)), 0);
        assertEq(newClip.wards(address(dss.end)), 1);
        assertEq(clip.wards(address(clipperMom)), 0);
        assertEq(newClip.wards(address(clipperMom)), 0);
        assertEq(cuttee.wards(address(newClip)), 1);
        assertEq(clipperMom.tolerance(address(newClip)), clipperMomToleranceClipper);
        assertEq(ilkRegistry.name(ilk), nameV);
        assertEq(ilkRegistry.symbol(ilk), symbolV);
        assertEq(ilkRegistry.class(ilk), classV);
        assertEq(ilkRegistry.dec(ilk), decV);
        assertEq(ilkRegistry.gem(ilk), gemV);
        assertEq(ilkRegistry.pip(ilk), pipV);
        assertEq(ilkRegistry.join(ilk), joinV);
        assertEq(ilkRegistry.xlip(ilk), address(newClip));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP"), address(newClip));

        vm.startPrank(pauseProxy);
        LockstakeInit.enableLiquidations(dss);
        vm.stopPrank();

        assertEq(newClip.wards(address(clipperMom)), 1);
        assertEq(newClip.stopped(), 0);
    }

    uint256 clipKicks;
    uint256 dirt1; uint256 dirt2; uint256 dirt3;

    function testFunctionality() public {
        vm.startPrank(pauseProxy);
        dss.vat.file(ilk, "line", 1_000_000_000 * 10**45);
        vm.stopPrank();

        (,,, dirt1) = dss.dog.ilks(ilk);

        address urn = engine.open(0);
        deal(address(sky), address(this), 1_000_000 * 10**18);
        sky.approve(address(engine), 1_000_000 * 10**18);
        engine.lock(address(this), 0, 1_000_000 * 10**18, 5);
        engine.draw(address(this), 0, address(this), 50_000 * 10**18);

        vm.startPrank(pauseProxy);
        LockstakeInit.updateClipper(dss, address(newClip), address(cuttee));
        LockstakeInit.enableLiquidations(dss);
        vm.stopPrank();

        _setMedianPrice(0.04 * 10**18);
        dss.spotter.poke(ilk);
        assertEq(newClip.kicks(), 0);
        assertEq(engine.urnAuctions(urn), 0);
        uint256 salesId = dss.dog.bark(ilk, address(urn), address(this));
        assertEq(newClip.kicks(), 1);
        assertEq(engine.urnAuctions(urn), 1);

        (,,, dirt2) = dss.dog.ilks(ilk);
        assertGt(dirt2, dirt1);

        uint256 snapshotId = vm.snapshotState();

        (, uint256 tab,, uint256 lot,,,,) = newClip.sales(salesId);
        vm.prank(pauseProxy); dss.vat.suck(address(0), address(this), tab);
        dss.vat.hope(address(newClip));
        newClip.take(salesId, lot, type(uint256).max, address(this), "");

        (,,, dirt3) = dss.dog.ilks(ilk);
        assertEq(dirt3, dirt1);

        vm.revertToState(snapshotId);

        vm.warp(block.timestamp + clip.tail() + 1);

        (bool needsRedo,,,) = newClip.getStatus(salesId);
        assertTrue(needsRedo);

        newClip.redo(salesId, address(this));

        vm.startPrank(pauseProxy);
        newClip.yank(salesId);
        vm.stopPrank();

        (,,, dirt3) = dss.dog.ilks(ilk);
        assertEq(dirt3, dirt1);
    }
}
