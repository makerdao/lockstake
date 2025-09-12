// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

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
    GemMock          public sky;
    GemMock          public usds;
    bytes32          public ilk;
    VatLike          public vat;
    JugLike          public jug;
    SpotterLike      public spot;
    DogLike          public dog;
    LockstakeClipper public clip;

    address   public pauseProxy;
    address   public owner;
    uint256   public index;
    address   public urn;
    address[] public voteDelegates;
    address[] public farms;
    address   public anyone = address(123);

    mapping(bytes32 => uint256) public numCalls;

    uint256 constant RAY = 10 ** 27;

    modifier callAsAnyone() {
        vm.startPrank(anyone);
        _;
        vm.stopPrank();
    }

    modifier callAsUrnOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    modifier callAsPauseProxy() {
        vm.startPrank(pauseProxy);
        _;
        vm.stopPrank();
    }

    constructor(
        Vm vm_,
        address engine_,
        address owner_,
        uint256 index_,
        address spot_,
        address dog_,
        address pauseProxy_,
        address[] memory voteDelegates_,
        address[] memory farms_
    ) {
        vm         = vm_;
        engine     = LockstakeEngine(engine_);
        sky        = GemMock(address(engine.sky()));
        usds       = GemMock(address(engine.usds()));
        pauseProxy = pauseProxy_;
        ilk        = engine.ilk();
        vat        = VatLike(address(engine.vat()));
        jug        = JugLike(address(engine.jug()));
        spot       = SpotterLike(spot_);
        dog        = DogLike(dog_);

        (address clip_, , , ) = dog.ilks(ilk);
        clip       = LockstakeClipper(clip_);
        owner      = owner_;
        index      = index_;
        urn        = engine.ownerUrns(owner, index);

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

    function _getRandomVoteDelegate(uint256 voteDelegateIndex) internal view returns (address) {
        return voteDelegates[bound(voteDelegateIndex, 0, voteDelegates.length - 1)];
    }

    function _getRandomFarm(uint256 farmIndex) internal view returns (address) {
        return farms[bound(farmIndex, 0, farms.length - 1)];
    }

    function _getRandomAuctionId(uint256 auctionIndex) internal view returns (uint256) {
        uint256[] memory active = clip.list();
        return active[bound(auctionIndex, 0, active.length - 1)];
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

    function addFarm(uint256 farmIndex) callAsPauseProxy() external {
        numCalls["addFarm"]++;
        engine.addFarm(_getRandomFarm(farmIndex));
    }

    function selectFarm(uint16 ref, uint256 farmIndex) callAsUrnOwner() external {
        numCalls["selectFarm"]++;
        engine.selectFarm(owner, index, _getRandomFarm(farmIndex), ref);
    }

    function selectVoteDelegate(uint256 voteDelegateIndex) callAsUrnOwner() external {
        numCalls["selectVoteDelegate"]++;
        engine.selectVoteDelegate(owner, index, _getRandomVoteDelegate(voteDelegateIndex));
    }

    function lock(uint256 wad, uint16 ref) external callAsAnyone {
        numCalls["lock"]++;

        // wad = bound(wad, 0, uint256(type(int256).max) / 10**18) * 10**18;
        (uint256 ink,) = vat.urns(ilk, urn);
        (,, uint256 spotPrice,,) = vat.ilks(ilk);
        wad = bound(wad, 0, _min(
                                uint256(type(int256).max),
                                type(uint256).max / spotPrice - ink
                            ) / 10**18
                    ) * 10**18;

        deal(address(sky), anyone, wad);
        sky.approve(address(engine), wad);

        engine.lock(owner, index, wad, ref);
    }

    function free(address to, uint256 wad) external callAsUrnOwner() {
        numCalls["free"]++;

        if (to == address(engine)) { revert("free-to-engine-unsupported"); }

        (uint256 ink, uint256 art) = vat.urns(ilk, urn);
        (, uint256 rate, uint256 spotPrice,,) = vat.ilks(ilk);
        wad = bound(wad, 0, ink - _divup(art * rate, spotPrice));

        engine.free(owner, index, to, wad);
    }

    function draw(uint256 wad) external callAsUrnOwner() {
        numCalls["draw"]++;

        (uint256 ink, uint256 art) = vat.urns(ilk, urn);
        (uint256 Art, uint256 rate, uint256 spotPrice,, uint256 dust) = vat.ilks(ilk);
        (uint256 duty, uint256 rho) = jug.ilks(ilk);
        rate = _rpow(duty, block.timestamp - rho, RAY) * rate / RAY;
        if (ink * spotPrice < art * rate) { revert("unsafe-fee-accumulation-or-price-drop"); }
        wad = bound(wad, art > 0 ? 0 : dust / RAY, _min(
                                                        (ink * spotPrice - art * rate) / RAY,
                                                        _min(
                                                            uint256(type(int256).max) / RAY,
                                                            (type(uint256).max - Art) * rate / RAY
                                                        )
                                                    ));

        engine.draw(owner, index, address(this), wad);
    }

    function wipe(uint256 wad) external callAsAnyone {
        numCalls["wipe"]++;

        (, uint256 art) = vat.urns(ilk, urn);
        (, uint256 rate,,, uint256 dust) = vat.ilks(ilk);
        wad = bound(wad, 0, art > 0 ? _min(
                                            (art * rate - dust) / RAY ,
                                            uint256(type(int256).max) / RAY
                                        )
                                    : 0);

        deal(address(usds), anyone, wad);
        usds.approve(address(engine), wad);

        engine.wipe(owner, index, wad);
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

    function take(uint256 auctionIndex) external {
        numCalls["take"]++;
        uint256 auctionId = _getRandomAuctionId(auctionIndex);
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.due, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(auctionId);

        vm.startPrank(pauseProxy); // we use startPrank as cannot override an ongoing prank with a single vm.prank
        vat.suck(address(0), address(this), sale.tab);
        vm.stopPrank();

        clip.take({
            id:  auctionId,
            amt: sale.lot,
            max: type(uint256).max,
            who: address(this),
            data: ""
        });
    }

    function yank(uint256 auctionIndex) external callAsPauseProxy() {
        numCalls["yank"]++;
        clip.yank(_getRandomAuctionId(auctionIndex));
    }

    function warp(uint256 secs) external {
        numCalls["warp"]++;
        secs = bound(secs, 0, 365 days);
        vm.warp(block.timestamp + secs);
    }
}
