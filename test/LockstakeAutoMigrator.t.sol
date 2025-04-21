// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit, LockstakeConfig, LockstakeInstance } from "deploy/LockstakeInit.sol";
import { LockstakeMigrator } from "src/LockstakeMigrator.sol";
import { LockstakeAutoMigrator } from "src/LockstakeAutoMigrator.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";

contract LockstakeAutoMigratorTest is DssTest {
    DssInstance           dss;
    address               pauseProxy;
    LockstakeEngine       oldEngine;
    LockstakeEngine       newEngine;
    LockstakeMigrator     migrator;
    LockstakeAutoMigrator autoMigrator;
    bytes32               oldIlk;
    bytes32               newIlk = "LSEV2-A";

    LockstakeConfig   cfg;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    event SetAdmin(address indexed admin);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 22315708);

        dss = MCD.loadFromChainlog(LOG);

        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        oldEngine = LockstakeEngine(dss.chainlog.getAddress("LOCKSTAKE_ENGINE"));

        LockstakeInstance memory instance = LockstakeDeploy.deployLockstake(
            address(this),
            pauseProxy,
            dss.chainlog.getAddress("VOTE_DELEGATE_FACTORY"), // using the old factory is ok for this test, as we don't redelegate
            newIlk,
            1,
            bytes4(abi.encodeWithSignature("newLinearDecrease(address)")),
            dss.chainlog.getAddress("MKR_SKY")
        );

        newEngine = LockstakeEngine(instance.engine);
        migrator = LockstakeMigrator(instance.migrator);
        oldIlk = oldEngine.ilk();

        cfg = LockstakeConfig({
            ilk: newIlk,
            farms: new address[](0),
            fee: 1,
            maxLine: 100_000_000 * 10**45,
            gap: 100_000_000 * 10**45,
            ttl: 1 days,
            dust: _dust(oldIlk),
            duty: _duty(oldIlk),
            mat: _mat(oldIlk),
            buf: 1.25 * 10**27, // 25% Initial price buffer
            tail: 3600, // 1 hour before reset
            cusp: 0.2 * 10**27, // 80% drop before reset
            chip: 2 * WAD / 100,
            tip: 3,
            stopped: 0,
            chop: _chop(oldIlk),
            hole: _hole(oldIlk),
            tau: 100,
            cut: 0,
            step: 0,
            lineMom: true,
            tolerance: 0.5 * 10**27,
            name: "LOCKSTAKE",
            symbol: "LSMKR"
        });

        vm.startPrank(pauseProxy);
        dss.chainlog.setAddress("PIP_SKY", dss.chainlog.getAddress("PIP_MKR")); // using MKR pip is ok for this test, as MKR price >>> SKY one
        LockstakeInit.initLockstake(dss, instance, cfg);
        vm.stopPrank();

        autoMigrator = new LockstakeAutoMigrator(address(migrator), pauseProxy);
    }

    function _art(bytes32 ilk_, address urn) internal view returns (uint256 art) {
        (, art) = dss.vat.urns(ilk_, urn);
    }

    function _dust(bytes32 ilk_) internal view returns (uint256 dust) {
        (,,,, dust) = dss.vat.ilks(ilk_);
    }

    function _duty(bytes32 ilk_) internal view returns (uint256 duty) {
        (duty,) = dss.jug.ilks(ilk_);
    }

    function _mat(bytes32 ilk_) internal view returns (uint256 mat) {
        (, mat) = dss.spotter.ilks(ilk_);
    }

    function _chop(bytes32 ilk_) internal view returns (uint256 chop) {
        (, chop,,) = dss.dog.ilks(ilk_);
    }

    function _hole(bytes32 ilk_) internal view returns (uint256 hole) {
        (,, hole,) = dss.dog.ilks(ilk_);
    }

    function testConstructor() public {
        vm.expectEmit();
        emit SetAdmin(address(456));
        LockstakeAutoMigrator m = new LockstakeAutoMigrator(address(123), address(456));
        assertEq(address(m.migrator()), address(123));
        assertEq(address(m.admin()), address(456));
    }

    function testAutoMigrator() public {
        address[] memory owners = new address[](5);
        uint256[] memory indexes = new uint256[](5);

        (owners[0], indexes[0]) = (0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, 4);  // 24.91M debt, urn - 0x4d506c9cB4dfcf46029a6337bf7f62C15074Cb00
        (owners[1], indexes[1]) = (0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, 5);  // 9.9M   debt, urn - 0xc8E67C2eee088ABE37D2C7ED33598073FBD73e3a
        (owners[2], indexes[2]) = (0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, 6);  // 4.7M   debt, urn - 0x994808601141010968d5385A98Fad2633e126737
        (owners[3], indexes[3]) = (0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, 7);  // 5.3M   debt, urn - 0xd13ab62a7fdEf9dF558a353ddb1698Fc09803c84
        (owners[4], indexes[4]) = (0xBaF3605Ecbe395fA134A3F4c6a729E53b72E27B7, 0);  // 70.12K debt, urn - 0x8f56b6b79A6cE8221AB599443cF54589a0CdaE80

        vm.startPrank(owners[0]);
        for (uint256 i = 0; i <= 6; i++) { newEngine.open(i); } // open 7 positions instead of 8 on purpose
        vm.stopPrank();
        vm.prank(owners[4]); newEngine.open(0);

        // first position hopes both migrator and auto-migrator - should succeed
        vm.prank(owners[0]); oldEngine.hope(owners[0], indexes[0], address(migrator));
        vm.prank(owners[0]); newEngine.hope(owners[0], indexes[0], address(migrator));
        vm.prank(owners[0]); oldEngine.hope(owners[0], indexes[0], address(autoMigrator));
        vm.prank(owners[0]); newEngine.hope(owners[0], indexes[0], address(autoMigrator));

        // second position hopes only migrator - should fail
        vm.prank(owners[1]); oldEngine.hope(owners[1], indexes[1], address(migrator));
        vm.prank(owners[1]); newEngine.hope(owners[1], indexes[1], address(migrator));

        // third position hopes only auto-migrator - should fail
        vm.prank(owners[2]); oldEngine.hope(owners[2], indexes[2], address(migrator));
        vm.prank(owners[2]); newEngine.hope(owners[2], indexes[2], address(migrator));

        // fourth position does not even have an open a position in the new engine - should fail
        vm.prank(owners[3]); oldEngine.hope(owners[3], indexes[3], address(migrator));
        vm.prank(owners[3]); oldEngine.hope(owners[3], indexes[3], address(autoMigrator));

        // fifth position hopes both migrator and auto-migrator - should succeed again
        vm.prank(owners[4]); oldEngine.hope(owners[4], indexes[4], address(migrator));
        vm.prank(owners[4]); newEngine.hope(owners[4], indexes[4], address(migrator));
        vm.prank(owners[4]); oldEngine.hope(owners[4], indexes[4], address(autoMigrator));
        vm.prank(owners[4]); newEngine.hope(owners[4], indexes[4], address(autoMigrator));

        vm.expectRevert("LockstakeAutoMigrator/not-admin");
        autoMigrator.autoMigrate(owners, indexes);

        uint256[] memory differentLengthIndexes = new uint256[](4);
        vm.expectRevert("LockstakeAutoMigrator/length-mismatch");
        vm.prank(pauseProxy); autoMigrator.autoMigrate(owners, differentLengthIndexes);

        vm.prank(pauseProxy); autoMigrator.autoMigrate(owners, indexes);
        assertEq(autoMigrator.done(), true);

        address oldUrnAddr;
        address newUrnAddr;

        // migrated
        oldUrnAddr = oldEngine.ownerUrns(owners[0], indexes[0]);
        newUrnAddr = newEngine.ownerUrns(owners[0], indexes[0]);
        assertEq(_art(oldIlk, oldUrnAddr), 0);
        assertGt(_art(newIlk, newUrnAddr), 0);

        // not migrated
        oldUrnAddr = oldEngine.ownerUrns(owners[1], indexes[1]);
        newUrnAddr = newEngine.ownerUrns(owners[1], indexes[1]);
        assertGt(_art(oldIlk, oldUrnAddr), 0);
        assertEq(_art(newIlk, newUrnAddr), 0);

        // not migrated
        oldUrnAddr = oldEngine.ownerUrns(owners[2], indexes[2]);
        newUrnAddr = newEngine.ownerUrns(owners[2], indexes[2]);
        assertGt(_art(oldIlk, oldUrnAddr), 0);
        assertEq(_art(newIlk, newUrnAddr), 0);

        // not migrated
        oldUrnAddr = oldEngine.ownerUrns(owners[3], indexes[3]);
        newUrnAddr = newEngine.ownerUrns(owners[3], indexes[3]);
        assertGt(_art(oldIlk, oldUrnAddr), 0);
        assertEq(_art(newIlk, newUrnAddr), 0);

        // migrated
        oldUrnAddr = oldEngine.ownerUrns(owners[4], indexes[4]);
        newUrnAddr = newEngine.ownerUrns(owners[4], indexes[4]);
        assertEq(_art(oldIlk, oldUrnAddr), 0);
        assertGt(_art(newIlk, newUrnAddr), 0);

        vm.expectRevert("LockstakeAutoMigrator/already-done");
        vm.prank(pauseProxy); autoMigrator.autoMigrate(owners, indexes);
    }
}
