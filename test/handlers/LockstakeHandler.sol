// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";

import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { GemMock }         from "test/mocks/GemMock.sol";
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

interface DogLike {
    function bark(bytes32, address, address) external returns (uint256);
    function ilks(bytes32) external view returns (address, uint256, uint256, uint256);
}

contract LockstakeHandler is DssTest {

    LockstakeEngine public engine;
    GemMock          public mkr;
    GemMock          public ngt;
    GemMock          public nst;
    bytes32          public ilk;
    VatLike          public vat;
    SpotterLike      public spot;
    DogLike          public dog;
    LockstakeClipper public clip;

    address   public  pauseProxy;

    address   public  sender; // assume one sender

    uint256   public  numUrns;
    uint256   public  currentIndex;

    address[] public  urns;
    address   public  currentUrn;

    address[] public  delegates;
    address   public  currentDelegate;

    address[] public  farms;
    address   public  currentFarm;

    uint256   public  currentAuctionId;

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

    modifier useRandomIndex(uint256 index) {
        currentIndex = bound(index, 0, numUrns - 1);
        _;
    }

    modifier useRandomUrn(uint256 urnIndex) {
        currentUrn = urns[bound(urnIndex, 0, urns.length - 1)];
        _;
    }

    modifier useRandomDelegate(uint256 delegateIndex) {
        currentDelegate = delegates[bound(delegateIndex, 0, delegates.length - 1)];
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
        address spot_,
        address dog_,
        address pauseProxy_,
        address sender_,
        uint256 numUrns_,
        address[] memory delegates_,
        address[] memory farms_
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

        vat.hope(address(clip));

        numUrns = numUrns_;
        for (uint i = 0; i < numUrns; i++) {
            urns.push(engine.getUrn(sender, i));
        }

        for (uint i = 0; i < delegates_.length ; i++) {
            delegates.push(delegates_[i]);
        }
        delegates.push(address(0));

        for (uint i = 0; i < farms_.length ; i++) {
            farms.push(farms_[i]);
        }
        farms.push(address(0));
    }

    function sumDelegated() external view returns (uint256 sum) {
        for (uint256 i = 0; i < delegates.length; i++) {
            if (delegates[i] == address(0)) continue;
            sum += mkr.balanceOf(delegates[i]);
        }
    }

    // note: There is no way to get the amount delegated per urn from the actual unmodified delegate contract,
    //       so we currently just return the total num of delegates that anyone delegated to.
    //       In practice it means that invariant_delegation_unique can only work when there is one urn.
    function numDelegated() external view returns (uint256 num) {
        for (uint256 i = 0; i < delegates.length; i++) {
            if (delegates[i] == address(0)) continue;
            if (mkr.balanceOf(delegates[i]) > 0) num++;
        }
    }

    function numStakedForUrn(address urn) external view returns (uint256 num) {
        for (uint256 i = 0; i < farms.length; i++) {
            address farm = farms[i];

            if (farm == address(0)) continue;
            if (GemMock(farms[i]).balanceOf(urn) > 0) num++;
        }
    }

    function sumInk() external view returns (uint256 sum) {
        for (uint256 i = 0; i < urns.length; i++) {
            (uint256 ink,) = vat.urns(ilk, urns[i]);
            sum += ink;
        }
    }

    function addFarm(uint256 farmIndex) usePauseProxy() useRandomFarm(farmIndex) external {
        numCalls["addFarm"]++;
        engine.addFarm(currentFarm);
    }

    function open(uint256 index) external useSender() useRandomIndex(index) returns (address) {
        numCalls["open"]++;
        return engine.open(currentIndex);
    }

    // TODO: support hope + nope once we support more than one sender

    function selectFarm(uint16 ref, uint256 urnIndex, uint256 farmIndex) useSender() useRandomUrn(urnIndex) useRandomFarm(farmIndex) external {
        numCalls["selectFarm"]++;
        engine.selectFarm(currentUrn, currentFarm, ref);
    }

    function selectDelegate(uint256 urnIndex, uint256 delegateIndex) useSender() useRandomUrn(urnIndex) useRandomDelegate(delegateIndex) external {
        numCalls["selectDelegate"]++;
        engine.selectDelegate(currentUrn, currentDelegate);
    }

    function lock(uint256 wad, uint16 ref, uint256 urnIndex) useSender() useRandomUrn(urnIndex) external {
        numCalls["lock"]++;
        wad = bound(wad, 0, uint256(type(int256).max));

        deal(address(mkr), sender, wad);
        mkr.approve(address(engine), wad);

        engine.lock(currentUrn, wad, ref);
    }

    function lockNgt(uint256 ngtWad, uint16 ref, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        numCalls["lockNgt"]++;
        deal(address(ngt), sender, ngtWad);
        ngt.approve(address(engine), ngtWad);

        engine.lockNgt(currentUrn, ngtWad, ref);
    }

    function free(address to, uint256 wad, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        numCalls["free"]++;
        engine.free(currentUrn, to, wad);
    }

    function freeNgt(address to, uint256 ngtWad, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        numCalls["freeNgt"]++;
        engine.freeNgt(currentUrn, to, ngtWad);
    }

    function draw(uint256 wad, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        numCalls["draw"]++;
        (uint256 ink,) = vat.urns(ilk, currentUrn);
        (,, uint256 spotPrice,, uint256 dust) = vat.ilks(ilk);

        wad = bound(wad, dust / RAY, ink * spotPrice / RAY);

        engine.draw(currentUrn, address(this), wad);
    }

    function wipe(uint256 wad, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        numCalls["wipe"]++;
        deal(address(nst), sender, wad);
        nst.approve(address(engine), wad);

        engine.wipe(currentUrn, wad);
    }

    // TODO: support getReward

    function dropPriceAndBark(uint256 urnIndex) external useRandomUrn(urnIndex) {
        numCalls["dropPriceAndBark"]++;
        (uint256 ink, uint256 art) = vat.urns(ilk, currentUrn);
        (address pip, uint256 mat) = SpotterLike(spot).ilks(ilk);
        (, uint256 rate,,,) = vat.ilks(ilk);

        uint256 minCollateralizedPrice = ((art * rate / RAY) * mat / ink) / 10**9;
        console.log("price", minCollateralizedPrice);

        PipMock(pip).setPrice(minCollateralizedPrice - 1);
        SpotterLike(spot).poke(ilk);

        dog.bark(ilk, currentUrn, address(0));
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
        vm.prank(pauseProxy); clip.yank(currentAuctionId);
    }
}
