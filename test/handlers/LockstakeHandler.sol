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

interface JugLike {
    function ilks(bytes32) external view returns (uint256, uint256);
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

contract LockstakeHandler is StdUtils, StdCheats {
    Vm vm;

    LockstakeEngine  public engine;
    GemMock          public mkr;
    GemMock          public ngt;
    GemMock          public nst;
    bytes32          public ilk;
    VatLike          public vat;
    JugLike          public jug;
    SpotterLike      public spot;
    DogLike          public dog;
    LockstakeClipper public clip;

    address   public pauseProxy;
    address   public urn;
    address   public urnOwner;
    address[] public voteDelegates;
    address   public currentVoteDelegate;
    address[] public farms;
    address   public currentFarm;
    uint256   public currentAuctionId;
    address   public yankCaller;
    uint256   public mkrNgtRate;
    address   public anyone = address(123);

    mapping(bytes32 => uint256) public numCalls;

    uint256 constant RAY = 10 ** 27;

    modifier useAnyone() {
        vm.startPrank(anyone);
        _;
        vm.stopPrank();
    }

    modifier useUrnOnwer() {
        vm.startPrank(urnOwner);
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
        Vm vm_,
        address engine_,
        address urn_,
        address spot_,
        address dog_,
        address pauseProxy_,
        address[] memory voteDelegates_,
        address[] memory farms_,
        address yankCaller_
    ) {
        vm         = vm_;
        engine     = LockstakeEngine(engine_);
        mkr        = GemMock(address(engine.mkr()));
        ngt        = GemMock(address(engine.ngt()));
        nst        = GemMock(address(engine.nst()));
        pauseProxy = pauseProxy_;
        ilk        = engine.ilk();
        vat        = VatLike(address(engine.vat()));
        jug        = JugLike(address(engine.jug()));
        spot       = SpotterLike(spot_);
        dog        = DogLike(dog_);

        (address clip_, , , ) = dog.ilks(ilk);
        clip       = LockstakeClipper(clip_);
        urn        = urn_;
        urnOwner   = engine.urnOwners(urn);
        yankCaller = yankCaller_;
        mkrNgtRate = engine.mkrNgtRate();

        vat.hope(address(clip));

        for (uint256 i = 0; i < voteDelegates_.length ; i++) {
            voteDelegates.push(voteDelegates_[i]);
        }
        // voteDelegates.push(address(0));

        for (uint256 i = 0; i < farms_.length ; i++) {
            farms.push(farms_[i]);
        }
        // farms.push(address(0));
    }

    function _rpow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
        assembly {
            switch x case 0 {switch n case 0 {z := b} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := b } default { z := x }
                let half := div(b, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, b)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // Note: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
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

    function selectFarm(uint16 ref, uint256 farmIndex) useUrnOnwer() useRandomFarm(farmIndex) external {
        numCalls["selectFarm"]++;
        engine.selectFarm(urn, currentFarm, ref);
    }

    function selectVoteDelegate(uint256 voteDelegateIndex) useUrnOnwer() useRandomVoteDelegate(voteDelegateIndex) external {
        numCalls["selectVoteDelegate"]++;
        engine.selectVoteDelegate(urn, currentVoteDelegate);
    }

    function lock(uint256 amt, uint16 ref) external useAnyone {
        numCalls["lock"]++;

        // amt = bound(amt, 0, uint256(type(int256).max) / 10**18) * 10**18;
        (uint256 ink,) = vat.urns(ilk, urn);
        (,, uint256 spotPrice,,) = vat.ilks(ilk);
        amt = bound(amt, 0, _min(
                                uint256(type(int256).max),
                                type(uint256).max / spotPrice - ink
                            ) / 10**18
                    ) * 10**18;

        deal(address(mkr), anyone, amt);
        mkr.approve(address(engine), amt);

        engine.lock(urn, amt, ref);
    }

    function lockNgt(uint256 ngtAmt, uint16 ref) external useAnyone {
        numCalls["lockNgt"]++;

        // ngtAmt = bound(ngtAmt, 0, uint256(type(int256).max) / 10**18) * 10**18;
        (uint256 ink,) = vat.urns(ilk, urn);
        (,, uint256 spotPrice,,) = vat.ilks(ilk);
        ngtAmt = bound(ngtAmt, 0, _min(
                                    uint256(type(int256).max),
                                    _min(
                                        type(uint256).max / spotPrice - ink,
                                        type(uint256).max / mkrNgtRate
                                    )
                                ) / 10**18
                      ) * 10**18 * mkrNgtRate;

        deal(address(ngt), anyone, ngtAmt);
        ngt.approve(address(engine), ngtAmt);

        engine.lockNgt(urn, ngtAmt, ref);
    }

    function free(address to, uint256 wad) external useUrnOnwer() {
        numCalls["free"]++;

        (uint256 ink, uint256 art) = vat.urns(ilk, urn);
        (, uint256 rate, uint256 spotPrice,,) = vat.ilks(ilk);
        wad = bound(wad, 0, ink - _divup(art * rate, spotPrice));

        engine.free(urn, to, wad);
    }

    function freeNgt(address to, uint256 ngtWad) external useUrnOnwer() {
        numCalls["freeNgt"]++;

        (uint256 ink, uint256 art ) = vat.urns(ilk, urn);
        (, uint256 rate, uint256 spotPrice,,) = vat.ilks(ilk);
        ngtWad = bound(ngtWad, 0, (ink - _divup(art * rate, spotPrice)) * mkrNgtRate);

        engine.freeNgt(urn, to, ngtWad);
    }

    function draw(uint256 wad) external useUrnOnwer() {
        numCalls["draw"]++;

        (uint256 ink, uint256 art) = vat.urns(ilk, urn);
        (, uint256 rate, uint256 spotPrice,, uint256 dust) = vat.ilks(ilk);
        (uint256 duty, uint256 rho) = jug.ilks(ilk);
        rate = _rpow(duty, block.timestamp - rho, RAY) * rate / RAY;
        wad = bound(wad, art > 0 ? 0 : dust / RAY, _min(
                                                        (ink * spotPrice - art * rate) / rate,
                                                        uint256(type(int256).max)
                                                    ));

        engine.draw(urn, address(this), wad);
    }

    function wipe(uint256 wad) external useAnyone {
        numCalls["wipe"]++;

        (, uint256 art) = vat.urns(ilk, urn);
        (, uint256 rate,,, uint256 dust) = vat.ilks(ilk);
        wad = bound(wad, 0, art > 0 ? _divup(art * rate, RAY) - dust / RAY : 0);

        deal(address(nst), anyone, wad);
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
        vm.startPrank(yankCaller);
        clip.yank(currentAuctionId);
        vm.stopPrank();
    }
}
