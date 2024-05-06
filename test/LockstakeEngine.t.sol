// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";
import "dss-interfaces/Interfaces.sol";
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit, LockstakeConfig, LockstakeInstance } from "deploy/LockstakeInit.sol";
import { LockstakeMkr } from "src/LockstakeMkr.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { LockstakeUrn } from "src/LockstakeUrn.sol";
import { VoteDelegateFactoryMock, VoteDelegateMock } from "test/mocks/VoteDelegateFactoryMock.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import { NstMock } from "test/mocks/NstMock.sol";
import { NstJoinMock } from "test/mocks/NstJoinMock.sol";
import { StakingRewardsMock } from "test/mocks/StakingRewardsMock.sol";
import { MkrNgtMock } from "test/mocks/MkrNgtMock.sol";

interface CalcFabLike {
    function newLinearDecrease(address) external returns (address);
}

interface LineMomLike {
    function ilks(bytes32) external view returns (uint256);
}

contract LockstakeEngineTest is DssTest {
    using stdStorage for StdStorage;

    DssInstance             dss;
    address                 pauseProxy;
    GemMock                 mkr;
    LockstakeMkr            lsmkr;
    LockstakeEngine         engine;
    LockstakeClipper        clip;
    address                 calc;
    MedianAbstract          pip;
    VoteDelegateFactoryMock voteDelegateFactory;
    NstMock                 nst;
    NstJoinMock             nstJoin;
    GemMock                 rTok;
    StakingRewardsMock      farm;
    MkrNgtMock              mkrNgt;
    GemMock                 ngt;
    bytes32                 ilk = "LSE";
    address                 voter;
    address                 voteDelegate;

    LockstakeConfig     cfg;

    uint256             prevLine;
    
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    event AddFarm(address farm);
    event DelFarm(address farm);
    event Open(address indexed owner, uint256 indexed index, address urn);
    event Hope(address indexed urn, address indexed usr);
    event Nope(address indexed urn, address indexed usr);
    event SelectVoteDelegate(address indexed urn, address indexed voteDelegate_);
    event SelectFarm(address indexed urn, address farm, uint16 ref);
    event Lock(address indexed urn, uint256 wad, uint16 ref);
    event LockNgt(address indexed urn, uint256 ngtWad, uint16 ref);
    event Free(address indexed urn, address indexed to, uint256 wad, uint256 freed);
    event FreeNgt(address indexed urn, address indexed to, uint256 ngtWad, uint256 ngtFreed);
    event FreeNoFee(address indexed urn, address indexed to, uint256 wad);
    event Draw(address indexed urn, address indexed to, uint256 wad);
    event Wipe(address indexed urn, uint256 wad);
    event GetReward(address indexed urn, address indexed farm, address indexed to, uint256 amt);
    event OnKick(address indexed urn, uint256 wad);
    event OnTake(address indexed urn, address indexed who, uint256 wad);
    event OnRemove(address indexed urn, uint256 sold, uint256 burn, uint256 refund);

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // Note: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dss = MCD.loadFromChainlog(LOG);

        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        pip = MedianAbstract(dss.chainlog.getAddress("PIP_MKR"));
        mkr = new GemMock(0);
        nst = new NstMock();
        nstJoin = new NstJoinMock(address(dss.vat), address(nst));
        rTok = new GemMock(0);
        ngt = new GemMock(0);
        mkrNgt = new MkrNgtMock(address(mkr), address(ngt), 24_000);

        voteDelegateFactory = new VoteDelegateFactoryMock(address(mkr));
        voter = address(123);
        vm.prank(voter); voteDelegate = voteDelegateFactory.create();

        vm.prank(pauseProxy); pip.kiss(address(this));
        vm.store(address(pip), bytes32(uint256(1)), bytes32(uint256(1_500 * 10**18)));

        LockstakeInstance memory instance = LockstakeDeploy.deployLockstake(
            address(this),
            pauseProxy,
            address(voteDelegateFactory),
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
        farm = new StakingRewardsMock(address(rTok), address(lsmkr));

        address[] memory farms = new address[](2);
        farms[0] = address(farm);
        farms[1] = address(1111111); // Just to test that more than 1 farm is correctly whitelisted

        cfg = LockstakeConfig({
            ilk: ilk,
            voteDelegateFactory: address(voteDelegateFactory),
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

        prevLine = dss.vat.Line();

        vm.startPrank(pauseProxy);
        LockstakeInit.initLockstake(dss, instance, cfg);
        vm.stopPrank();

        deal(address(mkr), address(this), 100_000 * 10**18, true);
        deal(address(ngt), address(this), 100_000 * 24_000 * 10**18, true);

        // Add some existing DAI assigned to nstJoin to avoid a particular error
        stdstore.target(address(dss.vat)).sig("dai(address)").with_key(address(nstJoin)).depth(0).checked_write(100_000 * RAD);
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
        assertEq(address(engine.vat()), address(dss.vat));
        assertEq(address(engine.nstJoin()), address(nstJoin));
        assertEq(address(engine.nst()), address(nst));
        assertEq(engine.ilk(), ilk);
        assertEq(address(engine.mkr()), address(mkr));
        assertEq(engine.fee(), 15 * WAD / 100);
        assertEq(address(engine.mkrNgt()), address(mkrNgt));
        assertEq(address(engine.ngt()), address(ngt));
        assertEq(engine.mkrNgtRate(), 24_000);
        assertEq(LockstakeUrn(engine.urnImplementation()).engine(), address(engine));
        assertEq(address(LockstakeUrn(engine.urnImplementation()).vat()), address(dss.vat));
        assertEq(address(LockstakeUrn(engine.urnImplementation()).lsmkr()), address(lsmkr));

        assertEq(clip.ilk(), ilk);
        assertEq(address(clip.vat()), address(dss.vat));
        assertEq(address(clip.engine()), address(engine));

        assertEq(_rate(ilk), 10**27);
        assertEq(dss.vat.Line(), prevLine + 1_000_000 * 10**45);
        assertEq(_line(ilk), 1_000_000 * 10**45);
        assertEq(_dust(ilk), 50);
        assertEq(dss.vat.wards(address(engine)), 1);
        assertEq(dss.vat.wards(address(clip)), 1);
        (uint256 maxline, uint256 gap, uint256 ttl,,) = DssAutoLineAbstract(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE")).ilks(ilk);
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
        assertTrue(engine.farms(address(1111111)) == LockstakeEngine.FarmStatus.ACTIVE);
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
        assertEq(symbol, "LMKR");
        assertEq(class, 7);
        assertEq(gem, address(mkr));
        assertEq(dec, 18);
        assertEq(pipV, address(pip));
        assertEq(join, address(0));
        assertEq(xlip, address(clip));

        assertEq(dss.chainlog.getAddress("LOCKSTAKE_MKR"),       address(lsmkr));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_ENGINE"),    address(engine));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP"),      address(clip));
        assertEq(dss.chainlog.getAddress("LOCKSTAKE_CLIP_CALC"), address(calc));

        LockstakeInstance memory instance2 = LockstakeDeploy.deployLockstake(
            address(this),
            pauseProxy,
            address(voteDelegateFactory),
            address(nstJoin),
            "eee",
            15 * WAD / 100,
            address(mkrNgt),
            bytes4(abi.encodeWithSignature("newStairstepExponentialDecrease(address)"))
        );
        cfg.ilk = "eee";
        cfg.tau = 0;
        cfg.cut = 10**27;
        cfg.step = 1;
        vm.startPrank(pauseProxy);
        LockstakeInit.initLockstake(dss, instance2, cfg);
        vm.stopPrank();
        assertEq(StairstepExponentialDecreaseAbstract(instance2.clipperCalc).cut(), 10**27);
        assertEq(StairstepExponentialDecreaseAbstract(instance2.clipperCalc).step(), 1);
    }

    function testConstructor() public {
        address lsmkr2 = address(new GemMock(0));
        vm.expectRevert("LockstakeEngine/fee-equal-or-greater-wad");
        new LockstakeEngine(address(voteDelegateFactory), address(nstJoin), "aaa", address(mkrNgt), lsmkr2, WAD);
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        LockstakeEngine e = new LockstakeEngine(address(voteDelegateFactory), address(nstJoin), "aaa", address(mkrNgt), lsmkr2, 100);
        assertEq(address(e.voteDelegateFactory()), address(voteDelegateFactory));
        assertEq(address(e.nstJoin()), address(nstJoin));
        assertEq(address(e.vat()), address(dss.vat));
        assertEq(address(e.nst()), address(nst));
        assertEq(e.ilk(), "aaa");
        assertEq(address(e.mkr()), address(mkr));
        assertEq(address(e.lsmkr()), lsmkr2);
        assertEq(e.fee(), 100);
        assertEq(address(e.mkrNgt()), address(mkrNgt));
        assertEq(address(e.ngt()), address(ngt));
        assertEq(e.mkrNgtRate(), 24_000);
        assertEq(LockstakeUrn(e.urnImplementation()).engine(), address(e));
        assertEq(address(LockstakeUrn(e.urnImplementation()).vat()), address(dss.vat));
        assertEq(address(LockstakeUrn(e.urnImplementation()).lsmkr()), lsmkr2);
        assertEq(dss.vat.can(address(e), address(nstJoin)), 1);
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

        bytes4[] memory urnOwnersMethods = new bytes4[](8);
        urnOwnersMethods[0] = engine.hope.selector;
        urnOwnersMethods[1] = engine.nope.selector;
        urnOwnersMethods[2] = engine.selectVoteDelegate.selector;
        urnOwnersMethods[3] = engine.selectFarm.selector;
        urnOwnersMethods[4] = engine.free.selector;
        urnOwnersMethods[5] = engine.freeNgt.selector;
        urnOwnersMethods[6] = engine.draw.selector;
        urnOwnersMethods[7] = engine.getReward.selector;

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
        assertEq(engine.usrAmts(address(this)), 0);
        address urn = engine.getUrn(address(this), 0);
        vm.expectRevert("LockstakeEngine/wrong-urn-index");
        engine.open(1);

        assertEq(dss.vat.can(urn, address(engine)), 0);
        assertEq(lsmkr.allowance(urn, address(engine)), 0);
        vm.expectEmit(true, true, true, true);
        emit Open(address(this), 0, urn);
        assertEq(engine.open(0), urn);
        assertEq(engine.usrAmts(address(this)), 1);
        assertEq(dss.vat.can(urn, address(engine)), 1);
        assertEq(lsmkr.allowance(urn, address(engine)), type(uint256).max);
        assertEq(LockstakeUrn(urn).engine(), address(engine));
        assertEq(address(LockstakeUrn(urn).lsmkr()), address(lsmkr));
        assertEq(address(LockstakeUrn(urn).vat()), address(dss.vat));
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
        engine.selectVoteDelegate(urn, voteDelegate);
        assertEq(engine.urnVoteDelegates(urn), voteDelegate);
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

    function testSelectVoteDelegate() public {
        address urn = engine.open(0);
        vm.expectRevert("LockstakeEngine/not-valid-vote-delegate");
        engine.selectVoteDelegate(urn, address(111));
        vm.expectEmit(true, true, true, true);
        emit SelectVoteDelegate(urn, voteDelegate);
        engine.selectVoteDelegate(urn, voteDelegate);
        vm.expectRevert("LockstakeEngine/same-vote-delegate");
        engine.selectVoteDelegate(urn, voteDelegate);
        assertEq(engine.urnVoteDelegates(urn), voteDelegate);
        vm.prank(address(888)); address voteDelegate2 = voteDelegateFactory.create();
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(VoteDelegateMock(voteDelegate).stake(address(engine)), 100_000 * 10**18);
        assertEq(VoteDelegateMock(voteDelegate2).stake(address(engine)), 0);
        assertEq(mkr.balanceOf(voteDelegate), 100_000 * 10**18);
        assertEq(mkr.balanceOf(voteDelegate2), 0);
        assertEq(mkr.balanceOf(address(engine)), 0);
        vm.expectEmit(true, true, true, true);
        emit SelectVoteDelegate(urn, voteDelegate2);
        engine.selectVoteDelegate(urn, voteDelegate2);
        assertEq(engine.urnVoteDelegates(urn), voteDelegate2);
        assertEq(VoteDelegateMock(voteDelegate).stake(address(engine)), 0);
        assertEq(VoteDelegateMock(voteDelegate2).stake(address(engine)), 100_000 * 10**18);
        assertEq(mkr.balanceOf(voteDelegate), 0);
        assertEq(mkr.balanceOf(voteDelegate2), 100_000 * 10**18);
        assertEq(mkr.balanceOf(address(engine)), 0);
        engine.selectVoteDelegate(urn, address(0));
        assertEq(engine.urnVoteDelegates(urn), address(0));
        assertEq(VoteDelegateMock(voteDelegate).stake(address(engine)), 0);
        assertEq(VoteDelegateMock(voteDelegate2).stake(address(engine)), 0);
        assertEq(mkr.balanceOf(voteDelegate), 0);
        assertEq(mkr.balanceOf(voteDelegate2), 0);
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
    }

    function testSelectFarm() public {
        StakingRewardsMock farm2 = new StakingRewardsMock(address(rTok), address(lsmkr));
        address urn = engine.open(0);
        assertEq(engine.urnFarms(urn), address(0));
        vm.expectRevert("LockstakeEngine/farm-unsupported-or-deleted");
        engine.selectFarm(urn, address(farm2), 5);
        vm.prank(pauseProxy); engine.addFarm(address(farm2));
        vm.expectEmit(true, true, true, true);
        emit SelectFarm(urn, address(farm2), 5);
        engine.selectFarm(urn, address(farm2), 5);
        assertEq(engine.urnFarms(urn), address(farm2));
        vm.expectRevert("LockstakeEngine/same-farm");
        engine.selectFarm(urn, address(farm2), 5);
        assertEq(lsmkr.balanceOf(address(farm)), 0);
        assertEq(lsmkr.balanceOf(address(farm2)), 0);
        mkr.approve(address(engine), 100_000 * 10**18);
        engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(lsmkr.balanceOf(address(farm)),  0);
        assertEq(lsmkr.balanceOf(address(farm2)), 100_000 * 10**18);
        assertEq(farm.balanceOf(urn),  0);
        assertEq(farm2.balanceOf(urn), 100_000 * 10**18);
        engine.selectFarm(urn, address(farm), 5);
        assertEq(lsmkr.balanceOf(address(farm)),  100_000 * 10**18);
        assertEq(lsmkr.balanceOf(address(farm2)), 0);
        assertEq(farm.balanceOf(urn),  100_000 * 10**18);
        assertEq(farm2.balanceOf(urn), 0);
        vm.prank(pauseProxy); engine.delFarm(address(farm2));
        vm.expectRevert("LockstakeEngine/farm-unsupported-or-deleted");
        engine.selectFarm(urn, address(farm2), 5);
    }

    function _testLockFree(bool withDelegate, bool withStaking) internal {
        uint256 initialMkrSupply = mkr.totalSupply();
        address urn = engine.open(0);
        deal(address(mkr), address(this), uint256(type(int256).max) + 1); // deal mkr to allow reaching the overflow revert
        mkr.approve(address(engine), uint256(type(int256).max) + 1);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.lock(urn, uint256(type(int256).max) + 1, 5);
        deal(address(mkr), address(this), 100_000 * 10**18); // back to normal mkr balance and allowance
        mkr.approve(address(engine), 100_000 * 10**18);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.free(urn, address(this), uint256(type(int256).max) + 1);
        if (withDelegate) {
            engine.selectVoteDelegate(urn, voteDelegate);
        }
        if (withStaking) {
            engine.selectFarm(urn, address(farm), 0);
        }
        assertEq(_ink(ilk, urn), 0);
        assertEq(lsmkr.balanceOf(urn), 0);
        mkr.transfer(address(123), 100_000 * 10**18);
        vm.prank(address(123)); mkr.approve(address(engine), 100_000 * 10**18);
        vm.expectRevert("LockstakeEngine/invalid-urn");
        vm.prank(address(123)); engine.lock(address(456), 100_000 * 10**18, 5);
        vm.expectEmit(true, true, true, true);
        emit Lock(urn, 100_000 * 10**18, 5);
        vm.prank(address(123)); engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(urn), 100_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 100_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(this)), 0);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 100_000 * 10**18); // Remains in voteDelegate as it is a mock (otherwise it would be in the Chief)
        } else {
            assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        }
        assertEq(mkr.totalSupply(), initialMkrSupply);
        vm.expectEmit(true, true, true, true);
        emit Free(urn, address(this), 40_000 * 10**18, 40_000 * 10**18 * 85 / 100);
        assertEq(engine.free(urn, address(this), 40_000 * 10**18), 40_000 * 10**18 * 85 / 100);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 60_000 * 10**18);
            assertEq(farm.balanceOf(urn), 60_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 60_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(this)), 40_000 * 10**18 - 40_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 60_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 60_000 * 10**18);
        }
        vm.expectEmit(true, true, true, true);
        emit Free(urn, address(123), 10_000 * 10**18, 10_000 * 10**18 * 85 / 100);
        assertEq(engine.free(urn, address(123), 10_000 * 10**18), 10_000 * 10**18 * 85 / 100);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 50_000 * 10**18);
            assertEq(farm.balanceOf(urn), 50_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 50_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(123)), 10_000 * 10**18 - 10_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 50_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 50_000 * 10**18);
        }
        assertEq(mkr.totalSupply(), initialMkrSupply - 50_000 * 10**18 * 15 / 100);
        if (withStaking) {
            mkr.approve(address(engine), 1);
            vm.prank(pauseProxy); engine.delFarm(address(farm));
            vm.expectRevert("LockstakeEngine/farm-deleted");
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
        // Note: overflow cannot be reached for lockNgt and freeNgt as with these functions and the value of rate (>=3) the MKR amount will be always lower
        if (withDelegate) {
            engine.selectVoteDelegate(urn, voteDelegate);
        }
        if (withStaking) {
            engine.selectFarm(urn, address(farm), 0);
        }
        assertEq(_ink(ilk, urn), 0);
        assertEq(lsmkr.balanceOf(urn), 0);
        ngt.approve(address(engine), 100_000 * 24_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit LockNgt(urn, 100_000 * 24_000 * 10**18, 5);
        engine.lockNgt(urn, 100_000 * 24_000 * 10**18, 5);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(urn), 100_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 100_000 * 10**18);
        }
        assertEq(ngt.balanceOf(address(this)), 0);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 100_000 * 10**18); // Remains in voteDelegate as it is a mock (otherwise it would be in the Chief)
        } else {
            assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        }
        assertEq(ngt.totalSupply(), initialNgtSupply - 100_000 * 24_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit FreeNgt(urn, address(this), 40_000 * 24_000 * 10**18, 40_000 * 24_000 * 10**18 * 85 / 100);
        assertEq(engine.freeNgt(urn, address(this), 40_000 * 24_000 * 10**18), 40_000 * 24_000 * 10**18 * 85 / 100);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 60_000 * 10**18);
            assertEq(farm.balanceOf(urn), 60_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 60_000 * 10**18);
        }
        assertEq(ngt.balanceOf(address(this)), 40_000 * 24_000 * 10**18 - 40_000 * 24_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 60_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 60_000 * 10**18);
        }
        vm.expectEmit(true, true, true, true);
        emit FreeNgt(urn, address(123), 10_000 * 24_000 * 10**18, 10_000 * 24_000 * 10**18 * 85 / 100);
        assertEq(engine.freeNgt(urn, address(123), 10_000 * 24_000 * 10**18), 10_000 * 24_000 * 10**18 * 85 / 100);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 50_000 * 10**18);
            assertEq(farm.balanceOf(urn), 50_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 50_000 * 10**18);
        }
        assertEq(ngt.balanceOf(address(123)), 10_000 * 24_000 * 10**18 - 10_000 * 24_000 * 10**18 * 15 / 100);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 50_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 50_000 * 10**18);
        }
        assertEq(ngt.totalSupply(), initialNgtSupply - (100_000 - 50_000) * 24_000 * 10**18 - 50_000 * 24_000 * 10**18 * 15 / 100);
        if (withStaking) {
            ngt.approve(address(engine), 24_000);
            vm.prank(pauseProxy); engine.delFarm(address(farm));
            vm.expectRevert("LockstakeEngine/farm-deleted");
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
        vm.expectRevert("LockstakeEngine/overflow");
        engine.freeNoFee(urn, address(this), uint256(type(int256).max) + 1);
        if (withDelegate) {
            engine.selectVoteDelegate(urn, voteDelegate);
        }
        if (withStaking) {
            engine.selectFarm(urn, address(farm), 0);
        }
        engine.lock(urn, 100_000 * 10**18, 5);
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(urn), 100_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 100_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(this)), 0);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 100_000 * 10**18); // Remains in voteDelegate as it is a mock (otherwise it would be in the Chief)
        } else {
            assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        }
        assertEq(mkr.totalSupply(), initialMkrSupply);
        vm.expectEmit(true, true, true, true);
        emit FreeNoFee(urn, address(this), 40_000 * 10**18);
        engine.freeNoFee(urn, address(this), 40_000 * 10**18);
        assertEq(_ink(ilk, urn), 60_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 60_000 * 10**18);
            assertEq(farm.balanceOf(urn), 60_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 60_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(this)), 40_000 * 10**18);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 60_000 * 10**18);
        } else {
            assertEq(mkr.balanceOf(address(engine)), 60_000 * 10**18);
        }
        vm.expectEmit(true, true, true, true);
        emit FreeNoFee(urn, address(123), 10_000 * 10**18);
        engine.freeNoFee(urn, address(123), 10_000 * 10**18);
        assertEq(_ink(ilk, urn), 50_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 50_000 * 10**18);
            assertEq(farm.balanceOf(urn), 50_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(urn), 50_000 * 10**18);
        }
        assertEq(mkr.balanceOf(address(123)), 10_000 * 10**18);
        if (withDelegate) {
            assertEq(mkr.balanceOf(address(engine)), 0);
            assertEq(mkr.balanceOf(voteDelegate), 50_000 * 10**18);
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
        uint256 expectedArt = 50 * 10**18 + _divup(50 * 10**18 * 100000000, 100000001);
        assertEq(art, expectedArt);
        uint256 rate = _rate(ilk);
        assertEq(rate, 100000001 * 10**27 / 100000000);
        assertEq(nst.balanceOf(address(this)), 100 * 10**18);
        assertGt(art * rate, 100.0000005 * 10**45);
        assertLt(art * rate, 100.0000006 * 10**45);
        vm.expectRevert("Nst/insufficient-balance");
        engine.wipe(urn, 100.0000006 * 10**18);
        address anyone = address(1221121);
        deal(address(nst), anyone, 100.0000006 * 10**18, true);
        assertEq(nst.balanceOf(anyone), 100.0000006 * 10**18);
        vm.prank(anyone); nst.approve(address(engine), 100.0000006 * 10**18);
        vm.expectRevert();
        vm.prank(anyone); engine.wipe(urn, 100.0000006 * 10**18); // It will try to wipe more art than existing, then reverts
        vm.expectEmit(true, true, true, true);
        emit Wipe(urn, 100.0000005 * 10**18);
        vm.prank(anyone); engine.wipe(urn, 100.0000005 * 10**18);
        assertEq(nst.balanceOf(anyone), 0.0000001 * 10**18);
        assertEq(_art(ilk, urn), 1); // Dust which is impossible to wipe via this regular function
        emit Wipe(urn, _divup(rate, RAY));
        vm.prank(anyone); assertEq(engine.wipeAll(urn), _divup(rate, RAY));
        assertEq(_art(ilk, urn), 0);
        assertEq(nst.balanceOf(anyone), 0.0000001 * 10**18 - _divup(rate, RAY));
        address other = address(123);
        assertEq(nst.balanceOf(other), 0);
        emit Draw(urn, other, 50 * 10**18);
        engine.draw(urn, other, 50 * 10**18);
        assertEq(nst.balanceOf(other), 50 * 10**18);
        // Check overflows
        stdstore.target(address(dss.vat)).sig("ilks(bytes32)").with_key(ilk).depth(1).checked_write(1);
        assertEq(_rate(ilk), 1);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.draw(urn, address(this), uint256(type(int256).max) / RAY + 1);
        stdstore.target(address(dss.vat)).sig("dai(address)").with_key(address(nstJoin)).depth(0).checked_write(uint256(type(int256).max) + RAY);
        deal(address(nst), address(this), uint256(type(int256).max) / RAY + 1, true);
        nst.approve(address(engine), uint256(type(int256).max) / RAY + 1);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.wipe(urn, uint256(type(int256).max) / RAY + 1);
        stdstore.target(address(dss.vat)).sig("urns(bytes32,address)").with_key(ilk).with_key(urn).depth(1).checked_write(uint256(type(int256).max) + 1);
        assertEq(_art(ilk, urn), uint256(type(int256).max) + 1);
        vm.expectRevert("LockstakeEngine/overflow");
        engine.wipeAll(urn);
    }

    function testOpenLockStakeMulticall() public {
        mkr.approve(address(engine), 100_000 * 10**18);

        address urn = engine.getUrn(address(this), 0);

        assertEq(engine.usrAmts(address(this)), 0);
        assertEq(_ink(ilk, urn), 0);
        assertEq(farm.balanceOf(address(urn)), 0);
        assertEq(lsmkr.balanceOf(address(farm)), 0);

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
        assertEq(lsmkr.balanceOf(address(farm)), 100_000 * 10**18);
    }

    function testGetReward() public {
        address urn = engine.open(0);
        vm.expectRevert("LockstakeEngine/farm-unsupported");
        engine.getReward(urn, address(456), address(123));
        farm.setReward(address(urn), 20_000);
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(123)), 0);
        vm.expectEmit(true, true, true, true);
        emit GetReward(urn, address(farm), address(123), 20_000);
        assertEq(engine.getReward(urn, address(farm), address(123)), 20_000);
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(123)), 20_000);
        vm.prank(pauseProxy); engine.delFarm(address(farm));
        farm.setReward(address(urn), 30_000);
        assertEq(engine.getReward(urn, address(farm), address(123)), 30_000); // Can get reward after farm is deleted
        assertEq(GemMock(address(farm.rewardsToken())).balanceOf(address(123)), 50_000);
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
        assertEq(_ink(ilk, urn), 100_000 * 10**18);
        assertEq(_art(ilk, urn), 2_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnVoteDelegates(urn), voteDelegate);
            assertEq(mkr.balanceOf(voteDelegate), 100_000 * 10**18);
            assertEq(mkr.balanceOf(address(engine)), 0);
        } else {
            assertEq(engine.urnVoteDelegates(urn), address(0));
            assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        }
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(urn)), 0);
            assertEq(lsmkr.balanceOf(address(farm)), 100_000 * 10**18);
            assertEq(farm.balanceOf(address(urn)), 100_000 * 10**18);
        } else {
            assertEq(lsmkr.balanceOf(address(urn)), 100_000 * 10**18);
        }
    }

    function _forceLiquidation(address urn) internal returns (uint256 id) {
        vm.store(address(pip), bytes32(uint256(1)), bytes32(uint256(0.05 * 10**18))); // Force liquidation
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
        uint256 lsmkrInitialSupply = lsmkr.totalSupply();
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
        assertEq(dss.vat.gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnVoteDelegates(urn), address(0));
            assertEq(mkr.balanceOf(voteDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 0);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 100_000 * 10**18);
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
        uint256 lsmkrInitialSupply = lsmkr.totalSupply();
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
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 75_000 * 10**18);
        assertEq(_art(ilk, urn), 1_500 * 10**18);
        assertEq(dss.vat.gem(ilk, address(clip)), 25_000 * 10**18);

        if (withDelegate) {
            assertEq(engine.urnVoteDelegates(urn), address(0));
            assertEq(mkr.balanceOf(voteDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 75_000 * 10**18);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 25_000 * 10**18);
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
        uint256 mkrInitialSupply = mkr.totalSupply();
        uint256 lsmkrInitialSupply = lsmkr.totalSupply();
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
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voteDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 0);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 100_000 * 10**18);

        address buyer = address(888);
        vm.prank(pauseProxy); dss.vat.suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); dss.vat.hope(address(clip));
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
        assertEq(dss.vat.gem(ilk, address(clip)), 80_000 * 10**18);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voteDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 80_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 0);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 100_000 * 10**18);

        uint256 burn = 32_000 * 10**18 * engine.fee() / (WAD - engine.fee());
        vm.expectEmit(true, true, true, true);
        emit OnTake(urn, buyer, 12_000 * 10**18);
        vm.expectEmit(true, true, true, true);
        emit OnRemove(urn, 32_000 * 10**18, burn, 100_000 * 10**18 - 32_000 * 10**18 - burn);
        vm.prank(buyer); clip.take(id, 12_000 * 10**18, type(uint256).max, buyer, "");
        assertEq(burn, (32_000 * 10**18 + burn) * engine.fee() / WAD);
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

        assertEq(_ink(ilk, urn), 100_000 * 10**18 - 32_000 * 10**18 - burn);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 0);

        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18 - 32_000 * 10**18 - burn);
        assertEq(mkr.totalSupply(), mkrInitialSupply - burn);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 100_000 * 10**18 - 32_000 * 10**18 - burn);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 32_000 * 10**18 - burn);
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
        uint256 mkrInitialSupply = mkr.totalSupply();
        uint256 lsmkrInitialSupply = lsmkr.totalSupply();
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
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voteDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 0);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 100_000 * 10**18);

        vm.warp(block.timestamp + 65); // Time passes to let the auction price to crash

        address buyer = address(888);
        vm.prank(pauseProxy); dss.vat.suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); dss.vat.hope(address(clip));
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
        assertEq(dss.vat.gem(ilk, address(clip)), 0);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voteDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 0);
        assertEq(mkr.totalSupply(), mkrInitialSupply - (100_000 * 10**18 - 91428571428571428571428)); // Can't burn 15% of 91428571428571428571428
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 0);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 100_000 * 10**18);
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
        uint256 mkrInitialSupply = mkr.totalSupply();
        uint256 lsmkrInitialSupply = lsmkr.totalSupply();
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
        assertEq(sale.top, pip.read() * (1.25 * 10**9));

        assertEq(_ink(ilk, urn), 0);
        assertEq(_art(ilk, urn), 0);
        assertEq(dss.vat.gem(ilk, address(clip)), 100_000 * 10**18);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voteDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 100_000 * 10**18);
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 0);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 100_000 * 10**18);

        vm.warp(block.timestamp + 80); // Time passes to let the auction price to crash

        address buyer = address(888);
        vm.prank(pauseProxy); dss.vat.suck(address(0), buyer, 2_000 * 10**45);
        vm.prank(buyer); dss.vat.hope(address(clip));
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
        assertEq(dss.vat.gem(ilk, address(clip)), 0);

        if (withDelegate) {
            assertEq(mkr.balanceOf(voteDelegate), 0);
        }
        assertEq(mkr.balanceOf(address(engine)), 0);
        assertEq(mkr.totalSupply(), mkrInitialSupply); // Can't burn anything
        if (withStaking) {
            assertEq(lsmkr.balanceOf(address(farm)), 0);
            assertEq(farm.balanceOf(address(urn)), 0);
        }
        assertEq(lsmkr.balanceOf(address(urn)), 0);
        assertEq(lsmkr.totalSupply(), lsmkrInitialSupply - 100_000 * 10**18);
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
        engine.selectVoteDelegate(urn, voteDelegate);
        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectFarm(urn, address(farm), 0);

        vm.prank(pauseProxy); dss.dog.file(ilk, "hole", 1000 * 10**45);
        uint256 id2 = dss.dog.bark(ilk, urn, address(this));

        assertEq(engine.urnAuctions(urn), 2);

        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectVoteDelegate(urn, voteDelegate);
        vm.expectRevert("LockstakeEngine/urn-in-auction");
        engine.selectFarm(urn, address(farm), 0);

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
        engine.selectVoteDelegate(urn, voteDelegate);
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

        // Can select voteDelegate and farm again
        engine.selectVoteDelegate(urn, voteDelegate);
        engine.selectFarm(urn, address(farm), 0);
    }

    function testUrnUnsafe() public {
        address urn = _urnSetUp(true, true);

        assertEq(engine.urnVoteDelegates(urn), voteDelegate);

        address voteDelegate2 = voteDelegateFactory.create();

        vm.store(address(pip), bytes32(uint256(1)), bytes32(uint256(0.05 * 10**18))); // Force urn unsafe
        dss.spotter.poke(ilk);

        vm.expectRevert("LockstakeEngine/urn-unsafe");
        engine.selectVoteDelegate(urn, voteDelegate2);

        engine.selectVoteDelegate(urn, address(0));

        vm.expectRevert("LockstakeEngine/urn-unsafe");
        engine.selectVoteDelegate(urn, voteDelegate2);

        vm.store(address(pip), bytes32(uint256(1)), bytes32(uint256(1_500 * 10**18))); // Back to safety
        dss.spotter.poke(ilk);

        engine.selectVoteDelegate(urn, voteDelegate2);

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
