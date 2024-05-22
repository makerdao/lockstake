// LockstakeEngine.spec

using MulticallExecutor as multicallExecutor;
using LockstakeUrn as lockstakeUrn;
using Vat as vat;
using MkrMock as mkr;
using LockstakeMkr as lsmkr;
using VoteDelegateMock as voteDelegate;
using VoteDelegate2Mock as voteDelegate2;
using VoteDelegateFactoryMock as voteDelegateFactory;
using StakingRewardsMock as stakingRewards;
using StakingRewards2Mock as stakingRewards2;
using MkrNgtMock as mkrNgt;
using NgtMock as ngt;
using NstMock as nst;
using NstJoinMock as nstJoin;
using Jug as jug;
using RewardsMock as rewardsToken;

methods {
    // storage variables
    function wards(address) external returns (uint256) envfree;
    function farms(address) external returns (LockstakeEngine.FarmStatus) envfree;
    function usrAmts(address) external returns (uint256) envfree;
    function urnOwners(address) external returns (address) envfree;
    function urnCan(address,address) external returns (uint256) envfree;
    function urnVoteDelegates(address) external returns (address) envfree;
    function urnFarms(address) external returns (address) envfree;
    function urnAuctions(address) external returns (uint256) envfree;
    function jug() external returns (address) envfree;
    // immutables
    function voteDelegateFactory() external returns (address) envfree;
    function vat() external returns (address) envfree;
    function nstJoin() external returns (address) envfree;
    function nst() external returns (address) envfree;
    function ilk() external returns (bytes32) envfree;
    function mkr() external returns (address) envfree;
    function lsmkr() external returns (address) envfree;
    function fee() external returns (uint256) envfree;
    function nst() external returns (address) envfree;
    function ngt() external returns (address) envfree;
    function mkrNgtRate() external returns (uint256) envfree;
    function urnImplementation() external returns (address) envfree;
    // custom getters
    function getUrn(address,uint256) external returns (address) envfree;
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
    function ngt.allowance(address,address) external returns (uint256) envfree;
    function ngt.balanceOf(address) external returns (uint256) envfree;
    function ngt.totalSupply() external returns (uint256) envfree;
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
    function mkrNgt.rate() external returns (uint256) envfree;
    function nst.allowance(address,address) external returns (uint256) envfree;
    function nst.balanceOf(address) external returns (uint256) envfree;
    function nst.totalSupply() external returns (uint256) envfree;
    function jug.vow() external returns (address) envfree;
    function rewardsToken.balanceOf(address) external returns (uint256) envfree;
    function rewardsToken.totalSupply() external returns (uint256) envfree;
    //
    function voteDelegate.stake(address) external returns (uint256) envfree;
    function voteDelegate2.stake(address) external returns (uint256) envfree;
    function voteDelegateFactory.created(address) external returns (uint256) envfree;
    function jug.drip(bytes32 ilk) external returns (uint256) => dripSummary(ilk);
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
    function _._ external => DISPATCH [
        currentContract.open(uint256),
        currentContract.hope(address,address),
        currentContract.nope(address,address),
        currentContract.selectVoteDelegate(address,address),
        currentContract.selectFarm(address,address,uint16),
        currentContract.lock(address,uint256,uint16),
        currentContract.lockNgt(address,uint256,uint16),
        currentContract.free(address,address,uint256),
        currentContract.freeNgt(address,address,uint256),
        currentContract.freeNoFee(address,address,uint256),
        currentContract.draw(address,address,uint256),
        currentContract.wipe(address,uint256),
        currentContract.wipeAll(address),
        currentContract.getReward(address,address,address)
    ] default HAVOC_ALL;
}

definition addrZero() returns address = 0x0000000000000000000000000000000000000000;
definition max_int256() returns mathint = 2^255 - 1;
definition min_int256() returns mathint = -2^255;
definition WAD() returns mathint = 10^18;
definition RAY() returns mathint = 10^27;

definition _divup(mathint x, mathint y) returns mathint = x != 0 ? ((x - 1) / y) + 1 : 0;

ghost mathint duty;
ghost mathint timeDiff;

