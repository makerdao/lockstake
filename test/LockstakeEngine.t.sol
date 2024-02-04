// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { LockstakeUrn } from "src/LockstakeUrn.sol";
import { PipMock } from "test/mocks/PipMock.sol";
import { DelegateFactoryMock, DelegateMock } from "test/mocks/DelegateMock.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import { NstMock } from "test/mocks/NstMock.sol";
import { NstJoinMock } from "test/mocks/NstJoinMock.sol";
import { StakingRewardsMock } from "test/mocks/StakingRewardsMock.sol";
import { MkrNgtMock } from "test/mocks/MkrNgtMock.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface VatLike {
    function can(address, address) external view returns (uint256);
    function dai(address) external view returns (uint256);
    function gem(bytes32, address) external view returns (uint256);
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function rely(address) external;
    function file(bytes32, bytes32, uint256) external;
    function init(bytes32) external;
    function hope(address) external;
    function suck(address, address, uint256) external;
}

interface SpotterLike {
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
    function poke(bytes32) external;
}

interface JugLike {
    function file(bytes32, bytes32, uint256) external;
    function init(bytes32) external;
}

interface DogLike {
    function ilks(bytes32) external view returns (address, uint256, uint256, uint256);
    function rely(address) external;
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
    function bark(bytes32, address, address) external returns (uint256);
}

interface CalcFabLike {
    function newLinearDecrease(address) external returns (address);
}

interface CalcLike {
    function file(bytes32, uint256) external;
}

