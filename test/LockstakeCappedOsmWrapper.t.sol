// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";
import { LockstakeCappedOsmWrapper } from "src/LockstakeCappedOsmWrapper.sol";
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit } from "deploy/LockstakeInit.sol";

interface OsmLike {
    function bud(address) external view returns (uint256);
    function stopped() external view returns (uint256);
    function src() external view returns (address);
    function hop() external view returns (uint16);
    function zzz() external view returns (uint64);
    function peek() external view returns (uint256, bool);
    function peep() external view returns (uint256, bool);
    function read() external view returns (uint256);
    function pass() external view returns (bool);
    function kiss(address) external;
}

interface LockstakeClipperLike {
    function ilk() external view returns (bytes32);
}

interface IlkRegistryLike {
    function pip(bytes32) external view returns (address);
}

contract LockstakeCappedOsmWrapperTest is DssTest {
    DssInstance dss;
    address pauseProxy;
    OsmLike osm;
    LockstakeCappedOsmWrapper cappedOsm;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dss = MCD.loadFromChainlog(LOG);
        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        osm = OsmLike(dss.chainlog.getAddress("PIP_SKY"));
        cappedOsm = LockstakeCappedOsmWrapper(LockstakeDeploy.deployCappedOsm(address(this), pauseProxy));
    }

    function testConstructor() public {
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        LockstakeCappedOsmWrapper c = new LockstakeCappedOsmWrapper(address(osm));
        assertEq(address(c.osm()), address(osm));
        assertEq(c.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(cappedOsm), "LockstakeCappedOsmWrapper");
    }

    function testFile() public {
        checkFileUint(address(cappedOsm), "LockstakeCappedOsmWrapper", ["cap"]);
    }

    function testModifiers() public {
        bytes4[] memory authedMethods = new bytes4[](2);
        authedMethods[0] = cappedOsm.kiss.selector;
        authedMethods[1] = cappedOsm.diss.selector;

        // this checks the case where sender is not authed
        vm.startPrank(address(0xBEEF));
        checkModifier(address(cappedOsm), "LockstakeCappedOsmWrapper/not-authorized", authedMethods);
        vm.stopPrank();

        bytes4[] memory budMethods = new bytes4[](3);
        budMethods[0] = cappedOsm.peek.selector;
        budMethods[1] = cappedOsm.read.selector;
        budMethods[2] = cappedOsm.peep.selector;

        // this checks the case where sender is not a bud
        vm.startPrank(address(0xBEEF));
        checkModifier(address(cappedOsm), "LockstakeCappedOsmWrapper/contract-not-whitelisted", budMethods);
        vm.stopPrank();
    }

    function testKissDiss() public {
        vm.prank(pauseProxy); osm.kiss(address(cappedOsm));

        assertEq(cappedOsm.bud(address(123)), 0);
        vm.expectRevert();
        vm.prank(address(123)); cappedOsm.read();
        vm.expectRevert();
        vm.prank(address(123)); cappedOsm.peek();
        vm.expectRevert();
        vm.prank(address(123)); cappedOsm.peep();

        vm.prank(pauseProxy); cappedOsm.kiss(address(123));

        assertEq(cappedOsm.bud(address(123)), 1);
        vm.prank(address(123)); cappedOsm.read();
        vm.prank(address(123)); cappedOsm.peek();
        vm.prank(address(123)); cappedOsm.peep();

        vm.prank(pauseProxy); cappedOsm.diss(address(123));

        assertEq(cappedOsm.bud(address(123)), 0);
        vm.expectRevert();
        vm.prank(address(123)); cappedOsm.read();
        vm.expectRevert();
        vm.prank(address(123)); cappedOsm.peek();
        vm.expectRevert();
        vm.prank(address(123)); cappedOsm.peep();
    }

    function testCompabilityFunctions() public {
        assertEq(cappedOsm.stopped(), osm.stopped());
        assertEq(cappedOsm.src(), osm.src());
        assertEq(cappedOsm.hop(), osm.hop());
        assertEq(cappedOsm.zzz(), osm.zzz());
        assertEq(cappedOsm.pass(), osm.pass());

        vm.warp(block.timestamp + 2 hours);

        uint256 zzz = osm.zzz();
        cappedOsm.poke();
        assertGt(osm.zzz(), zzz);
    }

    function testCurCappedPrice() public {
        vm.prank(pauseProxy); osm.kiss(address(cappedOsm));
        vm.prank(pauseProxy); osm.kiss(address(this));
        vm.prank(pauseProxy); cappedOsm.kiss(address(this));

        (uint256 osmPrice, bool osmHas) = osm.peek();
        assertEq(osmPrice, osm.read());
        assertTrue(osmHas);

        vm.prank(pauseProxy); cappedOsm.file("cap", osmPrice - 1);
        assertEq(uint256(cappedOsm.read()), osmPrice - 1);
        (bytes32 cappedOsmPrice, bool cappedOsmHas) = cappedOsm.peek();
        assertEq(uint256(cappedOsmPrice), osmPrice - 1);
        assertTrue(cappedOsmHas);

        vm.prank(pauseProxy); cappedOsm.file("cap", osmPrice + 1);
        assertEq(uint256(cappedOsm.read()), osmPrice);
        (cappedOsmPrice, cappedOsmHas) = cappedOsm.peek();
        assertEq(uint256(cappedOsmPrice), osmPrice);
        assertTrue(cappedOsmHas);

        vm.store(address(osm), bytes32(uint256(3)), bytes32(uint256(0)));
        (, osmHas) = osm.peek();
        assertFalse(osmHas);

        (, cappedOsmHas) = cappedOsm.peek();
        assertFalse(cappedOsmHas);

        vm.expectRevert("LockstakeCappedOsmWrapper/no-current-value");
        cappedOsm.read();
    }

    function testNxtCappedPrice() public {
        vm.prank(pauseProxy); osm.kiss(address(cappedOsm));
        vm.prank(pauseProxy); osm.kiss(address(this));
        vm.prank(pauseProxy); cappedOsm.kiss(address(this));

        (uint256 osmPrice, bool osmHas) = osm.peep();
        assertTrue(osmHas);

        vm.prank(pauseProxy); cappedOsm.file("cap", osmPrice - 1);
        (bytes32 cappedOsmPrice, bool cappedOsmHas) = cappedOsm.peep();
        assertEq(uint256(cappedOsmPrice), osmPrice - 1);
        assertTrue(cappedOsmHas);

        vm.prank(pauseProxy); cappedOsm.file("cap", osmPrice + 1);
        (cappedOsmPrice, cappedOsmHas) = cappedOsm.peep();
        assertEq(uint256(cappedOsmPrice), osmPrice);
        assertTrue(cappedOsmHas);

        vm.store(address(osm), bytes32(uint256(4)), bytes32(uint256(0)));
        (, osmHas) = osm.peep();
        assertFalse(osmHas);

        (, cappedOsmHas) = cappedOsm.peep();
        assertFalse(cappedOsmHas);
    }

    function testUpdateOsm() public {
        LockstakeClipperLike clipper = LockstakeClipperLike(dss.chainlog.getAddress("LOCKSTAKE_CLIP"));
        address clipperMom = dss.chainlog.getAddress("CLIPPER_MOM");
        IlkRegistryLike registry = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        bytes32 ilk = clipper.ilk();

        vm.expectRevert();
        dss.chainlog.getAddress("LOCKSTAKE_ORACLE");
        assertEq(registry.pip(ilk), address(osm));
        (address spotPip, uint256 mat) = dss.spotter.ilks(ilk);
        assertEq(spotPip, address(osm));
        assertEq(osm.bud(address(cappedOsm)), 0);
        assertEq(osm.bud(address(dss.spotter)), 1);
        assertEq(osm.bud(address(clipper)), 1);
        assertEq(osm.bud(clipperMom), 1);
        assertEq(osm.bud(address(dss.end)), 1);
        assertEq(cappedOsm.bud(address(dss.spotter)), 0);
        assertEq(cappedOsm.bud(address(clipper)), 0);
        assertEq(cappedOsm.bud(clipperMom), 0);
        assertEq(cappedOsm.bud(address(dss.end)), 0);
        assertEq(cappedOsm.cap(), 0);

        vm.startPrank(pauseProxy);
        LockstakeInit.updateOsm(dss, address(cappedOsm), 1 ether);
        vm.stopPrank();

        assertEq(dss.chainlog.getAddress("LOCKSTAKE_ORACLE"), address(cappedOsm));
        assertEq(registry.pip(ilk), address(cappedOsm));
        (spotPip,) = dss.spotter.ilks(ilk);
        assertEq(spotPip, address(cappedOsm));
        assertEq(osm.bud(address(cappedOsm)), 1);
        assertEq(osm.bud(address(dss.spotter)), 0);
        assertEq(osm.bud(address(clipper)), 0);
        assertEq(osm.bud(clipperMom), 0);
        assertEq(osm.bud(address(dss.end)), 0);
        assertEq(cappedOsm.bud(address(dss.spotter)), 1);
        assertEq(cappedOsm.bud(address(clipper)), 1);
        assertEq(cappedOsm.bud(clipperMom), 1);
        assertEq(cappedOsm.bud(address(dss.end)), 1);
        assertEq(cappedOsm.cap(), 1 ether);

        vm.prank(pauseProxy); osm.kiss(address(this));
        vm.prank(pauseProxy); cappedOsm.kiss(address(this));

        uint256 osmPrice = osm.read();
        uint256 par = dss.spotter.par();

        (,, uint256 spot,,) = dss.vat.ilks(ilk);
        assertEq(spot, (osmPrice * 10**9 * 10**27 / par) * 10**27 / mat);

        vm.prank(pauseProxy); cappedOsm.file("cap", osmPrice / 2);
        dss.spotter.poke(ilk);
        (,, spot,,) = dss.vat.ilks(ilk);

        assertEq(spot, ((osmPrice / 2) * 10**9 * 10**27 / par) * 10**27 / mat);
    }

    function testInitWithReducedPrice() public {
        vm.prank(pauseProxy); osm.kiss(address(this));
        uint256 osmPrice = osm.read();

        vm.startPrank(pauseProxy);
        LockstakeInit.updateOsm(dss, address(cappedOsm), osmPrice / 2);
        vm.stopPrank();

        bytes32 ilk = LockstakeClipperLike(dss.chainlog.getAddress("LOCKSTAKE_CLIP")).ilk();

        uint256 par = dss.spotter.par();
        (, uint256 mat) = dss.spotter.ilks(ilk);

        (,, uint256 spot,,) = dss.vat.ilks(ilk);
        assertEq(spot, ((osmPrice / 2) * 10**9 * 10**27 / par) * 10**27 / mat);
    }
}
