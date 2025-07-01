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

interface OldClipperSales {
    function sales(uint256) external view returns (uint256,uint256,uint256,uint256,address,uint96,uint256);
}

contract LockstakeClipperUpdate is DssTest {
    using stdStorage for StdStorage;

    DssInstance         dss;
    address             pauseProxy;
    IlkRegistryAbstract ilkRegistry;
    address             clipperMom;
    OsmAbstract         pip;
    bytes32             ilk;
    DSTokenAbstract     sky;
    address             lssky;
    LockstakeEngine     engine;
    LockstakeClipper   clip;
    LockstakeClipper    newClip;
    address             calc;
    address             cuttee;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function _setMedianPrice(uint256 price) internal {
        vm.store(pip.src(), bytes32(uint256(4)), bytes32(abi.encodePacked(uint32(block.timestamp), uint96(0), uint128(price))));
        vm.warp(block.timestamp + 1 hours);
        pip.poke();
        vm.warp(block.timestamp + 1 hours);
        pip.poke();
    }

    function _urnSetUp(uint256 index) internal returns (address urn) {
        urn = engine.open(index);
        deal(address(sky), address(this), 1_000_000 * 10**18);
        sky.approve(address(engine), 1_000_000 * 10**18);
        engine.lock(address(this), index, 1_000_000 * 10**18, 5);
        engine.draw(address(this), index, address(this), 50_000 * 10**18);
    }

    function _forceLiquidation(LockstakeClipper clipper, address urn) internal returns (uint256 id) {
        if (uint256(pip.read()) == 0.08 * 10**18) {
            _setMedianPrice(0.04 * 10**18); // Force liquidation
        }
        dss.spotter.poke(ilk);
        assertEq(clipper.kicks(), 0);
        assertEq(engine.urnAuctions(urn), 0);
        id = dss.dog.bark(ilk, address(urn), address(this));
        assertEq(clipper.kicks(), 1);
        assertEq(engine.urnAuctions(urn), 1);
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
        clipperMom = dss.chainlog.getAddress("CLIPPER_MOM");
        newClip = LockstakeClipper(LockstakeDeploy.deployClipper(address(this), pauseProxy));
        cuttee = address(new CutteeMock());

        ilk = engine.ilk();

        vm.label(lssky, "lssky");
        vm.label(address(engine), "engine");
        vm.label(address(clip), "clip");
        vm.label(calc, "calc");
        vm.label(pauseProxy, "pauseProxy");
        vm.label(address(pip), "pip");
        vm.label(clipperMom, "clipperMom");
        vm.label(address(newClip), "newClip");

        vm.prank(pauseProxy); pip.kiss(address(this));
        _setMedianPrice(0.08 * 10**18);
        assertEq(uint256(pip.read()), 0.08 * 10**18);
    }

    function _clip(bytes32 ilk_) internal view returns (address clipV) {
        (clipV,,,) = dss.dog.ilks(ilk_);
    }

    uint256 clipWardsClipperMom;
    string name1; string symbol1; uint256 class1; uint256 dec1; address gem1; address pip1; address join1; address xlip1;

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
        clipWardsClipperMom = clip.wards(clipperMom);
        assertEq(newClip.wards(clipperMom), 0);
        name1 = ilkRegistry.name(ilk);
        symbol1 = ilkRegistry.symbol(ilk);
        class1 = ilkRegistry.class(ilk);
        dec1 = ilkRegistry.dec(ilk);
        gem1 = ilkRegistry.gem(ilk);
        pip1 = ilkRegistry.pip(ilk);
        join1 = ilkRegistry.join(ilk);
        assertEq(ilkRegistry.xlip(ilk), address(clip));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP"), address(clip));

        vm.startPrank(pauseProxy);
        LockstakeInit.updateClipper(dss, address(newClip), cuttee);
        vm.stopPrank();

        assertEq(dss.vat.wards(address(clip)), 1);
        assertEq(dss.vat.wards(address(newClip)), 1);
        assertEq(pip.bud(address(clip)), 1);
        assertEq(pip.bud(address(newClip)), 1);
        assertEq(_clip(ilk), address(newClip));
        assertEq(dss.dog.wards(address(clip)), 1);
        assertEq(dss.dog.wards(address(newClip)), 1);
        assertEq(engine.wards(address(clip)), 1);
        assertEq(engine.wards(address(newClip)), 1);
        assertEq(newClip.buf(), clip.buf());
        assertEq(newClip.tail(), clip.tail());
        assertEq(newClip.cusp(), clip.cusp());
        assertEq(newClip.chip(), clip.chip());
        assertEq(newClip.tip(), clip.tip());
        assertEq(newClip.stopped(), clip.stopped());
        assertEq(newClip.vow(), clip.vow());
        assertEq(address(newClip.calc()), address(clip.calc()));
        assertEq(newClip.cuttee(), cuttee);
        assertEq(newClip.chost(), clip.chost());
        assertEq(clip.wards(address(dss.dog)), 1);
        assertEq(newClip.wards(address(dss.dog)), 1);
        assertEq(clip.wards(address(dss.end)), 1);
        assertEq(newClip.wards(address(dss.end)), 1);
        assertEq(clip.wards(clipperMom), clipWardsClipperMom);
        assertEq(newClip.wards(clipperMom), clipWardsClipperMom);
        assertEq(ilkRegistry.name(ilk), name1);
        assertEq(ilkRegistry.symbol(ilk), symbol1);
        assertEq(ilkRegistry.class(ilk), class1);
        assertEq(ilkRegistry.dec(ilk), dec1);
        assertEq(ilkRegistry.gem(ilk), gem1);
        assertEq(ilkRegistry.pip(ilk), pip1);
        assertEq(ilkRegistry.join(ilk), join1);
        assertEq(ilkRegistry.xlip(ilk), address(newClip));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP"), address(newClip));

        vm.startPrank(pauseProxy);
        LockstakeInit.removeClipper(dss, address(clip));
        vm.stopPrank();

        assertEq(dss.vat.wards(address(clip)), 0);
        assertEq(pip.bud(address(clip)), 0);
        assertEq(dss.dog.wards(address(clip)), 0);
        assertEq(engine.wards(address(clip)), 0);
        assertEq(clip.wards(address(dss.dog)), 0);
        assertEq(clip.wards(address(dss.end)), 0);
        assertEq(clip.wards(clipperMom), 0);
    }

    uint256 dirt1; uint256 dirt2; uint256 dirt3; uint256 dirt4; uint256 dirt5;

    function testFunctionality() public {
        vm.startPrank(pauseProxy);
        clip.rely(clipperMom);
        clip.file("stopped", 0);
        dss.vat.file(ilk, "line", 1_000_000_000 * 10**45);
        vm.stopPrank();

        assertEq(clip.kicks(), 0);
        assertEq(newClip.kicks(), 0);
        (,,, dirt1) = dss.dog.ilks(ilk);
        address urn = _urnSetUp(0);
        address urn2 = _urnSetUp(1);
        uint256 id = _forceLiquidation(clip, urn);
        assertEq(clip.kicks(), 1);
        assertEq(newClip.kicks(), 0);
        (,,, dirt2) = dss.dog.ilks(ilk);
        assertGt(dirt2, dirt1);

        vm.startPrank(pauseProxy);
        LockstakeInit.updateClipper(dss, address(newClip), address(0));
        vm.stopPrank();

        uint256 id2 = _forceLiquidation(newClip, urn2); // New clipper kick works

        assertEq(clip.kicks(), 1);
        assertEq(newClip.kicks(), 1);

        (,,, dirt3) = dss.dog.ilks(ilk);
        assertGt(dirt3, dirt2);

        (, uint256 tab, uint256 lot,,,,) = OldClipperSales(address(clip)).sales(id);
        vm.prank(pauseProxy); dss.vat.suck(address(0), address(this), tab);
        dss.vat.hope(address(clip));
        clip.take(id, lot, type(uint256).max, address(this), ""); // Old clip auction can still be taken

        (,,, dirt4) = dss.dog.ilks(ilk);
        assertEq(dirt4, dirt2);

        (, tab,, lot,,,,) = newClip.sales(id2);
        vm.prank(pauseProxy); dss.vat.suck(address(0), address(this), tab);
        dss.vat.hope(address(newClip));
        newClip.take(id2, lot, type(uint256).max, address(this), ""); // New clipper take works

        (,,, dirt5) = dss.dog.ilks(ilk);
        assertEq(dirt5, dirt1);
    }
}