contract LockstakeEngineTest is DssTest {
    using stdStorage for StdStorage;

    address             public pauseProxy;
    address             public vat;
    address             public spot;
    address             public dog;
    GemMock             public mkr;
    address             public jug;
    LockstakeEngine     public engine;
    LockstakeClipper    public clip;
    PipMock             public pip;
    DelegateFactoryMock public delFactory;
    NstMock             public nst;
    NstJoinMock         public nstJoin;
    GemMock             public stkMkr;
    GemMock             public rTok;
    StakingRewardsMock  public farm;
    MkrNgtMock          public mkrNgt;
    GemMock             public ngt;
    bytes32             public ilk = "LSE";
    address             public voter;
    address             public voterDelegate;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    event VerifyFarm(address farm, bool blockStaking);
    event Open(address indexed owner, uint256 indexed index, address urn);
    event Hope(address indexed urn, address indexed usr);
    event Nope(address indexed urn, address indexed usr);
    event SelectDelegate(address indexed urn, address indexed delegate_);
    event SelectFarm(address indexed urn, address farm, uint16 ref);
    event Lock(address indexed urn, uint256 wad, uint16 ref);
    event LockNgt(address indexed urn, uint256 ngtWad, uint16 ref);
    event Free(address indexed urn, address indexed to, uint256 wad, uint256 burn);
    event FreeNgt(address indexed urn, address indexed to, uint256 ngtWad, uint256 burn);
    event FreeNoFee(address indexed urn, address indexed to, uint256 wad);
    event Draw(address indexed urn, address indexed to, uint256 wad);
    event Wipe(address indexed urn, uint256 wad);
    event GetReward(address indexed urn, address indexed farm, address indexed to, uint256 amt);
    event OnKick(address indexed urn, uint256 wad);
    event OnTake(address indexed urn, address indexed who, uint256 wad);
    event OnRemove(address indexed urn, uint256 sold, uint256 burn, uint256 refund);

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        pauseProxy = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        vat = ChainlogLike(LOG).getAddress("MCD_VAT");
        spot = ChainlogLike(LOG).getAddress("MCD_SPOT");
        dog = ChainlogLike(LOG).getAddress("MCD_DOG");
        mkr = new GemMock(0);
        jug = ChainlogLike(LOG).getAddress("MCD_JUG");
        nst = new NstMock();
        nstJoin = new NstJoinMock(vat, address(nst));
        stkMkr = new GemMock(0);
        rTok = new GemMock(0);
        farm = new StakingRewardsMock(address(rTok), address(stkMkr));
        ngt = new GemMock(0);
        mkrNgt = new MkrNgtMock(address(mkr), address(ngt), 24_000);

        pip = new PipMock();
        delFactory = new DelegateFactoryMock(address(mkr));
        voter = address(123);
        vm.prank(voter); voterDelegate = delFactory.create();

        vm.startPrank(pauseProxy);
        engine = new LockstakeEngine(address(delFactory), address(nstJoin), ilk, address(stkMkr), 15 * WAD / 100, address(mkrNgt));
        engine.file("jug", jug);
        VatLike(vat).rely(address(engine));
        VatLike(vat).init(ilk);
        JugLike(jug).init(ilk);
        JugLike(jug).file(ilk, "duty", 1001 * 10**27 / 1000);
        SpotterLike(spot).file(ilk, "pip", address(pip));
        SpotterLike(spot).file(ilk, "mat", 3 * 10**27); // 300% coll ratio
        pip.setPrice(1500 * 10**18); // 1 MKR = 1500 USD
        SpotterLike(spot).poke(ilk);
        VatLike(vat).file(ilk, "line", 1_000_000 * 10**45);
        vm.stopPrank();

        deal(address(mkr), address(this), 100_000 * 10**18, true);
        deal(address(ngt), address(this), 100_000 * 24_000 * 10**18, true);

        // Add some existing DAI assigned to nstJoin to avoid a particular error
        stdstore.target(vat).sig("dai(address)").with_key(address(nstJoin)).depth(0).checked_write(100_000 * RAD);
    }

    function _ink(bytes32 ilk_, address urn) internal view returns (uint256 ink) {
        (ink,) = VatLike(vat).urns(ilk_, urn);
    }

    function _art(bytes32 ilk_, address urn) internal view returns (uint256 art) {
        (, art) = VatLike(vat).urns(ilk_, urn);
    }

    function _rate(bytes32 ilk_) internal view returns (uint256 rate) {
        (, rate,,,) = VatLike(vat).ilks(ilk_);
    }

    function testConstructor() public {
        vm.expectRevert("LockstakeEngine/fee-over-wad");
        new LockstakeEngine(address(delFactory), address(nstJoin), "aaa", address(stkMkr), WAD + 1, address(mkrNgt));
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        LockstakeEngine e = new LockstakeEngine(address(delFactory), address(nstJoin), "aaa", address(stkMkr), 100, address(mkrNgt));
        assertEq(address(e.delegateFactory()), address(delFactory));
        assertEq(address(e.nstJoin()), address(nstJoin));
        assertEq(address(e.vat()), vat);
        assertEq(address(e.nst()), address(nst));
        assertEq(e.ilk(), "aaa");
        assertEq(address(e.mkr()), address(mkr));
        assertEq(address(e.stkMkr()), address(stkMkr));
        assertEq(e.fee(), 100);
        assertEq(address(e.mkrNgt()), address(mkrNgt));
        assertEq(address(e.ngt()), address(ngt));
        assertEq(e.mkrNgtRate(), 24_000);
        assertEq(LockstakeUrn(e.urnImplementation()).engine(), address(e));
        assertEq(address(LockstakeUrn(e.urnImplementation()).vat()), vat);
        assertEq(address(LockstakeUrn(e.urnImplementation()).stkMkr()), address(stkMkr));
        assertEq(VatLike(vat).can(address(e), address(nstJoin)), 1);
        assertEq(nst.allowance(address(e), address(nstJoin)), type(uint256).max);
        assertEq(ngt.allowance(address(e), address(mkrNgt)),  type(uint256).max);
        assertEq(mkr.allowance(address(e), address(mkrNgt)),  type(uint256).max);
        assertEq(e.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(engine), "LockstakeEngine");
    }

    function testFile() public {
        checkFileAddress(address(engine), "LockstakeEngine", ["jug"]);
    }

    function testModifiers() public {
        bytes4[] memory authedMethods = new bytes4[](5);
        authedMethods[0] = engine.verifyFarm.selector;
        authedMethods[1] = engine.freeNoFee.selector;
        authedMethods[2] = engine.onKick.selector;
        authedMethods[3] = engine.onTake.selector;
        authedMethods[4] = engine.onRemove.selector;

        // this checks the case where sender is not authed
        vm.startPrank(address(0xBEEF));
        checkModifier(address(engine), "LockstakeEngine/not-authorized", authedMethods);
        vm.stopPrank();

        bytes4[] memory urnOwnersMethods = new bytes4[](11);
        urnOwnersMethods[0]  = engine.hope.selector;
        urnOwnersMethods[1]  = engine.nope.selector;
        urnOwnersMethods[2]  = engine.selectDelegate.selector;
        urnOwnersMethods[3]  = engine.selectFarm.selector;
        urnOwnersMethods[4]  = engine.lock.selector;
        urnOwnersMethods[5]  = engine.lockNgt.selector;
        urnOwnersMethods[6]  = engine.free.selector;
        urnOwnersMethods[7]  = engine.freeNgt.selector;
        urnOwnersMethods[8]  = engine.draw.selector;
        urnOwnersMethods[9]  = engine.wipe.selector;
        urnOwnersMethods[10] = engine.getReward.selector;

        // this checks the case when sender is not the urn owner and not hoped, the hoped case is checked in testHopeNope and the urn owner case in the specific tests
        vm.startPrank(address(0xBEEF));
        checkModifier(address(engine), "LockstakeEngine/urn-not-authorized", urnOwnersMethods);
        vm.stopPrank();

        bytes4[] memory authedAndUrnOwnersMethods = new bytes4[](1);
        authedAndUrnOwnersMethods[0] = engine.freeNoFee.selector;

        // this checks the case when sender is relied but is not the urn owner and is not hoped, the hoped case is checked in testHopeNope and the urn owner case in the specific tests
        vm.prank(pauseProxy); engine.rely(address(0x123));
        vm.startPrank(address(0x123));
        checkModifier(address(engine), "LockstakeEngine/urn-not-authorized", urnOwnersMethods);
        vm.stopPrank();
    }

    function testAddFarm() public {
        assert(engine.farms(address(1111)) == LockstakeEngine.FarmStatus.Disabled);
        vm.expectEmit(true, true, true, true);
        emit VerifyFarm(address(1111), false);
        vm.prank(pauseProxy); engine.verifyFarm(address(1111), false);
        assert(engine.farms(address(1111)) == LockstakeEngine.FarmStatus.CanStake);
    }

    function testOpen() public {
        assertEq(engine.usrAmts(address(this)), 0);
        address urn = engine.getUrn(address(this), 0);
        vm.expectRevert("LockstakeEngine/wrong-urn-index");
        engine.open(1);

        assertEq(VatLike(vat).can(urn, address(engine)), 0);
        assertEq(stkMkr.allowance(urn, address(engine)), 0);
        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 0, urn);
        assertEq(engine.open(0), urn);
        assertEq(engine.usrAmts(address(this)), 1);
        assertEq(VatLike(vat).can(urn, address(engine)), 1);
        assertEq(stkMkr.allowance(urn, address(engine)), type(uint256).max);
        assertEq(LockstakeUrn(urn).engine(), address(engine));
        assertEq(address(LockstakeUrn(urn).stkMkr()), address(stkMkr));
        assertEq(address(LockstakeUrn(urn).vat()), vat);
        vm.expectRevert("LockstakeUrn/not-engine");
        LockstakeUrn(urn).init();

        vm.expectRevert("LockstakeEngine/wrong-urn-index");
        engine.open(2);

        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 1, engine.getUrn(address(this), 1));
        assertEq(engine.open(1), engine.getUrn(address(this), 1));
        assertEq(engine.usrAmts(address(this)), 2);
        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 2, engine.getUrn(address(this), 2));
        assertEq(engine.open(2), engine.getUrn(address(this), 2));
        assertEq(engine.usrAmts(address(this)), 3);
    }

    function testHopeNope() public {
        address urnOwner = address(123);
        address urnAuthed = address(456);
        address authedAndUrnAuthed = address(789);
        vm.startPrank(pauseProxy);
        engine.rely(authedAndUrnAuthed);
        engine.verifyFarm(address(farm), false);
        vm.stopPrank();
        mkr.transfer(urnAuthed, 100_000 * 10**18);
        ngt.transfer(urnAuthed, 100_000 * 24_000 * 10**18);
        vm.startPrank(urnOwner);
        address urn = engine.open(0);
        assertTrue(engine.isUrnAuth(urn, urnOwner));
        assertTrue(!engine.isUrnAuth(urn, urnAuthed));
        assertEq(engine.urnCan(urn, urnAuthed), 0);
        vm.expectEmit(true, true, true, true);
        emit Hope(urn, urnAuthed);
        engine.hope(urn, urnAuthed);
        assertEq(engine.urnCan(urn, urnAuthed), 1);
        assertTrue(engine.isUrnAuth(urn, urnAuthed));
        engine.hope(urn, authedAndUrnAuthed);
        vm.stopPrank();
        vm.startPrank(urnAuthed);
        vm.expectEmit(true, true, true, true);
        emit Hope(urn, address(1111));
        engine.hope(urn, address(1111));
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18, 0);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        engine.free(urn, address(this), 50_000 * 10**18);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        ngt.approve(address(engine), 100_000 * 24_000 * 10**18);
        engine.lockNgt(urn, 100_000 * 24_000 * 10**18, 0);
        assertEq(_ink(ilk, urn), 150_000 * 10**18);
        engine.freeNgt(urn, address(this), 50_000 * 24_000 * 10**18);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        engine.selectDelegate(urn, voterDelegate);
        assertEq(engine.urnDelegates(urn), voterDelegate);
        engine.draw(urn, address(urnAuthed), 1);
        nst.approve(address(engine), 1);
        engine.wipe(urn, 1);
        engine.selectFarm(urn, address(farm), 0);
        engine.getReward(urn, address(farm), address(0));
        vm.expectEmit(true, true, true, true);
        emit Nope(urn, urnAuthed);
        engine.nope(urn, urnAuthed);
        assertEq(engine.urnCan(urn, urnAuthed), 0);
        assertTrue(!engine.isUrnAuth(urn, urnAuthed));
        vm.stopPrank();
        vm.prank(authedAndUrnAuthed); engine.freeNoFee(urn, address(this), 50_000 * 10**18);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
    }

    function testSelectDelegate() public {
        address urn = engine.open(0);
        vm.expectRevert("LockstakeEngine/not-valid-delegate");
        engine.selectDelegate(urn, address(111));
        vm.expectEmit(true, true, true, true);
        emit SelectDelegate(urn, voterDelegate);
        engine.selectDelegate(urn, voterDelegate);
        vm.expectRevert("LockstakeEngine/same-delegate");
        engine.selectDelegate(urn, voterDelegate);
        assertEq(engine.urnDelegates(urn), voterDelegate);
        vm.prank(address(888)); address voterDelegate2 = delFactory.create();
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(DelegateMock(voterDelegate).stake(address(engine)), 100_000 * 10**18);
        assertEq(DelegateMock(voterDelegate2).stake(address(engine)), 0);
        assertEq(mkr.balanceOf(voterDelegate), 100_000 * 10**18);
        assertEq(mkr.balanceOf(voterDelegate2), 0);
        assertEq(mkr.balanceOf(address(engine)), 0);
        vm.expectEmit(true, true, true, true);
        emit SelectDelegate(urn, voterDelegate2);
        engine.selectDelegate(urn, voterDelegate2);
        assertEq(engine.urnDelegates(urn), voterDelegate2);
        assertEq(DelegateMock(voterDelegate).stake(address(engine)), 0);
        assertEq(DelegateMock(voterDelegate2).stake(address(engine)), 100_000 * 10**18);
        assertEq(mkr.balanceOf(voterDelegate), 0);
        assertEq(mkr.balanceOf(voterDelegate2), 100_000 * 10**18);
        assertEq(mkr.balanceOf(address(engine)), 0);
        engine.selectDelegate(urn, address(0));
        assertEq(engine.urnDelegates(urn), address(0));
        assertEq(DelegateMock(voterDelegate).stake(address(engine)), 0);
        assertEq(DelegateMock(voterDelegate2).stake(address(engine)), 0);
        assertEq(mkr.balanceOf(voterDelegate), 0);
        assertEq(mkr.balanceOf(voterDelegate2), 0);
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
    }

    function testSelectFarm() public {
        StakingRewardsMock farm2 = new StakingRewardsMock(address(rTok), address(stkMkr));
        address urn = engine.open(0);
        assertEq(engine.urnFarms(urn), address(0));
        vm.expectRevert("LockstakeEngine/farm-staking-disabled");
        engine.selectFarm(urn, address(farm), 5);
        vm.prank(pauseProxy); engine.verifyFarm(address(farm), false);
        vm.expectEmit(true, true, true, true);
        emit SelectFarm(urn, address(farm), 5);
        engine.selectFarm(urn, address(farm), 5);
        assertEq(engine.urnFarms(urn), address(farm));
        vm.expectRevert("LockstakeEngine/same-farm");
        engine.selectFarm(urn, address(farm), 5);
        vm.prank(pauseProxy); engine.verifyFarm(address(farm2), false);
        engine.selectFarm(urn, address(farm2), 5);
        assertEq(engine.urnFarms(urn), address(farm2));
        assertEq(stkMkr.balanceOf(address(farm)), 0);
        assertEq(stkMkr.balanceOf(address(farm2)), 0);
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(stkMkr.balanceOf(address(farm)),  0);
        assertEq(stkMkr.balanceOf(address(farm2)), 100_000 * 10**18);
        assertEq(farm.balanceOf(urn),  0);
        assertEq(farm2.balanceOf(urn), 100_000 * 10**18);
        engine.selectFarm(urn, address(farm), 5);
        assertEq(stkMkr.balanceOf(address(farm)),  100_000 * 10**18);
        assertEq(stkMkr.balanceOf(address(farm2)), 0);
        assertEq(farm.balanceOf(urn),  100_000 * 10**18);
        assertEq(farm2.balanceOf(urn), 0);
    }

    function _testLockFree(bool withDelegate, bool withStaking) internal {
        uint256 initialMkrSupply = mkr.totalSupply();
        address urn = engine.open(0);
        deal(address(mkr), address(this), uint256(type(int256).max) + 1); // deal mkr to allow reaching the overflow revert
        mkr.approve(address(engine), uint256(type(int256).max) + 1);
        vm.expectRevert("LockstakeEngine/wad-overflow");
        engine.lock(urn, uint256(type(int256).max) + 1, 5);
        deal(address(mkr), address(this), 100_000 * 10**18); // back to normal mkr balance and allowance
        mkr.approve(address(engine), 100_000 * 10**18);
        vm.expectRevert("LockstakeEngine/wad-overflow");
        engine.free(urn, address(this), uint256(type(int256).max) + 1);
        if (withDelegate) {
            engine.selectDelegate(urn, voterDelegate);
        }
        if (withStaking) {
            vm.prank(pauseProxy); engine.verifyFarm(address(farm), false);
            engine.selectFarm(urn, address(farm), 0);
        }
        assertEq(_ink(ilk, urn), 0);
        assertEq(stkMkr.balanceOf(urn), 0);
        mkr.approve(address(engine), 100_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit Lock(urn, 100_000 * 10**18, 5);
        engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(urn), 100_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 100_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(this)), 0);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 100_000 * 10**18); // Remains in delegate as it is a mock (otherwise it would be in the Chief)
        } else {
            assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        }
        assertEq(mkr.totalSupply(), initialMkrSupply);
        vm.expectEmit(true, true, true, true);
        emit Free(urn, address(this), 40_000 * 10**18, 40_000 * 10**18 * 15 / 100);
        engine.free(urn, address(this), 40_000 * 10**18);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 60_000 * 10**18);
            assertEq(farm.balanceOf(urn), 60_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 60_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(this)), 40_000 * 10**18 - 40_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 60_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 60_000 * 10**18);
        }
        vm.expectEmit(true, true, true, true);
        emit Free(urn, address(123), 10_000 * 10**18, 10_000 * 10**18 * 15 / 100);
        engine.free(urn, address(123), 10_000 * 10**18);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 50_000 * 10**18);
            assertEq(farm.balanceOf(urn), 50_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 50_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(123)), 10_000 * 10**18 - 10_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 50_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 50_000 * 10**18);
        }
        assertEq(mkr.totalSupply(), initialMkrSupply - 50_000 * 10**18 * 15 / 100);
        if (withStaking) {
            mkr.approve(address(engine), 1);
            vm.prank(pauseProxy); engine.verifyFarm(address(farm), true);
            vm.expectRevert("LockstakeEngine/farm-staking-disabled");
            engine.lock(urn, 1, 0);
        }
    }

    function testLockFreeNoDelegateNoStaking() public {
        _testLockFree(false, false);
    }

    function testLockFreeWithDelegateNoStaking() public {
        _testLockFree(true, false);
    }

    function testLockFreeNoDelegateWithStaking() public {
        _testLockFree(false, true);
    }

    function testLockFreeWithDelegateWithStaking() public {
        _testLockFree(true, true);
    }

    function _testLockFreeNgt(bool withDelegate, bool withStaking) internal {
        uint256 initialNgtSupply = ngt.totalSupply();
        address urn = engine.open(0);
        // Note: wad-overflow cannot be reached for lockNgt and freeNgt as with these functions and the value of rate (>=3) the MKR amount will be always lower
        if (withDelegate) {
            engine.selectDelegate(urn, voterDelegate);
        }
        if (withStaking) {
            vm.prank(pauseProxy); engine.verifyFarm(address(farm), false);
            engine.selectFarm(urn, address(farm), 0);
        }
        assertEq(_ink(ilk, urn), 0);
        assertEq(stkMkr.balanceOf(urn), 0);
        ngt.approve(address(engine), 100_000 * 24_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit LockNgt(urn, 100_000 * 24_000 * 10**18, 5);
        engine.lockNgt(urn, 100_000 * 24_000 * 10**18, 5);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(urn), 100_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 100_000 * 10**18);
        }
        assertEq(ngt.balanceOf(address(this)), 0);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 100_000 * 10**18); // Remains in delegate as it is a mock (otherwise it would be in the Chief)
        } else {
            assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        }
        assertEq(ngt.totalSupply(), initialNgtSupply - 100_000 * 24_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit FreeNgt(urn, address(this), 40_000 * 24_000 * 10**18, 40_000 * 10**18 * 15 / 100);
        engine.freeNgt(urn, address(this), 40_000 * 24_000 * 10**18);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 60_000 * 10**18);
            assertEq(farm.balanceOf(urn), 60_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 60_000 * 10**18);
        }
        assertEq(ngt.balanceOf(address(this)), 40_000 * 24_000 * 10**18 - 40_000 * 24_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 60_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 60_000 * 10**18);
        }
        vm.expectEmit(true, true, true, true);
        emit FreeNgt(urn, address(123), 10_000 * 24_000 * 10**18, 10_000 * 10**18 * 15 / 100);
        engine.freeNgt(urn, address(123), 10_000 * 24_000 * 10**18);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 50_000 * 10**18);
            assertEq(farm.balanceOf(urn), 50_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 50_000 * 10**18);
        }
        assertEq(ngt.balanceOf(address(123)), 10_000 * 24_000 * 10**18 - 10_000 * 24_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 50_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 50_000 * 10**18);
        }
        assertEq(ngt.totalSupply(), initialNgtSupply - (100_000 - 50_000) * 24_000 * 10**18 - 50_000 * 24_000 * 10**18 * 15 / 100);
        if (withStaking) {
            ngt.approve(address(engine), 24_000);
            vm.prank(pauseProxy); engine.verifyFarm(address(farm), true);
            vm.expectRevert("LockstakeEngine/farm-staking-disabled");
            engine.lockNgt(urn, 24_000, 0);
        }
    }

    function testLockFreeNgtNoDelegateNoStaking() public {
        _testLockFreeNgt(false, false);
    }

    function testLockFreeNgtWithDelegateNoStaking() public {
        _testLockFreeNgt(true, false);
    }

    function testLockFreeNgtNoDelegateWithStaking() public {
        _testLockFreeNgt(false, true);
    }

    function testLockFreeNgtWithDelegateWithStaking() public {
        _testLockFreeNgt(true, true);
    }

    function _testFreeNoFee(bool withDelegate, bool withStaking) internal {
        vm.prank(pauseProxy); engine.rely(address(this));
        uint256 initialMkrSupply = mkr.totalSupply();
        address urn = engine.open(0);
        deal(address(mkr), address(this), 100_000 * 10**18);
        mkr.approve(address(engine), 100_000 * 10**18);
        vm.expectRevert("LockstakeEngine/wad-overflow");
        engine.freeNoFee(urn, address(this), uint256(type(int256).max) + 1);
        if (withDelegate) {
            engine.selectDelegate(urn, voterDelegate);
        }
        if (withStaking) {
            vm.prank(pauseProxy); engine.verifyFarm(address(farm), false);
            engine.selectFarm(urn, address(farm), 0);
        }
        engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(urn), 100_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 100_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(this)), 0);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 100_000 * 10**18); // Remains in delegate as it is a mock (otherwise it would be in the Chief)
        } else {
            assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        }
        assertEq(mkr.totalSupply(), initialMkrSupply);
        vm.expectEmit(true, true, true, true);
        emit FreeNoFee(urn, address(this), 40_000 * 10**18);
        engine.freeNoFee(urn, address(this), 40_000 * 10**18);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 60_000 * 10**18);
            assertEq(farm.balanceOf(urn), 60_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 60_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(this)), 40_000 * 10**18);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 60_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 60_000 * 10**18);
        }
        vm.expectEmit(true, true, true, true);
        emit FreeNoFee(urn, address(123), 10_000 * 10**18);
        engine.freeNoFee(urn, address(123), 10_000 * 10**18);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 50_000 * 10**18);
            assertEq(farm.balanceOf(urn), 50_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(urn), 50_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(123)), 10_000 * 10**18);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voterDelegate), 50_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 50_000 * 10**18);
        }
        assertEq(mkr.totalSupply(), initialMkrSupply);
    }

    function testFreeNoFeeNoDelegateNoStaking() public {
        _testFreeNoFee(false, false);
    }

    function testFreeNoFeeWithDelegateNoStaking() public {
        _testFreeNoFee(true, false);
    }

    function testFreeNoFeeNoDelegateWithStaking() public {
        _testFreeNoFee(false, true);
    }

    function testFreeNoFeeWithDelegateWithStaking() public {
        _testFreeNoFee(true, true);
    }

    function testDrawWipe() public {
        deal(address(mkr), address(this), 100_000 * 10**18, true);
        address urn = engine.open(0);
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(_art(ilk, urn), 0);
        vm.expectEmit(true, true, true, true);
        emit Draw(urn, address(this), 50 * 10**18);
        engine.draw(urn, address(this), 50 * 10**18);
        assertEq(_art(ilk, urn), 50 * 10**18);
        assertEq(_rate(ilk), 10**27);
        assertEq(nst.balanceOf(address(this)), 50 * 10**18);
        vm.warp(block.timestamp + 1);
        vm.expectEmit(true, true, true, true);
        emit Draw(urn, address(this), 50 * 10**18);
        engine.draw(urn, address(this), 50 * 10**18);
        uint256 art = _art(ilk, urn);
        uint256 expectedArt = 50 * 10**18 + _divup(50 * 10**18 * 1000, 1001);
        assertEq(art, expectedArt);
        uint256 rate = _rate(ilk);
        assertEq(rate, 1001 * 10**27 / 1000);
        assertEq(nst.balanceOf(address(this)), 100 * 10**18);
        assertGt(art * rate, 100.05 * 10**45);
        assertLt(art * rate, 100.06 * 10**45);
        vm.expectRevert("Nst/insufficient-balance");
        engine.wipe(urn, 100.06 * 10**18);
        deal(address(nst), address(this), 100.06 * 10**18, true);
        assertEq(nst.balanceOf(address(this)), 100.06 * 10**18);
        nst.approve(address(engine), 100.06 * 10**18);
        vm.expectRevert();
        engine.wipe(urn, 100.06 * 10**18); // It will try to wipe more art than existing, then reverts
        vm.expectEmit(true, true, true, true);
        emit Wipe(urn, 100.05 * 10**18);
        engine.wipe(urn, 100.05 * 10**18);
        assertEq(nst.balanceOf(address(this)), 0.01 * 10**18);
        assertEq(_art(ilk, urn), 1); // Dust which is impossible to wipe
        assertEq(nst.balanceOf(address(123)), 0);
        emit Draw(urn, address(123), 50 * 10**18);
        engine.draw(urn, address(123), 50 * 10**18);
        assertEq(nst.balanceOf(address(123)), 50 * 10**18);
    }

    function testOpenLockStakeMulticall() public {
        vm.prank(pauseProxy); engine.verifyFarm(address(farm), false);
        mkr.approve(address(engine), 100_000 * 10**18);

        address urn = engine.getUrn(address(this), 0);

        assertEq(engine.usrAmts(address(this)), 0);
        assertEq(_ink(ilk, urn), 0);
        assertEq(farm.balanceOf(address(urn)), 0);
        assertEq(stkMkr.balanceOf(address(farm)), 0);

        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 0 , urn);
        vm.expectEmit(true, true, true, true);
        emit Lock(urn, 100_000 * 10**18, uint16(5));
        vm.expectEmit(true, true, true, true);
        emit SelectFarm(urn, address(farm), uint16(5));
        bytes[] memory callsToExecute = new bytes[](3);
        callsToExecute[0] = abi.encodeWithSignature("open(uint256)", 0);
        callsToExecute[1] = abi.encodeWithSignature("lock(address,uint256,uint16)", urn, 100_000 * 10**18, uint16(5));
        callsToExecute[2] = abi.encodeWithSignature("selectFarm(address,address,uint16)", urn, address(farm), uint16(5));
        engine.multicall(callsToExecute);

        assertEq(engine.usrAmts(address(this)), 1);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        assertEq(farm.balanceOf(address(urn)), 100_000 * 10**18);
        assertEq(stkMkr.balanceOf(address(farm)), 100_000 * 10**18);
    }

    function testGetReward() public {
        address urn = engine.open(0);
        vm.expectRevert("LockstakeEngine/non-verified-farm");
        engine.getReward(urn, address(123), address(123));
        vm.prank(pauseProxy); engine.verifyFarm(address(farm), false);
        farm.setReward(address(urn), 20_000);
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(123)), 0);
        vm.expectEmit(true, true, true, true);
        emit GetReward(urn, address(farm), address(123), 20_000);
        assertEq(engine.getReward(urn, address(farm), address(123)), 20_000);
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(123)), 20_000);
    }

    function _clipperSetUp(bool withDelegate, bool withStaking) internal returns (address urn) {
        vm.startPrank(pauseProxy);
        engine.verifyFarm(address(farm), false);
        clip = new LockstakeClipper(vat, spot, dog, address(engine));
        clip.file("vow", ChainlogLike(LOG).getAddress("MCD_VOW"));
        engine.rely(address(clip));
        clip.upchost();
        DogLike(dog).file(ilk, "clip", address(clip));
        clip.rely(dog);
        DogLike(dog).rely(address(clip));
        VatLike(vat).rely(address(clip));

        CalcLike calc = CalcLike(CalcFabLike(ChainlogLike(LOG).getAddress("CALC_FAB")).newLinearDecrease(pauseProxy));
        calc.file("tau", 100);
        clip.file("buf",  1.25 * 10**27);     // 25% Initial price buffer
        clip.file("calc", address(calc));     // File price contract
        clip.file("cusp", 0.2 * 10**27);      // 80% drop before reset
        clip.file("tail", 3600);              // 1 hour before reset
        DogLike(dog).file(ilk, "chop", 1 ether); // 0% chop
        DogLike(dog).file(ilk, "hole", 10_000 * 10**45);
        vm.stopPrank();

        urn = engine.open(0);
        if (withDelegate) {
            engine.selectDelegate(urn, voterDelegate);
        }
        if (withStaking) {
            engine.selectFarm(urn, address(farm), 0);
        }
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18, 5);
        engine.draw(urn, address(this), 2_000 * 10**18);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        assertEq(_art(ilk, urn), 2_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnDelegates(urn), voterDelegate);
            assertEq(mkr.balanceOf(voterDelegate), 100_000 * 10**18);
            assertEq(mkr.balanceOf(address(engine)), 0);
        } else {
            assertEq(engine.urnDelegates(urn), address(0));
            assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        }
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(urn)), 0);
            assertEq(stkMkr.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(address(urn)), 100_000 * 10**18);
        } else {
            assertEq(stkMkr.balanceOf(address(urn)), 100_000 * 10**18);
        }
    }

    function _forceLiquidation(address urn) internal returns (uint256 id) {
        pip.setPrice(0.05 * 10**18); // Force liquidation
        SpotterLike(spot).poke(ilk);
        assertEq(clip.kicks(), 0);
        assertEq(engine.urnAuctions(urn), 0);
        (,, uint256 hole,) = DogLike(dog).ilks(ilk);
        uint256 kicked = hole < 2_000 * 10**45 ? 100_000 * 10**18 * hole / (2_000 * 10**45) : 100_000 * 10**18;
        vm.expectEmit(true, true, true, true);
        emit OnKick(urn, kicked);
        id = DogLike(dog).bark(ilk, address(urn), address(this));
        assertEq(clip.kicks(), 1);
        assertEq(engine.urnAuctions(urn), 1);
    }

    function _testOnKickFull(bool withDelegate, bool withStaking) internal {
        address urn = _clipperSetUp(withDelegate, withStaking);
        uint256 stkMkrInitialSupply = stkMkr.totalSupply();
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 2_000 * 10**45);
        assertEq(sale.lot, 100_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnDelegates(urn), address(0));
            assertEq(mkr.balanceOf(voterDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), 0);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 100_000 * 10**18);
    }

    function testOnKickFullNoStakingNoDelegate() public {
        _testOnKickFull(false, false);
    }

    function testOnKickFullNoStakingWithDelegate() public {
        _testOnKickFull(true, false);
    }

    function testOnKickFullWithStakingNoDelegate() public {
        _testOnKickFull(false, true);
    }

    function testOnKickFullWithStakingWithDelegate() public {
        _testOnKickFull(true, true);
    }

    function _testOnKickPartial(bool withDelegate, bool withStaking) internal {
        address urn = _clipperSetUp(withDelegate, withStaking);
        uint256 stkMkrInitialSupply = stkMkr.totalSupply();
        vm.prank(pauseProxy); DogLike(dog).file(ilk, "hole", 500 * 10**45);
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 500 * 10**45);
        assertEq(sale.lot, 25_000 * 10**18);
        assertEq(sale.tot, 25_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 75_000 * 10**18);
        assertEq(_art(ilk, urn), 1_500 * 10**18);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 25_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnDelegates(urn), address(0));
            assertEq(mkr.balanceOf(voterDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), 75_000 * 10**18);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 25_000 * 10**18);
    }

    function testOnKickPartialNoStakingNoDelegate() public {
        _testOnKickPartial(false, false);
    }

    function testOnKickPartialNoStakingWithDelegate() public {
        _testOnKickPartial(true, false);
    }

    function testOnKickPartialWithStakingNoDelegate() public {
        _testOnKickPartial(false, true);
    }

    function testOnKickPartialWithStakingWithDelegate() public {
        _testOnKickPartial(true, true);
    }

    function _testOnTake(bool withDelegate, bool withStaking) internal {
        address urn = _clipperSetUp(withDelegate, withStaking);
        uint256 mkrInitialSupply = mkr.totalSupply();
        uint256 stkMkrInitialSupply = stkMkr.totalSupply();
        address vow = address(ChainlogLike(LOG).getAddress("MCD_VOW"));
        uint256 vowInitialBalance = VatLike(vat).dai(vow);
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 2_000 * 10**45);
        assertEq(sale.lot, 100_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voterDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), 0);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 100_000 * 10**18);

        address buyer = address(888);
        vm.prank(pauseProxy); VatLike(vat).suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); VatLike(vat).hope(address(clip));
        assertEq(mkr.balanceOf(buyer), 0);
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 20_000 * 10**18);
        vm.prank(buyer); clip.take(id, 20_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(mkr.balanceOf(buyer), 20_000 * 10**18);

        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, (2_000 - 20_000 * 0.05 * 1.25) * 10**45);
        assertEq(sale.lot, 80_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 80_000 * 10**18);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voterDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 80_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), 0);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 100_000 * 10**18);

        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 12_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 32_000 * 10**18, 32_000 * 10**18 * engine.fee() / WAD, 100_000 * 10**18 - 32_000 * 10**18 - 32_000 * 10**18 * engine.fee() / WAD);
        vm.prank(buyer); clip.take(id, 12_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(mkr.balanceOf(buyer), 32_000 * 10**18);
        assertEq(engine.urnAuctions(urn), 0);

        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);

        assertEq(_ink(ilk, urn), (100_000 - 32_000 * 1.15) * 10**18);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 0);

        assertEq(mkr.balanceOf(address(engine)), (100_000 - 32_000 * 1.15) * 10**18);
        assertEq(mkr.totalSupply(), mkrInitialSupply - 32_000 * 0.15 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), (100_000 - 32_000 * 1.15) * 10**18);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 32_000 * 1.15 * 10**18);
        assertEq(VatLike(vat).dai(vow), vowInitialBalance + 2_000 * 10**45);
    }

    function testOnTakeNoWithStakingNoDelegate() public {
        _testOnTake(false, false);
    }

    function testOnTakeNoWithStakingWithDelegate() public {
        _testOnTake(true, false);
    }

    function testOnTakeWithStakingNoDelegate() public {
        _testOnTake(false, true);
    }

    function testOnTakeWithStakingWithDelegate() public {
        _testOnTake(true, true);
    }

    function _testOnTakePartialBurn(bool withDelegate, bool withStaking) internal {
        address urn = _clipperSetUp(withDelegate, withStaking);
        uint256 mkrInitialSupply = mkr.totalSupply();
        uint256 stkMkrInitialSupply = stkMkr.totalSupply();
        address vow = address(ChainlogLike(LOG).getAddress("MCD_VOW"));
        uint256 vowInitialBalance = VatLike(vat).dai(vow);
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 2_000 * 10**45);
        assertEq(sale.lot, 100_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voterDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), 0);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 100_000 * 10**18);

        vm.warp(block.timestamp + 65); // Time passes to let the auction price to crash

        address buyer = address(888);
        vm.prank(pauseProxy); VatLike(vat).suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); VatLike(vat).hope(address(clip));
        assertEq(mkr.balanceOf(buyer), 0);
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 91428571428571428571428);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 91428571428571428571428, 100_000 * 10**18 - 91428571428571428571428, 0);
        vm.prank(buyer); clip.take(id, 100_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(mkr.balanceOf(buyer), 91428571428571428571428);
        assertEq(engine.urnAuctions(urn), 0);

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 0);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voterDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 0);
        assertEq(mkr.totalSupply(), mkrInitialSupply - (100_000 * 10**18 - 91428571428571428571428)); // Can't burn 15% of 91428571428571428571428
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), 0);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 100_000 * 10**18);
        assertEq(VatLike(vat).dai(vow), vowInitialBalance + 2_000 * 10**45);
    }

    function testOnTakePartialBurnNoStakingNoDelegate() public {
        _testOnTakePartialBurn(false, false);
    }

    function testOnTakePartialBurnNoStakingWithDelegate() public {
        _testOnTakePartialBurn(true, false);
    }

    function testOnTakePartialBurnWithStakingNoDelegate() public {
        _testOnTakePartialBurn(false, true);
    }

    function testOnTakePartialBurnWithStakingWithDelegate() public {
        _testOnTakePartialBurn(true, true);
    }

    function _testOnTakeNoBurn(bool withDelegate, bool withStaking) internal {
        address urn = _clipperSetUp(withDelegate, withStaking);
        uint256 mkrInitialSupply = mkr.totalSupply();
        uint256 stkMkrInitialSupply = stkMkr.totalSupply();
        address vow = address(ChainlogLike(LOG).getAddress("MCD_VOW"));
        uint256 vowInitialBalance = VatLike(vat).dai(vow);
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 2_000 * 10**45);
        assertEq(sale.lot, 100_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voterDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), 0);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 100_000 * 10**18);

        vm.warp(block.timestamp + 80); // Time passes to let the auction price to crash

        address buyer = address(888);
        vm.prank(pauseProxy); VatLike(vat).suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); VatLike(vat).hope(address(clip));
        assertEq(mkr.balanceOf(buyer), 0);
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 100_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 100_000 * 10**18, 0, 0);
        vm.prank(buyer); clip.take(id, 100_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(mkr.balanceOf(buyer), 100_000 * 10**18);
        assertEq(engine.urnAuctions(urn), 0);

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 0);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voterDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 0);
        assertEq(mkr.totalSupply(), mkrInitialSupply); // Can't burn anything
        if (withStaking) {
            assertEq(stkMkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(stkMkr.balanceOf(address(urn)), 0);
        assertEq(stkMkr.totalSupply(), stkMkrInitialSupply - 100_000 * 10**18);
        assertLt(VatLike(vat).dai(vow), vowInitialBalance + 2_000 * 10**45); // Doesn't recover full debt
    }

    function testOnTakeNoBurnNoStakingNoDelegate() public {
        _testOnTakeNoBurn(false, false);
    }

    function testOnTakeNoBurnNoStakingWithDelegate() public {
        _testOnTakeNoBurn(true, false);
    }

    function testOnTakeNoBurnWithStakingNoDelegate() public {
        _testOnTakeNoBurn(false, true);
    }

    function testOnTakeNoBurnWithStakingWithDelegate() public {
        _testOnTakeNoBurn(true, true);
    }

    function testCannotSelectDuringAuction() public {
        address urn = _clipperSetUp(true, true);

        assertEq(engine.urnDelegates(urn), voterDelegate);
        assertEq(engine.urnFarms(urn), address(farm));

        vm.prank(pauseProxy); DogLike(dog).file(ilk, "hole", 500 * 10**45);
        uint256 id1 = _forceLiquidation(urn);

        assertEq(engine.urnDelegates(urn), address(0));
        assertEq(engine.urnFarms(urn), address(0));

        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectDelegate(urn, voterDelegate);
        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectFarm(urn, address(farm), 0);

        vm.prank(pauseProxy); DogLike(dog).file(ilk, "hole", 1000 * 10**45);
        uint256 id2 = DogLike(dog).bark(ilk, urn, address(this));

        assertEq(engine.urnAuctions(urn), 2);

        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectDelegate(urn, voterDelegate);
        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectFarm(urn, address(farm), 0);

        // Take with left > 0
        address buyer = address(888);
        vm.prank(pauseProxy); VatLike(vat).suck(address(0), buyer, 4_000 * 10**45);
        vm.prank(buyer); VatLike(vat).hope(address(clip));
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 8_000 * 10**18); // 500 / (0.05 * 1.25 )
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 8_000 * 10**18, 8_000 * 10**18 * engine.fee() / WAD, 25_000 * 10**18 - 8_000 * 10**18 - 8_000 * 10**18 * engine.fee() / WAD);
        vm.prank(buyer); clip.take(id1, 25_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(engine.urnAuctions(urn), 1);

        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectDelegate(urn, voterDelegate);
        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectFarm(urn, address(farm), 0);

        vm.warp(block.timestamp + 80); // Time passes to let the auction price to crash

        // Take with left == 0
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 25_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 25_000 * 10**18, 0, 0);
        vm.prank(buyer); clip.take(id2, 25_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(engine.urnAuctions(urn), 0);

        // Can select delegate and farm again
        engine.selectDelegate(urn, voterDelegate);
        engine.selectFarm(urn, address(farm), 0);
    }

    function testOnRemoveOverflow() public {
        vm.expectRevert("LockstakeEngine/refund-over-maxint");
        vm.prank(pauseProxy); engine.onRemove(address(1), 0, uint256(type(int256).max) + 1);
    }

    function _testYank(bool withDelegate, bool withStaking) internal {
        address urn = _clipperSetUp(withDelegate, withStaking);
        uint256 id = _forceLiquidation(urn);

        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 0, 0, 0);
        vm.prank(pauseProxy); clip.yank(id);
        assertEq(engine.urnAuctions(urn), 0);
    }

    function testYankNoStakingNoDelegate() public {
        _testYank(false, false);
    }

    function testYankNoStakingWithDelegate() public {
        _testYank(true, false);
    }

    function testYankWithStakingNoDelegate() public {
        _testYank(false, true);
    }

    function testYankWithStakingWithDelegate() public {
        _testYank(true, true);
    }
}
