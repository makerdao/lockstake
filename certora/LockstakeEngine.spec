// LockstakeEngine.spec

using LockstakeUrn as lockstakeUrn;
using Vat as vat;
using MkrMock as mkr;
using LockstakeMkr as lsmkr;
using VoteDelegateMock as voteDelegate;
using VoteDelegate2Mock as voteDelegate2;
using VoteDelegateFactoryMock as voteDelegateFactory;
using StakingRewardsMock as stakingRewards;
using StakingRewards2Mock as stakingRewards2;
using MkrSkyMock as mkrSky;
using SkyMock as sky;
using UsdsMock as usds;
using UsdsJoinMock as usdsJoin;
using Jug as jug;
using RewardsMock as rewardsToken;

methods {
    // storage variables
    function wards(address) external returns (uint256) envfree;
    function farms(address) external returns (LockstakeEngine.FarmStatus) envfree;
    function ownerUrnsCount(address) external returns (uint256) envfree;
    function ownerUrns(address,uint256) external returns (address) envfree;
    function urnOwners(address) external returns (address) envfree;
    function urnCan(address,address) external returns (uint256) envfree;
    function urnVoteDelegates(address) external returns (address) envfree;
    function urnFarms(address) external returns (address) envfree;
    function urnAuctions(address) external returns (uint256) envfree;
    function jug() external returns (address) envfree;
    function fee() external returns (uint256) envfree;
    // immutables
    function voteDelegateFactory() external returns (address) envfree;
    function vat() external returns (address) envfree;
    function usdsJoin() external returns (address) envfree;
    function usds() external returns (address) envfree;
    function ilk() external returns (bytes32) envfree;
    function mkr() external returns (address) envfree;
    function lsmkr() external returns (address) envfree;
    function usds() external returns (address) envfree;
    function sky() external returns (address) envfree;
    function mkrSkyRate() external returns (uint256) envfree;
    function urnImplementation() external returns (address) envfree;
    //
    function lockstakeUrn.engine() external returns (address) envfree;
    function vat.live() external returns (uint256) envfree;
    function vat.Line() external returns (uint256) envfree;
    function vat.debt() external returns (uint256) envfree;
    function vat.ilks(bytes32) external returns (uint256,uint256,uint256,uint256,uint256) envfree;
    function vat.dai(address) external returns (uint256) envfree;
    function vat.gem(bytes32,address) external returns (uint256) envfree;
    function vat.urns(bytes32,address) external returns (uint256,uint256) envfree;
    function vat.can(address,address) external returns (uint256) envfree;
    function vat.wards(address) external returns (uint256) envfree;
    function mkr.allowance(address,address) external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function mkr.totalSupply() external returns (uint256) envfree;
    function sky.allowance(address,address) external returns (uint256) envfree;
    function sky.balanceOf(address) external returns (uint256) envfree;
    function sky.totalSupply() external returns (uint256) envfree;
    function lsmkr.allowance(address,address) external returns (uint256) envfree;
    function lsmkr.balanceOf(address) external returns (uint256) envfree;
    function lsmkr.totalSupply() external returns (uint256) envfree;
    function lsmkr.wards(address) external returns (uint256) envfree;
    function stakingRewards.balanceOf(address) external returns (uint256) envfree;
    function stakingRewards.totalSupply() external returns (uint256) envfree;
    function stakingRewards.rewardsToken() external returns (address) envfree;
    function stakingRewards.rewards(address) external returns (uint256) envfree;
    function stakingRewards2.balanceOf(address) external returns (uint256) envfree;
    function stakingRewards2.totalSupply() external returns (uint256) envfree;
    function mkrSky.rate() external returns (uint256) envfree;
    function usds.allowance(address,address) external returns (uint256) envfree;
    function usds.balanceOf(address) external returns (uint256) envfree;
    function usds.totalSupply() external returns (uint256) envfree;
    function jug.vow() external returns (address) envfree;
    function rewardsToken.balanceOf(address) external returns (uint256) envfree;
    function rewardsToken.totalSupply() external returns (uint256) envfree;
    function voteDelegate.stake(address) external returns (uint256) envfree;
    function voteDelegate2.stake(address) external returns (uint256) envfree;
    function voteDelegateFactory.created(address) external returns (uint256) envfree;
    //
    function jug.drip(bytes32 ilk) external returns (uint256) => dripSummary(ilk);
    function _.hope(address) external => DISPATCHER(true);
    function _.approve(address,uint256) external => DISPATCHER(true);
    function _.init() external => DISPATCHER(true);
    function _.lock(uint256) external => DISPATCHER(true);
    function _.free(uint256) external => DISPATCHER(true);
    function _.stake(address,uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => DISPATCHER(true);
    function _.stake(uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.getReward(address,address) external => DISPATCHER(true);
    function _.getReward() external => DISPATCHER(true);
    function _.rewardsToken() external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
}

definition addrZero() returns address = 0x0000000000000000000000000000000000000000;
definition max_int256() returns mathint = 2^255 - 1;
definition min_int256() returns mathint = -2^255;
definition WAD() returns mathint = 10^18;
definition RAY() returns mathint = 10^27;
definition _divup(mathint x, mathint y) returns mathint = x != 0 ? ((x - 1) / y) + 1 : 0;
definition _min(mathint x, mathint y) returns mathint = x < y ? x : y;

persistent ghost address createdUrn;

hook CREATE1(uint value, uint offset, uint length) address v {
    createdUrn = v;
}

ghost mathint duty;
ghost mathint timeDiff;

function dripSummary(bytes32 ilk) returns uint256 {
    env e;
    require duty >= RAY();
    uint256 prev; uint256 a;
    a, prev, a, a, a = vat.ilks(ilk);
    uint256 rate = timeDiff == 0 ? prev : require_uint256(duty * timeDiff * prev / RAY());
    timeDiff = 0;
    vat.fold(e, ilk, jug.vow(), require_int256(rate - prev));
    return rate;
}

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) filtered { f -> f.selector != sig:multicall(bytes[]).selector  } {
    env e;

    address anyAddr;
    address anyAddr2;
    uint256 anyUint256;

    bytes32 ilk = ilk();

    mathint wardsBefore = wards(anyAddr);
    LockstakeEngine.FarmStatus farmsBefore = farms(anyAddr);
    mathint ownerUrnsCountBefore = ownerUrnsCount(anyAddr);
    address ownerUrnsBefore = ownerUrns(anyAddr, anyUint256);
    address urnOwnersBefore = urnOwners(anyAddr);
    mathint urnCanBefore = urnCan(anyAddr, anyAddr2);
    address urnVoteDelegatesBefore = urnVoteDelegates(anyAddr);
    address urnFarmsBefore = urnFarms(anyAddr);
    mathint urnAuctionsBefore = urnAuctions(anyAddr);
    address jugBefore = jug();

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);
    LockstakeEngine.FarmStatus farmsAfter = farms(anyAddr);
    mathint ownerUrnsCountAfter = ownerUrnsCount(anyAddr);
    address ownerUrnsAfter = ownerUrns(anyAddr, anyUint256);
    address urnOwnersAfter = urnOwners(anyAddr);
    mathint urnCanAfter = urnCan(anyAddr, anyAddr2);
    address urnVoteDelegatesAfter = urnVoteDelegates(anyAddr);
    address urnFarmsAfter = urnFarms(anyAddr);
    mathint urnAuctionsAfter = urnAuctions(anyAddr);
    address jugAfter = jug();

    assert wardsAfter != wardsBefore => f.selector == sig:rely(address).selector || f.selector == sig:deny(address).selector, "Assert 1";
    assert farmsAfter != farmsBefore => f.selector == sig:addFarm(address).selector || f.selector == sig:delFarm(address).selector, "Assert 2";
    assert ownerUrnsCountAfter != ownerUrnsCountBefore => f.selector == sig:open(uint256).selector, "Assert 3";
    assert ownerUrnsAfter != ownerUrnsBefore => f.selector == sig:open(uint256).selector, "Assert 4";
    assert urnOwnersAfter != urnOwnersBefore => f.selector == sig:open(uint256).selector, "Assert 5";
    assert urnCanAfter != urnCanBefore => f.selector == sig:hope(address,uint256,address).selector || f.selector == sig:nope(address,uint256,address).selector, "Assert 6";
    assert urnVoteDelegatesAfter != urnVoteDelegatesBefore => f.selector == sig:selectVoteDelegate(address,uint256,address).selector || f.selector == sig:onKick(address,uint256).selector, "Assert 7";
    assert urnFarmsAfter != urnFarmsBefore => f.selector == sig:selectFarm(address,uint256,address,uint16).selector || f.selector == sig:onKick(address,uint256).selector, "Assert 8";
    assert urnAuctionsAfter != urnAuctionsBefore => f.selector == sig:onKick(address,uint256).selector || f.selector == sig:onRemove(address,uint256,uint256).selector, "Assert 9";
    assert jugAfter != jugBefore => f.selector == sig:file(bytes32,address).selector, "Assert 10";
}

rule vatGemKeepsUnchanged(method f) filtered { f -> f.selector != sig:multicall(bytes[]).selector  } {
    env e;

    address anyAddr;

    bytes32 ilk = ilk();

    mathint vatGemIlkAnyBefore = vat.gem(ilk, anyAddr);

    calldataarg args;
    f(e, args);

    mathint vatGemIlkAnyAfter = vat.gem(ilk, anyAddr);

    assert vatGemIlkAnyAfter == vatGemIlkAnyBefore, "Assert 1";
}

