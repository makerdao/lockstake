// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import { LockstakeStickyOsm } from "src/LockstakeStickyOsm.sol";
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit } from "deploy/LockstakeInit.sol";
import { PipMock } from "test/mocks/PipMock.sol";

contract LockstakeStickyOsmTest is DssTest {
    DssInstance dss;
    LockstakeStickyOsm osm;
    address pauseProxy;
    address cappedUsr = address(111);

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event Lock(address indexed usr);
    event Free(address indexed usr);
    event LogValue(bytes32 val);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dss = MCD.loadFromChainlog(LOG);
        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");

        vm.warp(block.timestamp - block.timestamp % 1 hours); // Start from top of the hour
        osm = LockstakeStickyOsm(LockstakeDeploy.deployStickyOsm(address(this), pauseProxy));
        _setMedianPrice(100e18);
        vm.store(address(osm.src()), keccak256(abi.encode(address(address(osm)), uint256(2))), bytes32(uint256(1)));
        vm.startPrank(pauseProxy);
        LockstakeInit.updateToStickyOsm(
            dss,
            address(osm),
            1 hours,  // hop
            1_000e18, // cap
            0.1e18,   // alpha
            1.05e18,  // top
            100e18    // ewma
        );
        osm.kiss(address(this));
        osm.kiss(cappedUsr);
        osm.lock(cappedUsr);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 hours);
        osm.poke();
    }

    function _setMedianPrice(uint256 price) internal {
        vm.store(address(osm.src()), bytes32(uint256(4)), bytes32(price));
    }

    function testAuth() public {
        checkAuth(address(osm), "LockstakeStickyOsm");
    }

    function testFile() public {
        checkFileUint(address(osm), "LockstakeStickyOsm", ["hop", "cap", "alpha", "top", "ewma"]);
    }

    function testModifiers() public {
        bytes4[] memory authedMethods = new bytes4[](7);
        authedMethods[0] = osm.kiss.selector;
        authedMethods[1] = osm.diss.selector;
        authedMethods[2] = osm.lock.selector;
        authedMethods[3] = osm.free.selector;
        authedMethods[4] = osm.stop.selector;
        authedMethods[5] = osm.start.selector;
        authedMethods[6] = osm.void.selector;

        // this checks the case where sender is not authed
        vm.startPrank(address(0xBEEF));
        checkModifier(address(osm), "LockstakeStickyOsm/not-authorized", authedMethods);
        vm.stopPrank();

        bytes4[] memory budMethods = new bytes4[](9);
        budMethods[0] = osm.peek.selector;
        budMethods[1] = osm.read.selector;
        budMethods[2] = osm.peep.selector;
        budMethods[3] = osm.fPeek.selector;
        budMethods[4] = osm.fRead.selector;
        budMethods[5] = osm.fPeep.selector;
        budMethods[6] = osm.lPeek.selector;
        budMethods[7] = osm.lRead.selector;
        budMethods[8] = osm.lPeep.selector;

        // this checks the case where sender is not a bud
        vm.startPrank(address(0xBEEF));
        checkModifier(address(osm), "LockstakeStickyOsm/contract-not-whitelisted", budMethods);
        vm.stopPrank();
    }

    function testKissDiss() public {
        assertEq(osm.bud(address(123)), 0);
        vm.expectEmit();
        emit Kiss(address(123));
        vm.prank(pauseProxy); osm.kiss(address(123));
        assertEq(osm.bud(address(123)), 1);
        vm.expectEmit();
        emit Diss(address(123));
        vm.prank(pauseProxy); osm.diss(address(123));
        assertEq(osm.bud(address(123)), 0);
    }

    function testLockFree() public {
        assertEq(osm.capped(address(123)), 0);
        vm.expectEmit();
        emit Lock(address(123));
        vm.prank(pauseProxy); osm.lock(address(123));
        assertEq(osm.capped(address(123)), 1);
        vm.expectEmit();
        emit Free(address(123));
        vm.prank(pauseProxy); osm.free(address(123));
        assertEq(osm.capped(address(123)), 0);
    }

    function testStopStart() public {
        assertEq(osm.stopped(), 0);
        vm.prank(pauseProxy); osm.stop();
        assertEq(osm.stopped(), 1);
        vm.prank(pauseProxy); osm.start();
        assertEq(osm.stopped(), 0);
    }

    function testVoid() public {
        assertEq(osm.stopped(), 0);
        vm.warp(block.timestamp + 1 hours);
        osm.poke();
        (uint256 val, bool has) = osm.fPeek();
        assertEq(val, 100e18);
        assertTrue(has);
        (val, has) = osm.fPeep();
        assertEq(val, 100e18);
        assertTrue(has);
        (val, has) = osm.lPeek();
        assertEq(val, 100e18);
        assertTrue(has);
        (val, has) = osm.lPeep();
        assertEq(val, 100e18);
        assertTrue(has);

        vm.prank(pauseProxy); osm.void();

        assertEq(osm.stopped(), 1);
        (val, has) = osm.fPeek();
        assertEq(val, 0);
        assertTrue(!has);
        (val, has) = osm.fPeep();
        assertEq(val, 0);
        assertTrue(!has);
        (val, has) = osm.lPeek();
        assertEq(val, 0);
        assertTrue(!has);
        (val, has) = osm.lPeep();
        assertEq(val, 0);
        assertTrue(!has);
    }

    function testPoke() public {
        _setMedianPrice(101e18);

        vm.warp(block.timestamp + 1 hours);
        osm.poke();

        (uint256 val, bool has) = osm.fPeek();
        assertEq(val, 100e18);
        assertTrue(has);

        (val, has) = osm.fPeep();
        assertEq(val, 101e18);
        assertTrue(has);

        (val, has) = osm.lPeek();
        assertEq(val, 100e18);
        assertTrue(has);

        (val, has) = osm.lPeep();
        assertEq(val, 101e18);
        assertTrue(has);

        vm.warp(block.timestamp + 1 hours);
        osm.poke();

        (val, has) = osm.fPeek();
        assertEq(val, 101e18);
        assertTrue(has);

        (val, has) = osm.lPeek();
        assertEq(val, 101e18);
        assertTrue(has);

        vm.warp(block.timestamp + 1 hours - 1);
        vm.expectRevert("LockstakeStickyOsm/not-passed");
        osm.poke();

        vm.warp(block.timestamp + 1);
        vm.prank(pauseProxy); osm.stop();
        vm.expectRevert("LockstakeStickyOsm/is-stopped");
        osm.poke();
    }

    function testSrcPeekOverflow() public {
        // This can not be tested with the real SKY oracle as it doesn't allow bigger values than max uint128
        PipMock pip = new PipMock();
        LockstakeStickyOsm osm2 = new LockstakeStickyOsm(address(pip));
        pip.setPrice(uint256(type(uint128).max) + 1);
        vm.expectRevert("LockstakeStickyOsm/overflow");
        osm2.poke();
    }

    function testPokeEWMATopLimit() public {
        _setMedianPrice(110e18);
        assertEq(osm.ewma(), 100e18); // Initial ewma value

        vm.warp(block.timestamp + 1 hours);
        osm.poke();

        assertEq(osm.ewma(), (0.1e18 * 110e18 + 0.9e18 * 100e18) / 1e18); // 101e18
        assertEq(osm.ewma() * osm.top() / 1e18, 106.05e18); // ewma + top that will be exposed below as the limited price

        (uint256 val, bool has) = osm.fPeek();
        assertEq(val, 100e18);
        assertTrue(has);

        (val, has) = osm.fPeep();
        assertEq(val, 110e18);
        assertTrue(has);

        assertEq(osm.fRead(), 100e18);

        (val, has) = osm.lPeek();
        assertEq(val, 100e18);
        assertTrue(has);

        (val, has) = osm.lPeep();
        assertEq(val, 106.05e18);
        assertTrue(has);

        assertEq(osm.lRead(), 100e18);

        (val, has) = osm.peek();
        assertEq(val, 100e18);
        assertTrue(has);

        (val, has) = osm.peep();
        assertEq(val, 110e18);
        assertTrue(has);

        assertEq(osm.read(), 100e18);

        vm.prank(cappedUsr); (val, has) = osm.peek();
        assertEq(val, 100e18);
        assertTrue(has);

        vm.prank(cappedUsr); (val, has) = osm.peep();
        assertEq(val, 106.05e18);
        assertTrue(has);

        vm.prank(cappedUsr); assertEq(osm.read(), 100e18);

        vm.warp(block.timestamp + 1 hours);
        osm.poke();

        assertEq(osm.ewma(), (0.1e18 * 110e18 + 0.9e18 * 101e18) / 1e18); // 101.9e18
        assertEq(osm.ewma() * osm.top() / 1e18, 106.995e18);

        (val, has) = osm.fPeek();
        assertEq(val, 110e18);
        assertTrue(has);

        (val, has) = osm.fPeep();
        assertEq(val, 110e18);
        assertTrue(has);

        assertEq(osm.fRead(), 110e18);

        (val, has) = osm.lPeek();
        assertEq(val, 106.05e18);
        assertTrue(has);

        (val, has) = osm.lPeep();
        assertEq(val, 106.995e18);
        assertTrue(has);

        assertEq(osm.lRead(), 106.05e18);

        (val, has) = osm.peek();
        assertEq(val, 110e18);
        assertTrue(has);

        (val, has) = osm.peep();
        assertEq(val, 110e18);
        assertTrue(has);

        assertEq(osm.read(), 110e18);

        vm.prank(cappedUsr); (val, has) = osm.peek();
        assertEq(val, 106.05e18);
        assertTrue(has);

        vm.prank(cappedUsr); (val, has) = osm.peep();
        assertEq(val, 106.995e18);
        assertTrue(has);

        vm.prank(cappedUsr); assertEq(osm.read(), 106.05e18);
    }

    function testPokeCapLimit() public {
        _setMedianPrice(110e18);
        vm.prank(pauseProxy); osm.file("cap", 105e18);

        vm.warp(block.timestamp + 1 hours);
        osm.poke();

        assertEq(osm.ewma(), 101e18);
        assertEq(osm.ewma() * osm.top() / 1e18, 106.05e18); // Both new price and ewma above cap

        (uint256 val, bool has) = osm.fPeek();
        assertEq(val, 100e18);
        assertTrue(has);

        (val, has) = osm.fPeep();
        assertEq(val, 110e18);
        assertTrue(has);

        (val, has) = osm.lPeek();
        assertEq(val, 100e18);
        assertTrue(has);

        (val, has) = osm.lPeep();
        assertEq(val, 105e18);
        assertTrue(has);

        (val, has) = osm.peek();
        assertEq(val, 100e18);
        assertTrue(has);

        (val, has) = osm.peep();
        assertEq(val, 110e18);
        assertTrue(has);

        vm.prank(cappedUsr); (val, has) = osm.peek();
        assertEq(val, 100e18);
        assertTrue(has);

        vm.prank(cappedUsr); (val, has) = osm.peep();
        assertEq(val, 105e18);
        assertTrue(has);
    }
}
