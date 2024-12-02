// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";
import "dss-interfaces/Interfaces.sol";
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit, LockstakeConfig, LockstakeInstance } from "deploy/LockstakeInit.sol";
import { LockstakeMkr } from "src/LockstakeMkr.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { VoteDelegateFactory } from "test/integration/VoteDelegateFactory.sol";
import { VoteDelegate } from "test/integration/VoteDelegate.sol";
import { StakingRewards } from "test/integration/StakingRewards.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import { UsdsMock } from "test/mocks/UsdsMock.sol";
import { UsdsJoinMock } from "test/mocks/UsdsJoinMock.sol";
import { MkrSkyMock } from "test/mocks/MkrSkyMock.sol";

contract ClipperCalleeMock {
    function clipperCall(address, uint256, uint256, bytes calldata) external {}
}

contract LockstakeEngineBenchmarks is DssTest {
    using stdStorage for StdStorage;

    DssInstance         dss;
    address             pauseProxy;
    GemAbstract         mkr;
    LockstakeMkr        lsmkr;
    LockstakeEngine     engine;
    LockstakeClipper    clip;
    address             calc;
    MedianAbstract      pip;
    address             chief;
    VoteDelegateFactory delFactory;
    UsdsMock            usds;
    UsdsJoinMock        usdsJoin;
    GemMock             rTok;
    StakingRewards      farm;
    MkrSkyMock          mkrSky;
    GemMock             sky;
    bytes32             ilk = "LSE";
    address             voter = address(123);
    address             voteDelegate;

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dss = MCD.loadFromChainlog(LOG);

        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        pip = MedianAbstract(dss.chainlog.getAddress("PIP_MKR"));
        chief = dss.chainlog.getAddress("MCD_ADM");
        mkr = GemAbstract(dss.chainlog.getAddress("MCD_GOV"));
        usds = new UsdsMock();
        usdsJoin = new UsdsJoinMock(address(dss.vat), address(usds));
        sky = new GemMock(0);
        mkrSky = new MkrSkyMock(address(mkr), address(sky), 24_000);

        delFactory = new VoteDelegateFactory(chief, address(0));
        vm.prank(voter); voteDelegate = delFactory.create();
        assertEq(delFactory.created(voteDelegate), 1);

        vm.prank(pauseProxy); pip.kiss(address(this));
        vm.store(address(pip), bytes32(uint256(1)), bytes32(uint256(1_500 * 10**18)));

        LockstakeInstance memory instance = LockstakeDeploy.deployLockstake(
            address(this),
            pauseProxy,
            address(delFactory),
            address(usdsJoin),
            ilk,
            address(mkrSky),
            bytes4(abi.encodeWithSignature("newLinearDecrease(address)"))
        );

        engine = LockstakeEngine(instance.engine);
        clip = LockstakeClipper(instance.clipper);
        calc = instance.clipperCalc;
        lsmkr = LockstakeMkr(instance.lsmkr);

        rTok = new GemMock(0);
        farm = new StakingRewards(address(pauseProxy), address(pauseProxy), address(rTok), address(lsmkr));
        address[] memory farms = new address[](1);
        farms[0] = address(farm);

        LockstakeConfig memory cfg = LockstakeConfig({
            ilk: ilk,
            voteDelegateFactory: address(delFactory),
            usdsJoin: address(usdsJoin),
            usds: address(usdsJoin.usds()),
            mkr: address(mkr),
            mkrSky: address(mkrSky),
            sky: address(sky),
            farms: farms,
            fee: 15 * WAD / 100,
            maxLine: 10_000_000 * 10**45,
            gap: 1_000_000 * 10**45,
            ttl: 1 days,
            dust: 50,
            duty: 100000001 * 10**27 / 100000000,
            mat: 3 * 10**27,
            buf: 1.25 * 10**27, // 25% Initial price buffer
            tail: 3600, // 1 hour before reset
            cusp: 0.2 * 10**27, // 80% drop before reset
            chip: 2 * WAD / 100,
            tip: 3,
            stopped: 0,
            chop: 1 ether,
            hole: 10_000 * 10**45,
            tau: 100,
            cut: 0,
            step: 0,
            lineMom: true,
            tolerance: 0.5 * 10**27,
            name: "LOCKSTAKE",
            symbol: "LMKR"
        });

        vm.startPrank(pauseProxy);
        LockstakeInit.initLockstake(dss, instance, cfg);
        vm.stopPrank();

        deal(address(mkr), address(this), 200_000 * 10**18, true);
        deal(address(sky), address(this), 100_000 * 24_000 * 10**18, true);

        // Add some existing DAI assigned to usdsJoin to avoid a particular error
        stdstore.target(address(dss.vat)).sig("dai(address)").with_key(address(usdsJoin)).depth(0).checked_write(100_000 * RAD);
    }

    function _urnSetUp(bool withDelegate, bool withStaking) internal returns (address urn) {
        urn = engine.open(0);
        if (withDelegate) {
            engine.selectVoteDelegate(address(this), 0, voteDelegate);
        }
        if (withStaking) {
            engine.selectFarm(address(this), 0, address(farm), 0);
        }
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(address(this), 0, 100_000 * 10**18, 5);
        engine.draw(address(this), 0, address(this), 2_000 * 10**18);
    }

    function checkBenchmarkLiquidationCost(bool withDelegate, bool withStaking, uint256 numYays) private {
        console2.log(string(abi.encodePacked("Delegate: ", withDelegate ? "Y" : "N", ", Staking: ", withStaking ? "Y" : "N", ", Yays:")), numYays);
        address[] memory yays = new address[](numYays);
        for (uint256 i; i < numYays; i++) yays[i] = address(uint160(i + 1));
        vm.prank(voter); VoteDelegate(voteDelegate).vote(yays);

        // make sure the chief holds more votes than the votes from the user about to be liquidated
        mkr.approve(voteDelegate, 100_000 * 10**18);
        VoteDelegate(voteDelegate).lock(100_000 * 10**18);

        address urn = _urnSetUp(withDelegate, withStaking);
        vm.roll(block.number + 1);

        vm.store(address(pip), bytes32(uint256(1)), bytes32(uint256(0.05 * 10**18))); // Force liquidation
        dss.spotter.poke(ilk);
        uint256 startGas = gasleft();
        uint256 id = dss.dog.bark(ilk, address(urn), address(this));
        uint256 gasUsed = startGas - gasleft();
        console2.log("  Bark cost:", startGas - gasleft());

        address buyer = address(new ClipperCalleeMock());
        vm.prank(pauseProxy); dss.vat.suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); dss.vat.hope(address(clip));
        startGas = gasleft();
        vm.prank(buyer); clip.take(id, 100_000 * 10**18, type(uint256).max, buyer, "dummy");
        gasUsed = startGas - gasleft();
        console2.log("  Take cost:", gasUsed, "(excl. DEX trade)"); 
    }

    function testBenchmarkLiquidationCost_FF1() public {
        checkBenchmarkLiquidationCost(false, false, 1);
    }
    function testBenchmarkLiquidationCost_FT1() public {
        checkBenchmarkLiquidationCost(false, true, 1);
    }
    function testBenchmarkLiquidationCost_TF1() public {
        checkBenchmarkLiquidationCost(true, false, 1);
    }
    function testBenchmarkLiquidationCost_TF5() public {
        checkBenchmarkLiquidationCost(true, false, 5);
    }
    function testBenchmarkLiquidationCost_TT1() public {
        checkBenchmarkLiquidationCost(true, true, 1);
    }
    function testBenchmarkLiquidationCost_TT5() public {
        checkBenchmarkLiquidationCost(true, true, 5);
    }
}