rule inkMatchesLsmkrFarm(method f) filtered { f -> f.selector != sig:multicall(bytes[]).selector  } {
    env e;

    address anyUrn;
    require anyUrn != stakingRewards && anyUrn != stakingRewards2;

    bytes32 ilk = ilk();

    address farmBefore = urnFarms(anyUrn);
    require farmBefore == addrZero() || farmBefore == stakingRewards;

    mathint vatUrnsIlkAnyUrnInkBefore; mathint a;
    vatUrnsIlkAnyUrnInkBefore, a = vat.urns(ilk, anyUrn);

    mathint lsmkrBalanceOfAnyUrnBefore = lsmkr.balanceOf(anyUrn);
    mathint farmBalanceOfAnyUrnBefore = farmBefore == addrZero() ? 0 : stakingRewards.balanceOf(anyUrn);

    require stakingRewards2.balanceOf(anyUrn) == 0;
    require lsmkrBalanceOfAnyUrnBefore == 0 || farmBalanceOfAnyUrnBefore == 0;
    require lsmkrBalanceOfAnyUrnBefore > 0 => farmBefore == addrZero();
    require farmBalanceOfAnyUrnBefore  > 0 => farmBefore != addrZero();
    require vatUrnsIlkAnyUrnInkBefore == lsmkrBalanceOfAnyUrnBefore + farmBalanceOfAnyUrnBefore;

    calldataarg args;
    f(e, args);

    address farmAfter = urnFarms(anyUrn);
    require farmAfter == addrZero() || farmAfter == farmBefore || farmAfter != farmBefore && farmAfter == stakingRewards2;

    mathint vatUrnsIlkAnyUrnInkAfter;
    vatUrnsIlkAnyUrnInkAfter, a = vat.urns(ilk, anyUrn);

    mathint lsmkrBalanceOfAnyUrnAfter = lsmkr.balanceOf(anyUrn);
    mathint farmBalanceOfAnyUrnAfter = farmAfter == addrZero() ? 0 : (farmAfter == farmBefore ? stakingRewards.balanceOf(anyUrn) : stakingRewards2.balanceOf(anyUrn));

    assert f.selector != sig:onRemove(address,uint256,uint256).selector => lsmkrBalanceOfAnyUrnAfter == 0 || farmBalanceOfAnyUrnAfter == 0, "Assert 1";
    assert f.selector != sig:onRemove(address,uint256,uint256).selector => lsmkrBalanceOfAnyUrnAfter > 0 => farmAfter == addrZero(), "Assert 2";
    assert f.selector != sig:onRemove(address,uint256,uint256).selector => farmBalanceOfAnyUrnAfter  > 0 => farmAfter != addrZero(), "Assert 3";
    assert f.selector != sig:onKick(address,uint256).selector => vatUrnsIlkAnyUrnInkAfter == lsmkrBalanceOfAnyUrnAfter + farmBalanceOfAnyUrnAfter, "Assert 4";
}

rule inkMatchesLsmkrFarmOnKick(address urn, uint256 wad) {
    env e;

    address anyUrn;
    require anyUrn != stakingRewards && anyUrn != stakingRewards2;

    bytes32 ilk = ilk();

    address farmBefore = urnFarms(anyUrn);
    require farmBefore == addrZero() || farmBefore == stakingRewards;

    mathint vatUrnsIlkAnyUrnInkBefore; mathint a;
    vatUrnsIlkAnyUrnInkBefore, a = vat.urns(ilk, anyUrn);

    mathint lsmkrBalanceOfAnyUrnBefore = lsmkr.balanceOf(anyUrn);
    mathint farmBalanceOfAnyUrnBefore = farmBefore == addrZero() ? 0 : stakingRewards.balanceOf(anyUrn);

    require stakingRewards2.balanceOf(anyUrn) == 0;
    require lsmkrBalanceOfAnyUrnBefore == 0 || farmBalanceOfAnyUrnBefore == 0;
    require lsmkrBalanceOfAnyUrnBefore > 0 => farmBefore == addrZero();
    require farmBalanceOfAnyUrnBefore  > 0 => farmBefore != addrZero();
    require vatUrnsIlkAnyUrnInkBefore == lsmkrBalanceOfAnyUrnBefore + farmBalanceOfAnyUrnBefore;

    onKick(e, urn, wad);

    address farmAfter = urnFarms(anyUrn);
    require farmAfter == addrZero() || farmAfter == farmBefore || farmAfter != farmBefore && farmAfter == stakingRewards2;

    mathint vatUrnsIlkAnyUrnInkAfter;
    vatUrnsIlkAnyUrnInkAfter, a = vat.urns(ilk, anyUrn);

    mathint lsmkrBalanceOfAnyUrnAfter = lsmkr.balanceOf(anyUrn);
    mathint farmBalanceOfAnyUrnAfter = farmAfter == addrZero() ? 0 : (farmAfter == farmBefore ? stakingRewards.balanceOf(anyUrn) : stakingRewards2.balanceOf(anyUrn));

    assert urn != anyUrn => vatUrnsIlkAnyUrnInkAfter == lsmkrBalanceOfAnyUrnAfter + farmBalanceOfAnyUrnAfter, "Assert 1";
    assert urn == anyUrn => vatUrnsIlkAnyUrnInkAfter == lsmkrBalanceOfAnyUrnAfter + farmBalanceOfAnyUrnAfter + wad, "Assert 2";
}

