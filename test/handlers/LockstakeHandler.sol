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
    address   public  sender;
    address   public  urn;
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
        address urn_,
        address spot_,
        address dog_,
        address pauseProxy_,
        address sender_,
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
        urn    = urn_;

        vat.hope(address(clip));

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

    function numStakedForUrn(address urn_) external view returns (uint256 num) {
        for (uint256 i = 0; i < farms.length; i++) {
            address farm = farms[i];

            if (farm == address(0)) continue;
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

    function selectDelegate(uint256 delegateIndex) useSender() useRandomDelegate(delegateIndex) external {
        numCalls["selectDelegate"]++;
        engine.selectDelegate(urn, currentDelegate);
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
        engine.free(urn, to, wad);
    }

    function freeNgt(address to, uint256 ngtWad) external useSender() {
        numCalls["freeNgt"]++;
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
        vm.prank(pauseProxy); clip.yank(currentAuctionId);
    }
}
