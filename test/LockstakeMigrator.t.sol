// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit, LockstakeConfig, LockstakeInstance } from "deploy/LockstakeInit.sol";
import { LockstakeMigrator, FlashLike } from "src/LockstakeMigrator.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";

interface TokenLike {
    function allowance(address, address) external view returns (uint256);
}

interface VatLike {
    function can(address, address) external view returns (uint256);
}

interface MkrSkyLike {
    function rate() external view returns (uint256);
}

contract LockstakeMigratorTest is DssTest {
    DssInstance       dss;
    address           pauseProxy;
    LockstakeEngine   oldEngine;
    LockstakeEngine   newEngine;
    LockstakeMigrator migrator;
    FlashLike         flash;
    MkrSkyLike        mkrSky;
    bytes32           oldIlk;
    bytes32           newIlk = "LSEV2-A";

    LockstakeConfig   cfg;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    event Lock(address indexed owner, uint256 indexed index, uint256 wad, uint16 ref);
    event Migrate(address indexed oldOwner, uint256 indexed oldIndex, address indexed newOwner, uint256 indexed newIndex, uint256 ink, uint256 debt) anonymous;

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // Note: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 22517470);

        dss = MCD.loadFromChainlog(LOG);

        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        oldEngine = LockstakeEngine(dss.chainlog.getAddress("LOCKSTAKE_ENGINE"));
        mkrSky = MkrSkyLike(dss.chainlog.getAddress("MKR_SKY"));
        flash = FlashLike(dss.chainlog.getAddress("MCD_FLASH"));

        LockstakeInstance memory instance = LockstakeDeploy.deployLockstake(
            address(this),
            pauseProxy,
            dss.chainlog.getAddress("VOTE_DELEGATE_FACTORY"), // using the old factory is ok for this test, as we don't redelegate
            newIlk,
            1,
            bytes4(abi.encodeWithSignature("newLinearDecrease(address)")),
            address(mkrSky)
        );

        newEngine = LockstakeEngine(instance.engine);
        migrator = LockstakeMigrator(instance.migrator);

        oldIlk = oldEngine.ilk();

        cfg = LockstakeConfig({
            ilk: newIlk,
            farms: new address[](0),
            fee: 1,
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
    }

    function _ink(bytes32 ilk_, address urn) internal view returns (uint256 ink) {
        (ink,) = dss.vat.urns(ilk_, urn);
    }

    function _art(bytes32 ilk_, address urn) internal view returns (uint256 art) {
        (, art) = dss.vat.urns(ilk_, urn);
    }

    function _Art(bytes32 ilk_) internal view returns (uint256 Art) {
        (Art,,,,) = dss.vat.ilks(ilk_);
    }

    function _rate(bytes32 ilk_) internal view returns (uint256 rate) {
        (, rate,,,) = dss.vat.ilks(ilk_);
    }

    function _line(bytes32 ilk_) internal view returns (uint256 line) {
        (,,, line,) = dss.vat.ilks(ilk_);
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
        TokenLike mkr      = TokenLike(dss.chainlog.getAddress("MCD_GOV"));
        TokenLike sky      = TokenLike(dss.chainlog.getAddress("SKY"));
        TokenLike usds     = TokenLike(dss.chainlog.getAddress("USDS"));
        VatLike   vat      = VatLike(dss.chainlog.getAddress("MCD_VAT"));
        address   usdsJoin = dss.chainlog.getAddress("USDS_JOIN");

        LockstakeMigrator m = new LockstakeMigrator(address(oldEngine), address(newEngine), address(mkrSky), address(flash));
        assertEq(address(m.oldEngine()), address(oldEngine));
        assertEq(address(m.newEngine()), address(newEngine));
        assertEq(address(m.mkrSky()), address(mkrSky));
        assertEq(address(m.flash()), address(flash));
        assertEq(address(m.vat()), address(vat));
        assertEq(address(m.usdsJoin()), usdsJoin);
        assertEq(m.oldIlk(), oldEngine.ilk());
        assertEq(m.mkrSkyRate(), mkrSky.rate());

        assertEq(mkr.allowance(address(m), address(mkrSky)), type(uint256).max);
        assertEq(sky.allowance(address(m), address(newEngine)), type(uint256).max);
        assertEq(usds.allowance(address(m), address(oldEngine)), type(uint256).max);
        assertEq(usds.allowance(address(m), usdsJoin), type(uint256).max);
        assertEq(vat.can(address(m), usdsJoin), 1);
    }

    struct Urn {
        address owner;
        uint256 index;
    }

    function _checkMigrate(Urn memory oldUrn, Urn memory newUrn, address caller, bool hasDebt) internal {
        address oldUrnAddr = oldEngine.ownerUrns(oldUrn.owner, oldUrn.index);
        uint256 oldInkPrev = _ink(oldIlk, oldUrnAddr);
        uint256 oldArtPrev = _art(oldIlk, oldUrnAddr);
        assertGt(oldInkPrev, 0);
        if (hasDebt) {
            assertGt(oldArtPrev, 0);
        } else {
            assertEq(oldArtPrev, 0);
        }

        vm.prank(newUrn.owner); address newUrnAddr = newEngine.open(newUrn.index);

        assertEq(_ink(newIlk, newUrnAddr), 0);
        assertEq(_art(newIlk, newUrnAddr), 0);

        if (caller != oldUrn.owner) {
            vm.expectRevert("LockstakeMigrator/sender-not-authed-old-urn");
            vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);
            vm.prank(oldUrn.owner); oldEngine.hope(oldUrn.owner, oldUrn.index, caller);
        }

        if (caller != newUrn.owner) {
            vm.expectRevert("LockstakeMigrator/sender-not-authed-new-urn");
            vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);
            vm.prank(newUrn.owner); newEngine.hope(newUrn.owner, newUrn.index, caller);
        }

        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);
        vm.prank(oldUrn.owner); oldEngine.hope(oldUrn.owner, oldUrn.index, address(migrator));

        if (hasDebt) {
            vm.expectRevert("LockstakeEngine/urn-not-authorized");
            vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);
            vm.prank(newUrn.owner); newEngine.hope(newUrn.owner, newUrn.index, address(migrator));

            uint256 snapshotId = vm.snapshotState();
            vm.prank(pauseProxy); dss.vat.file(oldIlk, "line", 1);
            vm.expectRevert("LockstakeMigrator/old-ilk-line-not-zero");
            vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);
            vm.revertToState(snapshotId);
        }

        uint256 oldIlkRate = _rate(oldIlk);

        vm.expectEmit();
        emit Lock(newUrn.owner, newUrn.index, oldInkPrev * 24_000, 5);
        vm.expectEmit();
        emit Migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, oldInkPrev, hasDebt ? _divup(oldArtPrev * oldIlkRate, RAY) * RAY : 0);
        vm.prank(caller); migrator.migrate(oldUrn.owner, oldUrn.index, newUrn.owner, newUrn.index, 5);

        assertEq(_ink(oldIlk, oldUrnAddr), 0);
        assertEq(_art(oldIlk, oldUrnAddr), 0);

        assertEq(_ink(newIlk, newUrnAddr), oldInkPrev * 24_000);
        if (hasDebt) {
            assertApproxEqAbs(_art(newIlk, newUrnAddr) * _rate(newIlk), oldArtPrev * oldIlkRate, RAY);
        } else {
            assertEq(_art(newIlk, newUrnAddr), 0);
        }

        assertEq(_line(newIlk), 0);
    }

    function testMigrateSameOwnerAndCallerNoDebt() public {
        _checkMigrate({
            oldUrn: Urn({ owner: 0x625D04023Cd0e7941d493BeAa68c9BBb8f2754d1, index: 0 }),
            newUrn: Urn({ owner: 0x625D04023Cd0e7941d493BeAa68c9BBb8f2754d1, index: 0 }),
            caller: 0x625D04023Cd0e7941d493BeAa68c9BBb8f2754d1,
            hasDebt: false
        });
    }

    function testMigrateSameOwnerAndCallerWithDebt() public {
        _checkMigrate({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 4 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 0 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
    }

    function testMigrateDifferentOwnersCallerFirstOwnerNoDebt() public {
        _checkMigrate({
            oldUrn: Urn({ owner: 0x625D04023Cd0e7941d493BeAa68c9BBb8f2754d1, index: 0 }),
            newUrn: Urn({ owner: address(111)                              , index: 0 }),
            caller: 0x625D04023Cd0e7941d493BeAa68c9BBb8f2754d1,
            hasDebt: false
        });
    }

    function testMigrateDifferentOwnersCallerFirstOwnerWithDebt() public {
        _checkMigrate({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 4 }),
            newUrn: Urn({ owner: address(111)                              , index: 0 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
    }

    function testMigrateDifferentOwnersCallerSecondOwnerNoDebt() public {
        _checkMigrate({
            oldUrn: Urn({ owner: 0x625D04023Cd0e7941d493BeAa68c9BBb8f2754d1, index: 0 }),
            newUrn: Urn({ owner: address(111)                              , index: 0 }),
            caller: address(111),
            hasDebt: false
        });
    }

    function testMigrateDifferentOwnersCallerSecondOwnerWithDebt() public {
        _checkMigrate({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 4 }),
            newUrn: Urn({ owner: address(111)                              , index: 0 }),
            caller: address(111),
            hasDebt: true
        });
    }

    function testMigrateDifferentOwnersRandomCallerNoDebt() public {
        _checkMigrate({
            oldUrn: Urn({ owner: 0x625D04023Cd0e7941d493BeAa68c9BBb8f2754d1, index: 0 }),
            newUrn: Urn({ owner: address(111)                              , index: 0 }),
            caller: address(222),
            hasDebt: false
        });
    }

    function testMigrateDifferentOwnersRandomCallerWithDebt() public {
        _checkMigrate({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 4 }),
            newUrn: Urn({ owner: address(111)                              , index: 0 }),
            caller: address(222),
            hasDebt: true
        });
    }

    function testMigrateFlashLoanOrigin() public {
        vm.expectRevert("LockstakeMigrator/wrong-origin");
        migrator.onVatDaiFlashLoan(address(migrator), 10, 10, "");

        vm.expectRevert("LockstakeMigrator/wrong-origin");
        flash.vatDaiFlashLoan(address(migrator), 10, "");
    }

    function testMigrateCurrentUrnsWithRelevantDebt() public {
        assertEq(_Art(newIlk), 0);
        assertGt(_Art(oldIlk) * _rate(oldIlk), 40_000_000 * RAD);
        _checkMigrate({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 4 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 0 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
        _checkMigrate({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 5 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 1 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
        _checkMigrate({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 7 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 2 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
        _checkMigrate({
            oldUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 6 }),
            newUrn: Urn({ owner: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d, index: 3 }),
            caller: 0xf65475e74C1Ed6d004d5240b06E3088724dFDA5d,
            hasDebt: true
        });
        _checkMigrate({
            oldUrn: Urn({ owner: 0xBaF3605Ecbe395fA134A3F4c6a729E53b72E27B7, index: 0 }),
            newUrn: Urn({ owner: 0xBaF3605Ecbe395fA134A3F4c6a729E53b72E27B7, index: 0 }),
            caller: 0xBaF3605Ecbe395fA134A3F4c6a729E53b72E27B7,
            hasDebt: true
        });
        assertGt(_Art(newIlk) * _rate(newIlk), 40_000_000 * RAD);
        assertLt(_Art(oldIlk) * _rate(oldIlk),  1_000_000 * RAD);
    }
}