// Verify correct storage changes for non reverting rely
rule rely(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    rely(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 1, "Assert 1";
    assert wardsOtherAfter == wardsOtherBefore, "Assert 2";
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting deny
rule deny(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    deny(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 0, "Assert 1";
    assert wardsOtherAfter == wardsOtherBefore, "Assert 2";
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting file
rule file(bytes32 what, address data) {
    env e;

    file(e, what, data);

    address jugAfter = jug();

    assert jugAfter == data, "Assert 1";
}

// Verify revert rules on file
rule file_revert(bytes32 what, address data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = what != to_bytes32(0x6a75670000000000000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting addFarm
rule addFarm(address farm) {
    env e;

    address other;
    require other != farm;

    LockstakeEngine.FarmStatus farmsOtherBefore = farms(other);

    addFarm(e, farm);

    LockstakeEngine.FarmStatus farmsFarmAfter = farms(farm);
    LockstakeEngine.FarmStatus farmsOtherAfter = farms(other);

    assert farmsFarmAfter == LockstakeEngine.FarmStatus.ACTIVE, "Assert 1";
    assert farmsOtherAfter == farmsOtherBefore, "Assert 2";
}

// Verify revert rules on addFarm
rule addFarm_revert(address farm) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    addFarm@withrevert(e, farm);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting delFarm
rule delFarm(address farm) {
    env e;

    address other;
    require other != farm;

    LockstakeEngine.FarmStatus farmsOtherBefore = farms(other);

    delFarm(e, farm);

    LockstakeEngine.FarmStatus farmsFarmAfter = farms(farm);
    LockstakeEngine.FarmStatus farmsOtherAfter = farms(other);

    assert farmsFarmAfter == LockstakeEngine.FarmStatus.DELETED, "Assert 1";
    assert farmsOtherAfter == farmsOtherBefore, "Assert 2";
}

// Verify revert rules on delFarm
rule delFarm_revert(address farm) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    delFarm@withrevert(e, farm);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting open
rule open(uint256 index) {
    env e;

    address other;
    require other != e.msg.sender;
    address anyAddr; uint256 anyUint256;
    require anyAddr != e.msg.sender || anyUint256 != index;

    mathint ownerUrnsCountSenderBefore = ownerUrnsCount(e.msg.sender);
    mathint ownerUrnsCountOtherBefore = ownerUrnsCount(other);
    address ownerUrnsOtherBefore = ownerUrns(anyAddr, anyUint256);

    address urn = open(e, index);
    require urn.lsmkr(e) == lsmkr;

    mathint ownerUrnsCountSenderAfter = ownerUrnsCount(e.msg.sender);
    mathint ownerUrnsCountOtherAfter = ownerUrnsCount(other);
    address ownerUrnsSenderIndexAfter = ownerUrns(e.msg.sender, index);
    address ownerUrnsOtherAfter = ownerUrns(anyAddr, anyUint256);
    address urnOwnersUrnAfter = urnOwners(urn);
    mathint vatCanUrnEngineAfter = vat.can(urn, currentContract);
    mathint lsmkrAllowanceUrnEngine = lsmkr.allowance(urn, currentContract);

    assert ownerUrnsCountSenderAfter == ownerUrnsCountSenderBefore + 1, "Assert 1";
    assert ownerUrnsCountOtherAfter == ownerUrnsCountOtherBefore, "Assert 2";
    assert ownerUrnsSenderIndexAfter == urn, "Assert 3";
    assert ownerUrnsOtherAfter == ownerUrnsOtherBefore, "Assert 4";
    assert urnOwnersUrnAfter == e.msg.sender, "Assert 5";
    assert vatCanUrnEngineAfter == 1, "Assert 6";
    assert lsmkrAllowanceUrnEngine == max_uint256, "Assert 7";
}

// Verify revert rules on open
rule open_revert(uint256 index) {
    env e;

    createdUrn = 0;  // Now we can identify if the urn was created

    mathint ownerUrnsCountSender = ownerUrnsCount(e.msg.sender);

    open@withrevert(e, index);
    bool reverted = lastReverted; // `lastReverted` will be modified by `createdUrn.engine(e)`
    if (createdUrn != 0) {
        require createdUrn.engine(e) == currentContract;
    }

    bool revert1 = e.msg.value > 0;
    bool revert2 = to_mathint(index) != ownerUrnsCountSender;
    bool revert3 = ownerUrnsCountSender == max_uint256;

    assert reverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting hope
rule hope(address owner, uint256 index, address usr) {
    env e;

    address other;
    address other2;
    address urn = ownerUrns(owner, index);
    require other != urn || other2 != usr;

    mathint urnCanOtherBefore = urnCan(other, other2);

    hope(e, owner, index, usr);

    mathint urnCanUrnUsrAfter = urnCan(urn, usr);
    mathint urnCanOtherAfter = urnCan(other, other2);

    assert urnCanUrnUsrAfter == 1, "Assert 1";
    assert urnCanOtherAfter == urnCanOtherBefore, "Assert 2";
}

// Verify revert rules on hope
rule hope_revert(address owner, uint256 index, address usr) {
    env e;

    address urn = ownerUrns(owner, index);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    hope@withrevert(e, owner, index, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = owner != e.msg.sender && urnCanUrnSender != 1;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting nope
rule nope(address owner, uint256 index, address usr) {
    env e;

    address other;
    address other2;
    address urn = ownerUrns(owner, index);
    require other != urn || other2 != usr;

    mathint urnCanOtherBefore = urnCan(other, other2);

    nope(e, owner, index, usr);

    mathint urnCanUrnUsrAfter = urnCan(urn, usr);
    mathint urnCanOtherAfter = urnCan(other, other2);

    assert urnCanUrnUsrAfter == 0, "Assert 1";
    assert urnCanOtherAfter == urnCanOtherBefore, "Assert 2";
}

// Verify revert rules on nope
rule nope_revert(address owner, uint256 index, address usr) {
    env e;

    address urn = ownerUrns(owner, index);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    nope@withrevert(e, owner, index, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = owner != e.msg.sender && urnCanUrnSender != 1;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting selectVoteDelegate
rule selectVoteDelegate(address owner, uint256 index, address voteDelegate_) {
    env e;

    address urn = ownerUrns(owner, index);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address prevVoteDelegate = urnVoteDelegates(urn);
    require prevVoteDelegate == addrZero() || prevVoteDelegate == voteDelegate2;

    address other;
    require other != urn;
    address other2;
    require other2 != voteDelegate_ && other2 != prevVoteDelegate && other2 != currentContract;

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint a;
    vatUrnsIlkUrnInk, a = vat.urns(ilk, urn);

    address urnVoteDelegatesOtherBefore = urnVoteDelegates(other);
    mathint mkrBalanceOfPrevVoteDelegateBefore = mkr.balanceOf(prevVoteDelegate);
    mathint mkrBalanceOfNewVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);

    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkrBalanceOfPrevVoteDelegateBefore + mkrBalanceOfNewVoteDelegateBefore + mkrBalanceOfEngineBefore + mkrBalanceOfOtherBefore;

    selectVoteDelegate(e, owner, index, voteDelegate_);

    address urnVoteDelegatesUrnAfter = urnVoteDelegates(urn);
    address urnVoteDelegatesOtherAfter = urnVoteDelegates(other);
    mathint mkrBalanceOfPrevVoteDelegateAfter = mkr.balanceOf(prevVoteDelegate);
    mathint mkrBalanceOfNewVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);

    assert urnVoteDelegatesUrnAfter == voteDelegate_, "Assert 1";
    assert urnVoteDelegatesOtherAfter == urnVoteDelegatesOtherBefore, "Assert 2";
    assert prevVoteDelegate == addrZero() => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore, "Assert 3";
    assert prevVoteDelegate != addrZero() => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore - vatUrnsIlkUrnInk, "Assert 4";
    assert voteDelegate_ == addrZero() => mkrBalanceOfNewVoteDelegateAfter == mkrBalanceOfNewVoteDelegateBefore, "Assert 5";
    assert voteDelegate_ != addrZero() => mkrBalanceOfNewVoteDelegateAfter == mkrBalanceOfNewVoteDelegateBefore + vatUrnsIlkUrnInk, "Assert 6";
    assert prevVoteDelegate == addrZero() && voteDelegate_ == addrZero() || prevVoteDelegate != addrZero() && voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 7";
    assert prevVoteDelegate == addrZero() && voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - vatUrnsIlkUrnInk, "Assert 8";
    assert prevVoteDelegate != addrZero() && voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + vatUrnsIlkUrnInk, "Assert 9";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 10";
}

// Verify revert rules on selectVoteDelegate
rule selectVoteDelegate_revert(address owner, uint256 index, address voteDelegate_) {
    env e;

    address urn = ownerUrns(owner, index);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address prevVoteDelegate = urnVoteDelegates(urn);
    require prevVoteDelegate == addrZero() || prevVoteDelegate == voteDelegate2;

    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);
    mathint urnAuctions = urnAuctions(urn);
    mathint voteDelegateFactoryCreatedVoteDelegate = voteDelegateFactory.created(voteDelegate_);
    bytes32 ilk = ilk();
    mathint vatIlksIlkSpot; mathint a;
    a, a, vatIlksIlkSpot, a, a = vat.ilks(ilk);
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    mathint calcVatIlksIlkRateAfter = dripSummary(ilk);

    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(prevVoteDelegate) + mkr.balanceOf(voteDelegate_) + mkr.balanceOf(currentContract);
    // Practical Vat assumptions
    require vatUrnsIlkUrnInk * vatIlksIlkSpot <= max_uint256;
    require vatUrnsIlkUrnArt * calcVatIlksIlkRateAfter <= max_uint256;
    // TODO: this might be nice to prove in some sort
    require prevVoteDelegate == addrZero() && to_mathint(mkr.balanceOf(currentContract)) >= vatUrnsIlkUrnInk || prevVoteDelegate != addrZero() && to_mathint(mkr.balanceOf(prevVoteDelegate)) >= vatUrnsIlkUrnInk && to_mathint(voteDelegate2.stake(currentContract)) >= vatUrnsIlkUrnInk; // TODO: this might be interesting to be proved
    require voteDelegate.stake(currentContract) + vatUrnsIlkUrnInk <= max_uint256;

    selectVoteDelegate@withrevert(e, owner, index, voteDelegate_);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = owner != e.msg.sender && urnCanUrnSender != 1;
    bool revert4 = urnAuctions > 0;
    bool revert5 = voteDelegate_ != addrZero() && voteDelegateFactoryCreatedVoteDelegate != 1;
    bool revert6 = voteDelegate_ == prevVoteDelegate;
    bool revert7 = vatUrnsIlkUrnArt > 0 && voteDelegate_ != addrZero() && vatUrnsIlkUrnInk * vatIlksIlkSpot < vatUrnsIlkUrnArt * calcVatIlksIlkRateAfter;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7, "Revert rules failed";
}

// Verify correct storage changes for non reverting selectFarm
rule selectFarm(address owner, uint256 index, address farm, uint16 ref) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    require farm == addrZero() || farm == stakingRewards;
    address prevFarm = urnFarms(urn);
    require prevFarm == addrZero() || prevFarm == stakingRewards2;

    address other;
    require other != urn;
    address other2;
    require other2 != farm && other2 != prevFarm && other2 != urn;

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint a;
    vatUrnsIlkUrnInk, a = vat.urns(ilk, urn);

    address urnFarmsOtherBefore = urnFarms(other);
    mathint lsmkrBalanceOfPrevFarmBefore = lsmkr.balanceOf(prevFarm);
    mathint lsmkrBalanceOfNewFarmBefore = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

    // Tokens invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkrBalanceOfPrevFarmBefore + lsmkrBalanceOfNewFarmBefore + lsmkrBalanceOfUrnBefore + lsmkrBalanceOfOtherBefore;

    selectFarm(e, owner, index, farm, ref);

    address urnFarmsUrnAfter = urnFarms(urn);
    address urnFarmsOtherAfter = urnFarms(other);
    mathint lsmkrBalanceOfPrevFarmAfter = lsmkr.balanceOf(prevFarm);
    mathint lsmkrBalanceOfNewFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert urnFarmsUrnAfter == farm, "Assert 1";
    assert urnFarmsOtherAfter == urnFarmsOtherBefore, "Assert 2";
    assert prevFarm == addrZero() => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore, "Assert 3";
    assert prevFarm != addrZero() => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore - vatUrnsIlkUrnInk, "Assert 4";
    assert farm == addrZero() => lsmkrBalanceOfNewFarmAfter == lsmkrBalanceOfNewFarmBefore, "Assert 5";
    assert farm != addrZero() => lsmkrBalanceOfNewFarmAfter == lsmkrBalanceOfNewFarmBefore + vatUrnsIlkUrnInk, "Assert 6";
    assert prevFarm == addrZero() && farm == addrZero() || prevFarm != addrZero() && farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 7";
    assert prevFarm == addrZero() && farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - vatUrnsIlkUrnInk, "Assert 8";
    assert prevFarm != addrZero() && farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + vatUrnsIlkUrnInk, "Assert 9";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 10";
}

// Verify revert rules on selectFarm
rule selectFarm_revert(address owner, uint256 index, address farm, uint16 ref) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    require farm == addrZero() || farm == stakingRewards;
    address prevFarm = urnFarms(urn);
    require prevFarm == addrZero() || prevFarm == stakingRewards2;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);
    mathint urnAuctions = urnAuctions(urn);
    LockstakeEngine.FarmStatus farmsFarm = farms(farm);
    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint a;
    vatUrnsIlkUrnInk, a = vat.urns(ilk, urn);

    // TODO: this might be nice to prove in some sort
    require prevFarm == addrZero() && to_mathint(lsmkr.balanceOf(urn)) >= vatUrnsIlkUrnInk || prevFarm != addrZero() && to_mathint(lsmkr.balanceOf(prevFarm)) >= vatUrnsIlkUrnInk && to_mathint(stakingRewards2.balanceOf(urn)) >= vatUrnsIlkUrnInk;
    // Token invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(prevFarm) + lsmkr.balanceOf(farm) + lsmkr.balanceOf(urn);
    require stakingRewards2.totalSupply() >= stakingRewards2.balanceOf(urn);
    require stakingRewards.totalSupply() >= stakingRewards.balanceOf(urn);
    // Assumption
    require stakingRewards.totalSupply() + vatUrnsIlkUrnInk <= max_uint256;

    selectFarm@withrevert(e, owner, index, farm, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = owner != e.msg.sender && urnCanUrnSender != 1;
    bool revert4 = urnAuctions > 0;
    bool revert5 = farm != addrZero() && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert6 = farm == prevFarm;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
}

// Verify correct storage changes for non reverting lock
rule lock(address owner, uint256 index, uint256 wad, uint16 ref) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    address other;
    require other != e.msg.sender && other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm;

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInkBefore; mathint a;
    vatUrnsIlkUrnInkBefore, a = vat.urns(ilk, urn);
    mathint mkrBalanceOfSenderBefore = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkrBalanceOfSenderBefore + mkrBalanceOfEngineBefore + mkrBalanceOfVoteDelegateBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore + lsmkrBalanceOfOtherBefore;

    lock(e, owner, index, wad, ref);

    mathint vatUrnsIlkUrnInkAfter;
    vatUrnsIlkUrnInkAfter, a = vat.urns(ilk, urn);
    mathint mkrBalanceOfSenderAfter = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert vatUrnsIlkUrnInkAfter == vatUrnsIlkUrnInkBefore + wad, "Assert 1";
    assert mkrBalanceOfSenderAfter == mkrBalanceOfSenderBefore - wad, "Assert 2";
    assert voteDelegate_ == addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "Assert 3";
    assert voteDelegate_ != addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore + wad, "Assert 4";
    assert voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + wad, "Assert 5";
    assert voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 6";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 7";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore + wad, "Assert 8";
    assert farm == addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "Assert 9";
    assert farm != addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore + wad, "Assert 10";
    assert farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + wad, "Assert 11";
    assert farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 12";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 13";
}

// Verify revert rules on lock
rule lock_revert(address owner, uint256 index, uint256 wad, uint16 ref) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt; mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkDust; mathint a;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, a, vatIlksIlkDust = vat.ilks(ilk);

    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // User balance and approval
    require mkr.balanceOf(e.msg.sender) >= wad && mkr.allowance(e.msg.sender, currentContract) >= wad;
    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm);
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    require lsmkr.totalSupply() + wad <= to_mathint(mkr.totalSupply());
    // Practical Vat assumptions
    require vat.live() == 1;
    require vatIlksIlkRate >= RAY() && vatIlksIlkRate <= max_int256();
    require (vatUrnsIlkUrnInk + wad) * vatIlksIlkSpot <= max_uint256;
    require vatIlksIlkRate * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUrnArt;
    require vatUrnsIlkUrnArt == 0 || vatIlksIlkRate * vatUrnsIlkUrnArt >= vatIlksIlkDust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require vatUrnsIlkUrnInk == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    LockstakeEngine.FarmStatus farmsFarm = farms(farm);

    lock@withrevert(e, owner, index, wad, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = to_mathint(wad) > max_int256();
    bool revert4 = farm != addrZero() && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert5 = farm != addrZero() && wad == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting lockSky
rule lockSky(address owner, uint256 index, uint256 skyWad, uint16 ref) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    address other;
    require other != e.msg.sender && other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm;

    mathint mkrSkyRate = mkrSkyRate();

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInkBefore; mathint a;
    vatUrnsIlkUrnInkBefore, a = vat.urns(ilk, urn);
    mathint skyTotalSupplyBefore = sky.totalSupply();
    mathint skyBalanceOfSenderBefore = sky.balanceOf(e.msg.sender);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfSenderBefore = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

    // Happening in constructor
    require mkrSkyRate == to_mathint(mkrSky.rate());
    // Tokens invariants
    require skyTotalSupplyBefore >= skyBalanceOfSenderBefore + sky.balanceOf(currentContract) + sky.balanceOf(mkrSky);
    require mkrTotalSupplyBefore >= mkrBalanceOfSenderBefore + mkrBalanceOfEngineBefore + mkrBalanceOfVoteDelegateBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore + lsmkrBalanceOfOtherBefore;

    lockSky(e, owner, index, skyWad, ref);

    mathint vatUrnsIlkUrnInkAfter;
    vatUrnsIlkUrnInkAfter, a = vat.urns(ilk, urn);
    mathint skyTotalSupplyAfter = sky.totalSupply();
    mathint skyBalanceOfSenderAfter = sky.balanceOf(e.msg.sender);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfSenderAfter = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert vatUrnsIlkUrnInkAfter == vatUrnsIlkUrnInkBefore + skyWad/mkrSkyRate, "Assert 1";
    assert skyTotalSupplyAfter == skyTotalSupplyBefore - skyWad, "Assert 2";
    assert skyBalanceOfSenderAfter == skyBalanceOfSenderBefore - skyWad, "Assert 3";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore + skyWad/mkrSkyRate, "Assert 4";
    assert voteDelegate_ == addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "Assert 5";
    assert voteDelegate_ != addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore + skyWad/mkrSkyRate, "Assert 6";
    assert voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + skyWad/mkrSkyRate, "Assert 7";
    assert voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 8";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 9";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore + skyWad/mkrSkyRate, "Assert 10";
    assert farm == addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "Assert 11";
    assert farm != addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore + skyWad/mkrSkyRate, "Assert 12";
    assert farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + skyWad/mkrSkyRate, "Assert 13";
    assert farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 14";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 15";
}

// Verify revert rules on lockSky
rule lockSky_revert(address owner, uint256 index, uint256 skyWad, uint16 ref) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    mathint mkrSkyRate = mkrSkyRate();

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt; mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkDust; mathint a;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, a, vatIlksIlkDust = vat.ilks(ilk);

    // Happening in constructor
    require mkrSkyRate == to_mathint(mkrSky.rate());
    // Avoid division by zero
    require mkrSkyRate > 0;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    require sky.allowance(currentContract, mkrSky) == max_uint256;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // User balance and approval
    require sky.balanceOf(e.msg.sender) >= skyWad && sky.allowance(e.msg.sender, currentContract) >= skyWad;
    // Tokens invariants
    require to_mathint(sky.totalSupply()) >= sky.balanceOf(e.msg.sender) + sky.balanceOf(currentContract) + sky.balanceOf(mkrSky);
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm);
    // Assumption
    require to_mathint(mkr.totalSupply()) <= max_uint256 - skyWad/mkrSkyRate;
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    require lsmkr.totalSupply() + skyWad/mkrSkyRate <= to_mathint(mkr.totalSupply());
    // Practical Vat assumptions
    require vat.live() == 1;
    require vatIlksIlkRate >= RAY() && vatIlksIlkRate <= max_int256();
    require (vatUrnsIlkUrnInk + skyWad/mkrSkyRate) * vatIlksIlkSpot <= max_uint256;
    require vatIlksIlkRate * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUrnArt;
    require vatUrnsIlkUrnArt == 0 || vatIlksIlkRate * vatUrnsIlkUrnArt >= vatIlksIlkDust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule vatUrnsIlkUrnInkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require vatUrnsIlkUrnInk == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    LockstakeEngine.FarmStatus farmsFarm = farms(farm);

    lockSky@withrevert(e, owner, index, skyWad, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = skyWad/mkrSkyRate > max_int256();
    bool revert4 = farm != addrZero() && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert5 = farm != addrZero() && skyWad/mkrSkyRate == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting free
rule free(address owner, uint256 index, address to, uint256 wad) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    address other;
    require other != to && other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm;

    mathint fee = fee();

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInkBefore; mathint a;
    vatUrnsIlkUrnInkBefore, a = vat.urns(ilk, urn);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfToBefore = mkr.balanceOf(to);
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

    // Happening in constructor
    require fee < WAD();
    // Tokens invariants
    require mkrTotalSupplyBefore >= mkrBalanceOfToBefore + mkrBalanceOfEngineBefore + mkrBalanceOfVoteDelegateBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore + lsmkrBalanceOfOtherBefore;

    free(e, owner, index, to, wad);

    mathint vatUrnsIlkUrnInkAfter;
    vatUrnsIlkUrnInkAfter, a = vat.urns(ilk, urn);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfToAfter = mkr.balanceOf(to);
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert vatUrnsIlkUrnInkAfter == vatUrnsIlkUrnInkBefore - wad, "Assert 1";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - wad * fee / WAD(), "Assert 2";
    assert to != currentContract && to != voteDelegate_   ||
           to == currentContract && voteDelegate_ != addrZero() ||
           to == voteDelegate_ && voteDelegate_ == addrZero() => mkrBalanceOfToAfter == mkrBalanceOfToBefore + (wad - wad * fee / WAD()), "Assert 3";
    assert to == currentContract && voteDelegate_ == addrZero() ||
           to == voteDelegate_ && voteDelegate_ != addrZero() => mkrBalanceOfToAfter == mkrBalanceOfToBefore - wad * fee / WAD(), "Assert 4";
    assert to != voteDelegate_ && voteDelegate_ == addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "Assert 5";
    assert to != voteDelegate_ && voteDelegate_ != addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore - wad, "Assert 6";
    assert to != currentContract && voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - wad, "Assert 7";
    assert to != currentContract && voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 8";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 9";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore - wad, "Assert 10";
    assert farm == addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "Assert 11";
    assert farm != addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore - wad, "Assert 12";
    assert farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - wad, "Assert 13";
    assert farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 14";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 15";
}

// Verify revert rules on free
rule free_revert(address owner, uint256 index, address to, uint256 wad) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    mathint fee = fee();
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt; mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkDust; mathint a;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, a, vatIlksIlkDust = vat.ilks(ilk);

    // Hapenning in constructor
    require fee < WAD();
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    require lsmkr.allowance(urn, currentContract) == max_uint256;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm);
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require voteDelegate_ != addrZero() => to_mathint(voteDelegate.stake(currentContract)) >= vatUrnsIlkUrnInk;
    require voteDelegate_ == addrZero() => to_mathint(mkr.balanceOf(currentContract)) >= vatUrnsIlkUrnInk;
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    // Practical Vat assumptions
    require vat.live() == 1;
    require vatIlksIlkRate >= RAY() && vatIlksIlkRate <= max_int256();
    require (vatUrnsIlkUrnInk - wad) * vatIlksIlkSpot <= max_uint256;
    require vatIlksIlkRate * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUrnArt;
    require vatUrnsIlkUrnArt == 0 || vatIlksIlkRate * vatUrnsIlkUrnArt >= vatIlksIlkDust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require lsmkr.balanceOf(urn) > 0 => farm == addrZero();
    require stakingRewards.balanceOf(urn)  > 0 => farm != addrZero();
    require vatUrnsIlkUrnInk == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    free@withrevert(e, owner, index, to, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = owner != e.msg.sender && urnCanUrnSender != 1;
    bool revert4 = to_mathint(wad) > max_int256();
    bool revert5 = vatUrnsIlkUrnInk < to_mathint(wad) || wad > 0 && (vatUrnsIlkUrnInk - wad) * vatIlksIlkSpot < vatUrnsIlkUrnArt * vatIlksIlkRate;
    bool revert6 = farm != 0 && wad == 0;
    bool revert7 = wad * fee > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7, "Revert rules failed";
}

// Verify correct storage changes for non reverting freeSky
rule freeSky(address owner, uint256 index, address to, uint256 skyWad) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    address other;
    require other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm;
    address other3;
    require other3 != to;

    mathint mkrSkyRate = mkrSkyRate();
    mathint fee = fee();

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInkBefore; mathint a;
    vatUrnsIlkUrnInkBefore, a = vat.urns(ilk, urn);
    mathint skyTotalSupplyBefore = sky.totalSupply();
    mathint skyBalanceOfToBefore = sky.balanceOf(to);
    mathint skyBalanceOfOtherBefore = sky.balanceOf(other3);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

    // Happening in constructor
    require mkrSkyRate == to_mathint(mkrSky.rate());
    require fee < WAD();
    // Tokens invariants
    require skyTotalSupplyBefore >= skyBalanceOfToBefore + skyBalanceOfOtherBefore;
    require mkrTotalSupplyBefore >= mkrBalanceOfEngineBefore + mkrBalanceOfVoteDelegateBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore + lsmkrBalanceOfOtherBefore;

    freeSky(e, owner, index, to, skyWad);

    mathint vatUrnsIlkUrnInkAfter;
    vatUrnsIlkUrnInkAfter, a = vat.urns(ilk, urn);
    mathint skyTotalSupplyAfter = sky.totalSupply();
    mathint skyBalanceOfToAfter = sky.balanceOf(to);
    mathint skyBalanceOfOtherAfter = sky.balanceOf(other3);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert vatUrnsIlkUrnInkAfter == vatUrnsIlkUrnInkBefore - skyWad/mkrSkyRate, "Assert 1";
    assert skyTotalSupplyAfter == skyTotalSupplyBefore + (skyWad/mkrSkyRate - skyWad/mkrSkyRate * fee / WAD()) * mkrSkyRate, "Assert 2";
    assert skyBalanceOfToAfter == skyBalanceOfToBefore + (skyWad/mkrSkyRate - skyWad/mkrSkyRate * fee / WAD()) * mkrSkyRate, "Assert 3";
    assert skyBalanceOfOtherAfter == skyBalanceOfOtherBefore, "Assert 4";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - skyWad/mkrSkyRate, "Assert 5";
    assert to != voteDelegate_ && voteDelegate_ == addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "Assert 6";
    assert to != voteDelegate_ && voteDelegate_ != addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore - skyWad/mkrSkyRate, "Assert 7";
    assert to != currentContract && voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - skyWad/mkrSkyRate, "Assert 8";
    assert to != currentContract && voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 9";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 10";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore - skyWad/mkrSkyRate, "Assert 11";
    assert farm == addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "Assert 12";
    assert farm != addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore - skyWad/mkrSkyRate, "Assert 13";
    assert farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - skyWad/mkrSkyRate, "Assert 14";
    assert farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 15";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 16";
}

// Verify revert rules on freeSky
rule freeSky_revert(address owner, uint256 index, address to, uint256 skyWad) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    mathint mkrSkyRate = mkrSkyRate();
    mathint fee = fee();

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt; mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkDust; mathint a;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, a, vatIlksIlkDust = vat.ilks(ilk);

    // Happening in constructor
    require mkrSkyRate == to_mathint(mkrSky.rate());
    require fee < WAD();
    require mkr.allowance(currentContract, mkrSky) == max_uint256;
    // Avoid division by zero
    require mkrSkyRate > 0;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    require lsmkr.allowance(urn, currentContract) == max_uint256;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // Tokens invariants
    require sky.totalSupply() >= sky.balanceOf(to);
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm);
    // Practical assumption
    require sky.totalSupply() + skyWad <= max_uint256;
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require voteDelegate_ != addrZero() => to_mathint(voteDelegate.stake(currentContract)) >= vatUrnsIlkUrnInk;
    require voteDelegate_ == addrZero() => to_mathint(mkr.balanceOf(currentContract)) >= vatUrnsIlkUrnInk;
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    // Practical Vat assumptions
    require vat.live() == 1;
    require vatIlksIlkRate >= RAY() && vatIlksIlkRate <= max_int256();
    require (vatUrnsIlkUrnInk - skyWad/mkrSkyRate) * vatIlksIlkSpot <= max_uint256;
    require vatIlksIlkRate * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUrnArt;
    require vatUrnsIlkUrnArt == 0 || vatIlksIlkRate * vatUrnsIlkUrnArt >= vatIlksIlkDust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require lsmkr.balanceOf(urn) > 0 => farm == addrZero();
    require stakingRewards.balanceOf(urn)  > 0 => farm != addrZero();
    require vatUrnsIlkUrnInk == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    freeSky@withrevert(e, owner, index, to, skyWad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = owner != e.msg.sender && urnCanUrnSender != 1;
    bool revert4 = to_mathint(skyWad/mkrSkyRate) > max_int256();
    bool revert5 = vatUrnsIlkUrnInk < to_mathint(skyWad/mkrSkyRate) || skyWad/mkrSkyRate > 0 && (vatUrnsIlkUrnInk - skyWad/mkrSkyRate) * vatIlksIlkSpot < vatUrnsIlkUrnArt * vatIlksIlkRate;
    bool revert6 = farm != 0 && skyWad/mkrSkyRate == 0;
    bool revert7 = skyWad/mkrSkyRate * fee > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7, "Revert rules failed";
}

