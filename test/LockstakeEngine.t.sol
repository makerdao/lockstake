// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { PipMock } from "test/mocks/PipMock.sol";
import { DelegateFactoryMock, DelegateMock } from "test/mocks/DelegateMock.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import { NstMock } from "test/mocks/NstMock.sol";
import { NstJoinMock } from "test/mocks/NstJoinMock.sol";
import { StakingRewardsMock } from "test/mocks/StakingRewardsMock.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface VatLike {
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

contract AllocatorVaultTest is DssTest {
    using stdStorage for StdStorage;

    address             public pauseProxy;
    address             public vat;
    address             public spot;
    address             public dog;
    GemMock             public gov;
    address             public jug;
    LockstakeEngine     public engine;
    LockstakeClipper    public clip;
    PipMock             public pip;
    DelegateFactoryMock public delFactory;
    NstMock             public nst;
    NstJoinMock         public nstJoin;
    GemMock             public stkGov;
    GemMock             public rTok;
    StakingRewardsMock  public farm;
    bytes32             public ilk = "LSE";
    address             public voter;
    address             public voterDelegate;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    event AddFarm(address farm);
    event DelFarm(address farm);
    event Open(address indexed owner, address urn);
    event Lock(address indexed urn, uint256 wad);
    event Free(address indexed urn, uint256 wad, uint256 burn);
    event Delegate(address indexed urn, address indexed delegate_);
    event Draw(address indexed urn, uint256 wad);
    event Wipe(address indexed urn, uint256 wad);
    event SelectFarm(address indexed urn, address farm);
    event Stake(address indexed urn, address indexed farm, uint256 wad, uint16 ref);
    event Withdraw(address indexed urn, address indexed farm, uint256 amt);
    event GetReward(address indexed urn, address indexed farm);
    event OnKick(address indexed urn, uint256 wad);
    event OnTake(address indexed urn, address indexed who, uint256 wad);
    event OnTakeLeftovers(address indexed urn, uint256 tot, uint256 left, uint256 burn);

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
        gov = GemMock(ChainlogLike(LOG).getAddress("MCD_GOV"));
        jug = ChainlogLike(LOG).getAddress("MCD_JUG");
        nst = new NstMock();
        nstJoin = new NstJoinMock(vat, address(nst));
        stkGov = new GemMock(0);
        rTok = new GemMock(0);
        farm = new StakingRewardsMock(address(rTok), address(stkGov));

        pip = new PipMock();
        delFactory = new DelegateFactoryMock(address(gov));
        voter = address(123);
        vm.prank(voter); voterDelegate = delFactory.create();

        vm.startPrank(pauseProxy);
        engine = new LockstakeEngine(address(delFactory), address(nstJoin), ilk, address(stkGov), 15 * WAD / 100);
        engine.file("jug", jug);
        VatLike(vat).rely(address(engine));
        VatLike(vat).init(ilk);
        JugLike(jug).init(ilk);
        JugLike(jug).file(ilk, "duty", 1001 * 10**27 / 1000);
        SpotterLike(spot).file(ilk, "pip", address(pip));
        SpotterLike(spot).file(ilk, "mat", 3 * 10**27); // 300% coll ratio
        pip.setPrice(0.1 * 10**18); // 1 GOV = 0.1 USD
        SpotterLike(spot).poke(ilk);
        VatLike(vat).file(ilk, "line", 1_000_000 * 10**45);
        vm.stopPrank();

        deal(address(gov), address(this), 100_000 * 10**18, true);

        // Add some existing DAI assigned to nstJoin to avoid a particular error
        stdstore.target(address(vat)).sig("dai(address)").with_key(address(nstJoin)).depth(0).checked_write(100_000 * RAD);
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

    function testAuth() public {
        checkAuth(address(engine), "LockstakeEngine");
    }

    function testModifiers() public {
        bytes4[] memory authedMethods = new bytes4[](6);
        authedMethods[0] = engine.addFarm.selector;
        authedMethods[1] = engine.delFarm.selector;
        authedMethods[2] = engine.onKick.selector;
        authedMethods[3] = engine.onTake.selector;
        authedMethods[4] = engine.onTakeLeftovers.selector;
        authedMethods[5] = engine.onYank.selector;

        vm.startPrank(address(0xBEEF));
        checkModifier(address(engine), "LockstakeEngine/not-authorized", authedMethods);
        vm.stopPrank();

        bytes4[] memory urnOwnersMethods = new bytes4[](8);
        urnOwnersMethods[0] = engine.lock.selector;
        urnOwnersMethods[1] = engine.free.selector;
        urnOwnersMethods[2] = engine.draw.selector;
        urnOwnersMethods[3] = engine.wipe.selector;
        urnOwnersMethods[4] = engine.selectFarm.selector;
        urnOwnersMethods[5] = engine.stake.selector;
        urnOwnersMethods[6] = engine.withdraw.selector;
        urnOwnersMethods[7] = engine.getReward.selector;

        vm.startPrank(address(0xBEEF));
        checkModifier(address(engine), "LockstakeEngine/not-urn-owner", urnOwnersMethods);
        vm.stopPrank();
    }

    function testFile() public {
        checkFileAddress(address(engine), "LockstakeEngine", ["jug"]);
    }

    function testAddDelFarm() public {
        assertEq(engine.farms(address(1111)), 0);
        vm.expectEmit(true, true, true, true);
        emit AddFarm(address(1111));
        vm.prank(pauseProxy); engine.addFarm(address(1111));
        assertEq(engine.farms(address(1111)), 1);
        vm.expectEmit(true, true, true, true);
        emit DelFarm(address(1111));
        vm.prank(pauseProxy); engine.delFarm(address(1111));
        assertEq(engine.farms(address(1111)), 0);
    }

    function testOpen() public {
        assertEq(engine.urnsAmt(address(this)), 0);
        address urn = engine.getUrn(address(this), 0);
        vm.expectEmit(true, true, true, true);
        emit Open(address(this), urn);
        assertEq(engine.open(), urn);
        assertEq(engine.urnsAmt(address(this)), 1);
        assertEq(engine.getUrn(address(this), 1), engine.open());
        assertEq(engine.urnsAmt(address(this)), 2);
        assertEq(engine.getUrn(address(this), 2), engine.open());
        assertEq(engine.urnsAmt(address(this)), 3);
    }

    function testLockFree() public {
        uint256 initialSupply = gov.totalSupply();
        assertEq(gov.balanceOf(address(this)), 100_000 * 10**18);
        address urn = engine.open();
        engine.delegate(urn, voterDelegate);
        assertEq(_ink(ilk, urn), 0);
        assertEq(stkGov.balanceOf(urn), 0);
        gov.approve(address(engine), 100_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit Lock(urn, 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        assertEq(stkGov.balanceOf(urn), 100_000 * 10**18);
        assertEq(gov.balanceOf(address(this)), 0);
        assertEq(gov.totalSupply(), initialSupply);
        vm.expectEmit(true, true, true, true);
        emit Free(urn, 40_000 * 10**18, 40_000 * 10**18 * 15 / 100);
        engine.free(urn, 40_000 * 10**18);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        assertEq(stkGov.balanceOf(urn), 60_000 * 10**18);
        assertEq(gov.balanceOf(address(this)), 40_000 * 10**18 - 40_000 * 10**18 * 15 / 100);
        assertEq(gov.totalSupply(), initialSupply - 40_000 * 10**18 * 15 / 100);
    }

    function testDelegate() public {
        address urn = engine.open();
        engine.delegate(urn, voterDelegate);
        vm.prank(address(888)); address voterDelegate2 = delFactory.create();
        gov.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18);
        assertEq(DelegateMock(voterDelegate).stake(address(engine)), 100_000 * 10**18);
        assertEq(DelegateMock(voterDelegate2).stake(address(engine)), 0);
        assertEq(gov.balanceOf(voterDelegate), 100_000 * 10**18);
        assertEq(gov.balanceOf(voterDelegate2), 0);
        engine.delegate(urn, voterDelegate2);
        assertEq(DelegateMock(voterDelegate).stake(address(engine)), 0);
        assertEq(DelegateMock(voterDelegate2).stake(address(engine)), 100_000 * 10**18);
        assertEq(gov.balanceOf(voterDelegate), 0);
        assertEq(gov.balanceOf(voterDelegate2), 100_000 * 10**18);
    }

    function testDrawWipe() public {
        deal(address(gov), address(this), 100_000 * 10**18, true);
        address urn = engine.open();
        gov.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18);
        assertEq(_art(ilk, urn), 0);
        vm.expectEmit(true, true, true, true);
        emit Draw(urn, 50 * 10**18);
        engine.draw(urn, 50 * 10**18);
        assertEq(_art(ilk, urn), 50 * 10**18);
        assertEq(_rate(ilk), 10**27);
        assertEq(nst.balanceOf(address(this)), 50 * 10**18);
        vm.warp(block.timestamp + 1);
        vm.expectEmit(true, true, true, true);
        emit Draw(urn, 50 * 10**18);
        engine.draw(urn, 50 * 10**18);
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
    }

    function testSelectFarm() public {
        StakingRewardsMock farm2 = new StakingRewardsMock(address(rTok), address(stkGov));
        address urn = engine.open();
        assertEq(engine.selectedFarm(urn), address(0));
        vm.expectRevert("LockstakeEngine/non-existing-farm");
        engine.selectFarm(urn, address(farm));
        vm.prank(pauseProxy); engine.addFarm(address(farm));
        vm.expectEmit(true, true, true, true);
        emit SelectFarm(urn, address(farm));
        engine.selectFarm(urn, address(farm));
        assertEq(engine.selectedFarm(urn), address(farm));
        vm.prank(pauseProxy); engine.addFarm(address(farm2));
        engine.selectFarm(urn, address(farm2));
        assertEq(engine.selectedFarm(urn), address(farm2));
        gov.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18);
        engine.stake(urn, 100_000, 1);
        vm.expectRevert("LockstakeEngine/withdraw-first");
        engine.selectFarm(urn, address(farm));
        engine.withdraw(urn, 100_000);
        engine.selectFarm(urn, address(farm));
    }

    function testStakeWithdraw() public {
        vm.prank(pauseProxy); engine.addFarm(address(farm));
        address urn = engine.open();
        gov.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18);
        vm.expectRevert("LockstakeEngine/missing-selected-farm");
        engine.stake(urn, 100_000, 1);
        vm.expectRevert("LockstakeEngine/missing-selected-farm");
        engine.withdraw(urn, 0);
        engine.selectFarm(urn, address(farm));
        assertEq(stkGov.balanceOf(address(urn)), 100_000 * 10**18);
        assertEq(stkGov.balanceOf(address(farm)), 0);
        assertEq(farm.balanceOf(address(urn)), 0);
        vm.expectEmit(true, true, true, true);
        emit Stake(urn, address(farm), 60_000 * 10**18, 1);
        engine.stake(urn, 60_000 * 10**18, 1);
        assertEq(stkGov.balanceOf(address(urn)), 40_000 * 10**18);
        assertEq(stkGov.balanceOf(address(farm)), 60_000 * 10**18);
        assertEq(farm.balanceOf(address(urn)), 60_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(urn, address(farm), 15_000 * 10**18);
        engine.withdraw(urn, 15_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 55_000 * 10**18);
        assertEq(stkGov.balanceOf(address(farm)), 45_000 * 10**18);
        assertEq(farm.balanceOf(address(urn)), 45_000 * 10**18);
    }

    function testGetReward() public {
        vm.prank(pauseProxy); engine.addFarm(address(farm));
        address urn = engine.open();
        farm.setReward(address(urn), 20_000);
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(this)), 0);
        vm.expectEmit(true, true, true, true);
        emit GetReward(urn, address(farm));
        engine.getReward(urn, address(farm));
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(this)), 20_000);
    }

    function _clipperSetUp() internal returns (address urn) {
        vm.startPrank(pauseProxy);
        engine.addFarm(address(farm));
        clip = new LockstakeClipper(vat, spot, dog, address(engine));
        clip.file("vow", ChainlogLike(LOG).getAddress("MCD_VOW"));
        engine.rely(address(clip));
        clip.upchost();
        DogLike(dog).file(ilk, "clip", address(clip));
        clip.rely(address(dog));
        DogLike(dog).rely(address(clip));
        VatLike(vat).rely(address(clip));

        CalcLike calc = CalcLike(CalcFabLike(ChainlogLike(LOG).getAddress("CALC_FAB")).newLinearDecrease(address(pauseProxy)));
        calc.file("tau", 100);
        clip.file("buf",  1.25 * 10**27);     // 25% Initial price buffer
        clip.file("calc", address(calc));     // File price contract
        clip.file("cusp", 0.2 * 10**27);      // 80% drop before reset
        clip.file("tail", 3600);              // 1 hour before reset
        DogLike(dog).file(ilk, "chop", 1 ether); // 0% chop
        DogLike(dog).file(ilk, "hole", 10_000 * 10**45);
        vm.stopPrank();

        urn = engine.open();
        engine.delegate(urn, voterDelegate);
        gov.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18);
        engine.draw(urn, 2_000 * 10**18);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        assertEq(_art(ilk, urn), 2_000 * 10**18);
    }

    function _forceLiquidation(address urn) internal returns (uint256 id) {
        pip.setPrice(0.05 * 10**18); // Force liquidation
        SpotterLike(spot).poke(ilk);
        assertEq(clip.kicks(), 0);
        id = DogLike(dog).bark(ilk, address(urn), address(this));
        assertEq(clip.kicks(), 1);
    }

    function testOnKickFullNoStaked() public {
        address urn = _clipperSetUp();

        assertEq(gov.balanceOf(address(voterDelegate)), 100_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(stkGov.balanceOf(address(urn)), 100_000 * 10**18);
        uint256 stkGovInitialSupply = stkGov.totalSupply();

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

        assertEq(gov.balanceOf(address(voterDelegate)), 0);
        assertEq(gov.balanceOf(address(engine)), 100_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 100_000 * 10**18);
    }

    function testOnKickPartialNoStaked() public {
        address urn = _clipperSetUp();

        vm.prank(pauseProxy); DogLike(dog).file(ilk, "hole", 500 * 10**45);

        uint256 stkGovInitialSupply = stkGov.totalSupply();

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

        assertEq(gov.balanceOf(address(voterDelegate)), 75_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 25_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 75_000 * 10**18);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 25_000 * 10**18);
    }

    function testOnKickFullStakedPartial() public {
        address urn = _clipperSetUp();

        engine.selectFarm(urn, address(farm));
        engine.stake(urn, 60_000 * 10**18, 1);
        assertEq(stkGov.balanceOf(address(urn)), 40_000 * 10**18);
        assertEq(stkGov.balanceOf(address(farm)), 60_000 * 10**18);

        assertEq(gov.balanceOf(address(voterDelegate)), 100_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(stkGov.balanceOf(address(urn)), 40_000 * 10**18);
        assertEq(stkGov.balanceOf(address(farm)), 60_000 * 10**18);
        uint256 stkGovInitialSupply = stkGov.totalSupply();

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

        assertEq(gov.balanceOf(address(voterDelegate)), 0);
        assertEq(gov.balanceOf(address(engine)), 100_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.balanceOf(address(farm)), 0);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 100_000 * 10**18);
    }

    function testOnKickPartialStakedPartialNoWithdraw() public {
        address urn = _clipperSetUp();

        engine.selectFarm(urn, address(farm));
        engine.stake(urn, 60_000 * 10**18, 1);
        assertEq(stkGov.balanceOf(address(urn)), 40_000 * 10**18);
        assertEq(stkGov.balanceOf(address(farm)), 60_000 * 10**18);

        vm.prank(pauseProxy); DogLike(dog).file(ilk, "hole", 500 * 10**45);

        uint256 stkGovInitialSupply = stkGov.totalSupply();

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

        assertEq(gov.balanceOf(address(voterDelegate)), 75_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 25_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 15_000 * 10**18);
        assertEq(stkGov.balanceOf(address(farm)), 60_000 * 10**18);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 25_000 * 10**18);
    }

    function testOnKickPartialStakedPartialWithdraw() public {
        address urn = _clipperSetUp();

        engine.selectFarm(urn, address(farm));
        engine.stake(urn, 80_000 * 10**18, 1);
        assertEq(stkGov.balanceOf(address(urn)), 20_000 * 10**18);
        assertEq(stkGov.balanceOf(address(farm)), 80_000 * 10**18);

        vm.prank(pauseProxy); DogLike(dog).file(ilk, "hole", 500 * 10**45);

        uint256 stkGovInitialSupply = stkGov.totalSupply();

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

        assertEq(gov.balanceOf(address(voterDelegate)), 75_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 25_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.balanceOf(address(farm)), 75_000 * 10**18);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 25_000 * 10**18);
    }

    function testOnTake() public {
        address urn = _clipperSetUp();

        assertEq(gov.balanceOf(address(voterDelegate)), 100_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(stkGov.balanceOf(address(urn)), 100_000 * 10**18);

        uint256 govInitialSupply = gov.totalSupply();
        uint256 stkGovInitialSupply = stkGov.totalSupply();
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

        assertEq(gov.balanceOf(address(voterDelegate)), 0);
        assertEq(gov.balanceOf(address(engine)), 100_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 100_000 * 10**18);

        address buyer = address(888);
        vm.prank(pauseProxy); VatLike(vat).suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); VatLike(vat).hope(address(clip));
        assertEq(gov.balanceOf(buyer), 0);
        vm.prank(buyer); clip.take(id, 20_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(gov.balanceOf(buyer), 20_000 * 10**18);

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

        assertEq(gov.balanceOf(address(voterDelegate)), 0);
        assertEq(gov.balanceOf(address(engine)), 80_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 100_000 * 10**18);

        vm.prank(buyer); clip.take(id, 12_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(gov.balanceOf(buyer), 32_000 * 10**18);

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

        assertEq(gov.balanceOf(address(voterDelegate)), (100_000 - 32_000 * 1.15) * 10**18);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(gov.totalSupply(), govInitialSupply - 32_000 * 0.15 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), (100_000 - 32_000 * 1.15) * 10**18);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 32_000 * 1.15 * 10**18);
        assertEq(VatLike(vat).dai(vow), vowInitialBalance + 2_000 * 10**45);
    }

    function testOnTakePartialBurn() public {
        address urn = _clipperSetUp();

        assertEq(gov.balanceOf(address(voterDelegate)), 100_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(stkGov.balanceOf(address(urn)), 100_000 * 10**18);

        uint256 govInitialSupply = gov.totalSupply();
        uint256 stkGovInitialSupply = stkGov.totalSupply();
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

        assertEq(gov.balanceOf(address(voterDelegate)), 0);
        assertEq(gov.balanceOf(address(engine)), 100_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 100_000 * 10**18);

        vm.warp(block.timestamp + 65); // Time passes to let the auction price to crash

        address buyer = address(888);
        vm.prank(pauseProxy); VatLike(vat).suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); VatLike(vat).hope(address(clip));
        assertEq(gov.balanceOf(buyer), 0);
        vm.prank(buyer); clip.take(id, 100_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(gov.balanceOf(buyer), 91428571428571428571428);

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 0);

        assertEq(gov.balanceOf(address(voterDelegate)), 0);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(gov.totalSupply(), govInitialSupply - (100_000 * 10**18 - 91428571428571428571428)); // Can't burn 15% of 91428571428571428571428
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 100_000 * 10**18);
        assertEq(VatLike(vat).dai(vow), vowInitialBalance + 2_000 * 10**45);
    }

    function testOnTakeNoBurn() public {
        address urn = _clipperSetUp();

        assertEq(gov.balanceOf(address(voterDelegate)), 100_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(stkGov.balanceOf(address(urn)), 100_000 * 10**18);

        uint256 govInitialSupply = gov.totalSupply();
        uint256 stkGovInitialSupply = stkGov.totalSupply();
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

        assertEq(gov.balanceOf(address(voterDelegate)), 0);
        assertEq(gov.balanceOf(address(engine)), 100_000 * 10**18);
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 100_000 * 10**18);

        vm.warp(block.timestamp + 80); // Time passes to let the auction price to crash

        address buyer = address(888);
        vm.prank(pauseProxy); VatLike(vat).suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); VatLike(vat).hope(address(clip));
        assertEq(gov.balanceOf(buyer), 0);
        vm.prank(buyer); clip.take(id, 100_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(gov.balanceOf(buyer), 100_000 * 10**18);

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(VatLike(vat).gem(ilk, address(clip)), 0);

        assertEq(gov.balanceOf(address(voterDelegate)), 0);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(gov.totalSupply(), govInitialSupply); // Can't burn anything
        assertEq(stkGov.balanceOf(address(urn)), 0);
        assertEq(stkGov.totalSupply(), stkGovInitialSupply - 100_000 * 10**18);
        assertLt(VatLike(vat).dai(vow), vowInitialBalance + 2_000 * 10**45); // Doesn't recover full debt
    }

    function testOnYank() public {
        address urn = _clipperSetUp();

        assertEq(gov.balanceOf(address(voterDelegate)), 100_000 * 10**18);
        assertEq(gov.balanceOf(address(engine)), 0);
        assertEq(stkGov.balanceOf(address(urn)), 100_000 * 10**18);

        uint256 govInitialSupply = gov.totalSupply();

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

        vm.prank(pauseProxy); clip.yank(id);

        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);

        assertEq(gov.totalSupply(), govInitialSupply - 100_000 * 10**18);
    }
}
