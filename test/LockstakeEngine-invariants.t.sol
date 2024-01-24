// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { PipMock } from "test/mocks/PipMock.sol";
import { DelegateFactoryMock, DelegateMock } from "test/mocks/DelegateMock.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import { NstMock } from "test/mocks/NstMock.sol";
import { NstJoinMock } from "test/mocks/NstJoinMock.sol";
import { StakingRewardsMock } from "test/mocks/StakingRewardsMock.sol";
import { MkrNgtMock } from "test/mocks/MkrNgtMock.sol";
import { LockstakeHandler } from "test/handlers/LockstakeHandler.sol";

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
    function file(bytes32, uint256) external;
    function init(bytes32) external;
    function hope(address) external;
    function suck(address, address, uint256) external;
}

interface SpotterLike {
    function ilks(bytes32) external view returns (address, uint256);
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
    function bark(bytes32, address, address) external returns (uint256);
}

interface CalcFabLike {
    function newLinearDecrease(address) external returns (address);
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
    GemMock             public mkr;
    address             public jug;
    LockstakeEngine     public engine;
    LockstakeClipper    public clip;
    PipMock             public pip;
    DelegateFactoryMock public delFactory;
    NstMock             public nst;
    NstJoinMock         public nstJoin;
    GemMock             public stkMkr;
    GemMock             public rTok;
    StakingRewardsMock  public farm0;
    StakingRewardsMock  public farm1;
    MkrNgtMock          public mkrNgt;
    GemMock             public ngt;
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
        mkr = new GemMock(0);
        jug = ChainlogLike(LOG).getAddress("MCD_JUG");
        nst = new NstMock();
        nstJoin = new NstJoinMock(address(vat), address(nst));
        stkMkr = new GemMock(0);
        rTok = new GemMock(0);
        farm0 = new StakingRewardsMock(address(rTok), address(stkMkr));
        farm1 = new StakingRewardsMock(address(rTok), address(stkMkr));
        ngt = new GemMock(0);
        mkrNgt = new MkrNgtMock(address(mkr), address(ngt), 25_000);

        pip = new PipMock();
        delFactory = new DelegateFactoryMock(address(mkr));
        voter0 = address(123);
        voter1 = address(456);
        vm.prank(voter0); voterDelegate0 = delFactory.create();
        vm.prank(voter1); voterDelegate1 = delFactory.create();

        vm.startPrank(pauseProxy);
        engine = new LockstakeEngine(address(delFactory), address(nstJoin), ilk, address(stkMkr), 15 * WAD / 100, address(mkrNgt));
        engine.file("jug", jug);
        vat.rely(address(engine));
        vat.init(ilk);
        JugLike(jug).init(ilk);
        JugLike(jug).file(ilk, "duty", 1001 * 10**27 / 1000);
        SpotterLike(spot).file(ilk, "pip", address(pip));
        SpotterLike(spot).file(ilk, "mat", 3 * 10**27); // 300% coll ratio
        pip.setPrice(1000 * 10**18); // 1 MKR = 1000 USD
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

        deal(address(mkr), address(this), 100_000 * 10**18, true);
        deal(address(ngt), address(this), 100_000 * 25_000 * 10**18, true);

        // Add some existing DAI assigned to nstJoin to avoid a particular error
        stdstore.target(address(vat)).sig("dai(address)").with_key(address(nstJoin)).depth(0).checked_write(100_000 * RAD);

        address[] memory delegates = new address[](2);
        delegates[0] = voterDelegate0;
        delegates[1] = voterDelegate1;

        address[] memory farms = new address[](2);
        farms[0] = address(farm0);
        farms[1] = address(farm1);

        handler = new LockstakeHandler(
            address(engine),
            address(spot),
            address(dog),
            pauseProxy,
            address(this),
            1,
            delegates,
            farms
        );