function dripSummary(bytes32 ilk) returns uint256 {
    env e;
    require duty >= RAY();
    uint256 prev; uint256 a;
    a, prev, a, a, a = vat.ilks(ilk);
    uint256 rate = timeDiff == 0 ? prev : require_uint256(duty * timeDiff * prev / RAY());
    vat.fold(e, ilk, jug.vow(), require_int256(rate - prev));
    return rate;
}

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) filtered { f -> f.selector != sig:multicall(bytes[]).selector  } {
    env e;

    address anyAddr;
    address anyAddr2;

    bytes32 ilk = ilk();

    mathint wardsBefore = wards(anyAddr);
    LockstakeEngine.FarmStatus farmsBefore = farms(anyAddr);
    mathint usrAmtsBefore = usrAmts(anyAddr);
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
    mathint usrAmtsAfter = usrAmts(anyAddr);
    address urnOwnersAfter = urnOwners(anyAddr);
    mathint urnCanAfter = urnCan(anyAddr, anyAddr2);
    address urnVoteDelegatesAfter = urnVoteDelegates(anyAddr);
    address urnFarmsAfter = urnFarms(anyAddr);
    mathint urnAuctionsAfter = urnAuctions(anyAddr);
    address jugAfter = jug();

    assert wardsAfter != wardsBefore => f.selector == sig:rely(address).selector || f.selector == sig:deny(address).selector, "Assert 1";
    assert farmsAfter != farmsBefore => f.selector == sig:addFarm(address).selector || f.selector == sig:delFarm(address).selector, "Assert 2";
    assert usrAmtsAfter != usrAmtsBefore => f.selector == sig:open(uint256).selector, "Assert 3";
    assert urnOwnersAfter != urnOwnersBefore => f.selector == sig:open(uint256).selector, "Assert 4";
    assert urnCanAfter != urnCanBefore => f.selector == sig:hope(address,address).selector || f.selector == sig:nope(address,address).selector, "Assert 5";
    assert urnVoteDelegatesAfter != urnVoteDelegatesBefore => f.selector == sig:selectVoteDelegate(address,address).selector || f.selector == sig:onKick(address,uint256).selector, "Assert 6";
    assert urnFarmsAfter != urnFarmsBefore => f.selector == sig:selectFarm(address,address,uint16).selector || f.selector == sig:onKick(address,uint256).selector, "Assert 7";
    assert urnAuctionsAfter != urnAuctionsBefore => f.selector == sig:onKick(address,uint256).selector || f.selector == sig:onRemove(address,uint256,uint256).selector, "Assert 8";
    assert jugAfter != jugBefore => f.selector == sig:file(bytes32,address).selector, "Assert 9";
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

    bytes32 ilk = ilk();

    address farmBefore = urnFarms(anyUrn);
    require farmBefore == addrZero() || farmBefore == stakingRewards;

    mathint inkBefore; mathint a;
    inkBefore, a = vat.urns(ilk, anyUrn);

    mathint lsmkrBalanceOfAnyUrnBefore = lsmkr.balanceOf(anyUrn);
    mathint farmBalanceOfAnyUrnBefore = farmBefore == addrZero() ? 0 : stakingRewards.balanceOf(anyUrn);

    require stakingRewards2.balanceOf(anyUrn) == 0;
    require lsmkrBalanceOfAnyUrnBefore == 0 || farmBalanceOfAnyUrnBefore == 0;
    require lsmkrBalanceOfAnyUrnBefore > 0 => farmBefore == addrZero();
    require farmBalanceOfAnyUrnBefore  > 0 => farmBefore != addrZero();
    require inkBefore == lsmkrBalanceOfAnyUrnBefore + farmBalanceOfAnyUrnBefore;

    calldataarg args;
    f(e, args);

    address farmAfter = urnFarms(anyUrn);
    require farmAfter == addrZero() || farmAfter == farmBefore || farmAfter != farmBefore => farmAfter == stakingRewards2;

    mathint inkAfter;
    inkAfter, a = vat.urns(ilk, anyUrn);

    mathint lsmkrBalanceOfAnyUrnAfter = lsmkr.balanceOf(anyUrn);
    mathint farmBalanceOfAnyUrnAfter = farmAfter == addrZero() ? 0 : (farmAfter == farmBefore ? stakingRewards.balanceOf(anyUrn) : stakingRewards2.balanceOf(anyUrn));

    assert lsmkrBalanceOfAnyUrnAfter == 0 || farmBalanceOfAnyUrnAfter == 0, "Assert 1";
    assert lsmkrBalanceOfAnyUrnAfter > 0 => farmAfter == addrZero(), "Assert 2";
    assert farmBalanceOfAnyUrnAfter  > 0 => farmAfter != addrZero(), "Assert 3";
    assert inkAfter == lsmkrBalanceOfAnyUrnAfter + farmBalanceOfAnyUrnAfter, "Assert 4";
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

    mathint usrAmtsSenderBefore = usrAmts(e.msg.sender);
    mathint usrAmtsOtherBefore = usrAmts(other);
    address calcUrn = getUrn(e.msg.sender, index);

    address urn = open(e, index);
    require urn == lockstakeUrn;

    mathint usrAmtsSenderAfter = usrAmts(e.msg.sender);
    mathint usrAmtsOtherAfter = usrAmts(other);
    address urnOwnersUrnAfter = urnOwners(urn);
    mathint vatCanUrnEngineAfter = vat.can(urn, currentContract);
    mathint lsmkrAllowanceUrnEngine = lsmkr.allowance(urn, currentContract);

    // assert urn == calcUrn, "open did not created the same urn address than expected"; I don't think this can be checked with the Prover
    assert usrAmtsSenderAfter == usrAmtsSenderBefore + 1, "Assert 1";
    assert usrAmtsOtherAfter == usrAmtsOtherBefore, "Assert 2";
    assert urnOwnersUrnAfter == e.msg.sender, "Assert 3";
    assert vatCanUrnEngineAfter == 1, "Assert 4";
    assert lsmkrAllowanceUrnEngine == max_uint256, "Assert 5";
}