// Verify correct storage changes for non reverting freeNoFee
rule freeNoFee(address owner, uint256 index, address to, uint256 wad) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    address other;
    require other != to && other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm;

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInkBefore; mathint a;
    vatUrnsIlkUrnInkBefore, a = vat.urns(ilk, urn);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfToBefore = mkr.balanceOf(to);
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

    // Tokens invariants
    require mkrTotalSupplyBefore >= mkrBalanceOfToBefore + mkrBalanceOfEngineBefore + mkrBalanceOfVoteDelegateBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore + lsmkrBalanceOfOtherBefore;

    freeNoFee(e, owner, index, to, wad);

    mathint vatUrnsIlkUrnInkAfter;
    vatUrnsIlkUrnInkAfter, a = vat.urns(ilk, urn);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfToAfter = mkr.balanceOf(to);
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert vatUrnsIlkUrnInkAfter == vatUrnsIlkUrnInkBefore - wad, "Assert 1";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore, "Assert 2";
    assert to != currentContract && to != voteDelegate_   ||
           to == currentContract && voteDelegate_ != addrZero() ||
           to == voteDelegate_ && voteDelegate_ == addrZero() => mkrBalanceOfToAfter == mkrBalanceOfToBefore + wad, "Assert 3";
    assert to == currentContract && voteDelegate_ == addrZero() ||
           to == voteDelegate_ && voteDelegate_ != addrZero() => mkrBalanceOfToAfter == mkrBalanceOfToBefore, "Assert 4";
    assert to != voteDelegate_ && voteDelegate_ == addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "Assert 5";
    assert to != voteDelegate_ && voteDelegate_ != addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore - wad, "Assert 6";
    assert to != currentContract && voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - wad, "Assert 7";
    assert to != currentContract && voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 8";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 9";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore - wad, "Assert 10";
    assert farm == addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "Assert 11";
    assert farm != addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore - wad, "Assert 12";
    assert farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - wad, "Assert 13";
    assert farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 14";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 15";
}

