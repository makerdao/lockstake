// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { LockstakeSky } from "src/LockstakeSky.sol";
import { PipMock } from "test/mocks/PipMock.sol";
import { VoteDelegateFactoryMock, VoteDelegateMock } from "test/mocks/VoteDelegateMock.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import { UsdsMock } from "test/mocks/UsdsMock.sol";
import { UsdsJoinMock } from "test/mocks/UsdsJoinMock.sol";
import { StakingRewardsMock } from "test/mocks/StakingRewardsMock.sol";
import { LockstakeHandler } from "test/handlers/LockstakeHandler.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface VatLike {
    function gem(bytes32, address) external view returns (uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function rely(address) external;
    function file(bytes32, bytes32, uint256) external;
    function file(bytes32, uint256) external;
    function init(bytes32) external;
}

interface SpotterLike {
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
    function poke(bytes32) external;
}

interface JugLike {
    function file(bytes32, bytes32, uint256) external;
    function init(bytes32) external;
}

interface DogLike {
    function rely(address) external;
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
}

interface CalcFabLike {
    function newStairstepExponentialDecrease(address) external returns (address);
}

interface CalcLike {
    function file(bytes32, uint256) external;
}

contract LockstakeEngineIntegrationTest is DssTest {
    using stdStorage for StdStorage;

    address             public pauseProxy;
    VatLike             public vat;
    address             public spot;
    DogLike             public dog;
    GemMock             public sky;
    address             public jug;
    LockstakeEngine     public engine;
    address             public urn;
    LockstakeClipper    public clip;
    PipMock             public pip;
    VoteDelegateFactoryMock public delFactory;
    UsdsMock            public usds;
    UsdsJoinMock        public usdsJoin;
    LockstakeSky        public lssky;
    GemMock             public rTok;
    StakingRewardsMock  public farm0;
    StakingRewardsMock  public farm1;
    bytes32             public ilk = "LSE";
    address             public voter0;
    address             public voter1;
    address             public voterDelegate0;
    address             public voterDelegate1;

    LockstakeHandler    public handler;

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 9;
    }

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        pauseProxy = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        vat = VatLike(ChainlogLike(LOG).getAddress("MCD_VAT"));
        spot = ChainlogLike(LOG).getAddress("MCD_SPOT");
        dog = DogLike(ChainlogLike(LOG).getAddress("MCD_DOG"));
        sky = new GemMock(0);
        jug = ChainlogLike(LOG).getAddress("MCD_JUG");
        usds = new UsdsMock();
        usdsJoin = new UsdsJoinMock(address(vat), address(usds));
        lssky = new LockstakeSky();
        rTok = new GemMock(0);
        farm0 = new StakingRewardsMock(address(rTok), address(lssky));
        farm1 = new StakingRewardsMock(address(rTok), address(lssky));

        pip = new PipMock();
        delFactory = new VoteDelegateFactoryMock(address(sky));
        voter0 = address(123);
        voter1 = address(456);
        vm.prank(voter0); voterDelegate0 = delFactory.create();
        vm.prank(voter1); voterDelegate1 = delFactory.create();

        vm.startPrank(pauseProxy);
        engine = new LockstakeEngine(address(delFactory), address(usdsJoin), ilk, address(sky), address(lssky), 15 * WAD / 100);
        engine.file("jug", jug);
        vat.rely(address(engine));
        vat.init(ilk);
        JugLike(jug).init(ilk);
        JugLike(jug).file(ilk, "duty", 1000000021979553151239153027); // 100% APY
        SpotterLike(spot).file(ilk, "pip", address(pip));
        SpotterLike(spot).file(ilk, "mat", 3 * 10**27); // 300% coll ratio
        pip.setPrice(1000 * 10**18); // 1 SKY = 1000 USD
        SpotterLike(spot).poke(ilk);
        vat.file(ilk, "dust", rad(20 ether)); // $20 dust

        vat.file(ilk, "line", type(uint256).max);
        vat.file("Line", type(uint256).max);

        // dog and clip setup
        dog.file(ilk, "chop", 1.1 ether); // 10% chop
        dog.file(ilk, "hole", rad(1_000_000 ether));

        // dust and chop filed previously so clip.chost will be set correctly
        clip = new LockstakeClipper(address(vat), spot, address(dog), address(engine));
        clip.upchost();
        clip.rely(address(dog));

        dog.file(ilk, "clip", address(clip));
        dog.rely(address(clip));
        vat.rely(address(clip));
        engine.rely(address(clip));

        // setup for take
        address calc = CalcFabLike(ChainlogLike(LOG).getAddress("CALC_FAB")).newStairstepExponentialDecrease(pauseProxy);
        CalcLike(calc).file("cut",  RAY - ray(0.01 ether));  // 1% decrease
        CalcLike(calc).file("step", 1);                      // Decrease every 1 second

        clip.file("buf",  ray(1.25 ether));   // 25% Initial price buffer
        clip.file("calc", address(calc));     // File price contract
        clip.file("cusp", ray(0.3 ether));    // 70% drop before reset
        clip.file("tail", 3600);              // 1 hour before reset
        vm.stopPrank();

        lssky.rely(address(engine));

        deal(address(sky), address(this), 100_000 * 10**18, true);

        // Add some existing DAI assigned to usdsJoin to avoid a particular error
        stdstore.target(address(vat)).sig("dai(address)").with_key(address(usdsJoin)).depth(0).checked_write(100_000 * RAD);

        address[] memory voteDelegates = new address[](2);
        voteDelegates[0] = voterDelegate0;
        voteDelegates[1] = voterDelegate1;

        address[] memory farms = new address[](2);
        farms[0] = address(farm0);
        farms[1] = address(farm1);

        urn = engine.open(0);
        handler = new LockstakeHandler(
            vm,
            address(engine),
            address(this),
            0,
            address(spot),
            address(dog),
            pauseProxy,
            voteDelegates,
            farms
        );

        // uncomment and fill to only call specific functions
