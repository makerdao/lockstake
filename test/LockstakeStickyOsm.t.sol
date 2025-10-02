// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import { LockstakeStickyOsm } from "src/LockstakeStickyOsm.sol";
import { PipMock } from "test/mocks/PipMock.sol";

contract LockstakeStickyOsmTest is DssTest {

    PipMock feed;
    LockstakeStickyOsm osm;
    address cappedUsr = address(111);

    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event Lock(address indexed usr);
    event Free(address indexed usr);
    event LogValue(bytes32 val);

    function setUp() public {
        vm.warp(block.timestamp - block.timestamp % 1 hours); // Start from top of the hour
        feed = new PipMock();
        feed.setPrice(100e18);
        osm = new LockstakeStickyOsm(address(feed));
        osm.file("cap", 1_000e18);
        osm.file("alpha", 0.1e18);
        osm.file("top", 1.05e18);
        osm.file("ewma", 100e18);
        osm.file("hop", 1 hours);
        osm.step(1 hours);
        vm.warp(block.timestamp + 1 hours);
        osm.poke();
        osm.kiss(address(this));
        osm.kiss(cappedUsr);
        osm.lock(cappedUsr);
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
        osm.kiss(address(123));
        assertEq(osm.bud(address(123)), 1);
        vm.expectEmit();
        emit Diss(address(123));
        osm.diss(address(123));
        assertEq(osm.bud(address(123)), 0);
    }

    function testLockFree() public {
        assertEq(osm.capped(address(123)), 0);
        vm.expectEmit();
        emit Lock(address(123));
        osm.lock(address(123));
        assertEq(osm.capped(address(123)), 1);
        vm.expectEmit();
        emit Free(address(123));
        osm.free(address(123));
        assertEq(osm.capped(address(123)), 0);
    }

    function testStopStart() public {
        assertEq(osm.stopped(), 0);
        osm.stop();
        assertEq(osm.stopped(), 1);
        osm.start();
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

        osm.void();

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
        feed.setPrice(101e18);

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
        feed.setPrice(uint256(type(uint128).max) + 1);
        vm.expectRevert("LockstakeStickyOsm/overflow");
        osm.poke();

        osm.stop();
        vm.expectRevert("LockstakeStickyOsm/is-stopped");
        osm.poke();
    }

    function testPokeEWMATopLimit() public {
        feed.setPrice(110e18);
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
        feed.setPrice(110e18);
        osm.file("cap", 105e18);

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