// Verify revert rules on freeNoFee
rule freeNoFee_revert(address owner, uint256 index, address to, uint256 wad) {
    env e;

    address urn = ownerUrns(owner, index);
    require urn == lockstakeUrn;

    mathint wardsSender = wards(e.msg.sender);

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt; mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkDust; mathint a;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, a, vatIlksIlkDust = vat.ilks(ilk);

    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    require lsmkr.allowance(urn, currentContract) == max_uint256;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm);
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require voteDelegate_ != addrZero() => to_mathint(voteDelegate.stake(currentContract)) >= vatUrnsIlkUrnInk;
    require voteDelegate_ == addrZero() => to_mathint(mkr.balanceOf(currentContract)) >= vatUrnsIlkUrnInk;
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    // Practical Vat assumptions
    require vat.live() == 1;
    require vatIlksIlkRate >= RAY() && vatIlksIlkRate <= max_int256();
    require (vatUrnsIlkUrnInk - wad) * vatIlksIlkSpot <= max_uint256;
    require vatIlksIlkRate * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUrnArt;
    require vatUrnsIlkUrnArt == 0 || vatIlksIlkRate * vatUrnsIlkUrnArt >= vatIlksIlkDust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require lsmkr.balanceOf(urn) > 0 => farm == addrZero();
    require stakingRewards.balanceOf(urn)  > 0 => farm != addrZero();
    require vatUrnsIlkUrnInk == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    freeNoFee@withrevert(e, owner, index, to, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = urn == addrZero();
    bool revert4 = owner != e.msg.sender && urnCanUrnSender != 1;
    bool revert5 = to_mathint(wad) > max_int256();
    bool revert6 = vatUrnsIlkUrnInk < to_mathint(wad) || wad > 0 && (vatUrnsIlkUrnInk - wad) * vatIlksIlkSpot < vatUrnsIlkUrnArt * vatIlksIlkRate;
    bool revert7 = farm != 0 && wad == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7, "Revert rules failed";
}