        // uncomment and fill to only call specific functions
//        bytes4[] memory selectors = new bytes4[](6);
//        selectors[0] = LockstakeHandler.open.selector;
//        selectors[1] = LockstakeHandler.lock.selector;
//        selectors[2] = LockstakeHandler.draw.selector;
//        selectors[3] = LockstakeHandler.selectDelegate.selector;
//        selectors[4] = LockstakeHandler.dropPriceAndBark.selector;
//        selectors[5] = LockstakeHandler.yank.selector;
//
//        targetSelector(FuzzSelector({
//            addr: address(handler),
//            selectors: selectors
//        }));

        targetContract(address(handler)); // invariant tests should fuzz only handler functions
        excludeArtifact("LockstakeUrn");  // excluding since it seems to also be fuzzed
        // targetSender(address(this));   // not needed anymore since we have `useSender` in the handler
    }

    function invariant_system_mkr_equals_sum_of_ink() public {
        assertEq(mkr.balanceOf(address(engine)) + handler.sumDelegated() - vat.gem(ilk, address(clip)), handler.sumInk());
    }

    function invariant_system_mkr_equals_stkMkr_total_supply() public {
        assertEq(mkr.balanceOf(address(engine)) + handler.sumDelegated() - vat.gem(ilk, address(clip)), stkMkr.totalSupply());
    }

    // Note: relies on having only one urn (i.e. 1 passed to handler ctr)
    function invariant_delegation_exclusiveness() public {
        assert(handler.numUrns() == 1);

        assertLe(handler.numDelegated(), 1);
    }

    // Note: relies on having only one urn (i.e. 1 passed to handler ctr)
    function invariant_delegation_all_or_nothing() public {
        assert(handler.numUrns() == 1);

        address urn = handler.urns(0);
        address urnDelegate = engine.urnDelegates(urn);
        (uint256 ink,) = vat.urns(ilk, urn);

        if (urnDelegate == address(0)) {
            assertEq(mkr.balanceOf(address(engine)) - vat.gem(ilk, address(clip)), ink);
        } else {
            assertEq(mkr.balanceOf(address(engine)) - vat.gem(ilk, address(clip)), 0);
            assertEq(mkr.balanceOf(urnDelegate), ink);
        }
    }

    function invariant_staking_exclusiveness() public {
        for (uint256 i = 0; i < handler.numUrns(); i++) {
            assertLe(handler.numStakedForUrn(handler.urns(i)), 1);
        }
    }

    function invariant_staking_all_or_nothing() public {
        for (uint256 i = 0; i < handler.numUrns(); i++) {
            address urn = handler.urns(i);
            address urnFarm = engine.urnFarms(urn);
            (uint256 ink,) = vat.urns(ilk, urn);

            if (urnFarm == address(0)) {
                assertEq(stkMkr.balanceOf(urn), ink);
            } else {
                assertEq(stkMkr.balanceOf(urn), 0);
                assertEq(GemMock(urnFarm).balanceOf(urn), ink);
            }
        }
    }

    function invariant_no_delegation_or_staking_during_auction() public {
        for (uint256 i = 0; i < handler.numUrns(); i++) {
            assert(
                engine.urnAuctions(handler.urns(i)) == 0 ||
                engine.urnDelegates(handler.urns(i)) == address(0) && engine.urnFarms(handler.urns(i)) == address(0)
            );
        }
    }

    // TODO: invariant that no delegation and no stake during an auction

    function invariant_call_summary() external view {
        console.log("------------------");

        console.log("\nCall Summary\n");
        console.log("addFarm", handler.numCalls("addFarm"));
        console.log("open", handler.numCalls("open"));
        console.log("selectFarm", handler.numCalls("selectFarm"));
        console.log("selectDelegate", handler.numCalls("selectDelegate"));
        console.log("lock", handler.numCalls("lock"));
        console.log("lockNgt", handler.numCalls("lockNgt"));
        console.log("free", handler.numCalls("free"));
        console.log("freeNgt", handler.numCalls("freeNgt"));
        console.log("draw", handler.numCalls("draw"));
        console.log("wipe", handler.numCalls("wipe"));
        console.log("dropPriceAndBark", handler.numCalls("dropPriceAndBark"));
        console.log("take", handler.numCalls("take"));
        console.log("yank", handler.numCalls("yank"));
    }
}

