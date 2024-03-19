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
import { NstMock } from "test/mocks/NstMock.sol";
import { NstJoinMock } from "test/mocks/NstJoinMock.sol";
import { MkrNgtMock } from "test/mocks/MkrNgtMock.sol";

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
    NstMock             nst;
    NstJoinMock         nstJoin;
    GemMock             rTok;
    StakingRewards      farm;
    MkrNgtMock          mkrNgt;
    GemMock             ngt;
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
        nst = new NstMock();
        nstJoin = new NstJoinMock(address(dss.vat), address(nst));
        ngt = new GemMock(0);
        mkrNgt = new MkrNgtMock(address(mkr), address(ngt), 24_000);

        delFactory = new VoteDelegateFactory(chief, address(0));
        vm.prank(voter); voteDelegate = delFactory.create();
        assertEq(delFactory.created(voteDelegate), 1);

        vm.prank(pauseProxy); pip.kiss(address(this));
        vm.store(address(pip), bytes32(uint256(1)), bytes32(uint256(1_500 * 10**18)));

        LockstakeInstance memory instance = LockstakeDeploy.deployLockstake(
            address(this),
            pauseProxy,
            address(delFactory),
            address(nstJoin),
            ilk,
            15 * WAD / 100,
            address(mkrNgt),
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
            nstJoin: address(nstJoin),
            nst: address(nstJoin.nst()),
            mkr: address(mkr),
            mkrNgt: address(mkrNgt),
            ngt: address(ngt),
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

        deal(address(mkr), address(this), 100_000 * 10**18, true);
        deal(address(ngt), address(this), 100_000 * 24_000 * 10**18, true);

        // Add some existing DAI assigned to nstJoin to avoid a particular error
        stdstore.target(address(dss.vat)).sig("dai(address)").with_key(address(nstJoin)).depth(0).checked_write(100_000 * RAD);
    }

    function _urnSetUp(bool withDelegate, bool withStaking) internal returns (address urn) {
        urn = engine.open(0);
        if (withDelegate) {
            engine.selectVoteDelegate(urn, voteDelegate);
        }
        if (withStaking) {
            engine.selectFarm(urn, address(farm), 0);
        }
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18, 5);
        engine.draw(urn, address(this), 2_000 * 10**18);
    }

    function checkBenchmarkLiquidationCost(bool withDelegate, bool withStaking, uint256 numYays) private {
        console2.log(string(abi.encodePacked("Delegate: ", withDelegate ? "Y" : "N", ", Staking: ", withStaking ? "Y" : "N", ", Yays:")), numYays);
        address[] memory yays = new address[](numYays);
        for (uint256 i; i < numYays; i++) yays[i] = address(uint160(i + 1));
        vm.prank(voter); VoteDelegate(voteDelegate).vote(yays);

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