//      bytes4[] memory selectors = new bytes4[](5);
//      selectors[0] = LockstakeHandler.lock.selector;
//      selectors[1] = LockstakeHandler.draw.selector;
//      selectors[2] = LockstakeHandler.selectVoteDelegate.selector;
//      selectors[3] = LockstakeHandler.dropPriceAndBark.selector;
//      selectors[4] = LockstakeHandler.yank.selector;
//
//      targetSelector(FuzzSelector({
//          addr: address(handler),
//          selectors: selectors
//      }));

        targetContract(address(handler)); // invariant tests should fuzz only handler functions
    }

    function invariant_system_sky_equals_ink() public view {
        (uint256 ink,) = vat.urns(ilk, urn);
        assertEq(sky.balanceOf(address(engine)) + handler.sumDelegated() - vat.gem(ilk, address(clip)) - vat.gem(ilk, pauseProxy), ink);
    }

    function invariant_system_sky_equals_lssky_total_supply() public view {
        assertEq(sky.balanceOf(address(engine)) + handler.sumDelegated() - vat.gem(ilk, address(clip)) - vat.gem(ilk, pauseProxy), lssky.totalSupply());
    }

    function invariant_delegation_exclusiveness() public view {
        assertLe(handler.numDelegated(), 1);
    }

    function invariant_delegation_all_or_nothing() public view {
        address urnDelegate = engine.urnVoteDelegates(urn);
        (uint256 ink,) = vat.urns(ilk, urn);

        if (urnDelegate == address(0)) {
            assertEq(sky.balanceOf(address(engine)) - vat.gem(ilk, address(clip)) - vat.gem(ilk, pauseProxy), ink);
        } else {
            assertEq(sky.balanceOf(address(engine)) - vat.gem(ilk, address(clip)) - vat.gem(ilk, pauseProxy), 0);
            assertEq(handler.delegatedTo(urnDelegate), ink);
        }
    }

    function invariant_staking_exclusiveness() public view {
        assertLe(handler.numStakedForUrn(handler.urn()), 1);
    }

    function invariant_staking_all_or_nothing() public view {
        address urnFarm = engine.urnFarms(urn);
        (uint256 ink,) = vat.urns(ilk, urn);

        if (urnFarm == address(0)) {
            assertEq(lssky.balanceOf(urn), ink);
        } else {
            assertEq(lssky.balanceOf(urn), 0);
            assertEq(GemMock(urnFarm).balanceOf(urn), ink);
        }
    }

    function invariant_no_delegation_or_staking_during_auction() public view {
        assertTrue(
            engine.urnAuctions(urn) == 0 ||
            engine.urnVoteDelegates(urn) == address(0) && engine.urnFarms(urn) == address(0)
        );
    }

    function invariant_call_summary() private view { // make external to enable
        console.log("------------------");

        console.log("\nCall Summary\n");
        console.log("addFarm", handler.numCalls("addFarm"));
        console.log("selectFarm", handler.numCalls("selectFarm"));
        console.log("selectVoteDelegate", handler.numCalls("selectVoteDelegate"));
        console.log("lock", handler.numCalls("lock"));
        console.log("free", handler.numCalls("free"));
        console.log("draw", handler.numCalls("draw"));
        console.log("wipe", handler.numCalls("wipe"));
        console.log("dropPriceAndBark", handler.numCalls("dropPriceAndBark"));
        console.log("take", handler.numCalls("take"));
        console.log("yank", handler.numCalls("yank"));
        console.log("warp", handler.numCalls("warp"));
        console.log("total count", handler.numCalls("addFarm") + handler.numCalls("selectFarm") + handler.numCalls("selectVoteDelegate") +
                                   handler.numCalls("lock") + handler.numCalls("free") + handler.numCalls("draw") + handler.numCalls("wipe") +
                                   handler.numCalls("dropPriceAndBark") + handler.numCalls("take") + handler.numCalls("yank") +
                                   handler.numCalls("warp"));
    }
}
