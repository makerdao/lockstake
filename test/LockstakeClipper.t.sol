// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";

import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { LockstakeEngineMock } from "test/mocks/LockstakeEngineMock.sol";
import { PipMock } from "test/mocks/PipMock.sol";

contract BadGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(address sender, uint256 owe, uint256 slice, bytes calldata data)
        external {
        sender; owe; slice; data;
        clip.take({ // attempt reentrancy
            id: 1,
            amt: 25 ether,
            max: 5 ether * 10E27,
            who: address(this),
            data: ""
        });
    }
}

contract RedoGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        owe; slice; data;
        clip.redo(1, sender);
    }
}

contract KickGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        sender; owe; slice; data;
        clip.kick(1, 1, address(0), address(0));
    }
}

contract FileUintGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        sender; owe; slice; data;
        clip.file("stopped", 1);
    }
}

contract FileAddrGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        sender; owe; slice; data;
        clip.file("vow", address(123));
    }
}

contract YankGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        sender; owe; slice; data;
        clip.yank(1);
    }
}

contract PublicClip is LockstakeClipper {

    constructor(address vat, address spot, address dog, address engine) LockstakeClipper(vat, spot, dog, engine) {}

    function add() public returns (uint256 id) {
        id = ++kicks;
        active.push(id);
        sales[id].pos = active.length - 1;
    }

    function remove(uint256 id) public {
        _remove(id);
    }
}

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
    function frob(bytes32, address, address, address, int256, int256) external;
    function slip(bytes32, address, int256) external;
    function suck(address, address, uint256) external;
    function fold(bytes32, address, int256) external;
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
}

interface DogLike {
    function Dirt() external view returns (uint256);
    function chop(bytes32) external view returns (uint256);
    function ilks(bytes32) external view returns (address, uint256, uint256, uint256);
    function rely(address) external;
    function file(bytes32, uint256) external;
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
    function bark(bytes32, address, address) external returns (uint256);
}

interface SpotterLike {
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
    function poke(bytes32) external;
}

interface CalcFabLike {
    function newLinearDecrease(address) external returns (address);
    function newStairstepExponentialDecrease(address) external returns (address);
}

interface CalcLike {
    function file(bytes32, uint256) external;
} 

interface VowLike {

}

