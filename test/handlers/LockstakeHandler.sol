// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";

import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import { PipMock } from "test/mocks/PipMock.sol";

interface VatLike {
    function urns(bytes32, address) external view returns (uint256, uint256);
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function hope(address) external;
    function suck(address, address, uint256) external;
}

interface SpotterLike {
    function ilks(bytes32) external view returns (address, uint256);
    function poke(bytes32) external;
}

interface VoteDelegateLike {
    function stake(address) external view returns (uint256);
}

interface DogLike {
    function bark(bytes32, address, address) external returns (uint256);
    function ilks(bytes32) external view returns (address, uint256, uint256, uint256);
}

contract LockstakeHandler is DssTest {

    LockstakeEngine  public engine;
    GemMock          public mkr;
    GemMock          public ngt;
    GemMock          public nst;
    bytes32          public ilk;
    VatLike          public vat;
    SpotterLike      public spot;
    DogLike          public dog;
    LockstakeClipper public clip;

    address   public  pauseProxy;
    address   public  sender;
    address   public  urn;
    address[] public  voteDelegates;
    address   public  currentVoteDelegate;
    address[] public  farms;
    address   public  currentFarm;
    uint256   public  currentAuctionId;
    address   public  yankCaller;
    uint256   public  mkrNgtRate;

    mapping(bytes32 => uint256) public numCalls;

    modifier useSender() {
        vm.startPrank(sender);
        _;
        vm.stopPrank();
    }

    modifier usePauseProxy() {
        vm.startPrank(pauseProxy);
        _;
        vm.stopPrank();
    }

    modifier useRandomVoteDelegate(uint256 voteDelegateIndex) {
        currentVoteDelegate = voteDelegates[bound(voteDelegateIndex, 0, voteDelegates.length - 1)];
        _;
    }

    modifier useRandomFarm(uint256 farmIndex) {
        currentFarm = farms[bound(farmIndex, 0, farms.length - 1)];
        _;
    }

    modifier useRandomAuctionId(uint256 auctionIndex) {
        uint256[] memory active = clip.list();
        currentAuctionId = active[bound(auctionIndex, 0, active.length - 1)];
        _;
    }

    constructor(
        address engine_,
        address urn_,
        address spot_,
        address dog_,
        address pauseProxy_,
        address sender_,
        address[] memory voteDelegates_,
        address[] memory farms_,
        address yankCaller_
    ) {
        engine     = LockstakeEngine(engine_);
        mkr        = GemMock(address(engine.mkr()));
        ngt        = GemMock(address(engine.ngt()));
        nst        = GemMock(address(engine.nst()));
        pauseProxy = pauseProxy_;
        ilk        = engine.ilk();
        vat        = VatLike(address(engine.vat()));
        spot       = SpotterLike(spot_);
        dog        = DogLike(dog_);

        (address clip_, , , ) = dog.ilks(ilk);
        clip   = LockstakeClipper(clip_);
        sender = sender_;
        urn    = urn_;
        yankCaller = yankCaller_;
        mkrNgtRate = engine.mkrNgtRate();

        vat.hope(address(clip));

        for (uint256 i = 0; i < voteDelegates_.length ; i++) {
            voteDelegates.push(voteDelegates_[i]);
        }
        voteDelegates.push(address(0));

        for (uint256 i = 0; i < farms_.length ; i++) {
            farms.push(farms_[i]);
        }
        farms.push(address(0));
    }

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // Note: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function delegatedTo(address voteDelegate) external view returns (uint256) {
        return VoteDelegateLike(voteDelegate).stake(address(engine));
    }

    function sumDelegated() external view returns (uint256 sum) {
        for (uint256 i = 0; i < voteDelegates.length; i++) {
            if (voteDelegates[i] == address(0)) continue;
            sum += VoteDelegateLike(voteDelegates[i]).stake(address(engine));
        }
    }

    // note: There is no way to get the amount delegated per urn from the actual unmodified vote delegate contract,
    //       so we currently just return the total num of voteDelegates that anyone delegated to.
    //       In practice it means that invariant_delegation_exclusiveness can only work when there is one urn.
    function numDelegated() external view returns (uint256 num) {
        for (uint256 i = 0; i < voteDelegates.length; i++) {
            if (voteDelegates[i] == address(0)) continue;
            if (VoteDelegateLike(voteDelegates[i]).stake(address(engine)) > 0) num++;
        }
    }

    function numStakedForUrn(address urn_) external view returns (uint256 num) {
        for (uint256 i = 0; i < farms.length; i++) {
            if (farms[i] == address(0)) continue;
            if (GemMock(farms[i]).balanceOf(urn_) > 0) num++;
        }
    }

    function addFarm(uint256 farmIndex) usePauseProxy() useRandomFarm(farmIndex) external {
        numCalls["addFarm"]++;
        engine.addFarm(currentFarm);
    }

    function selectFarm(uint16 ref, uint256 farmIndex) useSender() useRandomFarm(farmIndex) external {
        numCalls["selectFarm"]++;
        engine.selectFarm(urn, currentFarm, ref);
    }

    function selectVoteDelegate(uint256 voteDelegateIndex) useSender() useRandomVoteDelegate(voteDelegateIndex) external {
        numCalls["selectVoteDelegate"]++;
        engine.selectVoteDelegate(urn, currentVoteDelegate);
    }

    function lock(uint256 wad, uint16 ref) useSender() external {
        numCalls["lock"]++;
        wad = bound(wad, 0, uint256(type(int256).max));

        deal(address(mkr), sender, wad);
        mkr.approve(address(engine), wad);

        engine.lock(urn, wad, ref);
    }

    function lockNgt(uint256 ngtWad, uint16 ref) external useSender() {
        numCalls["lockNgt"]++;
        deal(address(ngt), sender, ngtWad);
        ngt.approve(address(engine), ngtWad);

        engine.lockNgt(urn, ngtWad, ref);
    }

    function free(address to, uint256 wad) external useSender() {
        numCalls["free"]++;

        (uint256 ink,) = vat.urns(ilk, urn);
        wad = bound(wad, 0, ink);

        engine.free(urn, to, wad);
    }

    function freeNgt(address to, uint256 ngtWad) external useSender() {
        numCalls["freeNgt"]++;

        (uint256 ink,) = vat.urns(ilk, urn);
        ngtWad = bound(ngtWad, 0, ink * mkrNgtRate);

        engine.freeNgt(urn, to, ngtWad);
    }

    function draw(uint256 wad) external useSender() {
        numCalls["draw"]++;

        (uint256 ink,) = vat.urns(ilk, urn);
        (,, uint256 spotPrice,, uint256 dust) = vat.ilks(ilk);
        wad = bound(wad, dust / RAY, ink * spotPrice / RAY);

        engine.draw(urn, address(this), wad);
    }

    function wipe(uint256 wad) external useSender() {
        numCalls["wipe"]++;

        (, uint256 art) = vat.urns(ilk, urn);
        (, uint256 rate,,,) = vat.ilks(ilk);
        wad = bound(wad, 0, _divup(art * rate, RAY));

        deal(address(nst), sender, wad);
        nst.approve(address(engine), wad);

        engine.wipe(urn, wad);
    }

    function dropPriceAndBark() external {
        numCalls["dropPriceAndBark"]++;
        (uint256 ink, uint256 art) = vat.urns(ilk, urn);
        (address pip, uint256 mat) = spot.ilks(ilk);
        (, uint256 rate,,,) = vat.ilks(ilk);

        uint256 minCollateralizedPrice = ((art * rate / RAY) * mat / ink) / 10**9;
        PipMock(pip).setPrice(minCollateralizedPrice - 1);
        spot.poke(ilk);

        dog.bark(ilk, urn, address(0));
    }

    function take(uint256 auctionIndex) external useRandomAuctionId(auctionIndex) {
        numCalls["take"]++;
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(currentAuctionId);

        vm.startPrank(pauseProxy); // we use startPrank as cannot override an ongoing prank with a single vm.prank
        vat.suck(address(0), address(this), sale.tab);
        vm.stopPrank();

        clip.take({
            id:  currentAuctionId,
            amt: sale.lot,
            max: type(uint256).max,
            who: address(this),
            data: ""
        });
    }

    function yank(uint256 auctionIndex) external useRandomAuctionId(auctionIndex) {
        numCalls["yank"]++;
        vm.prank(yankCaller); clip.yank(currentAuctionId);
    }
}