// Verify correct storage changes for non reverting draw
rule draw(address owner, uint256 index, address to, uint256 wad) {
    env e;

    address other;
    require other != to;

    address urn = ownerUrns(owner, index);
    bytes32 ilk = ilk();
    mathint vatIlksIlkArtBefore; mathint a;
    vatIlksIlkArtBefore, a, a, a, a = vat.ilks(ilk);
    mathint vatUrnsIlkUrnArtBefore;
    a, vatUrnsIlkUrnArtBefore = vat.urns(ilk, urn);
    mathint usdsTotalSupplyBefore = usds.totalSupply();
    mathint usdsBalanceOfToBefore = usds.balanceOf(to);
    mathint usdsBalanceOfOtherBefore = usds.balanceOf(other);

    // Tokens invariants
    require usdsTotalSupplyBefore >= usdsBalanceOfToBefore + usdsBalanceOfOtherBefore;

    draw(e, owner, index, to, wad);

    mathint vatIlksIlkArtAfter; mathint vatIlksIlkRateAfter;
    vatIlksIlkArtAfter, vatIlksIlkRateAfter, a, a, a = vat.ilks(ilk);
    mathint vatUrnsIlkUrnArtAfter;
    a, vatUrnsIlkUrnArtAfter = vat.urns(ilk, urn);
    mathint usdsTotalSupplyAfter = usds.totalSupply();
    mathint usdsBalanceOfToAfter = usds.balanceOf(to);
    mathint usdsBalanceOfOtherAfter = usds.balanceOf(other);

    assert vatIlksIlkArtAfter == vatIlksIlkArtBefore + _divup(wad * RAY(), vatIlksIlkRateAfter), "Assert 1";
    assert vatUrnsIlkUrnArtAfter == vatUrnsIlkUrnArtBefore + _divup(wad * RAY(), vatIlksIlkRateAfter), "Assert 2";
    assert usdsTotalSupplyAfter == usdsTotalSupplyBefore + wad, "Assert 3";
    assert usdsBalanceOfToAfter == usdsBalanceOfToBefore + wad, "Assert 4";
    assert usdsBalanceOfOtherAfter == usdsBalanceOfOtherBefore, "Assert 5";
}

// Verify revert rules on draw
rule draw_revert(address owner, uint256 index, address to, uint256 wad) {
    env e;

    address urn = ownerUrns(owner, index);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    bytes32 ilk = ilk();
    mathint vatDebt = vat.debt();
    mathint vatLine = vat.Line();
    mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkLine; mathint vatIlksIlkDust; mathint a;
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, vatIlksIlkLine, vatIlksIlkDust = vat.ilks(ilk);
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    mathint usdsTotalSupply = usds.totalSupply();
    mathint usdsBalanceOfTo = usds.balanceOf(to);

    storage init = lastStorage;
    mathint calcVatIlksIlkRateAfter = dripSummary(ilk);
    // Avoid division by zero
    require calcVatIlksIlkRateAfter > 0;

    mathint dart = _divup(wad * RAY(), calcVatIlksIlkRateAfter);

    // Happening in constructor
    require vat.can(currentContract, usdsJoin) == 1;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    // Tokens invariants
    require usdsTotalSupply >= usdsBalanceOfTo;
    // Practical token assumtiopns
    require usdsTotalSupply + wad <= max_uint256;
    // Practical Vat assumptions
    require vat.live() == 1;
    require vat.wards(jug) == 1;
    require calcVatIlksIlkRateAfter >= RAY() && calcVatIlksIlkRateAfter <= max_int256();
    require vatUrnsIlkUrnInk * vatIlksIlkSpot <= max_uint256;
    require calcVatIlksIlkRateAfter * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUrnArt;
    require vatIlksIlkArt + dart <= max_uint256;
    require calcVatIlksIlkRateAfter * dart <= max_int256();
    require vatDebt + vatIlksIlkArt * (calcVatIlksIlkRateAfter - vatIlksIlkRate) + (calcVatIlksIlkRateAfter * dart) <= max_int256();
    require vat.dai(currentContract) + (dart * calcVatIlksIlkRateAfter) <= max_uint256;
    require vat.dai(usdsJoin) + (dart * calcVatIlksIlkRateAfter) <= max_uint256;
    // Other assumptions
    require wad * RAY() <= max_uint256;

    draw@withrevert(e, owner, index, to, wad) at init;

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = owner != e.msg.sender && urnCanUrnSender != 1;
    bool revert4 = to_mathint(dart) > max_int256();
    bool revert5 = dart > 0 && ((vatIlksIlkArt + dart) * calcVatIlksIlkRateAfter > vatIlksIlkLine || vatDebt + vatIlksIlkArt * (calcVatIlksIlkRateAfter - vatIlksIlkRate) + (calcVatIlksIlkRateAfter * dart) > vatLine);
    bool revert6 = dart > 0 && vatUrnsIlkUrnInk * vatIlksIlkSpot < (vatUrnsIlkUrnArt + dart) * calcVatIlksIlkRateAfter;
    bool revert7 = vatUrnsIlkUrnArt + dart > 0 && calcVatIlksIlkRateAfter * (vatUrnsIlkUrnArt + dart) < vatIlksIlkDust;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7, "Revert rules failed";
}

// Verify correct storage changes for non reverting wipe
rule wipe(address owner, uint256 index, uint256 wad) {
    env e;

    address other;
    require other != e.msg.sender;

    address urn = ownerUrns(owner, index);
    bytes32 ilk = ilk();
    mathint vatIlksIlkArtBefore; mathint vatIlksIlkRate; mathint a;
    vatIlksIlkArtBefore, vatIlksIlkRate, a, a, a = vat.ilks(ilk);
    mathint vatUrnsIlkUrnArtBefore;
    a, vatUrnsIlkUrnArtBefore = vat.urns(ilk, urn);
    mathint usdsTotalSupplyBefore = usds.totalSupply();
    mathint usdsBalanceOfSenderBefore = usds.balanceOf(e.msg.sender);
    mathint usdsBalanceOfOtherBefore = usds.balanceOf(other);

    // Tokens invariants
    require usdsTotalSupplyBefore >= usdsBalanceOfSenderBefore + usdsBalanceOfOtherBefore;

    wipe(e, owner, index, wad);

    mathint vatIlksIlkArtAfter;
    vatIlksIlkArtAfter, a, a, a, a = vat.ilks(ilk);
    mathint vatUrnsIlkUrnArtAfter;
    a, vatUrnsIlkUrnArtAfter = vat.urns(ilk, urn);
    mathint usdsTotalSupplyAfter = usds.totalSupply();
    mathint usdsBalanceOfSenderAfter = usds.balanceOf(e.msg.sender);
    mathint usdsBalanceOfOtherAfter = usds.balanceOf(other);

    assert vatIlksIlkArtAfter == vatIlksIlkArtBefore - wad * RAY() / vatIlksIlkRate, "Assert 1";
    assert vatUrnsIlkUrnArtAfter == vatUrnsIlkUrnArtBefore - wad * RAY() / vatIlksIlkRate, "Assert 2";
    assert usdsTotalSupplyAfter == usdsTotalSupplyBefore - wad, "Assert 3";
    assert usdsBalanceOfSenderAfter == usdsBalanceOfSenderBefore - wad, "Assert 4";
    assert usdsBalanceOfOtherAfter == usdsBalanceOfOtherBefore, "Assert 5";
}