// Verify revert rules on open
rule open_revert(uint256 index) {
    env e;

    require lockstakeUrn.engine() == currentContract;

    mathint usrAmtsSender = usrAmts(e.msg.sender);

    open@withrevert(e, index);

    bool revert1 = e.msg.value > 0;
    bool revert2 = to_mathint(index) != usrAmtsSender;
    bool revert3 = usrAmtsSender == max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting hope
rule hope(address urn, address usr) {
    env e;

    address other;
    address other2;
    require other != urn || other2 != usr;

    mathint urnCanOtherBefore = urnCan(other, other2);

    hope(e, urn, usr);

    mathint urnCanUrnUsrAfter = urnCan(urn, usr);
    mathint urnCanOtherAfter = urnCan(other, other2);

    assert urnCanUrnUsrAfter == 1, "Assert 1";
    assert urnCanOtherAfter == urnCanOtherBefore, "Assert 2";
}

// Verify revert rules on hope
rule hope_revert(address urn, address usr) {
    env e;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    hope@withrevert(e, urn, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting nope
rule nope(address urn, address usr) {
    env e;

    address other;
    address other2;
    require other != urn || other2 != usr;

    mathint urnCanOtherBefore = urnCan(other, other2);

    nope(e, urn, usr);

    mathint urnCanUrnUsrAfter = urnCan(urn, usr);
    mathint urnCanOtherAfter = urnCan(other, other2);

    assert urnCanUrnUsrAfter == 0, "Assert 1";
    assert urnCanOtherAfter == urnCanOtherBefore, "Assert 2";
}

// Verify revert rules on nope
rule nope_revert(address urn, address usr) {
    env e;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    nope@withrevert(e, urn, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting selectVoteDelegate
rule selectVoteDelegate(address urn, address voteDelegate_) {
    env e;

    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address prevVoteDelegate = urnVoteDelegates(urn);
    require prevVoteDelegate == addrZero() || prevVoteDelegate == voteDelegate2;

    address other;
    require other != urn;
    address other2;
    require other2 != voteDelegate_ && other2 != prevVoteDelegate && other2 != currentContract;

    bytes32 ilk = ilk();
    mathint ink; mathint a;
    ink, a = vat.urns(ilk, urn);

    address urnVoteDelegatesOtherBefore = urnVoteDelegates(other);
    mathint mkrBalanceOfPrevVoteDelegateBefore = mkr.balanceOf(prevVoteDelegate);
    mathint mkrBalanceOfNewVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);

    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkrBalanceOfPrevVoteDelegateBefore + mkrBalanceOfNewVoteDelegateBefore + mkrBalanceOfEngineBefore + mkrBalanceOfOtherBefore;

    selectVoteDelegate(e, urn, voteDelegate_);

    address urnVoteDelegatesUrnAfter = urnVoteDelegates(urn);
    address urnVoteDelegatesOtherAfter = urnVoteDelegates(other);
    mathint mkrBalanceOfPrevVoteDelegateAfter = mkr.balanceOf(prevVoteDelegate);
    mathint mkrBalanceOfNewVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);

    assert urnVoteDelegatesUrnAfter == voteDelegate_, "Assert 1";
    assert urnVoteDelegatesOtherAfter == urnVoteDelegatesOtherBefore, "Assert 2";
    assert prevVoteDelegate == addrZero() => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore, "Assert 3";
    assert prevVoteDelegate != addrZero() => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore - ink, "Assert 4";
    assert voteDelegate_ == addrZero() => mkrBalanceOfNewVoteDelegateAfter == mkrBalanceOfNewVoteDelegateBefore, "Assert 5";
    assert voteDelegate_ != addrZero() => mkrBalanceOfNewVoteDelegateAfter == mkrBalanceOfNewVoteDelegateBefore + ink, "Assert 6";
    assert prevVoteDelegate == addrZero() && voteDelegate_ == addrZero() || prevVoteDelegate != addrZero() && voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 7";
    assert prevVoteDelegate == addrZero() && voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - ink, "Assert 8";
    assert prevVoteDelegate != addrZero() && voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + ink, "Assert 9";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 10";
}

// Verify revert rules on selectVoteDelegate
rule selectVoteDelegate_revert(address urn, address voteDelegate_) {
    env e;

    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address prevVoteDelegate = urnVoteDelegates(urn);
    require prevVoteDelegate == addrZero() || prevVoteDelegate == voteDelegate2;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);
    mathint urnAuctions = urnAuctions(urn);
    mathint voteDelegateFactoryCreatedVoteDelegate = voteDelegateFactory.created(voteDelegate_);
    bytes32 ilk = ilk();
    mathint a; mathint rate; mathint spot; mathint b; mathint c;
    a, rate, spot, b, c = vat.ilks(ilk);
    mathint ink; mathint art;
    ink, art = vat.urns(ilk, urn);

    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(prevVoteDelegate) + mkr.balanceOf(voteDelegate_) + mkr.balanceOf(currentContract);
    // Practical Vat assumptions
    require ink * spot <= max_uint256;
    require art * rate <= max_uint256;
    // TODO: this might be nice to prove in some sort
    require prevVoteDelegate == addrZero() && to_mathint(mkr.balanceOf(currentContract)) >= ink || prevVoteDelegate != addrZero() && to_mathint(mkr.balanceOf(prevVoteDelegate)) >= ink && to_mathint(voteDelegate2.stake(currentContract)) >= ink; // TODO: this might be interesting to be proved
    require voteDelegate.stake(currentContract) + ink <= max_uint256;

    selectVoteDelegate@withrevert(e, urn, voteDelegate_);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = urnAuctions > 0;
    bool revert4 = voteDelegate_ != addrZero() && voteDelegateFactoryCreatedVoteDelegate != 1;
    bool revert5 = voteDelegate_ == prevVoteDelegate;
    bool revert6 = art > 0 && voteDelegate_ != addrZero() && ink * spot < art * rate;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
}

// Verify correct storage changes for non reverting selectFarm
rule selectFarm(address urn, address farm, uint16 ref) {
    env e;

    require urn == lockstakeUrn;

    require farm == addrZero() || farm == stakingRewards;
    address prevFarm = urnFarms(urn);
    require prevFarm == addrZero() || prevFarm == stakingRewards2;

    address other;
    require other != urn;
    address other2;
    require other2 != farm && other2 != prevFarm && other2 != urn;

    bytes32 ilk = ilk();
    mathint ink; mathint a;
    ink, a = vat.urns(ilk, urn);

    address urnFarmsOtherBefore = urnFarms(other);
    mathint lsmkrBalanceOfPrevFarmBefore = lsmkr.balanceOf(prevFarm);
    mathint lsmkrBalanceOfNewFarmBefore = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

    // Tokens invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkrBalanceOfPrevFarmBefore + lsmkrBalanceOfNewFarmBefore + lsmkrBalanceOfUrnBefore + lsmkrBalanceOfOtherBefore;

    selectFarm(e, urn, farm, ref);

    address urnFarmsUrnAfter = urnFarms(urn);
    address urnFarmsOtherAfter = urnFarms(other);
    mathint lsmkrBalanceOfPrevFarmAfter = lsmkr.balanceOf(prevFarm);
    mathint lsmkrBalanceOfNewFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert urnFarmsUrnAfter == farm, "Assert 1";
    assert urnFarmsOtherAfter == urnFarmsOtherBefore, "Assert 2";
    assert prevFarm == addrZero() => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore, "Assert 3";
    assert prevFarm != addrZero() => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore - ink, "Assert 4";
    assert farm == addrZero() => lsmkrBalanceOfNewFarmAfter == lsmkrBalanceOfNewFarmBefore, "Assert 5";
    assert farm != addrZero() => lsmkrBalanceOfNewFarmAfter == lsmkrBalanceOfNewFarmBefore + ink, "Assert 6";
    assert prevFarm == addrZero() && farm == addrZero() || prevFarm != addrZero() && farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 7";
    assert prevFarm == addrZero() && farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - ink, "Assert 8";
    assert prevFarm != addrZero() && farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + ink, "Assert 9";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 10";
}

// Verify revert rules on selectFarm
rule selectFarm_revert(address urn, address farm, uint16 ref) {
    env e;

    require urn == lockstakeUrn;

    require farm == addrZero() || farm == stakingRewards;
    address prevFarm = urnFarms(urn);
    require prevFarm == addrZero() || prevFarm == stakingRewards2;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);
    mathint urnAuctions = urnAuctions(urn);
    LockstakeEngine.FarmStatus farmsFarm = farms(farm);
    bytes32 ilk = ilk();
    mathint ink; mathint a;
    ink, a = vat.urns(ilk, urn);

    // TODO: this might be nice to prove in some sort
    require prevFarm == addrZero() && to_mathint(lsmkr.balanceOf(urn)) >= ink || prevFarm != addrZero() && to_mathint(lsmkr.balanceOf(prevFarm)) >= ink && to_mathint(stakingRewards2.balanceOf(urn)) >= ink;
    // Token invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(prevFarm) + lsmkr.balanceOf(farm) + lsmkr.balanceOf(urn);
    require stakingRewards2.totalSupply() >= stakingRewards2.balanceOf(urn);
    require stakingRewards.totalSupply() >= stakingRewards.balanceOf(urn);
    // Assumption
    require stakingRewards.totalSupply() + ink <= max_uint256;

    selectFarm@withrevert(e, urn, farm, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = urnAuctions > 0;
    bool revert4 = farm != addrZero() && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert5 = farm == prevFarm;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting lock
rule lock(address urn, uint256 wad, uint16 ref) {
    env e;

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
    mathint inkBefore; mathint a;
    inkBefore, a = vat.urns(ilk, urn);
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

    lock(e, urn, wad, ref);

    mathint inkAfter;
    inkAfter, a = vat.urns(ilk, urn);
    mathint mkrBalanceOfSenderAfter = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore + wad, "Assert 1";
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
rule lock_revert(address urn, uint256 wad, uint16 ref) {
    env e;

    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    address urnOwnersUrn = urnOwners(urn);

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

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
    require rate >= RAY() && rate <= max_int256();
    require (ink + wad) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require ink == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    LockstakeEngine.FarmStatus farmsFarm = farms(farm);

    lock@withrevert(e, urn, wad, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn == addrZero();
    bool revert3 = to_mathint(wad) > max_int256();
    bool revert4 = farm != addrZero() && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert5 = farm != addrZero() && wad == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting lockNgt
rule lockNgt(address urn, uint256 ngtWad, uint16 ref) {
    env e;

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

    mathint mkrNgtRate = mkrNgtRate();

    bytes32 ilk = ilk();
    mathint inkBefore; mathint a;
    inkBefore, a = vat.urns(ilk, urn);
    mathint ngtTotalSupplyBefore = ngt.totalSupply();
    mathint ngtBalanceOfSenderBefore = ngt.balanceOf(e.msg.sender);
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
    require mkrNgtRate == to_mathint(mkrNgt.rate());
    // Tokens invariants
    require ngtTotalSupplyBefore >= ngtBalanceOfSenderBefore + ngt.balanceOf(currentContract) + ngt.balanceOf(mkrNgt);
    require mkrTotalSupplyBefore >= mkrBalanceOfSenderBefore + mkrBalanceOfEngineBefore + mkrBalanceOfVoteDelegateBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore + lsmkrBalanceOfOtherBefore;

    lockNgt(e, urn, ngtWad, ref);

    mathint inkAfter;
    inkAfter, a = vat.urns(ilk, urn);
    mathint ngtTotalSupplyAfter = ngt.totalSupply();
    mathint ngtBalanceOfSenderAfter = ngt.balanceOf(e.msg.sender);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfSenderAfter = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore + ngtWad/mkrNgtRate, "Assert 1";
    assert ngtTotalSupplyAfter == ngtTotalSupplyBefore - ngtWad, "Assert 2";
    assert ngtBalanceOfSenderAfter == ngtBalanceOfSenderBefore - ngtWad, "Assert 3";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore + ngtWad/mkrNgtRate, "Assert 4";
    assert voteDelegate_ == addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "Assert 5";
    assert voteDelegate_ != addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore + ngtWad/mkrNgtRate, "Assert 6";
    assert voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + ngtWad/mkrNgtRate, "Assert 7";
    assert voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 8";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 9";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore + ngtWad/mkrNgtRate, "Assert 10";
    assert farm == addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "Assert 11";
    assert farm != addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore + ngtWad/mkrNgtRate, "Assert 12";
    assert farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + ngtWad/mkrNgtRate, "Assert 13";
    assert farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 14";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 15";
}

// Verify revert rules on lockNgt
rule lockNgt_revert(address urn, uint256 ngtWad, uint16 ref) {
    env e;

    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    mathint mkrNgtRate = mkrNgtRate();
    address urnOwnersUrn = urnOwners(urn);

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

    // Happening in constructor
    require mkrNgtRate == to_mathint(mkrNgt.rate());
    // Avoid division by zero
    require mkrNgtRate > 0;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    require ngt.allowance(currentContract, mkrNgt) == max_uint256;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // User balance and approval
    require ngt.balanceOf(e.msg.sender) >= ngtWad && ngt.allowance(e.msg.sender, currentContract) >= ngtWad;
    // Tokens invariants
    require to_mathint(ngt.totalSupply()) >= ngt.balanceOf(e.msg.sender) + ngt.balanceOf(currentContract) + ngt.balanceOf(mkrNgt);
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm);
    // Assumption
    require to_mathint(mkr.totalSupply()) <= max_uint256 - ngtWad/mkrNgtRate;
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    require lsmkr.totalSupply() + ngtWad/mkrNgtRate <= to_mathint(mkr.totalSupply());
    // Practical Vat assumptions
    require vat.live() == 1;
    require rate >= RAY() && rate <= max_int256();
    require (ink + ngtWad/mkrNgtRate) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require ink == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    LockstakeEngine.FarmStatus farmsFarm = farms(farm);

    lockNgt@withrevert(e, urn, ngtWad, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn == addrZero();
    bool revert3 = ngtWad/mkrNgtRate > max_int256();
    bool revert4 = farm != addrZero() && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert5 = farm != addrZero() && ngtWad/mkrNgtRate == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting free
rule free(address urn, address to, uint256 wad) {
    env e;

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
    mathint inkBefore; mathint a;
    inkBefore, a = vat.urns(ilk, urn);
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

    free(e, urn, to, wad);

    mathint inkAfter;
    inkAfter, a = vat.urns(ilk, urn);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfToAfter = mkr.balanceOf(to);
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore - wad, "Assert 1";
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
rule free_revert(address urn, address to, uint256 wad) {
    env e;

    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    mathint fee = fee();
    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

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
    require voteDelegate_ != addrZero() => to_mathint(voteDelegate.stake(currentContract)) >= ink;
    require voteDelegate_ == addrZero() => to_mathint(mkr.balanceOf(currentContract)) >= ink;
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    // Practical Vat assumptions
    require vat.live() == 1;
    require rate >= RAY() && rate <= max_int256();
    require (ink - wad) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require lsmkr.balanceOf(urn) > 0 => farm == addrZero();
    require stakingRewards.balanceOf(urn)  > 0 => farm != addrZero();
    require ink == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    free@withrevert(e, urn, to, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = to_mathint(wad) > max_int256();
    bool revert4 = ink < to_mathint(wad) || wad > 0 && (ink - wad) * spot < art * rate;
    bool revert5 = farm != 0 && wad == 0;
    bool revert6 = wad * fee > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
}

// Verify correct storage changes for non reverting freeNgt
rule freeNgt(address urn, address to, uint256 ngtWad) {
    env e;

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

    mathint mkrNgtRate = mkrNgtRate();
    mathint fee = fee();

    bytes32 ilk = ilk();
    mathint inkBefore; mathint a;
    inkBefore, a = vat.urns(ilk, urn);
    mathint ngtTotalSupplyBefore = ngt.totalSupply();
    mathint ngtBalanceOfToBefore = ngt.balanceOf(to);
    mathint ngtBalanceOfOtherBefore = ngt.balanceOf(other3);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

    // Happening in constructor
    require mkrNgtRate == to_mathint(mkrNgt.rate());
    require fee < WAD();
    // Tokens invariants
    require ngtTotalSupplyBefore >= ngtBalanceOfToBefore + ngtBalanceOfOtherBefore;
    require mkrTotalSupplyBefore >= mkrBalanceOfEngineBefore + mkrBalanceOfVoteDelegateBefore + mkrBalanceOfOtherBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore + lsmkrBalanceOfOtherBefore;

    freeNgt(e, urn, to, ngtWad);

    mathint inkAfter;
    inkAfter, a = vat.urns(ilk, urn);
    mathint ngtTotalSupplyAfter = ngt.totalSupply();
    mathint ngtBalanceOfToAfter = ngt.balanceOf(to);
    mathint ngtBalanceOfOtherAfter = ngt.balanceOf(other3);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore - ngtWad/mkrNgtRate, "Assert 1";
    assert ngtTotalSupplyAfter == ngtTotalSupplyBefore + (ngtWad/mkrNgtRate - ngtWad/mkrNgtRate * fee / WAD()) * mkrNgtRate, "Assert 2";
    assert ngtBalanceOfToAfter == ngtBalanceOfToBefore + (ngtWad/mkrNgtRate - ngtWad/mkrNgtRate * fee / WAD()) * mkrNgtRate, "Assert 3";
    assert ngtBalanceOfOtherAfter == ngtBalanceOfOtherBefore, "Assert 4";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - ngtWad/mkrNgtRate, "Assert 5";
    assert to != voteDelegate_ && voteDelegate_ == addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "Assert 6";
    assert to != voteDelegate_ && voteDelegate_ != addrZero() => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore - ngtWad/mkrNgtRate, "Assert 7";
    assert to != currentContract && voteDelegate_ == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - ngtWad/mkrNgtRate, "Assert 8";
    assert to != currentContract && voteDelegate_ != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 9";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 10";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore - ngtWad/mkrNgtRate, "Assert 11";
    assert farm == addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "Assert 12";
    assert farm != addrZero() => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore - ngtWad/mkrNgtRate, "Assert 13";
    assert farm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - ngtWad/mkrNgtRate, "Assert 14";
    assert farm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "Assert 15";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "Assert 16";
}

// Verify revert rules on freeNgt
rule freeNgt_revert(address urn, address to, uint256 ngtWad) {
    env e;

    require urn == lockstakeUrn;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    mathint mkrNgtRate = mkrNgtRate();
    mathint fee = fee();

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

    // Happening in constructor
    require mkrNgtRate == to_mathint(mkrNgt.rate());
    require fee < WAD();
    require mkr.allowance(currentContract, mkrNgt) == max_uint256;
    // Avoid division by zero
    require mkrNgtRate > 0;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    require lsmkr.allowance(urn, currentContract) == max_uint256;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // Tokens invariants
    require ngt.totalSupply() >= ngt.balanceOf(to);
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm);
    // Practical assumption
    require ngt.totalSupply() + ngtWad <= max_uint256;
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require voteDelegate_ != addrZero() => to_mathint(voteDelegate.stake(currentContract)) >= ink;
    require voteDelegate_ == addrZero() => to_mathint(mkr.balanceOf(currentContract)) >= ink;
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    // Practical Vat assumptions
    require vat.live() == 1;
    require rate >= RAY() && rate <= max_int256();
    require (ink - ngtWad/mkrNgtRate) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require lsmkr.balanceOf(urn) > 0 => farm == addrZero();
    require stakingRewards.balanceOf(urn)  > 0 => farm != addrZero();
    require ink == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    freeNgt@withrevert(e, urn, to, ngtWad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = to_mathint(ngtWad/mkrNgtRate) > max_int256();
    bool revert4 = ink < to_mathint(ngtWad/mkrNgtRate) || ngtWad/mkrNgtRate > 0 && (ink - ngtWad/mkrNgtRate) * spot < art * rate;
    bool revert5 = farm != 0 && ngtWad/mkrNgtRate == 0;
    bool revert6 = ngtWad/mkrNgtRate * fee > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
}

// Verify correct storage changes for non reverting freeNoFee
rule freeNoFee(address urn, address to, uint256 wad) {
    env e;

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
    mathint inkBefore; mathint a;
    inkBefore, a = vat.urns(ilk, urn);
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

    freeNoFee(e, urn, to, wad);

    mathint inkAfter;
    inkAfter, a = vat.urns(ilk, urn);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfToAfter = mkr.balanceOf(to);
    mathint mkrBalanceOfVoteDelegateAfter = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore - wad, "Assert 1";
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
rule freeNoFee_revert(address urn, address to, uint256 wad) {
    env e;

    require urn == lockstakeUrn;

    mathint wardsSender = wards(e.msg.sender);

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == addrZero() || voteDelegate_ == voteDelegate;
    address farm = urnFarms(urn);
    require farm == addrZero() || farm == stakingRewards;

    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

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
    require voteDelegate_ != addrZero() => to_mathint(voteDelegate.stake(currentContract)) >= ink;
    require voteDelegate_ == addrZero() => to_mathint(mkr.balanceOf(currentContract)) >= ink;
    require stakingRewards.totalSupply() == stakingRewards.balanceOf(urn);
    require lsmkr.balanceOf(farm) == stakingRewards.totalSupply();
    // Practical Vat assumptions
    require vat.live() == 1;
    require rate >= RAY() && rate <= max_int256();
    require (ink - wad) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // Safe to assume as Engine doesn't modify vat.gem(ilk,urn) (rule vatGemKeepsUnchanged)
    require vat.gem(ilk, urn) == 0;
    // Safe to assume as Engine keeps the invariant (rule inkMatchesLsmkrFarm)
    require lsmkr.balanceOf(urn) == 0 || stakingRewards.balanceOf(urn) == 0;
    require lsmkr.balanceOf(urn) > 0 => farm == addrZero();
    require stakingRewards.balanceOf(urn)  > 0 => farm != addrZero();
    require ink == lsmkr.balanceOf(urn) + stakingRewards.balanceOf(urn);

    freeNoFee@withrevert(e, urn, to, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert4 = to_mathint(wad) > max_int256();
    bool revert5 = ink < to_mathint(wad) || wad > 0 && (ink - wad) * spot < art * rate;
    bool revert6 = farm != 0 && wad == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
}

// Verify correct storage changes for non reverting draw
rule draw(address urn, address to, uint256 wad) {
    env e;

    address other;
    require other != to;

    bytes32 ilk = ilk();
    mathint ArtBefore; mathint a;
    ArtBefore, a, a, a, a = vat.ilks(ilk);
    mathint artBefore;
    a, artBefore = vat.urns(ilk, urn);
    mathint nstTotalSupplyBefore = nst.totalSupply();
    mathint nstBalanceOfToBefore = nst.balanceOf(to);
    mathint nstBalanceOfOtherBefore = nst.balanceOf(other);

    // Tokens invariants
    require nstTotalSupplyBefore >= nstBalanceOfToBefore + nstBalanceOfOtherBefore;

    draw(e, urn, to, wad);

    mathint ArtAfter; mathint rateAfter;
    ArtAfter, rateAfter, a, a, a = vat.ilks(ilk);
    mathint artAfter;
    a, artAfter = vat.urns(ilk, urn);
    mathint nstTotalSupplyAfter = nst.totalSupply();
    mathint nstBalanceOfToAfter = nst.balanceOf(to);
    mathint nstBalanceOfOtherAfter = nst.balanceOf(other);

    assert ArtAfter == ArtBefore + _divup(wad * RAY(), rateAfter), "Assert 1";
    assert artAfter == artBefore + _divup(wad * RAY(), rateAfter), "Assert 2";
    assert nstTotalSupplyAfter == nstTotalSupplyBefore + wad, "Assert 3";
    assert nstBalanceOfToAfter == nstBalanceOfToBefore + wad, "Assert 4";
    assert nstBalanceOfOtherAfter == nstBalanceOfOtherBefore, "Assert 5";
}

// Verify revert rules on draw
rule draw_revert(address urn, address to, uint256 wad) {
    env e;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    bytes32 ilk = ilk();
    mathint Line = vat.Line();
    mathint debt = vat.debt();
    mathint Art; mathint prev; mathint spot; mathint line; mathint dust; mathint a;
    Art, prev, spot, line, dust = vat.ilks(ilk);
    mathint ink; mathint art;
    ink, art = vat.urns(ilk, urn);
    mathint nstTotalSupply = nst.totalSupply();
    mathint nstBalanceOfTo = nst.balanceOf(to);

    storage init = lastStorage;
    mathint rate = dripSummary(ilk);
    // Avoid division by zero
    require rate > 0;

    mathint dart = _divup(wad * RAY(), rate);

    // Happening in constructor
    require vat.can(currentContract, nstJoin) == 1;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    // Tokens invariants
    require nstTotalSupply >= nstBalanceOfTo;
    // Practical token assumtiopns
    require nstTotalSupply + wad <= max_uint256;
    // Practical Vat assumptions
    require vat.live() == 1;
    require vat.wards(jug) == 1;
    require rate >= RAY() && rate <= max_int256();
    require ink * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require Art + dart <= max_uint256;
    require rate * dart <= max_int256();
    require debt + Art * (rate - prev) + (rate * dart) <= max_int256();
    require vat.dai(currentContract) + (dart * rate) <= max_uint256;
    require vat.dai(nstJoin) + (dart * rate) <= max_uint256;
    // Other assumptions
    require wad * RAY() <= max_uint256;

    draw@withrevert(e, urn, to, wad) at init;

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = to_mathint(dart) > max_int256();
    bool revert4 = dart > 0 && ((Art + dart) * rate > line || debt + Art * (rate - prev) + (rate * dart) > Line);
    bool revert5 = dart > 0 && ink * spot < (art + dart) * rate;
    bool revert6 = art + dart > 0 && rate * (art + dart) < dust;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
}

// Verify correct storage changes for non reverting wipe
rule wipe(address urn, uint256 wad) {
    env e;

    address other;
    require other != e.msg.sender;

    bytes32 ilk = ilk();
    mathint ArtBefore; mathint rate; mathint a;
    ArtBefore, rate, a, a, a = vat.ilks(ilk);
    mathint artBefore;
    a, artBefore = vat.urns(ilk, urn);
    mathint nstTotalSupplyBefore = nst.totalSupply();
    mathint nstBalanceOfSenderBefore = nst.balanceOf(e.msg.sender);
    mathint nstBalanceOfOtherBefore = nst.balanceOf(other);

    // Tokens invariants
    require nstTotalSupplyBefore >= nstBalanceOfSenderBefore + nstBalanceOfOtherBefore;

    wipe(e, urn, wad);

    mathint ArtAfter;
    ArtAfter, a, a, a, a = vat.ilks(ilk);
    mathint artAfter;
    a, artAfter = vat.urns(ilk, urn);
    mathint nstTotalSupplyAfter = nst.totalSupply();
    mathint nstBalanceOfSenderAfter = nst.balanceOf(e.msg.sender);
    mathint nstBalanceOfOtherAfter = nst.balanceOf(other);

    assert ArtAfter == ArtBefore - wad * RAY() / rate, "Assert 1";
    assert artAfter == artBefore - wad * RAY() / rate, "Assert 2";
    assert nstTotalSupplyAfter == nstTotalSupplyBefore - wad, "Assert 3";
    assert nstBalanceOfSenderAfter == nstBalanceOfSenderBefore - wad, "Assert 4";
    assert nstBalanceOfOtherAfter == nstBalanceOfOtherBefore, "Assert 5";
}

// Verify revert rules on wipe
rule wipe_revert(address urn, uint256 wad) {
    env e;

    bytes32 ilk = ilk();
    mathint Line = vat.Line();
    mathint debt = vat.debt();
    mathint Art; mathint rate; mathint spot; mathint line; mathint dust; mathint a;
    Art, rate, spot, line, dust = vat.ilks(ilk);
    mathint ink; mathint art;
    ink, art = vat.urns(ilk, urn);
    mathint nstTotalSupply = nst.totalSupply();
    mathint nstBalanceOfSender = nst.balanceOf(e.msg.sender);

    // Avoid division by zero
    require rate > 0;

    mathint dart = wad * RAY() / rate;

    // Happening in constructor
    require nst.allowance(currentContract, nstJoin) == max_uint256;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    // Tokens invariants
    require nstTotalSupply >= nstBalanceOfSender + nst.balanceOf(currentContract) + nst.balanceOf(nstJoin);
    // Practical token assumtiopns
    require nstBalanceOfSender >= to_mathint(wad);
    require nst.allowance(e.msg.sender, currentContract) >= wad;
    // Practical Vat assumptions
    require vat.live() == 1;
    require vat.wards(jug) == 1;
    require rate >= RAY() && rate <= max_int256();
    require ink * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require rate * -dart >= min_int256();
    require debt >= rate * dart;
    require vat.dai(currentContract) + wad * RAY() <= max_uint256;
    require to_mathint(vat.dai(nstJoin)) >= wad * RAY();
    // Other assumptions
    require wad * RAY() <= max_uint256;

    wipe@withrevert(e, urn, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = to_mathint(dart) > max_int256();
    bool revert3 = art < dart;
    bool revert4 = art - dart > 0 && rate * (art - dart) < dust;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting wipeAll
rule wipeAll(address urn) {
    env e;

    address other;
    require other != e.msg.sender;

    bytes32 ilk = ilk();
    mathint ArtBefore; mathint rate; mathint a;
    ArtBefore, rate, a, a, a = vat.ilks(ilk);
    mathint artBefore;
    a, artBefore = vat.urns(ilk, urn);
    mathint wad = _divup(artBefore * rate, RAY());
    mathint nstTotalSupplyBefore = nst.totalSupply();
    mathint nstBalanceOfSenderBefore = nst.balanceOf(e.msg.sender);
    mathint nstBalanceOfOtherBefore = nst.balanceOf(other);

    // Tokens invariants
    require nstTotalSupplyBefore >= nstBalanceOfSenderBefore + nstBalanceOfOtherBefore;

    wipeAll(e, urn);

    mathint ArtAfter;
    ArtAfter, a, a, a, a = vat.ilks(ilk);
    mathint artAfter;
    a, artAfter = vat.urns(ilk, urn);
    mathint nstTotalSupplyAfter = nst.totalSupply();
    mathint nstBalanceOfSenderAfter = nst.balanceOf(e.msg.sender);
    mathint nstBalanceOfOtherAfter = nst.balanceOf(other);

    assert ArtAfter == ArtBefore - artBefore, "Assert 1";
    assert artAfter == 0, "Assert 2";
    assert nstTotalSupplyAfter == nstTotalSupplyBefore - wad, "Assert 3";
    assert nstBalanceOfSenderAfter == nstBalanceOfSenderBefore - wad, "Assert 4";
    assert nstBalanceOfOtherAfter == nstBalanceOfOtherBefore, "Assert 5";
}

// Verify revert rules on wipeAll
rule wipeAll_revert(address urn) {
    env e;

    bytes32 ilk = ilk();
    mathint Line = vat.Line();
    mathint debt = vat.debt();
    mathint Art; mathint rate; mathint spot; mathint line; mathint dust; mathint a;
    Art, rate, spot, line, dust = vat.ilks(ilk);
    mathint ink; mathint art;
    ink, art = vat.urns(ilk, urn);
    mathint nstTotalSupply = nst.totalSupply();
    mathint nstBalanceOfSender = nst.balanceOf(e.msg.sender);

    mathint wad = _divup(art * rate, RAY());

    // Happening in constructor
    require nst.allowance(currentContract, nstJoin) == max_uint256;
    // Happening in urn init
    require vat.can(urn, currentContract) == 1;
    // Tokens invariants
    require nstTotalSupply >= nstBalanceOfSender + nst.balanceOf(currentContract) + nst.balanceOf(nstJoin);
    // Practical token assumtiopns
    require nstBalanceOfSender >= to_mathint(wad);
    require to_mathint(nst.allowance(e.msg.sender, currentContract)) >= wad;
    // Practical Vat assumptions
    require vat.live() == 1;
    require vat.wards(jug) == 1;
    require rate >= RAY() && rate <= max_int256();
    require ink * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require rate * -art >= min_int256();
    require debt >= rate * art;
    require vat.dai(currentContract) + wad * RAY() <= max_uint256;
    require to_mathint(vat.dai(nstJoin)) >= wad * RAY();
    // Other assumptions
    require wad * RAY() <= max_uint256;

    wipeAll@withrevert(e, urn);

    bool revert1 = e.msg.value > 0;
    bool revert2 = to_mathint(art) > max_int256();

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting getReward
rule getReward(address urn, address farm, address to) {
    env e;

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

    getReward(e, urn, farm, to);

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
rule getReward_revert(address urn, address farm, address to) {
    env e;

    require farm == stakingRewards;
    require stakingRewards.rewardsToken() == rewardsToken;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);
    LockstakeEngine.FarmStatus farmsFarm = farms(farm);

    // Tokens invariants
    require to_mathint(rewardsToken.totalSupply()) >= rewardsToken.balanceOf(to) + rewardsToken.balanceOf(urn) + rewardsToken.balanceOf(farm);

    // Assumption from the farm
    require rewardsToken.balanceOf(farm) >= stakingRewards.rewards(urn);

    getReward@withrevert(e, urn, farm, to);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = farmsFarm == LockstakeEngine.FarmStatus.UNSUPPORTED;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
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
    mathint ink; mathint a;
    ink, a = vat.urns(ilk, urn);

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
    assert prevVoteDelegate != addrZero() => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore - ink - wad, "Assert 8";
    assert prevVoteDelegate == addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "Assert 9";
    assert prevVoteDelegate != addrZero() => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + ink + wad, "Assert 10";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 11";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore - wad, "Assert 12";
    assert prevFarm == addrZero() => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore, "Assert 13";
    assert prevFarm != addrZero() => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore - ink - wad, "Assert 14";
    assert prevFarm == addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - wad, "Assert 15";
    assert prevFarm != addrZero() => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + ink, "Assert 16";
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

    mathint urnAuctionsUrn = urnAuctions(urn);
    mathint wardsSender = wards(e.msg.sender);
    mathint ink; mathint art;
    ink, art = vat.urns(ilk(), urn);

    // Happening in urn init
    require lsmkr.allowance(urn, currentContract) == max_uint256;
    // Tokens invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(prevFarm) + lsmkr.balanceOf(urn) + lsmkr.balanceOf(currentContract);
    require stakingRewards.totalSupply() >= stakingRewards.balanceOf(urn);
    // VoteDelegate assumptions
    require prevVoteDelegate == addrZero() || to_mathint(voteDelegate.stake(currentContract)) >= ink + wad;
    require prevVoteDelegate == addrZero() || mkr.balanceOf(voteDelegate) >= voteDelegate.stake(currentContract);
    // StakingRewards assumptions
    require prevFarm == addrZero() && lsmkr.balanceOf(urn) >= wad ||
            prevFarm != addrZero() && to_mathint(stakingRewards.balanceOf(urn)) >= ink + wad && to_mathint(lsmkr.balanceOf(prevFarm)) >= ink + wad;
    // LockstakeClipper assumption
    require wad > 0;
    // Practical assumption (ink + wad should be the same than the ink prev to the kick call)
    require ink + wad <= max_uint256;

    onKick@withrevert(e, urn, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = urnAuctionsUrn == max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// using LockstakeEngine as _Engine;
// using MuticallTest as _MuticallTest;
// using LockstakeUrn as _LockstakeUrn;
// using StkMock as _stkMkr;
// using MkrMock as _mkrMock;
// using DelegateFactoryMock as _DelegateFactory;
// using DelegateMock as _DelegateMock;
// using GemMockRewards as _GemMockRewards;

// methods {
//     // `LockstakeEngine`
//     function urnFarms(address) external returns (address) envfree;
//     function farms(address) external returns (LockstakeEngine.FarmStatus) envfree;

//     // `LockstakeUrn`
//     function _.stake(address,uint256,uint16) external => DISPATCHER(true);
//     function _.withdraw(address,uint256) external => DISPATCHER(true);
//     function _.getReward(address,address) external => DISPATCHER(true);
//     function _.init() external => DISPATCHER(true); // Prevent havoc due to `init`

//     // `StkMock`
//     function StkMock.balanceOf(address) external returns (uint256) envfree;

//     // `MkrMock`
//     function MkrMock.balanceOf(address) external returns (uint256) envfree;
//     function MkrMock.allowance(address,address) external returns (uint256) envfree;
//     // Summarize `transfer` to prevent overflow
//     function MkrMock.transfer(
//         address to, uint256 value
//     ) external returns (bool) with (env e) => transferSummary(to, value, e);

//     // `DelegateMock`
//     function _.lock(uint256) external => DISPATCHER(true);
//     function _.free(uint256) external => DISPATCHER(true);

//     // `StakingRewardsMock`
//     function _.rewardsToken() external => DISPATCHER(true);
//     function _.stake(uint256,uint16) external => DISPATCHER(true);
//     function _.withdraw(uint256) external => DISPATCHER(true);
//     function _.getReward() external => DISPATCHER(true);

//     // `rewardsToken` - using dispatcher to avoid unresolved calls causing havoc
//     function _.transfer(address,uint256) external => DISPATCHER(true);

//     // The Prover will attempt to dispatch to the following functions any unresolved
//     // call, if the signature fits. Otherwise it will use the summary defined by the
//     // `default` keyword.
//     // NOTE: The more functions added, the longer the verification time will be.
//     function _._ external => DISPATCH [
//         _Engine.selectFarm(address,address,uint16),
//         _Engine.lock(address,uint256,uint16),
//         _Engine.hope(address,address),
//         _Engine.nope(address,address),
//         _Engine.rely(address),
//         _Engine.deny(address),
//         _Engine.open(uint256)
//     ] default HAVOC_ALL;
// }


// /// @title Select and lock integrity
// rule selectLockIntegrity(
//         uint256 index,
//         address farm,
//         uint16 ref,
//         uint256 wad
//         ) {
//     // NOTE: `_MuticallTest` is the contract calling the `multicall` function
//     uint256 mkrBefore = _mkrMock.balanceOf(_MuticallTest);
//     uint256 allowanceBefore = _mkrMock.allowance(_MuticallTest, currentContract);

//     env e;
//     _MuticallTest.standardMulticall(e, _LockstakeUrn, farm, ref, wad);

//     uint256 mkrAfter = _mkrMock.balanceOf(_MuticallTest);
//     uint256 allowanceAfter = _mkrMock.allowance(_MuticallTest, currentContract);

//     assert (
//         mkrBefore - mkrAfter == to_mathint(wad), "locking reduces users amount by wad"
//     );
//     assert (
//         (
//             allowanceBefore < max_uint256 =>
//             allowanceBefore - allowanceAfter == to_mathint(wad)
//         ) && (
//             allowanceBefore == max_uint256 => allowanceBefore == allowanceAfter
//         ),
//         "allowance correctly changed by locking"
//     );
//     assert urnFarms(_LockstakeUrn) == farm, "farm was selected";

//     // This assertion fails - the counter example uses `address(0)` as `farm`
//     assert farms(farm) == LockstakeEngine.FarmStatus.ACTIVE, "farm is active";
// }


// /// @title Prevent transfer from overflowing
// function transferSummary(address to, uint256 value, env e) returns bool {
//     // NOTE: use this require only if you are certain of it.
//     require _mkrMock.balanceOf(to) + value <= max_uint256;
//     return _mkrMock.transfer(e, to, value);
// }


// /// @title Only the user can reduce their own balance
// rule onlyUserCanChangeOwnBalance(method f, address user) {

//     require user != _DelegateMock;
//     require user != _Engine;
//     require user != _GemMockRewards;
//     uint256 balanceBefore = _mkrMock.balanceOf(user);

//     env e;
//     calldataarg args;
//     f(e, args);
    
//     uint256 balanceAfter = _mkrMock.balanceOf(user);
    
//     assert (
//         balanceBefore > balanceAfter => e.msg.sender == user,
//         "only the user can change their own balance"
//     );
// }