contract LockstakeClipperTest is DssTest {
    address     pauseProxy;
    VatLike     vat;
    DogLike     dog;
    SpotterLike spot;
    VowLike     vow;
    PipMock     pip;
    GemLike     dai;

    LockstakeEngineMock engine;
    LockstakeClipper clip;

    // Exchange exchange;

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address ali;
    address bob;
    address che;

    bytes32 constant ilk = "LSE";
    uint256 constant price = 5 ether;

    uint256 constant startTime = 604411200; // Used to avoid issues with `block.timestamp`

    function _ink(bytes32 ilk_, address urn_) internal view returns (uint256) {
        (uint256 ink_,) = vat.urns(ilk_, urn_);
        return ink_;
    }
    function _art(bytes32 ilk_, address urn_) internal view returns (uint256) {
        (,uint256 art_) = vat.urns(ilk_, urn_);
        return art_;
    }

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 9;
    }

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }

    modifier takeSetup {
        address calc = CalcFabLike(ChainlogLike(LOG).getAddress("CALC_FAB")).newStairstepExponentialDecrease(address(this));
        CalcLike(calc).file("cut",  RAY - ray(0.01 ether));  // 1% decrease
        CalcLike(calc).file("step", 1);                      // Decrease every 1 second

        clip.file("buf",  ray(1.25 ether));   // 25% Initial price buffer
        clip.file("calc", address(calc));     // File price contract
        clip.file("cusp", ray(0.3 ether));    // 70% drop before reset
        clip.file("tail", 3600);              // 1 hour before reset

        (uint256 ink, uint256 art) = vat.urns(ilk, address(this));
        assertEq(ink, 40 ether);
        assertEq(art, 100 ether);

        assertEq(clip.kicks(), 0);
        dog.bark(ilk, address(this), address(this));
        assertEq(clip.kicks(), 1);

        (ink, art) = vat.urns(ilk, address(this));
        assertEq(ink, 0);
        assertEq(art, 0);

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, rad(110 ether));
        assertEq(sale.lot, 40 ether);
        assertEq(sale.tot, 40 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(5 ether)); // $4 plus 25%

        assertEq(vat.gem(ilk, ali), 0);
        assertEq(vat.dai(ali), rad(1000 ether));
        assertEq(vat.gem(ilk, bob), 0);
        assertEq(vat.dai(bob), rad(1000 ether));

        _;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        vm.warp(startTime);

        pauseProxy = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        vat = VatLike(ChainlogLike(LOG).getAddress("MCD_VAT"));
        spot = SpotterLike(ChainlogLike(LOG).getAddress("MCD_SPOT"));
        vow = VowLike(ChainlogLike(LOG).getAddress("MCD_VOW"));
        dog = DogLike(ChainlogLike(LOG).getAddress("MCD_DOG"));
        dai = GemLike(ChainlogLike(LOG).getAddress("MCD_DAI"));

        pip = new PipMock();
        pip.setPrice(price); // Spot = $2.5

        vm.prank(pauseProxy); vat.init(ilk);

        vm.prank(pauseProxy); spot.file(ilk, "pip", address(pip));
        vm.prank(pauseProxy); spot.file(ilk, "mat", ray(2 ether)); // 200% liquidation ratio for easier test calcs
        spot.poke(ilk);

        vm.prank(pauseProxy); vat.file(ilk, "dust", rad(20 ether)); // $20 dust
        vm.prank(pauseProxy); vat.file(ilk, "line", rad(10000 ether));
        // vm.prank(pauseProxy); vat.file("Line",      rad(10000 ether));

        vm.prank(pauseProxy); dog.file(ilk, "chop", 1.1 ether); // 10% chop
        vm.prank(pauseProxy); dog.file(ilk, "hole", rad(1000 ether));
        // vm.prank(pauseProxy); dog.file("Hole", rad(1000 ether));

        engine = new LockstakeEngineMock(address(vat), ilk);
        vm.prank(pauseProxy); vat.rely(address(engine));

        // dust and chop filed previously so clip.chost will be set correctly
        clip = new LockstakeClipper(address(vat), address(spot), address(dog), address(engine));
        clip.upchost();
        clip.rely(address(dog));

        vm.prank(pauseProxy); dog.file(ilk, "clip", address(clip));
        vm.prank(pauseProxy); dog.rely(address(clip));
        vm.prank(pauseProxy); vat.rely(address(clip));

        vm.prank(pauseProxy); vat.slip(ilk, address(this), int256(1000 ether));

        assertEq(vat.gem(ilk, address(this)), 1000 ether);
        assertEq(vat.dai(address(this)), 0);
        vat.frob(ilk, address(this), address(this), address(this), 40 ether, 100 ether);
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        assertEq(vat.dai(address(this)), rad(100 ether));

        pip.setPrice(4 ether); // Spot = $2
        spot.poke(ilk);          // Now unsafe

        ali = address(111);
        bob = address(222);
        che = address(333);

        vat.hope(address(clip));
        vm.prank(ali); vat.hope(address(clip));
        vm.prank(bob); vat.hope(address(clip));

        vm.prank(pauseProxy); vat.suck(address(0), address(this), rad(1000 ether));
        vm.prank(pauseProxy); vat.suck(address(0), address(ali),  rad(1000 ether));
        vm.prank(pauseProxy); vat.suck(address(0), address(bob),  rad(1000 ether));
    }

    function testChangeDog() public {
        assertTrue(address(clip.dog()) != address(123));
        clip.file("dog", address(123));
        assertEq(address(clip.dog()), address(123));
    }

    function testGetChop() public {
        uint256 chop = dog.chop(ilk);
        (, uint256 chop2,,) = dog.ilks(ilk);
        assertEq(chop, chop2);
    }

    function testKick() public {
        clip.file("tip",  rad(100 ether)); // Flat fee of 100 DAI
        clip.file("chip", 0);              // No linear increase

        assertEq(clip.kicks(), 0);
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        assertEq(vat.dai(ali), rad(1000 ether));
        (uint256 ink, uint256 art) = vat.urns(ilk, address(this));
        assertEq(ink, 40 ether);
        assertEq(art, 100 ether);

        vm.prank(ali); dog.bark(ilk, address(this), address(ali));

        assertEq(clip.kicks(), 1);
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, rad(110 ether));
        assertEq(sale.lot, 40 ether);
        assertEq(sale.tot, 40 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(4 ether));
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        assertEq(vat.dai(ali), rad(1100 ether)); // Paid "tip" amount of DAI for calling bark()
        (ink, art) = vat.urns(ilk, address(this));
        assertEq(ink, 0 ether);
        assertEq(art, 0 ether);

        pip.setPrice(price); // Spot = $2.5
        spot.poke(ilk);          // Now safe

        vm.warp(startTime + 100);
        vat.frob(ilk, address(this), address(this), address(this), 40 ether, 100 ether);

        pip.setPrice(4 ether); // Spot = $2
        spot.poke(ilk);          // Now unsafe

        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(2);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
        assertEq(vat.gem(ilk, address(this)), 920 ether);

        clip.file(bytes32("buf"),  ray(1.25 ether)); // 25% Initial price buffer

        clip.file("tip",  rad(100 ether)); // Flat fee of 100 DAI
        clip.file("chip", 0.02 ether);     // Linear increase of 2% of tab

        assertEq(vat.dai(bob), rad(1000 ether));

        vm.prank(bob); dog.bark(ilk, address(this), address(bob));

        assertEq(clip.kicks(), 2);
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(2);
        assertEq(sale.pos, 1);
        assertEq(sale.tab, rad(110 ether));
        assertEq(sale.lot, 40 ether);
        assertEq(sale.tot, 40 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(5 ether));
        assertEq(vat.gem(ilk, address(this)), 920 ether);
        (ink, art) = vat.urns(ilk, address(this));
        assertEq(ink, 0 ether);
        assertEq(art, 0 ether);

        assertEq(vat.dai(bob), rad(1000 ether) + rad(100 ether) + sale.tab * 0.02 ether / WAD); // Paid (tip + due * chip) amount of DAI for calling bark()
    }

    function testRevertsKickZeroPrice() public {
        pip.setPrice(0);
        vm.expectRevert("LockstakeClipper/zero-top-price");
        dog.bark(ilk, address(this), address(this));
    }

    function testRevertsRedoZeroPrice() public {
        _auctionResetSetup(1 hours);

        pip.setPrice(0);

        vm.warp(startTime + 1801 seconds);
        (bool needsRedo,,,) = clip.getStatus(1);
        assertTrue(needsRedo);
        vm.expectRevert("LockstakeClipper/zero-top-price");
        clip.redo(1, address(this));
    }

    function testKickBasic() public {
        clip.kick(1 ether, 2 ether, address(1), address(this));
    }

    function testRevertsKickZeroTab() public {
        vm.expectRevert("LockstakeClipper/zero-tab");
        clip.kick(0, 2 ether, address(1), address(this));
    }

    function testRevertsKickZeroLot() public {
        vm.expectRevert("LockstakeClipper/zero-lot");
        clip.kick(1 ether, 0, address(1), address(this));
    }

    function testRevertsKickLotOverMaxInt() public {
        vm.expectRevert("LockstakeClipper/over-maxint-lot");
        clip.kick(1 ether, uint256(type(int256).max) + 1, address(1), address(this));
    }

    function testRevertsKickZeroUsr() public {
        vm.expectRevert("LockstakeClipper/zero-usr");
        clip.kick(1 ether, 2 ether, address(0), address(this));
    }

    function testBarkNotLeavingDust() public {
        vm.prank(pauseProxy); dog.file(ilk, "hole", rad(80 ether)); // Makes room = 80 WAD
        vm.prank(pauseProxy); dog.file(ilk, "chop", 1 ether); // 0% chop (for precise calculations)

        assertEq(clip.kicks(), 0);
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (uint256 ink, uint256 art) = vat.urns(ilk, address(this));
        assertEq(ink, 40 ether);
        assertEq(art, 100 ether);

        dog.bark(ilk, address(this), address(this)); // art - dart = 100 - 80 = dust (= 20)

        assertEq(clip.kicks(), 1);
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, rad(80 ether)); // No chop
        assertEq(sale.lot, 32 ether);
        assertEq(sale.tot, 32 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(4 ether));
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (ink, art) = vat.urns(ilk, address(this));
        assertEq(ink, 8 ether);
        assertEq(art, 20 ether);
    }

    function testBarkNotLeavingDustOverHole() public {
        vm.prank(pauseProxy); dog.file(ilk, "hole", rad(80 ether) + ray(1 ether)); // Makes room = 80 WAD + 1 wei
        vm.prank(pauseProxy); dog.file(ilk, "chop", 1 ether); // 0% chop (for precise calculations)

        assertEq(clip.kicks(), 0);
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (uint256 ink, uint256 art) = vat.urns(ilk, address(this));
        assertEq(ink, 40 ether);
        assertEq(art, 100 ether);

        dog.bark(ilk, address(this), address(this)); // art - dart = 100 - (80 + 1 wei) < dust (= 20) then the whole debt is taken

        assertEq(clip.kicks(), 1);
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, rad(100 ether)); // No chop
        assertEq(sale.lot, 40 ether);
        assertEq(sale.tot, 40 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(4 ether));
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (ink, art) = vat.urns(ilk, address(this));
        assertEq(ink, 0 ether);
        assertEq(art, 0 ether);
    }

    function testBarkNotLeavingDustRate() public {
        vm.prank(pauseProxy); vat.fold(ilk, address(vow), int256(ray(0.02 ether)));
        (, uint256 rate,,,) = vat.ilks(ilk);
        assertEq(rate, ray(1.02 ether));

        vm.prank(pauseProxy); dog.file(ilk, "hole", 100 * RAD);   // Makes room = 100 RAD
        vm.prank(pauseProxy); dog.file(ilk, "chop",   1 ether);   // 0% chop for precise calculations
        vm.prank(pauseProxy); vat.file(ilk, "dust",  20 * RAD);   // 20 DAI minimum Vault debt
        clip.upchost();

        assertEq(clip.kicks(), 0);
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (uint256 ink, uint256 art) = vat.urns(ilk, address(this));
        assertEq(ink, 40 ether);
        assertEq(art, 100 ether);  // Full debt is 102 DAI since rate = 1.02 * RAY

        // (art - dart) * rate ~= 2 RAD < dust = 20 RAD
        //   => remnant would be dusty, so a full liquidation occurs.
        dog.bark(ilk, address(this), address(this));

        assertEq(clip.kicks(), 1);
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 100 ether * rate);  // No chop
        assertEq(sale.lot, 40 ether);
        assertEq(sale.tot, 40 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(4 ether));
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (ink, art) = vat.urns(ilk, address(this));
        assertEq(ink, 0);
        assertEq(art, 0);
    }

    function testBarkOnlyLeavingDustOverHoleRate() public {
        vm.prank(pauseProxy); vat.fold(ilk, address(vow), int256(ray(0.02 ether)));
        (, uint256 rate,,,) = vat.ilks(ilk);
        assertEq(rate, ray(1.02 ether));

        vm.prank(pauseProxy); dog.file(ilk, "hole", 816 * RAD / 10);  // Makes room = 81.6 RAD => dart = 80
        vm.prank(pauseProxy); dog.file(ilk, "chop",   1 ether);       // 0% chop for precise calculations
        vm.prank(pauseProxy); vat.file(ilk, "dust", 204 * RAD / 10);  // 20.4 DAI dust
        clip.upchost();

        assertEq(clip.kicks(), 0);
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (uint256 ink, uint256 art) = vat.urns(ilk, address(this));
        assertEq(ink, 40 ether);
        assertEq(art, 100 ether);

        // (art - dart) * rate = 20.4 RAD == dust
        //   => marginal threshold at which partial liquidation is acceptable
        dog.bark(ilk, address(this), address(this));

        assertEq(clip.kicks(), 1);
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 816 * RAD / 10);  // Equal to ilk.hole
        assertEq(sale.lot, 32 ether);
        assertEq(sale.tot, 32 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(4 ether));
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (ink, art) = vat.urns(ilk, address(this));
        assertEq(ink, 8 ether);
        assertEq(art, 20 ether);
        (,,,, uint256 dust) = vat.ilks(ilk);
        assertEq(art * rate, dust);
    }

    function testHolehole() public {
        assertEq(dog.Dirt(), 0);
        (,,, uint256 dirt) = dog.ilks(ilk);
        assertEq(dirt, 0);

        dog.bark(ilk, address(this), address(this));

        (, uint256 tab,,,,,) = clip.sales(1);

        assertEq(dog.Dirt(), tab);
        (,,, dirt) = dog.ilks(ilk);
        assertEq(dirt, tab);

        bytes32 ilk2 = "LSE2";
        LockstakeEngineMock engine2 = new LockstakeEngineMock(address(vat), ilk2);
        vm.prank(pauseProxy); vat.rely(address(engine2));
        LockstakeClipper clip2 = new LockstakeClipper(address(vat), address(spot), address(dog), address(engine2));
        clip2.upchost();
        clip2.rely(address(dog));

        vm.prank(pauseProxy); dog.file(ilk2, "clip", address(clip2));
        vm.prank(pauseProxy); dog.file(ilk2, "chop", 1.1 ether);
        vm.prank(pauseProxy); dog.file(ilk2, "hole", rad(1000 ether));
        vm.prank(pauseProxy); dog.rely(address(clip2));

        vm.prank(pauseProxy); vat.init(ilk2);
        vm.prank(pauseProxy); vat.rely(address(clip2));
        vm.prank(pauseProxy); vat.file(ilk2, "line", rad(100 ether));

        vm.prank(pauseProxy); vat.slip(ilk2, address(this), 40 ether);

        PipMock pip2 = new PipMock();
        pip2.setPrice(price); // Spot = $2.5

        vm.prank(pauseProxy); spot.file(ilk2, "pip", address(pip2));
        vm.prank(pauseProxy); spot.file(ilk2, "mat", ray(2 ether));
        spot.poke(ilk2);
        vat.frob(ilk2, address(this), address(this), address(this), 40 ether, 100 ether);
        pip2.setPrice(4 ether); // Spot = $2
        spot.poke(ilk2);

        dog.bark(ilk2, address(this), address(this));

        (, uint256 tab2,,,,,) = clip2.sales(1);

        assertEq(dog.Dirt(), tab + tab2);
        (,,, dirt) = dog.ilks(ilk);
        (,,, uint256 dirt2) = dog.ilks(ilk2);
        assertEq(dirt, tab);
        assertEq(dirt2, tab2);
    }

    function testPartialLiquidationHoleLimit() public {
        vm.prank(pauseProxy); dog.file("Hole", rad(75 ether));

        assertEq(_ink(ilk, address(this)), 40 ether);
        assertEq(_art(ilk, address(this)), 100 ether);

        assertEq(dog.Dirt(), 0);
        (,uint256 chop,, uint256 dirt) = dog.ilks(ilk);
        assertEq(dirt, 0);

        dog.bark(ilk, address(this), address(this));

        LockstakeClipper.Sale memory sale;
        (, sale.tab, sale.lot,,,,) = clip.sales(1);

        (, uint256 rate,,,) = vat.ilks(ilk);

        assertEq(sale.lot, 40 ether * (sale.tab * WAD / rate / chop) / 100 ether);
        assertEq(sale.tab, rad(75 ether) - ray(0.2 ether)); // 0.2 RAY rounding error

        assertEq(_ink(ilk, address(this)), 40 ether - sale.lot);
        assertEq(_art(ilk, address(this)), 100 ether - sale.tab * WAD / rate / chop);

        assertEq(dog.Dirt(), sale.tab);
        (,,, dirt) = dog.ilks(ilk);
        assertEq(dirt, sale.tab);
    }

    function testPartialLiquidationholeLimit() public {
        vm.prank(pauseProxy); dog.file(ilk, "hole", rad(75 ether));

        assertEq(_ink(ilk, address(this)), 40 ether);
        assertEq(_art(ilk, address(this)), 100 ether);

        assertEq(dog.Dirt(), 0);
        (,uint256 chop,, uint256 dirt) = dog.ilks(ilk);
        assertEq(dirt, 0);

        dog.bark(ilk, address(this), address(this));

        LockstakeClipper.Sale memory sale;
        (, sale.tab, sale.lot,,,,) = clip.sales(1);

        (, uint256 rate,,,) = vat.ilks(ilk);

        assertEq(sale.lot, 40 ether * (sale.tab * WAD / rate / chop) / 100 ether);
        assertEq(sale.tab, rad(75 ether) - ray(0.2 ether)); // 0.2 RAY rounding error

        assertEq(_ink(ilk, address(this)), 40 ether - sale.lot);
        assertEq(_art(ilk, address(this)), 100 ether - sale.tab * WAD / rate / chop);

        assertEq(dog.Dirt(), sale.tab);
        (,,, dirt) = dog.ilks(ilk);
        assertEq(dirt, sale.tab);
    }

    function testTakeZeroUsr() public takeSetup {
        // Auction id 2 is unpopulated.
        (,,,, address usr,,) = clip.sales(2);
        assertEq(usr, address(0));
        vm.expectRevert("LockstakeClipper/not-running-auction");
        clip.take(2, 25 ether, ray(5 ether), address(ali), "");
    }

    function testTakeOverTab() public takeSetup {
        // Bid so owe (= 25 * 5 = 125 RAD) > tab (= 110 RAD)
        // Readjusts slice to be tab/top = 25
        vm.prank(ali); clip.take({
            id:  1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });

        assertEq(vat.gem(ilk, ali), 22 ether);  // Didn't take whole lot
        assertEq(vat.dai(ali), rad(890 ether)); // Didn't pay more than tab (110)
        assertEq(vat.gem(ilk, address(this)),  978 ether); // 960 + (40 - 22) returned to usr

        // Assert auction ends
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);

        assertEq(dog.Dirt(), 0);
        (,,, uint256 dirt) = dog.ilks(ilk);
        assertEq(dirt, 0);
    }

    function testTakeAtTab() public takeSetup {
        // Bid so owe (= 22 * 5 = 110 RAD) == tab (= 110 RAD)
        vm.prank(ali); clip.take({
            id:  1,
            amt: 22 ether,
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });

        assertEq(vat.gem(ilk, ali), 22 ether);  // Didn't take whole lot
        assertEq(vat.dai(ali), rad(890 ether)); // Paid full tab (110)
        assertEq(vat.gem(ilk, address(this)), 978 ether);  // 960 + (40 - 22) returned to usr

        // Assert auction ends
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);

        assertEq(dog.Dirt(), 0);
        (,,, uint256 dirt) = dog.ilks(ilk);
        assertEq(dirt, 0);
    }

    function testTakeEmptyDataOrForbiddenWho() public takeSetup {
        vm.expectRevert(); // Reverts as who is a random address that do not implement clipperCall
        vm.prank(ali); clip.take({
            id:  1,
            amt: 11 ether,
            max: ray(5 ether),
            who: address(123),
            data: "aaa"
        });
        uint256 snapshotId = vm.snapshot();
        // This one won't revert as has empty data
        vm.prank(ali); clip.take({
            id:  1,
            amt: 11 ether,
            max: ray(5 ether),
            who: address(123),
            data: ""
        });
        vm.revertTo(snapshotId);
        // The following ones won't revert as are the forbidden addresses and the clipperCall will be ignored
        vm.prank(ali); clip.take({
            id:  1,
            amt: 11 ether,
            max: ray(5 ether),
            who: address(dog),
            data: "aaa"
        });
        vm.revertTo(snapshotId);
        vm.prank(ali); clip.take({
            id:  1,
            amt: 11 ether,
            max: ray(5 ether),
            who: address(vat),
            data: "aaa"
        });
        vm.revertTo(snapshotId);
        vm.prank(ali); clip.take({
            id:  1,
            amt: 11 ether,
            max: ray(5 ether),
            who: address(engine),
            data: "aaa"
        });
    }

    function testTakeUnderTab() public takeSetup {
        // Bid so owe (= 11 * 5 = 55 RAD) < tab (= 110 RAD)
        vm.prank(ali); clip.take({
            id:  1,
            amt: 11 ether,     // Half of tab at $110
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });

        assertEq(vat.gem(ilk, ali), 11 ether);  // Didn't take whole lot
        assertEq(vat.dai(ali), rad(945 ether)); // Paid half tab (55)
        assertEq(vat.gem(ilk, address(this)), 960 ether);  // Collateral not returned (yet)

        // Assert auction DOES NOT end
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, rad(55 ether));  // 110 - 5 * 11
        assertEq(sale.lot, 29 ether);       // 40 - 11
        assertEq(sale.tot, 40 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(5 ether));

        assertEq(dog.Dirt(), sale.tab);
        (,,, uint256 dirt) = dog.ilks(ilk);
        assertEq(dirt, sale.tab);
    }

    function testTakeFullLotPartialTab() public takeSetup {
        vm.warp(block.timestamp + 69);  // approx 50% price decline
        // Bid to purchase entire lot less than tab (~2.5 * 40 ~= 100 < 110)
        vm.prank(ali); clip.take({
            id:  1,
            amt: 40 ether,     // purchase all collateral
            max: ray(2.5 ether),
            who: address(ali),
            data: ""
        });

        assertEq(vat.gem(ilk, ali), 40 ether);  // Took entire lot
        assertLt(vat.dai(ali) - rad(900 ether), rad(0.1 ether));  // Paid about 100 ether
        assertEq(vat.gem(ilk, address(this)), 960 ether);  // Collateral not returned

        // Assert auction ends
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);

        // All dirt should be cleared, since the auction has ended, even though < 100% of tab was collected
        assertEq(dog.Dirt(), 0);
        (,,, uint256 dirt) = dog.ilks(ilk);
        assertEq(dirt, 0);
    }

    function testRevertsTakeBidTooLow() public takeSetup {
        // Bid so max (= 4) < price (= top = 5) (fails with "Clipper/too-expensive")
        vm.expectRevert("LockstakeClipper/too-expensive");
        vm.prank(ali); clip.take({
            id:  1,
            amt: 22 ether,
            max: ray(4 ether),
            who: address(ali),
            data: ""
        });
    }

    function testTakeBidRecalculatesDueToChostCheck() public takeSetup {
        (, uint256 tab, uint256 lot,,,,) = clip.sales(1);
        assertEq(tab, rad(110 ether));
        assertEq(lot, 40 ether);

        (, uint256 _price, uint256 _lot, uint256 _tab) = clip.getStatus(1);
        assertEq(_lot, lot);
        assertEq(_tab, tab);
        assertEq(_price, ray(5 ether));

        // Bid for an amount that would leave less than chost remaining tab--bid will be decreased
        // to leave tab == chost post-execution.
        vm.prank(ali); clip.take({
            id:  1,
            amt: 18 * WAD,  // Costs 90 DAI at current price; 110 - 90 == 20 < 22 == chost
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });

        (, tab, lot,,,,) = clip.sales(1);
        assertEq(tab, clip.chost());
        assertEq(lot, 40 ether - (110 * RAD - clip.chost()) / _price);
    }

    function testTakeBidAvoidsRecalculateDueNoMoreLot() public takeSetup {
        vm.warp(block.timestamp + 60); // Reducing the price

        (, uint256 tab, uint256 lot,,,,) = clip.sales(1);
        assertEq(tab, rad(110 ether));
        assertEq(lot, 40 ether);

        (, uint256 _price,,) = clip.getStatus(1);
        assertEq(_price, 2735783211953807380973706855); // 2.73 RAY

        // Bid so owe (= (22 - 1wei) * 5 = 110 RAD - 1) < tab (= 110 RAD)
        // 1 < 20 RAD => owe = 110 RAD - 20 RAD
        vm.prank(ali); clip.take({
            id:  1,
            amt: 40 ether,
            max: ray(2.8 ether),
            who: address(ali),
            data: ""
        });

        // 40 * 2.73 = 109.42...
        // It means a very low amount of tab (< dust) would remain but doesn't matter
        // as the auction is finished because there isn't more lot
        (, tab, lot,,,,) = clip.sales(1);
        assertEq(tab, 0);
        assertEq(lot, 0);
    }

    function testTakeBidFailsNoPartialAllowed() public takeSetup {
        (, uint256 _price,,) = clip.getStatus(1);
        assertEq(_price, ray(5 ether));

        clip.take({
            id:  1,
            amt: 17.6 ether,
            max: ray(5 ether),
            who: address(this),
            data: ""
        });

        (, uint256 tab, uint256 lot,,,,) = clip.sales(1);
        assertEq(tab, rad(22 ether));
        assertEq(lot, 22.4 ether);
        assertTrue(!(tab > clip.chost()));

        vm.expectRevert("LockstakeClipper/no-partial-purchase");
        clip.take({
            id:  1,
            amt: 1 ether,  // partial purchase attempt when !(tab > chost)
            max: ray(5 ether),
            who: address(this),
            data: ""
        });

        clip.take({
            id:  1,
            amt: tab / _price, // This time take the whole tab
            max: ray(5 ether),
            who: address(this),
            data: ""
        });
    }

    function testTakeMultipleBidsDifferentPrices() public takeSetup {
        // Bid so owe (= 10 * 5 = 50 RAD) < tab (= 110 RAD)
        vm.prank(ali); clip.take({
            id:  1,
            amt: 10 ether,
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });

        assertEq(vat.gem(ilk, ali), 10 ether);  // Didn't take whole lot
        assertEq(vat.dai(ali), rad(950 ether)); // Paid some tab (50)
        assertEq(vat.gem(ilk, address(this)), 960 ether);  // Collateral not returned (yet)

        // Assert auction DOES NOT end
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, rad(60 ether));  // 110 - 5 * 10
        assertEq(sale.lot, 30 ether);       // 40 - 10
        assertEq(sale.tot, 40 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(5 ether));

        vm.warp(block.timestamp + 30);

        (, uint256 _price, uint256 _lot,) = clip.getStatus(1);
        vm.prank(bob); clip.take({
            id:  1,
            amt: _lot,     // Buy the rest of the lot
            max: ray(_price), // 5 * 0.99 ** 30 = 3.698501866941401 RAY => max > price
            who: address(bob),
            data: ""
        });

        // Assert auction is over
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);

        uint256 expectedGem = (RAY * 60 ether) / _price;  // tab / price
        assertEq(vat.gem(ilk, bob), expectedGem);         // Didn't take whole lot
        assertEq(vat.dai(bob), rad(940 ether));           // Paid rest of tab (60)

        uint256 lotReturn = 30 ether - expectedGem;         // lot - loaf.tab / max = 15
        assertEq(vat.gem(ilk, address(this)), 960 ether + lotReturn);  // Collateral returned (10 WAD)
    }

    function _auctionResetSetup(uint256 tau) internal {
        address calc = CalcFabLike(ChainlogLike(LOG).getAddress("CALC_FAB")).newLinearDecrease(address(this));
        CalcLike(calc).file("tau", tau);       // tau hours till zero is reached (used to test tail)

        vm.prank(pauseProxy); vat.file(ilk, "dust", rad(20 ether)); // $20 dust

        clip.file("buf",  ray(1.25 ether));   // 25% Initial price buffer
        clip.file("calc", address(calc));     // File price contract
        clip.file("cusp", ray(0.5 ether));    // 50% drop before reset
        clip.file("tail", 3600);              // 1 hour before reset

        assertEq(clip.kicks(), 0);
        dog.bark(ilk, address(this), address(this));
        assertEq(clip.kicks(), 1);
    }

    function testAuctionResetTail() public {
        _auctionResetSetup(10 hours); // 10 hours till zero is reached (used to test tail)

        pip.setPrice(3 ether); // Spot = $1.50 (update price before reset is called)

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.tic, startTime);
        assertEq(sale.top, ray(5 ether)); // $4 spot + 25% buffer = $5 (wasn't affected by poke)

        vm.warp(startTime + 3600 seconds);
        (bool needsRedo,,,) = clip.getStatus(1);
        assertTrue(!needsRedo);
        vm.expectRevert("LockstakeClipper/cannot-reset");
        clip.redo(1, address(this));
        vm.warp(startTime + 3601 seconds);
        (needsRedo,,,) = clip.getStatus(1);
        assertTrue(needsRedo);
        clip.redo(1, address(this));

        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.tic, startTime + 3601 seconds);     // (block.timestamp)
        assertEq(sale.top, ray(3.75 ether)); // $3 spot + 25% buffer = $5 (used most recent OSM price)
    }

    function testAuctionResetCusp() public {
        _auctionResetSetup(1 hours); // 1 hour till zero is reached (used to test cusp)

        pip.setPrice(3 ether); // Spot = $1.50 (update price before reset is called)

        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.tic, startTime);
        assertEq(sale.top, ray(5 ether)); // $4 spot + 25% buffer = $5 (wasn't affected by poke)

        vm.warp(startTime + 1800 seconds);
        (bool needsRedo,,,) = clip.getStatus(1);
        assertTrue(!needsRedo);
        vm.expectRevert("LockstakeClipper/cannot-reset");
        clip.redo(1, address(this));
        vm.warp(startTime + 1801 seconds);
        (needsRedo,,,) = clip.getStatus(1);
        assertTrue(needsRedo);
        clip.redo(1, address(this));

        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.tic, startTime + 1801 seconds);     // (block.timestamp)
        assertEq(sale.top, ray(3.75 ether)); // $3 spot + 25% buffer = $3.75 (used most recent OSM price)
    }

    function testAuctionResetTailTwice() public {
        _auctionResetSetup(10 hours); // 10 hours till zero is reached (used to test tail)

        vm.warp(startTime + 3601 seconds);
        clip.redo(1, address(this));

        vm.expectRevert("LockstakeClipper/cannot-reset");
        clip.redo(1, address(this));
    }

    function testAuctionResetCuspTwice() public {
        _auctionResetSetup(1 hours); // 1 hour till zero is reached (used to test cusp)

        vm.warp(startTime + 1801 seconds); // Price goes below 50% "cusp" after 30min01sec
        clip.redo(1, address(this));

        vm.expectRevert("LockstakeClipper/cannot-reset");
        clip.redo(1, address(this));
    }

    function testRedoZeroUsr() public {
        // Can't reset a non-existent auction.
        vm.expectRevert("LockstakeClipper/not-running-auction");
        clip.redo(1, address(this));
    }

    function testSetBreaker() public {
        clip.file("stopped", 1);
        assertEq(clip.stopped(), 1);
        clip.file("stopped", 2);
        assertEq(clip.stopped(), 2);
        clip.file("stopped", 3);
        assertEq(clip.stopped(), 3);
        clip.file("stopped", 0);
        assertEq(clip.stopped(), 0);
    }

    function testStoppedKick() public {
        assertEq(clip.kicks(), 0);
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        (uint256 ink, uint256 art) = vat.urns(ilk, address(this));
        assertEq(ink, 40 ether);
        assertEq(art, 100 ether);

        // Any level of stoppage prevents kicking.
        clip.file("stopped", 1);
        vm.expectRevert("LockstakeClipper/stopped-incorrect");
        dog.bark(ilk, address(this), address(this));

        clip.file("stopped", 2);
        vm.expectRevert("LockstakeClipper/stopped-incorrect");
        dog.bark(ilk, address(this), address(this));

        clip.file("stopped", 3);
        vm.expectRevert("LockstakeClipper/stopped-incorrect");
        dog.bark(ilk, address(this), address(this));

        clip.file("stopped", 0);
        dog.bark(ilk, address(this), address(this));
    }

    // At a stopped == 1 we are ok to take
    function testStopped1Take() public takeSetup {
        clip.file("stopped", 1);
        // Bid so owe (= 25 * 5 = 125 RAD) > tab (= 110 RAD)
        // Readjusts slice to be tab/top = 25
        vm.prank(ali); clip.take({
            id:  1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });
    }

    function testStopped2Take() public takeSetup {
        clip.file("stopped", 2);
        // Bid so owe (= 25 * 5 = 125 RAD) > tab (= 110 RAD)
        // Readjusts slice to be tab/top = 25
        vm.prank(ali); clip.take({
            id:  1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });
    }

    function testFailStopped3Take() public takeSetup {
        clip.file("stopped", 3);
        // Bid so owe (= 25 * 5 = 125 RAD) > tab (= 110 RAD)
        // Readjusts slice to be tab/top = 25
        vm.prank(ali); clip.take({
            id:  1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });
    }

    function testStopped1AuctionResetTail() public {
        _auctionResetSetup(10 hours); // 10 hours till zero is reached (used to test tail)

        clip.file("stopped", 1);

        pip.setPrice(3 ether); // Spot = $1.50 (update price before reset is called)

        (,,,,, uint96 ticBefore, uint256 topBefore) = clip.sales(1);
        assertEq(uint256(ticBefore), startTime);
        assertEq(topBefore, ray(5 ether)); // $4 spot + 25% buffer = $5 (wasn't affected by poke)

        vm.warp(startTime + 3600 seconds);
        vm.expectRevert("LockstakeClipper/cannot-reset");
        clip.redo(1, address(this));
        vm.warp(startTime + 3601 seconds);
        clip.redo(1, address(this));

        (,,,,, uint96 ticAfter, uint256 topAfter) = clip.sales(1);
        assertEq(uint256(ticAfter), startTime + 3601 seconds);     // (block.timestamp)
        assertEq(topAfter, ray(3.75 ether)); // $3 spot + 25% buffer = $5 (used most recent OSM price)
    }

    function testStopped2AuctionResetTail() public {
        _auctionResetSetup(10 hours); // 10 hours till zero is reached (used to test tail)

        clip.file("stopped", 2);

        pip.setPrice(3 ether); // Spot = $1.50 (update price before reset is called)

        (,,,,, uint96 ticBefore, uint256 topBefore) = clip.sales(1);
        assertEq(uint256(ticBefore), startTime);
        assertEq(topBefore, ray(5 ether)); // $4 spot + 25% buffer = $5 (wasn't affected by poke)

        vm.warp(startTime + 3601 seconds);
        (bool needsRedo,,,) = clip.getStatus(1);
        assertTrue(needsRedo);  // Redo possible if circuit breaker not set
        vm.expectRevert("LockstakeClipper/stopped-incorrect");
        clip.redo(1, address(this));  // Redo fails because of circuit breaker
    }

    function testStopped3AuctionResetTail() public {
        _auctionResetSetup(10 hours); // 10 hours till zero is reached (used to test tail)

        clip.file("stopped", 3);

        pip.setPrice(3 ether); // Spot = $1.50 (update price before reset is called)

        (,,,,, uint96 ticBefore, uint256 topBefore) = clip.sales(1);
        assertEq(uint256(ticBefore), startTime);
        assertEq(topBefore, ray(5 ether)); // $4 spot + 25% buffer = $5 (wasn't affected by poke)

        vm.warp(startTime + 3601 seconds);
        (bool needsRedo,,,) = clip.getStatus(1);
        assertTrue(needsRedo);  // Redo possible if circuit breaker not set
        vm.expectRevert("LockstakeClipper/stopped-incorrect");
        clip.redo(1, address(this));  // Redo fails because of circuit breaker
    }

    function testRedoIncentive() public takeSetup {
        clip.file("tip",  rad(100 ether)); // Flat fee of 100 DAI
        clip.file("chip", 0);              // No linear increase

        (, uint256 tab, uint256 lot,,,,) = clip.sales(1);

        assertEq(tab, rad(110 ether));
        assertEq(lot, 40 ether);

        vm.warp(block.timestamp + 300);
        clip.redo(1, address(123));
        assertEq(vat.dai(address(123)), clip.tip());

        clip.file("chip", 0.02 ether);     // Reward 2% of tab
        vm.warp(block.timestamp + 300);
        clip.redo(1, address(234));
        assertEq(vat.dai(address(234)), clip.tip() + clip.chip() * tab / WAD);

        clip.file("tip", 0); // No more flat fee
        vm.warp(block.timestamp + 300);
        clip.redo(1, address(345));
        assertEq(vat.dai(address(345)), clip.chip() * tab / WAD);

        vm.prank(pauseProxy); vat.file(ilk, "dust", rad(100 ether) + 1); // ensure wmul(dust, chop) > 110 DAI (tab)
        clip.upchost();
        assertEq(clip.chost(), 110 * RAD + 1);

        vm.warp(block.timestamp + 300);
        clip.redo(1, address(456));
        assertEq(vat.dai(address(456)), 0);

        // Set dust so that wmul(dust, chop) is well below tab to check the dusty lot case.
        vm.prank(pauseProxy); vat.file(ilk, "dust", rad(20 ether)); // $20 dust
        clip.upchost();
        assertEq(clip.chost(), 22 * RAD);

        vm.warp(block.timestamp + 100); // Reducing the price

        (, uint256 _price,,) = clip.getStatus(1);
        assertEq(_price, 1830161706366147524653080130); // 1.83 RAY

        clip.take({
            id:  1,
            amt: 38 ether,
            max: ray(5 ether),
            who: address(this),
            data: ""
        });

        (, tab, lot,,,,) = clip.sales(1);

        assertEq(tab, rad(110 ether) - 38 ether * _price); // > 22 DAI chost
        // When auction is reset the current price of lot
        // is calculated from oracle price ($4) to see if dusty
        assertEq(lot, 2 ether); // (2 * $4) < $20 quivalent (dusty collateral)

        vm.warp(block.timestamp + 300);
        clip.redo(1, address(567));
        assertEq(vat.dai(address(567)), 0);
    }

    function testIncentiveMaxValues() public {
        clip.file("chip", 2 ** 64 - 1);
        clip.file("tip", 2 ** 192 - 1);

        assertEq(uint256(clip.chip()), uint256(18.446744073709551615 * 10 ** 18));
        assertEq(uint256(clip.tip()), uint256(6277101735386.680763835789423207666416102355444464034512895 * 10 ** 45));

        clip.file("chip", 2 ** 64);
        clip.file("tip", 2 ** 192);

        assertEq(uint256(clip.chip()), 0);
        assertEq(uint256(clip.tip()), 0);
    }

    function testClipperYank() public takeSetup {
        (,, uint256 lot,, address usr,,) = clip.sales(1);
        address caller = address(123);
        clip.rely(caller);
        uint256 prevUsrGemBalance = vat.gem(ilk, address(usr));
        uint256 prevCallerGemBalance = vat.gem(ilk, address(caller));
        uint256 prevClipperGemBalance = vat.gem(ilk, address(clip));

        uint startGas = gasleft();
        vm.prank(caller); clip.yank(1);
        uint endGas = gasleft();
        emit log_named_uint("yank gas", startGas - endGas);

        // Assert that the auction was deleted.
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);

        // Assert that callback to clear dirt was successful.
        assertEq(dog.Dirt(), 0);
        (,,, uint256 dirt) = dog.ilks(ilk);
        assertEq(dirt, 0);

        // Assert transfer of gem.
        assertEq(vat.gem(ilk, address(usr)), prevUsrGemBalance);
        assertEq(vat.gem(ilk, address(caller)), prevCallerGemBalance + lot);
        assertEq(vat.gem(ilk, address(clip)), prevClipperGemBalance - lot);
    }

    function testRemoveId() public {
        LockstakeEngineMock engine2 = new LockstakeEngineMock(address(vat), "random");
        PublicClip pclip = new PublicClip(address(vat), address(spot), address(dog), address(engine2));
        uint256 pos;

        pclip.add();
        pclip.add();
        uint256 id = pclip.add();
        pclip.add();
        pclip.add();

        // [1,2,3,4,5]
        assertEq(pclip.count(), 5);   // 5 elements added
        assertEq(pclip.active(0), 1);
        assertEq(pclip.active(1), 2);
        assertEq(pclip.active(2), 3);
        assertEq(pclip.active(3), 4);
        assertEq(pclip.active(4), 5);

        pclip.remove(id);

        // [1,2,5,4]
        assertEq(pclip.count(), 4);
        assertEq(pclip.active(0), 1);
        assertEq(pclip.active(1), 2);
        assertEq(pclip.active(2), 5);  // Swapped last for middle
        (pos,,,,,,) = pclip.sales(5);
        assertEq(pos, 2);
        assertEq(pclip.active(3), 4);

        pclip.remove(4);

        // [1,2,5]
        assertEq(pclip.count(), 3);

        (pos,,,,,,) = pclip.sales(1);
        assertEq(pos, 0); // Sale 1 in slot 0
        assertEq(pclip.active(0), 1);

        (pos,,,,,,) = pclip.sales(2);
        assertEq(pos, 1); // Sale 2 in slot 1
        assertEq(pclip.active(1), 2);

        (pos,,,,,,) = pclip.sales(5);
        assertEq(pos, 2); // Sale 5 in slot 2
        assertEq(pclip.active(2), 5); // Final element removed

        (pos,,,,,,) = pclip.sales(4);
        assertEq(pos, 0); // Sale 4 was deleted. Returns 0

        vm.expectRevert();
        pclip.active(9); // Fail because id is out of range
    }

    // function testRevertsNotEnoughDai() public takeSetup {
    //     vm.expectRevert();
    //     vm.prank(che); clip.take({
    //         id:  1,
    //         amt: 25 ether,
    //         max: ray(5 ether),
    //         who: address(che),
    //         data: ""
    //     });
    // }

    // function testFlashsale() public takeSetup {
    //     address che = address(new Trader(clip, vat, gold, goldJoin, dai, daiJoin, exchange));
    //     assertEq(vat.dai(che), 0);
    //     assertEq(dai.balanceOf(che), 0);
    //     vm.prank(che); clip.take({
    //         id:  1,
    //         amt: 25 ether,
    //         max: ray(5 ether),
    //         who: address(che),
    //         data: "hey"
    //     });
    //     assertEq(vat.dai(che), 0);
    //     assertTrue(dai.balanceOf(che) > 0); // Che turned a profit
    // }

    function testRevertsReentrancyTake() public takeSetup {
        BadGuy usr = new BadGuy(clip);
        vm.prank(address(usr)); vat.hope(address(clip));
        vm.prank(pauseProxy); vat.suck(address(0), address(usr),  rad(1000 ether));

        vm.expectRevert("LockstakeClipper/system-locked");
        vm.prank(address(usr)); clip.take({
            id: 1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(usr),
            data: "hey"
        });
    }

    function testRevertsReentrancyRedo() public takeSetup {
        RedoGuy usr = new RedoGuy(clip);
        vm.prank(address(usr)); vat.hope(address(clip));
        vm.prank(pauseProxy); vat.suck(address(0), address(usr),  rad(1000 ether));

        vm.expectRevert("LockstakeClipper/system-locked");
        vm.prank(address(usr)); clip.take({
            id: 1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(usr),
            data: "hey"
        });
    }

    function testRevertsReentrancyKick() public takeSetup {
        KickGuy usr = new KickGuy(clip);
        vm.prank(address(usr)); vat.hope(address(clip));
        vm.prank(pauseProxy); vat.suck(address(0), address(usr),  rad(1000 ether));
        clip.rely(address(usr));

        vm.expectRevert("LockstakeClipper/system-locked");
        vm.prank(address(usr)); clip.take({
            id: 1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(usr),
            data: "hey"
        });
    }

    function testRevertsReentrancyFileUint() public takeSetup {
        FileUintGuy usr = new FileUintGuy(clip);
        vm.prank(address(usr)); vat.hope(address(clip));
        vm.prank(pauseProxy); vat.suck(address(0), address(usr),  rad(1000 ether));
        clip.rely(address(usr));

        vm.expectRevert("LockstakeClipper/system-locked");
        vm.prank(address(usr)); clip.take({
            id: 1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(usr),
            data: "hey"
        });
    }

    function testRevertsReentrancyFileAddr() public takeSetup {
        FileAddrGuy usr = new FileAddrGuy(clip);
        vm.prank(address(usr)); vat.hope(address(clip));
        vm.prank(pauseProxy); vat.suck(address(0), address(usr),  rad(1000 ether));
        clip.rely(address(usr));

        vm.expectRevert("LockstakeClipper/system-locked");
        vm.prank(address(usr)); clip.take({
            id: 1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(usr),
            data: "hey"
        });
    }

    function testRevertsReentrancyYank() public takeSetup {
        YankGuy usr = new YankGuy(clip);
        vm.prank(address(usr)); vat.hope(address(clip));
        vm.prank(pauseProxy); vat.suck(address(0), address(usr),  rad(1000 ether));
        clip.rely(address(usr));

        vm.expectRevert("LockstakeClipper/system-locked");
        vm.prank(address(usr)); clip.take({
            id: 1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(usr),
            data: "hey"
        });
    }

    // function testRevertsTakeImpersonation() public takeSetup { // should fail, but works
    //     vm.expectRevert();
    //     vm.prank(address(bob)); clip.take({
    //         id: 1,
    //         amt: 99999999999999 ether,
    //         max: ray(99999999999999 ether),
    //         who: address(ali),
    //         data: ""
    //     });
    // }

    function testGasBarkKick() public {
        // Assertions to make sure setup is as expected.
        assertEq(clip.kicks(), 0);
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
        assertEq(vat.gem(ilk, address(this)), 960 ether);
        assertEq(vat.dai(ali), rad(1000 ether));
        (uint256 ink, uint256 art) = vat.urns(ilk, address(this));
        assertEq(ink, 40 ether);
        assertEq(art, 100 ether);

        uint256 preGas = gasleft();
        vm.prank(ali); dog.bark(ilk, address(this), address(ali));
        uint256 diffGas = preGas - gasleft();
        emit log_named_uint("bark with kick gas", diffGas);
    }

    function testGasPartialTake() public takeSetup {
        uint256 preGas = gasleft();
        // Bid so owe (= 11 * 5 = 55 RAD) < tab (= 110 RAD)
        vm.prank(ali); clip.take({
            id:  1,
            amt: 11 ether,     // Half of tab at $110
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });
        uint256 diffGas = preGas - gasleft();
        emit log_named_uint("partial take gas", diffGas);

        assertEq(vat.gem(ilk, ali), 11 ether);  // Didn't take whole lot
        assertEq(vat.dai(ali), rad(945 ether)); // Paid half tab (55)
        assertEq(vat.gem(ilk, address(this)), 960 ether);  // Collateral not returned (yet)

        // Assert auction DOES NOT end
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, rad(55 ether));  // 110 - 5 * 11
        assertEq(sale.lot, 29 ether);       // 40 - 11
        assertEq(sale.tot, 40 ether);
        assertEq(sale.usr, address(this));
        assertEq(sale.tic, block.timestamp);
        assertEq(sale.top, ray(5 ether));
    }

    function testGasFullTake() public takeSetup {
        uint256 preGas = gasleft();
        // Bid so owe (= 25 * 5 = 125 RAD) > tab (= 110 RAD)
        // Readjusts slice to be tab/top = 25
        vm.prank(ali); clip.take({
            id:  1,
            amt: 25 ether,
            max: ray(5 ether),
            who: address(ali),
            data: ""
        });
        uint256 diffGas = preGas - gasleft();
        emit log_named_uint("full take gas", diffGas);

        assertEq(vat.gem(ilk, ali), 22 ether);  // Didn't take whole lot
        assertEq(vat.dai(ali), rad(890 ether)); // Didn't pay more than tab (110)
        assertEq(vat.gem(ilk, address(this)),  978 ether); // 960 + (40 - 22) returned to usr

        // Assert auction ends
        LockstakeClipper.Sale memory sale;
        (sale.pos, sale.tab, sale.lot, sale.tot, sale.usr, sale.tic, sale.top) = clip.sales(1);
        assertEq(sale.pos, 0);
        assertEq(sale.tab, 0);
        assertEq(sale.lot, 0);
        assertEq(sale.tot, 0);
        assertEq(sale.usr, address(0));
        assertEq(sale.tic, 0);
        assertEq(sale.top, 0);
    }
}