// Verify revert rules on wipe
rule wipe_revert(address owner, uint256 index, uint256 wad) {
    env e;

    address urn = ownerUrns(owner, index);
    bytes32 ilk = ilk();
    mathint vatDebt = vat.debt();
    mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkLine; mathint vatIlksIlkDust; mathint a;
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, vatIlksIlkLine, vatIlksIlkDust = vat.ilks(ilk);
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    mathint usdsTotalSupply = usds.totalSupply();
    mathint usdsBalanceOfSender = usds.balanceOf(e.msg.sender);

    // Avoid division by zero
    require vatIlksIlkRate > 0;

    mathint dart = wad * RAY() / vatIlksIlkRate;

    // Happening in constructor
    require usds.allowance(currentContract, usdsJoin) == max_uint256;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    // Tokens invariants
    require usdsTotalSupply >= usdsBalanceOfSender + usds.balanceOf(currentContract) + usds.balanceOf(usdsJoin);
    // Practical token assumtiopns
    require usdsBalanceOfSender >= to_mathint(wad);
    require usds.allowance(e.msg.sender, currentContract) >= wad;
    // Practical Vat assumptions
    require vat.live() == 1;
    require vat.wards(jug) == 1;
    require vatIlksIlkRate >= RAY() && vatIlksIlkRate <= max_int256();
    require vatUrnsIlkUrnInk * vatIlksIlkSpot <= max_uint256;
    require vatIlksIlkRate * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUrnArt;
    require vatIlksIlkRate * -dart >= min_int256();
    require vatDebt >= vatIlksIlkRate * dart;
    require vat.dai(currentContract) + wad * RAY() <= max_uint256;
    require to_mathint(vat.dai(usdsJoin)) >= wad * RAY();
    // Other assumptions
    require wad * RAY() <= max_uint256;

    wipe@withrevert(e, owner, index, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = to_mathint(dart) > max_int256();
    bool revert4 = vatUrnsIlkUrnArt < dart;
    bool revert5 = vatUrnsIlkUrnArt - dart > 0 && vatIlksIlkRate * (vatUrnsIlkUrnArt - dart) < vatIlksIlkDust;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting wipeAll
rule wipeAll(address owner, uint256 index) {
    env e;

    address other;
    require other != e.msg.sender;

    address urn = ownerUrns(owner, index);
    bytes32 ilk = ilk();
    mathint vatIlksIlkArtBefore; mathint vatIlksIlkRate; mathint a;
    vatIlksIlkArtBefore, vatIlksIlkRate, a, a, a = vat.ilks(ilk);
    mathint vatUrnsIlkUrnArtBefore;
    a, vatUrnsIlkUrnArtBefore = vat.urns(ilk, urn);
    mathint wad = _divup(vatUrnsIlkUrnArtBefore * vatIlksIlkRate, RAY());
    mathint usdsTotalSupplyBefore = usds.totalSupply();
    mathint usdsBalanceOfSenderBefore = usds.balanceOf(e.msg.sender);
    mathint usdsBalanceOfOtherBefore = usds.balanceOf(other);

    // Tokens invariants
    require usdsTotalSupplyBefore >= usdsBalanceOfSenderBefore + usdsBalanceOfOtherBefore;

    wipeAll(e, owner, index);

    mathint vatIlksIlkArtAfter;
    vatIlksIlkArtAfter, a, a, a, a = vat.ilks(ilk);
    mathint vatUrnsIlkUrnArtAfter;
    a, vatUrnsIlkUrnArtAfter = vat.urns(ilk, urn);
    mathint usdsTotalSupplyAfter = usds.totalSupply();
    mathint usdsBalanceOfSenderAfter = usds.balanceOf(e.msg.sender);
    mathint usdsBalanceOfOtherAfter = usds.balanceOf(other);

    assert vatIlksIlkArtAfter == vatIlksIlkArtBefore - vatUrnsIlkUrnArtBefore, "Assert 1";
    assert vatUrnsIlkUrnArtAfter == 0, "Assert 2";
    assert usdsTotalSupplyAfter == usdsTotalSupplyBefore - wad, "Assert 3";
    assert usdsBalanceOfSenderAfter == usdsBalanceOfSenderBefore - wad, "Assert 4";
    assert usdsBalanceOfOtherAfter == usdsBalanceOfOtherBefore, "Assert 5";
}

// Verify revert rules on wipeAll
rule wipeAll_revert(address owner, uint256 index) {
    env e;

    address urn = ownerUrns(owner, index);
    bytes32 ilk = ilk();
    mathint vatDebt = vat.debt();
    mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkLine; mathint vatIlksIlkDust; mathint a;
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, vatIlksIlkLine, vatIlksIlkDust = vat.ilks(ilk);
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    mathint usdsTotalSupply = usds.totalSupply();
    mathint usdsBalanceOfSender = usds.balanceOf(e.msg.sender);

    mathint wad = _divup(vatUrnsIlkUrnArt * vatIlksIlkRate, RAY());

    // Happening in constructor
    require usds.allowance(currentContract, usdsJoin) == max_uint256;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    // Tokens invariants
    require usdsTotalSupply >= usdsBalanceOfSender + usds.balanceOf(currentContract) + usds.balanceOf(usdsJoin);
    // Practical token assumtiopns
    require usdsBalanceOfSender >= to_mathint(wad);
    require to_mathint(usds.allowance(e.msg.sender, currentContract)) >= wad;
    // Practical Vat assumptions
    require vat.live() == 1;
    require vat.wards(jug) == 1;
    require vatIlksIlkRate >= RAY() && vatIlksIlkRate <= max_int256();
    require vatUrnsIlkUrnInk * vatIlksIlkSpot <= max_uint256;
    require vatIlksIlkRate * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUrnArt;
    require vatIlksIlkRate * -vatUrnsIlkUrnArt >= min_int256();
    require vatDebt >= vatIlksIlkRate * vatUrnsIlkUrnArt;
    require vat.dai(currentContract) + wad * RAY() <= max_uint256;
    require to_mathint(vat.dai(usdsJoin)) >= wad * RAY();
    // Other assumptions
    require wad * RAY() <= max_uint256;

    wipeAll@withrevert(e, owner, index);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = to_mathint(vatUrnsIlkUrnArt) > max_int256();

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting getReward
rule getReward(address owner, uint256 index, address farm, address to) {
    env e;

    address urn = ownerUrns(owner, index);
    address other;
    require other != to && other != urn && other != farm;

    require urn == lockstakeUrn;
    require farm == stakingRewards;
    require stakingRewards.rewardsToken() == rewardsToken;

    mathint farmRewardsUrnBefore = stakingRewards.rewards(urn);
    mathint rewardsTokenBalanceOfToBefore = rewardsToken.balanceOf(to);
    mathint rewardsTokenBalanceOfUrnBefore = rewardsToken.balanceOf(urn);
    mathint rewardsTokenBalanceOfFarmBefore = rewardsToken.balanceOf(farm);
    mathint rewardsTokenBalanceOfOtherBefore = rewardsToken.balanceOf(other);

    // Tokens invariants
    require to_mathint(rewardsToken.totalSupply()) >= rewardsTokenBalanceOfToBefore + rewardsTokenBalanceOfUrnBefore + rewardsTokenBalanceOfFarmBefore + rewardsTokenBalanceOfOtherBefore;

    getReward(e, owner, index, farm, to);

    mathint farmRewardsUrnAfter = stakingRewards.rewards(urn);
    mathint rewardsTokenBalanceOfToAfter = rewardsToken.balanceOf(to);
    mathint rewardsTokenBalanceOfUrnAfter = rewardsToken.balanceOf(urn);
    mathint rewardsTokenBalanceOfFarmAfter = rewardsToken.balanceOf(farm);
    mathint rewardsTokenBalanceOfOtherAfter = rewardsToken.balanceOf(other);

    assert farmRewardsUrnAfter == 0, "Assert 1";
    assert to != urn && to != farm => rewardsTokenBalanceOfToAfter == rewardsTokenBalanceOfToBefore + rewardsTokenBalanceOfUrnBefore + farmRewardsUrnBefore, "Assert 2";
    assert to == urn => rewardsTokenBalanceOfToAfter == rewardsTokenBalanceOfToBefore + farmRewardsUrnBefore, "Assert 3";
    assert to == farm => rewardsTokenBalanceOfToAfter == rewardsTokenBalanceOfToBefore + rewardsTokenBalanceOfUrnBefore, "Assert 4";
    assert to != urn => rewardsTokenBalanceOfUrnAfter == 0, "Assert 5";
    assert to != farm => rewardsTokenBalanceOfFarmAfter == rewardsTokenBalanceOfFarmBefore - farmRewardsUrnBefore, "Assert 6";
    assert rewardsTokenBalanceOfOtherAfter == rewardsTokenBalanceOfOtherBefore, "Assert 7";
}

// Verify revert rules on getReward
rule getReward_revert(address owner, uint256 index, address farm, address to) {
    env e;

    address urn = ownerUrns(owner, index);
    require farm == stakingRewards;
    require stakingRewards.rewardsToken() == rewardsToken;

    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);
    LockstakeEngine.FarmStatus farmsFarm = farms(farm);

    // Tokens invariants
    require to_mathint(rewardsToken.totalSupply()) >= rewardsToken.balanceOf(to) + rewardsToken.balanceOf(urn) + rewardsToken.balanceOf(farm);

    // Assumption from the farm
    require rewardsToken.balanceOf(farm) >= stakingRewards.rewards(urn);

    getReward@withrevert(e, owner, index, farm, to);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urn == addrZero();
    bool revert3 = owner != e.msg.sender && urnCanUrnSender != 1;
    bool revert4 = farmsFarm == LockstakeEngine.FarmStatus.UNSUPPORTED;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting onKick
rule onKick(address urn, uint256 wad) {
    env e;

    require urn == lockstakeUrn;
    address prevVoteDelegate = urnVoteDelegates(urn);
    require prevVoteDelegate == addrZero() || prevVoteDelegate == voteDelegate;
    address prevFarm = urnFarms(urn);
    require prevFarm == addrZero() || prevFarm == stakingRewards;

    address other;
    require other != urn;
    address other2;
    require other2 != prevVoteDelegate && other2 != currentContract;
    address other3;
    require other3 != prevFarm && other3 != urn;

    bytes32 ilk = ilk();
    mathint vatUrnsIlkUrnInk; mathint a;
    vatUrnsIlkUrnInk, a = vat.urns(ilk, urn);

    address urnVoteDelegatesOtherBefore = urnVoteDelegates(other);
    address urnFarmsOtherBefore = urnFarms(other);
    mathint urnAuctionsUrnBefore = urnAuctions(urn);
    mathint urnAuctionsOtherBefore = urnAuctions(other);
    mathint mkrBalanceOfPrevVoteDelegateBefore = mkr.balanceOf(prevVoteDelegate);
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfPrevFarmBefore = lsmkr.balanceOf(prevFarm);
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other3);

    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkrBalanceOfPrevVoteDelegateBefore + mkrBalanceOfEngineBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfPrevFarmBefore + lsmkrBalanceOfUrnBefore + lsmkrBalanceOfOtherBefore;

    onKick(e, urn, wad);

    address urnVoteDelegatesUrnAfter = urnVoteDelegates(urn);
    address urnVoteDelegatesOtherAfter = urnVoteDelegates(other);
    address urnFarmsUrnAfter = urnFarms(urn);
    address urnFarmsOtherAfter = urnFarms(other);
    mathint urnAuctionsUrnAfter = urnAuctions(urn);
    mathint urnAuctionsOtherAfter = urnAuctions(other);
    mathint mkrBalanceOfPrevVoteDelegateAfter = mkr.balanceOf(prevVoteDelegate);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfPrevFarmAfter = lsmkr.balanceOf(prevFarm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other3);

    assert urnVoteDelegatesUrnAfter == addrZero(), "Assert 1";
    assert urnVoteDelegatesOtherAfter == urnVoteDelegatesOtherBefore, "Assert 2";
    assert urnFarmsUrnAfter == addrZero(), "Assert 3";
    assert urnFarmsOtherAfter == urnFarmsOtherBefore, "Assert 4";
    assert urnAuctionsUrnAfter == urnAuctionsUrnBefore + 1, "Assert 5";
    assert urnAuctionsOtherAfter == urnAuctionsOtherBefore, "Assert 6";
    assert prevVoteDelegate == addrZero() => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore, "Assert 7";
    assert prevVoteDelegate != addrZero() => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore - vatUrnsIlkUrnInk - wad, "Assert 8";
    assert prevVoteDelegate == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 9";
    assert prevVoteDelegate != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + vatUrnsIlkUrnInk + wad, "Assert 10";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 11";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore - wad, "Assert 12";
    assert prevFarm == addrZero() => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore, "Assert 13";
    assert prevFarm != addrZero() => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore - vatUrnsIlkUrnInk - wad, "Assert 14";
    assert prevFarm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - wad, "Assert 15";
    assert prevFarm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + vatUrnsIlkUrnInk, "Assert 16";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 17";
}

// Verify revert rules on onKick
rule onKick_revert(address urn, uint256 wad) {
    env e;

    require urn == lockstakeUrn;
    address prevVoteDelegate = urnVoteDelegates(urn);
    require prevVoteDelegate == addrZero() || prevVoteDelegate == voteDelegate;
    address prevFarm = urnFarms(urn);
    require prevFarm == addrZero() || prevFarm == stakingRewards;

    mathint wardsSender = wards(e.msg.sender);
    mathint urnAuctionsUrn = urnAuctions(urn);
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk(), urn);

    // Happening in urn init
    require lsmkr.allowance(urn, currentContract) == max_uint256;
    // Tokens invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(prevFarm) + lsmkr.balanceOf(urn) + lsmkr.balanceOf(currentContract);
    require stakingRewards.totalSupply() >= stakingRewards.balanceOf(urn);
    // VoteDelegate assumptions
    require prevVoteDelegate == addrZero() || to_mathint(voteDelegate.stake(currentContract)) >= vatUrnsIlkUrnInk + wad;
    require prevVoteDelegate == addrZero() || mkr.balanceOf(voteDelegate) >= voteDelegate.stake(currentContract);
    // StakingRewards assumptions
    require prevFarm == addrZero() && lsmkr.balanceOf(urn) >= wad ||
            prevFarm != addrZero() && to_mathint(stakingRewards.balanceOf(urn)) >= vatUrnsIlkUrnInk + wad && to_mathint(lsmkr.balanceOf(prevFarm)) >= vatUrnsIlkUrnInk + wad;
    // LockstakeClipper assumption
    require wad > 0;
    // Practical assumption (vatUrnsIlkUrnInk + wad should be the same than the vatUrnsIlkUrnInk prev to the kick call)
    require vatUrnsIlkUrnInk + wad <= max_uint256;

    onKick@withrevert(e, urn, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = urnAuctionsUrn == max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting onTake
rule onTake(address urn, address who, uint256 wad) {
    env e;

    address other;
    require other != currentContract && other != who;

    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfWhoBefore = mkr.balanceOf(who);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other);

    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkrBalanceOfEngineBefore + mkrBalanceOfWhoBefore + mkrBalanceOfOtherBefore;

    onTake(e, urn, who, wad);

    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfWhoAfter = mkr.balanceOf(who);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);

    assert who != currentContract => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - wad, "Assert 1";
    assert who != currentContract => mkrBalanceOfWhoAfter == mkrBalanceOfWhoBefore + wad, "Assert 2";
    assert who == currentContract => mkrBalanceOfWhoAfter == mkrBalanceOfWhoBefore, "Assert 3";
}

// Verify revert rules on onTake
rule onTake_revert(address urn, address who, uint256 wad) {
    env e;

    mathint wardsSender = wards(e.msg.sender);
    mathint mkrBalanceOfEngine = mkr.balanceOf(currentContract);

    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkrBalanceOfEngine + mkr.balanceOf(who);
    // LockstakeClipper assumption
    require mkrBalanceOfEngine >= to_mathint(wad);

    onTake@withrevert(e, urn, who, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting onRemove
rule onRemove(address urn, uint256 sold, uint256 left) {
    env e;

    address other;
    require other != urn;
    address other2;
    require other2 != currentContract;

    bytes32 ilk = ilk();
    mathint fee = fee();
    mathint urnAuctionsUrnBefore = urnAuctions(urn);
    mathint urnAuctionsOtherBefore = urnAuctions(other);
    mathint vatUrnsIlkUrnInkBefore; mathint a;
    vatUrnsIlkUrnInkBefore, a = vat.urns(ilk, urn);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other);

    // Happening in constructor
    require fee < WAD();
    // Tokens invariants
    require mkrTotalSupplyBefore >= mkrBalanceOfEngineBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfOtherBefore;

    mathint burn = _min(sold * fee / (WAD() - fee), left);
    mathint refund = left - burn;

    onRemove(e, urn, sold, left);

    mathint urnAuctionsUrnAfter = urnAuctions(urn);
    mathint urnAuctionsOtherAfter = urnAuctions(other);
    mathint vatUrnsIlkUrnInkAfter;
    vatUrnsIlkUrnInkAfter, a = vat.urns(ilk, urn);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other);

    assert urnAuctionsUrnAfter == urnAuctionsUrnBefore - 1, "Assert 1";
    assert urnAuctionsOtherAfter == urnAuctionsOtherBefore, "Assert 2";
    assert refund > 0 => vatUrnsIlkUrnInkAfter == vatUrnsIlkUrnInkBefore + refund, "Assert 3";
    assert refund == 0 => vatUrnsIlkUrnInkAfter == vatUrnsIlkUrnInkBefore, "Assert 4";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - burn, "Assert 5";
    assert mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - burn, "Assert 6";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 7";
    assert refund > 0 => lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore + refund, "Assert 8";
    assert refund == 0 => lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore, "Assert 9";
    assert refund > 0 => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + refund, "Assert 10";
    assert refund == 0 => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 11";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 12";
}

// Verify revert rules on onRemove
rule onRemove_revert(address urn, uint256 sold, uint256 left) {
    env e;

    mathint wardsSender = wards(e.msg.sender);
    bytes32 ilk = ilk();
    mathint fee = fee();
    mathint urnAuctionsUrn = urnAuctions(urn);
    mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint a;
    vatIlksIlkArt, vatIlksIlkRate, a, a, a = vat.ilks(ilk);
    mathint vatUrnsIlkUrnInk; mathint vatUrnsIlkUrnArt;
    vatUrnsIlkUrnInk, vatUrnsIlkUrnArt = vat.urns(ilk, urn);
    mathint mkrTotalSupply = mkr.totalSupply();
    mathint mkrBalanceOfEngine = mkr.balanceOf(currentContract);
    mathint lsmkrTotalSupply = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrn = lsmkr.balanceOf(urn);

    // Happening in constructor
    require fee < WAD();
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // Tokens invariants
    require mkrTotalSupply >= mkrBalanceOfEngine;
    require lsmkrTotalSupply >= lsmkrBalanceOfUrn;

    require sold * fee < max_uint256;
    mathint burn = _min(sold * fee / (WAD() - fee), left);
    mathint refund = left - burn;

    // Practical Vat assumptions
    require vat.live() == 1;
    require vat.wards(currentContract) == 1;
    require vatUrnsIlkUrnInk + refund <= max_uint256;
    require vatIlksIlkRate <= max_int256();
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Practical token assumptions
    require lsmkrTotalSupply + refund <= max_uint256;
    // Assumption from LockstakeClipper
    require mkrBalanceOfEngine >= burn;
    require urn != lsmkr && urn != addrZero();

    onRemove@withrevert(e, urn, sold, left);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = refund > max_int256();
    bool revert4 = urnAuctionsUrn == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}
