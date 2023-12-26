// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";

import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { GemMock }         from "test/mocks/GemMock.sol";

interface VatLike {
    function urns(bytes32, address) external view returns (uint256, uint256);
}

contract LockstakeHandler is DssTest {

    LockstakeEngine public engine;
    GemMock         public mkr;
    GemMock         public ngt;
    bytes32         public ilk;
    VatLike         public vat;

    address  public  pauseProxy;

    address   public  sender; // assume one sender

    uint256   public  numUrns;
    uint256   public  currentIndex;

    address[] public  urns;
    address   public  currentUrn;

    address[] public  delegates;
    address   public  currentDelegate;

    address[] public  farms;
    address   public  currentFarm;


//  uint256 public sumBalance;

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

    constructor(
        address engine_,
        address mkr_,
        address ngt_,
        address pauseProxy_,
        address sender_,
        uint256 numUrns_,
        address[] memory delegates_,
        address[] memory farms_
    ) {

        engine     = LockstakeEngine(engine_);
        mkr        = GemMock(mkr_);
        ngt        = GemMock(ngt_);
        pauseProxy = pauseProxy_;
        ilk        = engine.ilk();
        vat        = VatLike(address(engine.vat()));

        sender = sender_;

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
            sum += mkr.balanceOf(delegates[i]);
        }
    }

    function numDelegated() external view returns (uint256 num) {
        for (uint256 i = 0; i < delegates.length; i++) {
            if (mkr.balanceOf(delegates[i]) > 0) num++;
        }
    }

    function sumInk() external view returns (uint256 sum) {
        for (uint256 i = 0; i < urns.length; i++) {
            (uint256 ink,) = vat.urns(ilk, urns[i]);
            sum += ink;
        }
    }

    function addFarm(uint256 farmIndex) usePauseProxy() useRandomFarm(farmIndex) external {
        engine.addFarm(currentFarm);
    }

    function open(uint256 index) external useSender() useRandomIndex(index) returns (address) {
        return engine.open(currentIndex);
    }

    // TODO: hope + nope

    function selectFarm(uint16 ref, uint256 urnIndex, uint256 farmIndex) useSender() useRandomUrn(urnIndex) useRandomFarm(farmIndex) external {
        engine.selectFarm(currentUrn, currentFarm, ref);
    }

    function selectDelegate(uint256 urnIndex, uint256 delegateIndex) useSender() useRandomUrn(urnIndex) useRandomDelegate(delegateIndex) external {
        engine.selectDelegate(currentUrn, currentDelegate);
    }

    function lock(uint256 wad, uint16 ref, uint256 urnIndex) useSender() useRandomUrn(urnIndex) external {
        deal(address(mkr), address(this), wad);
        mkr.approve(address(engine), wad);

        engine.lock(currentUrn, wad, ref);
    }

    function lockNgt(uint256 ngtWad, uint16 ref, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        deal(address(ngt), address(this), ngtWad);
        ngt.approve(address(engine), ngtWad);

        engine.lockNgt(currentUrn, ngtWad, ref);
    }

    function free(address to, uint256 wad, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        engine.free(currentUrn, to, wad);
    }

    function freeNgt(address to, uint256 ngtWad, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        engine.freeNgt(currentUrn, to, ngtWad);
    }

    function draw(uint256 wad, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        engine.draw(currentUrn, wad);
    }

    function wipe(uint256 wad, uint256 urnIndex) external useSender() useRandomUrn(urnIndex) {
        engine.wipe(currentUrn, wad);
    }

    // TODO: liquidations
}
