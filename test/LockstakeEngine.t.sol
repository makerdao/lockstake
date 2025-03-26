// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";
import "dss-interfaces/Interfaces.sol";
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit, LockstakeConfig, LockstakeInstance } from "deploy/LockstakeInit.sol";
import { LockstakeSky } from "src/LockstakeSky.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { LockstakeUrn } from "src/LockstakeUrn.sol";
import { LockstakeMigrator } from "src/LockstakeMigrator.sol";
import { VoteDelegateFactoryMock, VoteDelegateMock } from "test/mocks/VoteDelegateMock.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import { StakingRewardsMock } from "test/mocks/StakingRewardsMock.sol";

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

contract LockstakeEngineTest is DssTest {
    using stdStorage for StdStorage;

    DssInstance             dss;
    address                 oldLsmkr;
    address                 oldEngine;
    address                 oldClip;
    address                 oldCalc;
    address                 pauseProxy;
    DSTokenAbstract         sky;
    LockstakeSky            lssky;
    LockstakeEngine         engine;
    LockstakeClipper        clip;
    address                 calc;
    LockstakeMigrator       migrator;
    OsmAbstract             pip;
    VoteDelegateFactoryMock voteDelegateFactory;
    UsdsLike                usds;
    address                 usdsJoin;
    GemMock                 rTok;
    StakingRewardsMock      farm;
    StakingRewardsMock      farm2;
    bytes32                 ilk = "LSEV2-A";
    address                 voter;
    address                 voteDelegate;

    LockstakeConfig     cfg;

    uint256             prevLine;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    event AddFarm(address farm);
    event DelFarm(address farm);
    event Open(address indexed owner, uint256 indexed index, address urn);
    event Hope(address indexed owner, uint256 indexed index, address indexed usr);
    event Nope(address indexed owner, uint256 indexed index, address indexed usr);
    event SelectVoteDelegate(address indexed owner, uint256 indexed index, address indexed voteDelegate_);
    event SelectFarm(address indexed owner, uint256 indexed index, address indexed farm, uint16 ref);
    event Lock(address indexed owner, uint256 indexed index, uint256 wad, uint16 ref);
    event Free(address indexed owner, uint256 indexed index, address to, uint256 wad, uint256 freed);
    event FreeNoFee(address indexed owner, uint256 indexed index, address to, uint256 wad);
    event Draw(address indexed owner, uint256 indexed index, address to, uint256 wad);
    event Wipe(address indexed owner, uint256 indexed index, uint256 wad);
    event GetReward(address indexed owner, uint256 indexed index, address indexed farm, address to, uint256 amt);
    event OnKick(address indexed urn, uint256 wad);
    event OnTake(address indexed urn, address indexed who, uint256 wad);
    event OnRemove(address indexed urn, uint256 sold, uint256 burn, uint256 refund);

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // Note: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function _setMedianPrice(uint256 price) internal {
        vm.store(pip.src(), bytes32(uint256(1)), bytes32(price));
        vm.warp(block.timestamp + 1 hours);
        pip.poke();
        vm.warp(block.timestamp + 1 hours);
        pip.poke();
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dss = MCD.loadFromChainlog(LOG);

        oldLsmkr = dss.chainlog.getAddress("LOCKSTAKE_MKR");
        oldEngine = dss.chainlog.getAddress("LOCKSTAKE_ENGINE");
        oldClip = dss.chainlog.getAddress("LOCKSTAKE_CLIP");
        oldCalc = dss.chainlog.getAddress("LOCKSTAKE_CLIP_CALC");

        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        pip = OsmAbstract(dss.chainlog.getAddress("PIP_MKR"));
        sky = DSTokenAbstract(dss.chainlog.getAddress("SKY"));
        usds = UsdsLike(dss.chainlog.getAddress("USDS"));
        usdsJoin = dss.chainlog.getAddress("USDS_JOIN");
        rTok = new GemMock(0);

        voteDelegateFactory = new VoteDelegateFactoryMock(address(sky));
        voter = address(123);
        vm.prank(voter); voteDelegate = voteDelegateFactory.create();

        vm.prank(pauseProxy); pip.kiss(address(this));
        _setMedianPrice(1_500 * 10**18);

        LockstakeInstance memory instance = LockstakeDeploy.deployLockstake(
            address(this),
            pauseProxy,
            address(voteDelegateFactory),
            ilk,
            15 * WAD / 100,
            bytes4(abi.encodeWithSignature("newLinearDecrease(address)")),
            dss.chainlog.getAddress("MKR_SKY")
        );

        engine = LockstakeEngine(instance.engine);
        clip = LockstakeClipper(instance.clipper);
        calc = instance.clipperCalc;
        migrator = LockstakeMigrator(instance.migrator);
        lssky = LockstakeSky(instance.lssky);
        farm = new StakingRewardsMock(address(rTok), address(lssky));
        farm2 = new StakingRewardsMock(address(rTok), address(lssky));

        address[] memory farms = new address[](2);
        farms[0] = address(farm);
        farms[1] = address(farm2);

        cfg = LockstakeConfig({
            ilk: ilk,
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
            symbol: "LSSKY"
        });

        prevLine = dss.vat.Line();

        vm.startPrank(pauseProxy);
        dss.chainlog.setAddress("VOTE_DELEGATE_FACTORY", address(voteDelegateFactory));
        dss.chainlog.setAddress("PIP_SKY", address(pip));
        LockstakeInit.initLockstake(dss, instance, cfg);
        vm.stopPrank();

        deal(address(sky), address(this), 100_000 * 10**18, true);

        // Add some existing DAI assigned to usdsJoin to avoid a particular error
        stdstore.target(address(dss.vat)).sig("dai(address)").with_key(address(usdsJoin)).depth(0).checked_write(100_000 * RAD);
    }

    function _ink(bytes32 ilk_, address urn) internal view returns (uint256 ink) {
        (ink,) = dss.vat.urns(ilk_, urn);
    }

    function _art(bytes32 ilk_, address urn) internal view returns (uint256 art) {
        (, art) = dss.vat.urns(ilk_, urn);
    }

    function _rate(bytes32 ilk_) internal view returns (uint256 rate) {
        (, rate,,,) = dss.vat.ilks(ilk_);
    }

    function _spot(bytes32 ilk_) internal view returns (uint256 spot) {
        (,, spot,,) = dss.vat.ilks(ilk_);
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

    function _rho(bytes32 ilk_) internal view returns (uint256 rho) {
        (, rho) = dss.jug.ilks(ilk_);
    }

    function _pip(bytes32 ilk_) internal view returns (address pipV) {
        (pipV,) = dss.spotter.ilks(ilk_);
    }

    function _mat(bytes32 ilk_) internal view returns (uint256 mat) {
        (, mat) = dss.spotter.ilks(ilk_);
    }

    function _clip(bytes32 ilk_) internal view returns (address clipV) {
        (clipV,,,) = dss.dog.ilks(ilk_);
    }

    function _chop(bytes32 ilk_) internal view returns (uint256 chop) {
        (, chop,,) = dss.dog.ilks(ilk_);
    }

    function _hole(bytes32 ilk_) internal view returns (uint256 hole) {
        (,, hole,) = dss.dog.ilks(ilk_);
    }

    function testDeployAndInit() public {
        assertEq(address(engine.voteDelegateFactory()), address(voteDelegateFactory));
        assertEq(address(engine.usdsJoin()), address(usdsJoin));
        assertEq(engine.ilk(), ilk);
        assertEq(address(engine.sky()), address(sky));
        assertEq(address(engine.lssky()), address(lssky));
        assertEq(engine.fee(), 15 * WAD / 100);

        assertEq(address(clip.vat()), address(dss.vat));
        assertEq(address(clip.spotter()), address(dss.spotter));
        assertEq(address(clip.dog()), address(dss.dog));
        assertEq(address(clip.engine()), address(engine));

        assertEq(address(migrator.oldEngine()), oldEngine);
        assertEq(address(migrator.newEngine()), address(engine));
        assertEq(address(migrator.mkrSky()), dss.chainlog.getAddress("MKR_SKY"));
        assertEq(address(migrator.flash()), dss.chainlog.getAddress("MCD_FLASH"));

        assertEq(LockstakeEngine(oldEngine).wards(address(migrator)), 1);
        bytes32 oldIlk = LockstakeEngine(oldEngine).ilk();
        assertEq(_line(oldIlk), 0);
        (uint256 maxline, uint256 gap, uint256 ttl,,) = DssAutoLineAbstract(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE")).ilks(oldIlk);
        assertEq(maxline, 0);
        assertEq(gap, 0);
        assertEq(ttl, 0);
        assertEq(_rate(ilk), 10**27);
        assertEq(dss.vat.Line(), prevLine + 1_000_000 * 10**45);
        assertEq(_line(ilk), 1_000_000 * 10**45);
        assertEq(_dust(ilk), 50);
        assertEq(dss.vat.wards(address(engine)), 1);
        assertEq(dss.vat.wards(address(clip)), 1);
        (maxline, gap, ttl,,) = DssAutoLineAbstract(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE")).ilks(ilk);
        assertEq(maxline, 10_000_000 * 10**45);
        assertEq(gap, 1_000_000 * 10**45);
        assertEq(ttl, 1 days);
        assertEq(_rho(ilk), block.timestamp);
        assertEq(_duty(ilk), 100000001 * 10**27 / 100000000);
        address osmMom = dss.chainlog.getAddress("OSM_MOM");
        address clipperMom = dss.chainlog.getAddress("CLIPPER_MOM");
        assertEq(OsmMomAbstract(osmMom).osms(ilk), address(pip));
        assertEq(pip.wards(osmMom), 1);
        assertEq(pip.bud(address(dss.spotter)), 1);
        assertEq(pip.bud(address(clip)), 1);
        assertEq(pip.bud(clipperMom), 1);
        assertEq(pip.bud(address(dss.end)), 1);
        assertEq(_mat(ilk), 3 * 10**27);
        assertEq(_pip(ilk), address(pip));
        assertEq(_spot(ilk), (1500 / 3) * 10**27);
        assertEq(_clip(ilk), address(clip));
        assertEq(_chop(ilk), 1 ether);
        assertEq(_hole(ilk), 10_000 * 10**45);
        assertEq(dss.dog.wards(address(clip)), 1);
        assertEq(address(engine.jug()), address(dss.jug));
        assertTrue(engine.farms(address(farm)) == LockstakeEngine.FarmStatus.ACTIVE);
        assertTrue(engine.farms(address(farm2)) == LockstakeEngine.FarmStatus.ACTIVE);
        assertEq(engine.wards(address(clip)), 1);
        assertEq(clip.buf(), 1.25 * 10**27);
        assertEq(clip.tail(), 3600);
        assertEq(clip.cusp(), 0.2 * 10**27);
        assertEq(clip.chip(), 2 * WAD / 100);
        assertEq(clip.tip(), 3);
        assertEq(clip.stopped(), 0);
        assertEq(clip.vow(), address(dss.vow));
        assertEq(address(clip.calc()), calc);
        assertEq(clip.chost(), 50 * 1 ether / 10**18);
        assertEq(clip.wards(address(dss.dog)), 1);
        assertEq(clip.wards(address(dss.end)), 1);
        assertEq(clip.wards(clipperMom), 1);
        assertEq(LinearDecreaseAbstract(calc).tau(), 100);
        assertEq(LineMomLike(dss.chainlog.getAddress("LINE_MOM")).ilks(ilk), 1);
        assertEq(ClipperMomAbstract(clipperMom).tolerance(address(clip)), 0.5 * 10**27);

        (
            string memory name,
            string memory symbol,
            uint256 class,
            uint256 dec,
            address gem,
            address pipV,
            address join,
            address xlip
        ) = IlkRegistryAbstract(dss.chainlog.getAddress("ILK_REGISTRY")).info(ilk);
        assertEq(name, "LOCKSTAKE");
        assertEq(symbol, "LSSKY");
        assertEq(class, 7);
        assertEq(gem, address(sky));
        assertEq(dec, 18);
        assertEq(pipV, address(pip));
        assertEq(join, address(0));
        assertEq(xlip, address(clip));

        assertEq(dss.chainlog.getAddress("LOCKSTAKE_SKY"),       address(lssky));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_ENGINE"),    address(engine));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP"),      address(clip));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP_CALC"), calc);
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_MIGRATOR"),  address(migrator));

        assertEq(dss.chainlog.getAddress("LOCKSTAKE_MKR_OLD_V1"),       oldLsmkr);
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_ENGINE_OLD_V1"),    oldEngine);
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP_OLD_V1"),      oldClip);
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP_CALC_OLD_V1"), oldCalc);

        vm.expectRevert("dss-chain-log/invalid-key");
        dss.chainlog.getAddress("LOCKSTAKE_MKR");

        vm.prank(pauseProxy); dss.chainlog.setAddress("LOCKSTAKE_MKR", oldLsmkr);
        vm.prank(pauseProxy); dss.chainlog.setAddress("LOCKSTAKE_ENGINE", oldEngine);
        LockstakeInstance memory instance2 = LockstakeDeploy.deployLockstake(
            address(this),
            pauseProxy,
            address(voteDelegateFactory),
            "eee",
            15 * WAD / 100,
            bytes4(abi.encodeWithSignature("newStairstepExponentialDecrease(address)")),
            dss.chainlog.getAddress("MKR_SKY")
        );
        cfg.ilk = "eee";
        cfg.tau = 0;
        cfg.cut = 10**27;
        cfg.step = 1;
        cfg.farms[0] = address(new StakingRewardsMock(address(rTok), address(instance2.lssky)));
        cfg.farms[1] = address(new StakingRewardsMock(address(rTok), address(instance2.lssky)));
        vm.startPrank(pauseProxy);
        LockstakeInit.initLockstake(dss, instance2, cfg);
        vm.stopPrank();
        assertEq(StairstepExponentialDecreaseAbstract(instance2.clipperCalc).cut(), 10**27);
        assertEq(StairstepExponentialDecreaseAbstract(instance2.clipperCalc).step(), 1);
    }

    function testConstructor() public {
        address lssky2 = address(new GemMock(0));
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        LockstakeEngine e = new LockstakeEngine(address(voteDelegateFactory), address(usdsJoin), "aaa", address(sky), lssky2, 123);
        assertEq(address(e.voteDelegateFactory()), address(voteDelegateFactory));
        assertEq(address(e.usdsJoin()), address(usdsJoin));
        assertEq(address(e.vat()), address(dss.vat));
        assertEq(address(e.usds()), address(usds));
        assertEq(e.ilk(), "aaa");
        assertEq(address(e.sky()), address(sky));
        assertEq(address(e.lssky()), lssky2);
        assertEq(e.fee(), 123);
        assertEq(LockstakeUrn(e.urnImplementation()).engine(), address(e));
        assertEq(address(LockstakeUrn(e.urnImplementation()).vat()), address(dss.vat));
        assertEq(address(LockstakeUrn(e.urnImplementation()).lssky()), lssky2);
        assertEq(dss.vat.can(address(e), address(usdsJoin)), 1);
        assertEq(usds.allowance(address(e), address(usdsJoin)), type(uint256).max);
        assertEq(e.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(engine), "LockstakeEngine");
    }

    function testFile() public {
        checkFileAddress(address(engine), "LockstakeEngine", ["jug"]);
    }

    function testModifiers() public {
        bytes4[] memory authedMethods = new bytes4[](6);
        authedMethods[0] = engine.addFarm.selector;
        authedMethods[1] = engine.delFarm.selector;
        authedMethods[2] = engine.freeNoFee.selector;
        authedMethods[3] = engine.onKick.selector;
        authedMethods[4] = engine.onTake.selector;
        authedMethods[5] = engine.onRemove.selector;

        // this checks the case where sender is not authed
        vm.startPrank(address(0xBEEF));
        checkModifier(address(engine), "LockstakeEngine/not-authorized", authedMethods);
        vm.stopPrank();
    }

    function testAddDelFarm() public {
        assertTrue(engine.farms(address(1111)) == LockstakeEngine.FarmStatus.UNSUPPORTED);
        vm.expectEmit(true, true, true, true);
        emit AddFarm(address(1111));
        vm.prank(pauseProxy); engine.addFarm(address(1111));
        assertTrue(engine.farms(address(1111)) == LockstakeEngine.FarmStatus.ACTIVE);
        vm.expectEmit(true, true, true, true);
        emit DelFarm(address(1111));
        vm.prank(pauseProxy); engine.delFarm(address(1111));
        assertTrue(engine.farms(address(1111)) == LockstakeEngine.FarmStatus.DELETED);
    }

    function testOpen() public {
        assertEq(engine.ownerUrnsCount(address(this)), 0);
        address urn = vm.computeCreateAddress(address(engine), vm.getNonce(address(engine)));
        vm.expectRevert("LockstakeEngine/wrong-urn-index");
        engine.open(1);

        assertEq(dss.vat.can(urn, address(engine)), 0);
        assertEq(lssky.allowance(urn, address(engine)), 0);
        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 0, urn);
        assertEq(engine.open(0), urn);
        assertEq(engine.ownerUrnsCount(address(this)), 1);
        assertEq(dss.vat.can(urn, address(engine)), 1);
        assertEq(lssky.allowance(urn, address(engine)), type(uint256).max);
        assertEq(LockstakeUrn(urn).engine(), address(engine));
        assertEq(address(LockstakeUrn(urn).lssky()), address(lssky));
        assertEq(address(LockstakeUrn(urn).vat()), address(dss.vat));
        vm.expectRevert("LockstakeUrn/not-engine");
        LockstakeUrn(urn).init();

        vm.expectRevert("LockstakeEngine/wrong-urn-index");
        engine.open(2);

        address urn2 = vm.computeCreateAddress(address(engine), vm.getNonce(address(engine)));
        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 1, urn2);
        assertEq(engine.open(1), urn2);
        assertEq(engine.ownerUrnsCount(address(this)), 2);
        address urn3 = vm.computeCreateAddress(address(engine), vm.getNonce(address(engine)));
        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 2, urn3);
        assertEq(engine.open(2), urn3);
        assertEq(engine.ownerUrnsCount(address(this)), 3);
    }

    function testInvalidUrn() public {
        assertEq(engine.ownerUrns(address(this), 0), address(0));
        address urn = engine.open(0);
        assertEq(engine.ownerUrns(address(this), 0), urn);
        assertEq(engine.ownerUrns(address(this), 1), address(0));
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.isUrnAuth(address(this), 1, address(123));
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.hope(address(this), 1, address(123));
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.nope(address(this), 1, address(123));
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.selectVoteDelegate(address(this), 1, address(123));
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.selectFarm(address(this), 1, address(123), 1);
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.lock(address(this), 1, 1, 1);
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.free(address(this), 1, address(123), 1);
        vm.expectRevert("LockstakeEngine/invalid-urn");
        vm.prank(pauseProxy); engine.freeNoFee(address(this), 1, address(123), 1);
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.draw(address(this), 1, address(123), 1);
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.wipe(address(this), 1, 1);
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.wipeAll(address(this), 1);
        vm.expectRevert("LockstakeEngine/invalid-urn");
        engine.getReward(address(this), 1, address(123), address(456));
    }

    function testUrnNotAuthorized() public {
        vm.prank(address(123)); engine.open(0);

        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        engine.hope(address(123), 0, address(this));
        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        engine.nope(address(123), 0, address(this));
        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        engine.selectVoteDelegate(address(123), 0, address(123));
        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        engine.selectFarm(address(123), 0, address(123), 1);
        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        engine.free(address(123), 0, address(123), 1);
        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        vm.prank(pauseProxy); engine.freeNoFee(address(123), 0, address(123), 1);
        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        engine.draw(address(123), 0, address(123), 1);
        vm.expectRevert("LockstakeEngine/urn-not-authorized");
        engine.getReward(address(123), 0, address(123), address(456));
    }

    function testHopeNope() public {
        address urnOwner = address(123);
        address urnAuthed = address(456);
        address authedAndUrnAuthed = address(789);
        vm.startPrank(pauseProxy);
        engine.rely(authedAndUrnAuthed);
        vm.stopPrank();
        sky.transfer(urnAuthed, 100_000 * 10**18);
        vm.startPrank(urnOwner);
        address urn = engine.open(0);
        assertTrue(engine.isUrnAuth(urnOwner, 0, urnOwner));
        assertTrue(!engine.isUrnAuth(urnOwner, 0, urnAuthed));
        assertEq(engine.urnCan(urn, urnAuthed), 0);
        vm.expectEmit(true, true, true, true);
        emit Hope(urnOwner, 0, urnAuthed);
        engine.hope(urnOwner, 0, urnAuthed);
        assertEq(engine.urnCan(urn, urnAuthed), 1);
        assertTrue(engine.isUrnAuth(urnOwner, 0, urnAuthed));
        engine.hope(urnOwner, 0, authedAndUrnAuthed);
        vm.stopPrank();
        vm.startPrank(urnAuthed);
        vm.expectEmit(true, true, true, true);
        emit Hope(urnOwner, 0, address(1111));
        engine.hope(urnOwner, 0, address(1111));
        sky.approve(address(engine), 100_000 * 10**18);
        engine.lock(urnOwner, 0, 100_000 * 10**18, 0);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        engine.free(urnOwner, 0, address(this), 50_000 * 10**18);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        engine.selectVoteDelegate(urnOwner, 0, voteDelegate);
        assertEq(engine.urnVoteDelegates(urn), voteDelegate);
        engine.draw(urnOwner, 0, address(urnAuthed), 1);
        usds.approve(address(engine), 1);
        engine.wipe(urnOwner, 0, 1);
        engine.selectFarm(urnOwner, 0, address(farm), 0);
        engine.getReward(urnOwner, 0, address(farm), address(0));
        vm.expectEmit(true, true, true, true);
        emit Nope(urnOwner, 0, urnAuthed);
        engine.nope(urnOwner, 0, urnAuthed);
        assertEq(engine.urnCan(urn, urnAuthed), 0);
        assertTrue(!engine.isUrnAuth(urnOwner, 0, urnAuthed));
        vm.stopPrank();
        vm.prank(authedAndUrnAuthed); engine.freeNoFee(urnOwner, 0, address(this), 25_000 * 10**18);
        assertEq(_ink(ilk, urn), 25_000 * 10**18);
    }

    function testSelectVoteDelegate() public {
        address urn = engine.open(0);
        vm.expectRevert("LockstakeEngine/not-valid-vote-delegate");
        engine.selectVoteDelegate(address(this), 0, address(111));
        vm.expectEmit(true, true, true, true);
        emit SelectVoteDelegate(address(this), 0, voteDelegate);
        engine.selectVoteDelegate(address(this), 0, voteDelegate);
        vm.expectRevert("LockstakeEngine/same-vote-delegate");
        engine.selectVoteDelegate(address(this), 0, voteDelegate);
        assertEq(engine.urnVoteDelegates(urn), voteDelegate);
        vm.prank(address(888)); address voteDelegate2 = voteDelegateFactory.create();
        sky.approve(address(engine), 100_000 * 10**18);
        engine.lock(address(this), 0, 100_000 * 10**18, 5);
        engine.draw(address(this), 0, address(this), 10_000 * 10**18);
        assertEq(VoteDelegateMock(voteDelegate).stake(address(engine)), 100_000 * 10**18);
        assertEq(VoteDelegateMock(voteDelegate2).stake(address(engine)), 0);
        assertEq(sky.balanceOf(voteDelegate), 100_000 * 10**18);
        assertEq(sky.balanceOf(voteDelegate2), 0);
        assertEq(sky.balanceOf(address(engine)), 0);
        dss.jug.drip(ilk);
        (, uint256 rateA,,,) = dss.vat.ilks(ilk);
        vm.warp(block.timestamp + 20);
        vm.expectEmit(true, true, true, true);
        emit SelectVoteDelegate(address(this), 0, voteDelegate2);
        engine.selectVoteDelegate(address(this), 0, voteDelegate2);
        (, uint256 rateB,,,) = dss.vat.ilks(ilk);
        assertGt(rateB, rateA);
        assertEq(engine.urnVoteDelegates(urn), voteDelegate2);
        assertEq(VoteDelegateMock(voteDelegate).stake(address(engine)), 0);
        assertEq(VoteDelegateMock(voteDelegate2).stake(address(engine)), 100_000 * 10**18);
        assertEq(sky.balanceOf(voteDelegate), 0);
        assertEq(sky.balanceOf(voteDelegate2), 100_000 * 10**18);
        assertEq(sky.balanceOf(address(engine)), 0);
        engine.selectVoteDelegate(address(this), 0, address(0));
        assertEq(engine.urnVoteDelegates(urn), address(0));
        assertEq(VoteDelegateMock(voteDelegate).stake(address(engine)), 0);
        assertEq(VoteDelegateMock(voteDelegate2).stake(address(engine)), 0);
        assertEq(sky.balanceOf(voteDelegate), 0);
        assertEq(sky.balanceOf(voteDelegate2), 0);
        assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
    }

    function testSelectFarm() public {
        StakingRewardsMock farm3 = new StakingRewardsMock(address(rTok), address(lssky));
        address urn = engine.open(0);
        assertEq(engine.urnFarms(urn), address(0));
        vm.expectRevert("LockstakeEngine/farm-unsupported-or-deleted");
        engine.selectFarm(address(this), 0, address(farm3), 5);
        vm.prank(pauseProxy); engine.addFarm(address(farm3));
        vm.expectEmit(true, true, true, true);
        emit SelectFarm(address(this), 0, address(farm3), 5);
        engine.selectFarm(address(this), 0, address(farm3), 5);
        assertEq(engine.urnFarms(urn), address(farm3));
        vm.expectRevert("LockstakeEngine/same-farm");
        engine.selectFarm(address(this), 0, address(farm3), 5);
        assertEq(lssky.balanceOf(address(farm)), 0);
        assertEq(lssky.balanceOf(address(farm3)), 0);
        sky.approve(address(engine), 100_000 * 10**18);
        engine.lock(address(this), 0, 100_000 * 10**18, 5);
        assertEq(lssky.balanceOf(address(farm)),  0);
        assertEq(lssky.balanceOf(address(farm3)), 100_000 * 10**18);
        assertEq(farm.balanceOf(urn),  0);
        assertEq(farm3.balanceOf(urn), 100_000 * 10**18);
        engine.selectFarm(address(this), 0, address(farm), 5);
        assertEq(lssky.balanceOf(address(farm)),  100_000 * 10**18);
        assertEq(lssky.balanceOf(address(farm3)), 0);
        assertEq(farm.balanceOf(urn),  100_000 * 10**18);
        assertEq(farm3.balanceOf(urn), 0);
        vm.prank(pauseProxy); engine.delFarm(address(farm3));
        vm.expectRevert("LockstakeEngine/farm-unsupported-or-deleted");
        engine.selectFarm(address(this), 0, address(farm3), 5);
    }

    function _testLockFree(bool withDelegate, bool withStaking) internal {
        uint256 initialSkySupply = sky.totalSupply();
        address urn = engine.open(0);
        deal(address(sky), address(this), uint256(type(int256).max) + 1); // deal sky to allow reaching the overflow revert
        sky.approve(address(engine), uint256(type(int256).max) + 1);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.lock(address(this), 0, uint256(type(int256).max) + 1, 5);
        deal(address(sky), address(this), 100_000 * 10**18); // back to normal sky balance and allowance
        sky.approve(address(engine), 100_000 * 10**18);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.free(address(this), 0, address(this), uint256(type(int256).max) + 1);
        if (withDelegate) {
            engine.selectVoteDelegate(address(this), 0, voteDelegate);
        }
        if (withStaking) {
            engine.selectFarm(address(this), 0, address(farm), 0);
        }
        assertEq(_ink(ilk, urn), 0);
        assertEq(lssky.balanceOf(urn), 0);
        sky.transfer(address(123), 100_000 * 10**18);
        vm.prank(address(123)); sky.approve(address(engine), 100_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit Lock(address(this), 0, 100_000 * 10**18, 5);
        vm.prank(address(123)); engine.lock(address(this), 0, 100_000 * 10**18, 5);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(urn), 100_000 * 10**18);
        } else {
            assertEq(lssky.balanceOf(urn), 100_000 * 10**18);
        }
        assertEq(sky.balanceOf(address(this)), 0);
        if (withDelegate) {
            assertEq(sky.balanceOf(address(engine)), 0);
            assertEq(sky.balanceOf(voteDelegate), 100_000 * 10**18); // Remains in voteDelegate as it is a mock (otherwise it would be in the Chief)
        } else {
            assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
        }
        assertEq(sky.totalSupply(), initialSkySupply);
        vm.expectEmit(true, true, true, true);
        emit Free(address(this), 0, address(this), 40_000 * 10**18, 40_000 * 10**18 * 85 / 100);
        assertEq(engine.free(address(this), 0, address(this), 40_000 * 10**18), 40_000 * 10**18 * 85 / 100);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 60_000 * 10**18);
            assertEq(farm.balanceOf(urn), 60_000 * 10**18);
        } else {
            assertEq(lssky.balanceOf(urn), 60_000 * 10**18);
        }
        assertEq(sky.balanceOf(address(this)), 40_000 * 10**18 - 40_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(sky.balanceOf(address(engine)), 0);
            assertEq(sky.balanceOf(voteDelegate), 60_000 * 10**18);
        } else {
            assertEq(sky.balanceOf(address(engine)), 60_000 * 10**18);
        }
        vm.expectEmit(true, true, true, true);
        emit Free(address(this), 0, address(123), 10_000 * 10**18, 10_000 * 10**18 * 85 / 100);
        assertEq(engine.free(address(this), 0, address(123), 10_000 * 10**18), 10_000 * 10**18 * 85 / 100);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 50_000 * 10**18);
            assertEq(farm.balanceOf(urn), 50_000 * 10**18);
        } else {
            assertEq(lssky.balanceOf(urn), 50_000 * 10**18);
        }
        assertEq(sky.balanceOf(address(123)), 10_000 * 10**18 - 10_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(sky.balanceOf(address(engine)), 0);
            assertEq(sky.balanceOf(voteDelegate), 50_000 * 10**18);
        } else {
            assertEq(sky.balanceOf(address(engine)), 50_000 * 10**18);
        }
        assertEq(sky.totalSupply(), initialSkySupply - 50_000 * 10**18 * 15 / 100);
        if (withStaking) {
            sky.approve(address(engine), 1);
            vm.prank(pauseProxy); engine.delFarm(address(farm));
            vm.expectRevert("LockstakeEngine/farm-deleted");
            engine.lock(address(this), 0, 1, 0);
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

    function _testFreeNoFee(bool withDelegate, bool withStaking) internal {
        vm.prank(pauseProxy); engine.rely(address(this));
        uint256 initialSkySupply = sky.totalSupply();
        address urn = engine.open(0);
        deal(address(sky), address(this), 100_000 * 10**18);
        sky.approve(address(engine), 100_000 * 10**18);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.freeNoFee(address(this), 0, address(this), uint256(type(int256).max) + 1);
        if (withDelegate) {
            engine.selectVoteDelegate(address(this), 0, voteDelegate);
        }
        if (withStaking) {
            engine.selectFarm(address(this), 0, address(farm), 0);
        }
        engine.lock(address(this), 0, 100_000 * 10**18, 5);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(urn), 100_000 * 10**18);
        } else {
            assertEq(lssky.balanceOf(urn), 100_000 * 10**18);
        }
        assertEq(sky.balanceOf(address(this)), 0);
        if (withDelegate) {
            assertEq(sky.balanceOf(address(engine)), 0);
            assertEq(sky.balanceOf(voteDelegate), 100_000 * 10**18); // Remains in voteDelegate as it is a mock (otherwise it would be in the Chief)
        } else {
            assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
        }
        assertEq(sky.totalSupply(), initialSkySupply);
        vm.expectEmit(true, true, true, true);
        emit FreeNoFee(address(this), 0, address(this), 40_000 * 10**18);
        engine.freeNoFee(address(this), 0, address(this), 40_000 * 10**18);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 60_000 * 10**18);
            assertEq(farm.balanceOf(urn), 60_000 * 10**18);
        } else {
            assertEq(lssky.balanceOf(urn), 60_000 * 10**18);
        }
        assertEq(sky.balanceOf(address(this)), 40_000 * 10**18);
        if (withDelegate) {
            assertEq(sky.balanceOf(address(engine)), 0);
            assertEq(sky.balanceOf(voteDelegate), 60_000 * 10**18);
        } else {
            assertEq(sky.balanceOf(address(engine)), 60_000 * 10**18);
        }
        vm.expectEmit(true, true, true, true);
        emit FreeNoFee(address(this), 0, address(123), 10_000 * 10**18);
        engine.freeNoFee(address(this), 0, address(123), 10_000 * 10**18);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 50_000 * 10**18);
            assertEq(farm.balanceOf(urn), 50_000 * 10**18);
        } else {
            assertEq(lssky.balanceOf(urn), 50_000 * 10**18);
        }
        assertEq(sky.balanceOf(address(123)), 10_000 * 10**18);
        if (withDelegate) {
            assertEq(sky.balanceOf(address(engine)), 0);
            assertEq(sky.balanceOf(voteDelegate), 50_000 * 10**18);
        } else {
            assertEq(sky.balanceOf(address(engine)), 50_000 * 10**18);
        }
        assertEq(sky.totalSupply(), initialSkySupply);
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
        deal(address(sky), address(this), 100_000 * 10**18, true);
        address urn = engine.open(0);
        sky.approve(address(engine), 100_000 * 10**18);
        engine.lock(address(this), 0, 100_000 * 10**18, 5);
        assertEq(_art(ilk, urn), 0);
        vm.expectEmit(true, true, true, true);
        emit Draw(address(this), 0, address(this), 50 * 10**18);
        engine.draw(address(this), 0, address(this), 50 * 10**18);
        assertEq(_art(ilk, urn), 50 * 10**18);
        assertEq(_rate(ilk), 10**27);
        assertEq(usds.balanceOf(address(this)), 50 * 10**18);
        vm.warp(block.timestamp + 1);
        vm.expectEmit(true, true, true, true);
        emit Draw(address(this), 0, address(this), 50 * 10**18);
        engine.draw(address(this), 0, address(this), 50 * 10**18);
        uint256 art = _art(ilk, urn);
        uint256 expectedArt = 50 * 10**18 + _divup(50 * 10**18 * 100000000, 100000001);
        assertEq(art, expectedArt);
        uint256 rate = _rate(ilk);
        assertEq(rate, 100000001 * 10**27 / 100000000);
        assertEq(usds.balanceOf(address(this)), 100 * 10**18);
        assertGt(art * rate, 100.0000005 * 10**45);
        assertLt(art * rate, 100.0000006 * 10**45);
        vm.expectRevert("Usds/insufficient-balance");
        engine.wipe(address(this), 0, 100.0000006 * 10**18);
        address anyone = address(1221121);
        deal(address(usds), anyone, 100.0000006 * 10**18, true);
        assertEq(usds.balanceOf(anyone), 100.0000006 * 10**18);
        vm.prank(anyone); usds.approve(address(engine), 100.0000006 * 10**18);
        vm.expectRevert();
        vm.prank(anyone); engine.wipe(address(this), 0, 100.0000006 * 10**18); // It will try to wipe more art than existing, then reverts
        vm.expectEmit(true, true, true, true);
        emit Wipe(address(this), 0, 100.0000005 * 10**18);
        vm.prank(anyone); engine.wipe(address(this), 0, 100.0000005 * 10**18);
        assertEq(usds.balanceOf(anyone), 0.0000001 * 10**18);
        assertEq(_art(ilk, urn), 1); // Dust which is impossible to wipe via this regular function
        emit Wipe(address(this), 0, _divup(rate, RAY));
        vm.prank(anyone); assertEq(engine.wipeAll(address(this), 0), _divup(rate, RAY));
        assertEq(_art(ilk, urn), 0);
        assertEq(usds.balanceOf(anyone), 0.0000001 * 10**18 - _divup(rate, RAY));
        address other = address(123);
        assertEq(usds.balanceOf(other), 0);
        emit Draw(address(this), 0, other, 50 * 10**18);
        engine.draw(address(this), 0, other, 50 * 10**18);
        assertEq(usds.balanceOf(other), 50 * 10**18);
        // Check overflows
        stdstore.target(address(dss.vat)).sig("ilks(bytes32)").with_key(ilk).depth(1).checked_write(1);
        assertEq(_rate(ilk), 1);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.draw(address(this), 0, address(this), uint256(type(int256).max) / RAY + 1);
        stdstore.target(address(dss.vat)).sig("dai(address)").with_key(address(usdsJoin)).depth(0).checked_write(uint256(type(int256).max) + RAY);
        deal(address(usds), address(this), uint256(type(int256).max) / RAY + 1, true);
        usds.approve(address(engine), uint256(type(int256).max) / RAY + 1);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.wipe(address(this), 0, uint256(type(int256).max) / RAY + 1);
        stdstore.target(address(dss.vat)).sig("urns(bytes32,address)").with_key(ilk).with_key(urn).depth(1).checked_write(uint256(type(int256).max) + 1);
        assertEq(_art(ilk, urn), uint256(type(int256).max) + 1);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.wipeAll(address(this), 0);
    }

    function testOpenLockStakeMulticall() public {
        sky.approve(address(engine), 100_000 * 10**18);

        address urn = vm.computeCreateAddress(address(engine), vm.getNonce(address(engine)));

        assertEq(engine.ownerUrnsCount(address(this)), 0);
        assertEq(_ink(ilk, urn), 0);
        assertEq(farm.balanceOf(address(urn)), 0);
        assertEq(lssky.balanceOf(address(farm)), 0);

        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 0 , urn);
        vm.expectEmit(true, true, true, true);
        emit Lock(address(this), 0, 100_000 * 10**18, uint16(5));
        vm.expectEmit(true, true, true, true);
        emit SelectFarm(address(this), 0, address(farm), uint16(5));
        bytes[] memory callsToExecute = new bytes[](3);
        callsToExecute[0] = abi.encodeWithSignature("open(uint256)", 0);
        callsToExecute[1] = abi.encodeWithSignature("lock(address,uint256,uint256,uint16)", address(this), 0, 100_000 * 10**18, uint16(5));
        callsToExecute[2] = abi.encodeWithSignature("selectFarm(address,uint256,address,uint16)", address(this), 0, address(farm), uint16(5));
        engine.multicall(callsToExecute);

        assertEq(engine.ownerUrnsCount(address(this)), 1);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        assertEq(farm.balanceOf(address(urn)), 100_000 * 10**18);
        assertEq(lssky.balanceOf(address(farm)), 100_000 * 10**18);

        bytes[] memory revertExecute = new bytes[](1);
        revertExecute[0] = abi.encodeWithSignature("open(uint256)", 2);
        vm.expectRevert("LockstakeEngine/wrong-urn-index");
        engine.multicall(revertExecute);

        revertExecute[0] = abi.encodeWithSignature("onRemove(address,uint256,uint256)", urn, uint256(0), uint256(0));
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(pauseProxy); engine.multicall(revertExecute);
    }

    function testGetReward() public {
        address urn = engine.open(0);
        vm.expectRevert("LockstakeEngine/farm-unsupported");
        engine.getReward(address(this), 0, address(456), address(123));
        farm.setReward(address(urn), 20_000);
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(123)), 0);
        vm.expectEmit(true, true, true, true);
        emit GetReward(address(this), 0, address(farm), address(123), 20_000);
        assertEq(engine.getReward(address(this), 0, address(farm), address(123)), 20_000);
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(123)), 20_000);
        vm.prank(pauseProxy); engine.delFarm(address(farm));
        farm.setReward(address(urn), 30_000);
        assertEq(engine.getReward(address(this), 0, address(farm), address(123)), 30_000); // Can get reward after farm is deleted
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(123)), 50_000);
    }

    function _urnSetUp(bool withDelegate, bool withStaking) internal returns (address urn) {
        urn = engine.open(0);
        if (withDelegate) {
            engine.selectVoteDelegate(address(this), 0, voteDelegate);
        }
        if (withStaking) {
            engine.selectFarm(address(this), 0, address(farm), 0);
        }
        sky.approve(address(engine), 100_000 * 10**18);
        engine.lock(address(this), 0, 100_000 * 10**18, 5);
        engine.draw(address(this), 0, address(this), 2_000 * 10**18);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        assertEq(_art(ilk, urn), 2_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnVoteDelegates(urn), voteDelegate);
            assertEq(sky.balanceOf(voteDelegate), 100_000 * 10**18);
            assertEq(sky.balanceOf(address(engine)), 0);
        } else {
            assertEq(engine.urnVoteDelegates(urn), address(0));
            assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
        }
        if (withStaking) {
            assertEq(lssky.balanceOf(address(urn)), 0);
            assertEq(lssky.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(address(urn)), 100_000 * 10**18);
        } else {
            assertEq(lssky.balanceOf(address(urn)), 100_000 * 10**18);
        }
    }

    function _forceLiquidation(address urn) internal returns (uint256 id) {
        _setMedianPrice(0.05 * 10**18); // Force liquidation
        dss.spotter.poke(ilk);
        assertEq(clip.kicks(), 0);
        assertEq(engine.urnAuctions(urn), 0);
        (,, uint256 hole,) = dss.dog.ilks(ilk);
        uint256 kicked = hole < 2_000 * 10**45 ? 100_000 * 10**18 * hole / (2_000 * 10**45) : 100_000 * 10**18;
        vm.expectEmit(true, true, true, true);
        emit OnKick(urn, kicked);
        id = dss.dog.bark(ilk, address(urn), address(this));
        assertEq(clip.kicks(), 1);
        assertEq(engine.urnAuctions(urn), 1);
    }

    function _testOnKickFull(bool withDelegate, bool withStaking) internal {
        address urn = _urnSetUp(withDelegate, withStaking);
        uint256 lsskyInitialSupply = lssky.totalSupply();
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 2_000 * 10**45);
        assertEq(sale.lot, 100_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, uint256(pip.read()) * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnVoteDelegates(urn), address(0));
            assertEq(sky.balanceOf(voteDelegate), 0);
        }
        assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 0);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 100_000 * 10**18);
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
        address urn = _urnSetUp(withDelegate, withStaking);
        uint256 lsskyInitialSupply = lssky.totalSupply();
        vm.prank(pauseProxy); dss.dog.file(ilk, "hole", 500 * 10**45);
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 500 * 10**45);
        assertEq(sale.lot, 25_000 * 10**18);
        assertEq(sale.tot, 25_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, uint256(pip.read()) * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 75_000 * 10**18);
        assertEq(_art(ilk, urn), 1_500 * 10**18);
        assertEq(dss.vat.gem(ilk, address(clip)), 25_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnVoteDelegates(urn), address(0));
            assertEq(sky.balanceOf(voteDelegate), 0);
        }
        assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 75_000 * 10**18);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 25_000 * 10**18);
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
        address urn = _urnSetUp(withDelegate, withStaking);
        uint256 skyInitialSupply = sky.totalSupply();
        uint256 lsskyInitialSupply = lssky.totalSupply();
        address vow = address(dss.vow);
        uint256 vowInitialBalance = dss.vat.dai(vow);
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 2_000 * 10**45);
        assertEq(sale.lot, 100_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, uint256(pip.read()) * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(sky.balanceOf(voteDelegate), 0);
        }
        assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 0);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 100_000 * 10**18);

        address buyer = address(888);
        vm.prank(pauseProxy); dss.vat.suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); dss.vat.hope(address(clip));
        assertEq(sky.balanceOf(buyer), 0);
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 20_000 * 10**18);
        vm.prank(buyer); clip.take(id, 20_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(sky.balanceOf(buyer), 20_000 * 10**18);

        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, (2_000 - 20_000 * 0.05 * 1.25) * 10**45);
        assertEq(sale.lot, 80_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, uint256(pip.read()) * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 80_000 * 10**18);

        if (withDelegate) {
            assertEq(sky.balanceOf(voteDelegate), 0);
        }
        assertEq(sky.balanceOf(address(engine)), 80_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 0);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 100_000 * 10**18);

        uint256 burn = 32_000 * 10**18 * engine.fee() / (WAD - engine.fee());
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 12_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 32_000 * 10**18, burn, 100_000 * 10**18 - 32_000 * 10**18 - burn);
        vm.prank(buyer); clip.take(id, 12_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(burn, (32_000 * 10**18 + burn) * engine.fee() / WAD);
        assertEq(sky.balanceOf(buyer), 32_000 * 10**18);
        assertEq(engine.urnAuctions(urn), 0);

        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);

        assertEq(_ink(ilk, urn), 100_000 * 10**18 - 32_000 * 10**18 - burn);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 0);

        assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18 - 32_000 * 10**18 - burn);
        assertEq(sky.totalSupply(), skyInitialSupply - burn);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 100_000 * 10**18 - 32_000 * 10**18 - burn);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 32_000 * 10**18 - burn);
        assertEq(dss.vat.dai(vow), vowInitialBalance + 2_000 * 10**45);
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
        address urn = _urnSetUp(withDelegate, withStaking);
        uint256 skyInitialSupply = sky.totalSupply();
        uint256 lsskyInitialSupply = lssky.totalSupply();
        address vow = address(dss.vow);
        uint256 vowInitialBalance = dss.vat.dai(vow);
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 2_000 * 10**45);
        assertEq(sale.lot, 100_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, uint256(pip.read()) * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(sky.balanceOf(voteDelegate), 0);
        }
        assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 0);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 100_000 * 10**18);

        vm.warp(block.timestamp + 65); // Time passes to let the auction price to crash

        address buyer = address(888);
        vm.prank(pauseProxy); dss.vat.suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); dss.vat.hope(address(clip));
        assertEq(sky.balanceOf(buyer), 0);
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 91428571428571428571428);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 91428571428571428571428, 100_000 * 10**18 - 91428571428571428571428, 0);
        vm.prank(buyer); clip.take(id, 100_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(sky.balanceOf(buyer), 91428571428571428571428);
        assertEq(engine.urnAuctions(urn), 0);

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 0);

        if (withDelegate) {
            assertEq(sky.balanceOf(voteDelegate), 0);
        }
        assertEq(sky.balanceOf(address(engine)), 0);
        assertEq(sky.totalSupply(), skyInitialSupply - (100_000 * 10**18 - 91428571428571428571428)); // Can't burn 15% of 91428571428571428571428
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 0);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 100_000 * 10**18);
        assertEq(dss.vat.dai(vow), vowInitialBalance + 2_000 * 10**45);
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
        address urn = _urnSetUp(withDelegate, withStaking);
        uint256 skyInitialSupply = sky.totalSupply();
        uint256 lsskyInitialSupply = lssky.totalSupply();
        address vow = address(dss.vow);
        uint256 vowInitialBalance = dss.vat.dai(vow);
        uint256 id = _forceLiquidation(urn);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(id);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 2_000 * 10**45);
        assertEq(sale.lot, 100_000 * 10**18);
        assertEq(sale.tot, 100_000 * 10**18);
        assertEq(sale.usr, address(urn));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, uint256(pip.read()) * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(sky.balanceOf(voteDelegate), 0);
        }
        assertEq(sky.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 0);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 100_000 * 10**18);

        vm.warp(block.timestamp + 80); // Time passes to let the auction price to crash

        address buyer = address(888);
        vm.prank(pauseProxy); dss.vat.suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); dss.vat.hope(address(clip));
        assertEq(sky.balanceOf(buyer), 0);
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 100_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 100_000 * 10**18, 0, 0);
        vm.prank(buyer); clip.take(id, 100_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(sky.balanceOf(buyer), 100_000 * 10**18);
        assertEq(engine.urnAuctions(urn), 0);

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 0);

        if (withDelegate) {
            assertEq(sky.balanceOf(voteDelegate), 0);
        }
        assertEq(sky.balanceOf(address(engine)), 0);
        assertEq(sky.totalSupply(), skyInitialSupply); // Can't burn anything
        if (withStaking) {
            assertEq(lssky.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lssky.balanceOf(address(urn)), 0);
        assertEq(lssky.totalSupply(), lsskyInitialSupply - 100_000 * 10**18);
        assertLt(dss.vat.dai(vow), vowInitialBalance + 2_000 * 10**45); // Doesn't recover full debt
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
        address urn = _urnSetUp(true, true);

        assertEq(engine.urnVoteDelegates(urn), voteDelegate);
        assertEq(engine.urnFarms(urn), address(farm));

        vm.prank(pauseProxy); dss.dog.file(ilk, "hole", 500 * 10**45);
        uint256 id1 = _forceLiquidation(urn);

        assertEq(engine.urnVoteDelegates(urn), address(0));
        assertEq(engine.urnFarms(urn), address(0));

        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectVoteDelegate(address(this), 0, voteDelegate);
        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectFarm(address(this), 0, address(farm), 0);

        vm.prank(pauseProxy); dss.dog.file(ilk, "hole", 1000 * 10**45);
        uint256 id2 = dss.dog.bark(ilk, urn, address(this));

        assertEq(engine.urnAuctions(urn), 2);

        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectVoteDelegate(address(this), 0, voteDelegate);
        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectFarm(address(this), 0, address(farm), 0);

        // Take with left > 0
        address buyer = address(888);
        vm.prank(pauseProxy); dss.vat.suck(address(0), buyer, 4_000 * 10**45);
        vm.prank(buyer); dss.vat.hope(address(clip));
        uint256 burn = 8_000 * 10**18 * engine.fee() / (WAD - engine.fee());
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 8_000 * 10**18); // 500 / (0.05 * 1.25 )
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 8_000 * 10**18, burn, 25_000 * 10**18 - 8_000 * 10**18 - burn);
        vm.prank(buyer); clip.take(id1, 25_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(engine.urnAuctions(urn), 1);

        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectVoteDelegate(address(this), 0, voteDelegate);
        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectFarm(address(this), 0, address(farm), 0);

        vm.warp(block.timestamp + 80); // Time passes to let the auction price to crash

        // Take with left == 0
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 25_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 25_000 * 10**18, 0, 0);
        vm.prank(buyer); clip.take(id2, 25_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(engine.urnAuctions(urn), 0);

        // Can select voteDelegate and farm again
        engine.selectVoteDelegate(address(this), 0, voteDelegate);
        engine.selectFarm(address(this), 0, address(farm), 0);
    }

    function testUrnUnsafe() public {
        address urn = _urnSetUp(true, true);

        assertEq(engine.urnVoteDelegates(urn), voteDelegate);

        address voteDelegate2 = voteDelegateFactory.create();

        _setMedianPrice(0.05 * 10**18); // Force urn unsafe
        dss.spotter.poke(ilk);

        vm.expectRevert("LockstakeEngine/urn-unsafe");
        engine.selectVoteDelegate(address(this), 0, voteDelegate2);

        engine.selectVoteDelegate(address(this), 0, address(0));

        vm.expectRevert("LockstakeEngine/urn-unsafe");
        engine.selectVoteDelegate(address(this), 0, voteDelegate2);

        _setMedianPrice(1_500 * 10**18); // Back to safety
        dss.spotter.poke(ilk);

        engine.selectVoteDelegate(address(this), 0, voteDelegate2);

        assertEq(engine.urnVoteDelegates(urn), voteDelegate2);
    }

    function testOnRemoveOverflow() public {
        vm.expectRevert("LockstakeEngine/overflow");
        vm.prank(pauseProxy); engine.onRemove(address(1), 0, uint256(type(int256).max) + 1);
    }

    function _testYank(bool withDelegate, bool withStaking) internal {
        address urn = _urnSetUp(withDelegate, withStaking);
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
