// LockstakeClipper.spec

using LockstakeEngine as lockstakeEngine;
using LockstakeUrn as lockstakeUrn;
using LockstakeMkr as lsmkr;
using MkrMock as mkr;
using Vat as vat;
using Spotter as spotter;
using Dog as dog;
using VoteDelegateMock as voteDelegate;
using StakingRewardsMock as stakingRewards;
using BadGuy as badGuy;
using RedoGuy as redoGuy;
using KickGuy as kickGuy;
using FileUintGuy as fileUintGuy;
using FileAddrGuy as fileAddrGuy;
using YankGuy as yankGuy;

methods {
    // storage variables
    function wards(address) external returns (uint256) envfree;
    function dog() external returns (address) envfree;
    function vow() external returns (address) envfree;
    function spotter() external returns (address) envfree;
    function calc() external returns (address) envfree;
    function buf() external returns (uint256) envfree;
    function tail() external returns (uint256) envfree;
    function cusp() external returns (uint256) envfree;
    function chip() external returns (uint64) envfree;
    function tip() external returns (uint192) envfree;
    function chost() external returns (uint256) envfree;
    function kicks() external returns (uint256) envfree;
    function active(uint256) external returns (uint256) envfree;
    function sales(uint256) external returns (uint256,uint256,uint256,uint256,address,uint96,uint256) envfree;
    function stopped() external returns (uint256) envfree;
    function count() external returns (uint256) envfree;
    function active(uint256) external returns (uint256) envfree;
    // immutables
    function ilk() external returns (bytes32) envfree;
    //
    function lockstakeEngine.wards(address) external returns (uint256) envfree;
    function lockstakeEngine.urnAuctions(address) external returns (uint256) envfree;
    function lockstakeEngine.urnVoteDelegates(address) external returns (address) envfree;
    function lockstakeEngine.urnFarms(address) external returns (address) envfree;
    function lockstakeEngine.ilk() external returns (bytes32) envfree;
    function lockstakeEngine.fee() external returns (uint256) envfree;
    function mkr.totalSupply() external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function lsmkr.wards(address) external returns (uint256) envfree;
    function lsmkr.totalSupply() external returns (uint256) envfree;
    function lsmkr.allowance(address,address) external returns (uint256) envfree;
    function lsmkr.balanceOf(address) external returns (uint256) envfree;
    function stakingRewards.balanceOf(address) external returns (uint256) envfree;
    function stakingRewards.totalSupply() external returns (uint256) envfree;
    function voteDelegate.stake(address) external returns (uint256) envfree;
    function vat.wards(address) external returns (uint256) envfree;
    function vat.live() external returns (uint256) envfree;
    function vat.can(address, address) external returns (uint256) envfree;
    function vat.debt() external returns (uint256) envfree;
    function vat.vice() external returns (uint256) envfree;
    function vat.dai(address) external returns (uint256) envfree;
    function vat.sin(address) external returns (uint256) envfree;
    function vat.gem(bytes32,address) external returns (uint256) envfree;
    function vat.ilks(bytes32) external returns (uint256,uint256,uint256,uint256,uint256) envfree;
    function vat.urns(bytes32, address) external returns (uint256,uint256) envfree;
    function spotter.ilks(bytes32) external returns (address,uint256) envfree;
    function spotter.par() external returns (uint256) envfree;
    function dog.wards(address) external returns (uint256) envfree;
    function dog.Dirt() external returns (uint256) envfree;
    function dog.ilks(bytes32) external returns (address,uint256,uint256,uint256) envfree;
    //
    function _.peek() external => peekSummary() expect (uint256, bool);
    function _.price(uint256,uint256) external => calcPriceSummary() expect (uint256);
    function _.free(uint256) external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    // `ClipperCallee`
    // NOTE: this might result in recursion, since we linked all the `ClipperCallee`
    // to the `LockstakeClipper`.
    function _.clipperCall(
        address, uint256, uint256, bytes
    ) external => DISPATCHER(true);
}

definition addrZero() returns address = 0x0000000000000000000000000000000000000000;
definition max_int256() returns mathint = 2^255 - 1;
definition WAD() returns mathint = 10^18;
definition RAY() returns mathint = 10^27;
definition _min(mathint x, mathint y) returns mathint = x < y ? x : y;

ghost uint256 pipVal;
ghost bool pipOk;
function peekSummary() returns (uint256, bool) {
    return (pipVal, pipOk);
}

ghost uint256 calcPrice;
function calcPriceSummary() returns uint256 {
    return calcPrice;
}

ghost lockedGhost() returns uint256;

hook Sstore locked uint256 n_locked {
    havoc lockedGhost assuming lockedGhost@new() == n_locked;
}

hook Sload uint256 value locked {
    require lockedGhost() == value;
}

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) {
    env e;

    address anyAddr;
    uint256 anyUint256;

    mathint wardsBefore = wards(anyAddr);
    address dogBefore = dog();
    address vowBefore = vow();
    address spotterBefore = spotter();
    address calcBefore = calc();
    mathint bufBefore = buf();
    mathint tailBefore = tail();
    mathint cuspBefore = cusp();
    mathint chipBefore = chip();
    mathint tipBefore = tip();
    mathint chostBefore = chost();
    mathint kicksBefore = kicks();
    mathint activeBefore = active(anyUint256);
    mathint countBefore = count();
    mathint salesAnyPosBefore; mathint salesAnyTabBefore; mathint salesAnyLotBefore; mathint salesAnyTotBefore; address salesAnyUsrBefore; mathint salesAnyTicBefore; mathint salesAnyTopBefore;
    salesAnyPosBefore, salesAnyTabBefore, salesAnyLotBefore, salesAnyTotBefore, salesAnyUsrBefore, salesAnyTicBefore, salesAnyTopBefore = sales(anyUint256);
    mathint stoppedBefore = stopped();

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);
    address dogAfter = dog();
    address vowAfter = vow();
    address spotterAfter = spotter();
    address calcAfter = calc();
    mathint bufAfter = buf();
    mathint tailAfter = tail();
    mathint cuspAfter = cusp();
    mathint chipAfter = chip();
    mathint tipAfter = tip();
    mathint chostAfter = chost();
    mathint kicksAfter = kicks();
    mathint activeAfter = active(anyUint256);
    mathint countAfter = count();
    mathint salesAnyPosAfter; mathint salesAnyTabAfter; mathint salesAnyLotAfter; mathint salesAnyTotAfter; address salesAnyUsrAfter; mathint salesAnyTicAfter; mathint salesAnyTopAfter;
    salesAnyPosAfter, salesAnyTabAfter, salesAnyLotAfter, salesAnyTotAfter, salesAnyUsrAfter, salesAnyTicAfter, salesAnyTopAfter = sales(anyUint256);
    mathint stoppedAfter = stopped();

    assert wardsAfter != wardsBefore => f.selector == sig:rely(address).selector || f.selector == sig:deny(address).selector, "Assert 1";
    assert dogAfter != dogBefore => f.selector == sig:file(bytes32,address).selector, "Assert 2";
    assert vowAfter != vowBefore => f.selector == sig:file(bytes32,address).selector, "Assert 3";
    assert spotterAfter != spotterBefore => f.selector == sig:file(bytes32,address).selector, "Assert 4";
    assert calcAfter != calcBefore => f.selector == sig:file(bytes32,address).selector, "Assert 5";
    assert bufAfter != bufBefore => f.selector == sig:file(bytes32,uint256).selector, "Assert 6";
    assert tailAfter != tailBefore => f.selector == sig:file(bytes32,uint256).selector, "Assert 7";
    assert cuspAfter != cuspBefore => f.selector == sig:file(bytes32,uint256).selector, "Assert 8";
    assert chipAfter != chipBefore => f.selector == sig:file(bytes32,uint256).selector, "Assert 9";
    assert tipAfter != tipBefore => f.selector == sig:file(bytes32,uint256).selector, "Assert 10";
    assert chostAfter != chostBefore => f.selector == sig:upchost().selector, "Assert 11";
    assert kicksAfter != kicksBefore => f.selector == sig:kick(uint256,uint256,address,address).selector, "Assert 12";
    assert countAfter != countBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 13";
    assert activeAfter != activeBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 14";
    assert salesAnyPosAfter != salesAnyPosBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 15";
    assert salesAnyTabAfter != salesAnyTabBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 16";
    assert salesAnyLotAfter != salesAnyLotBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 17";
    assert salesAnyTotAfter != salesAnyTotBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 18";
    assert salesAnyUsrAfter != salesAnyUsrBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 19";
    assert salesAnyTicAfter != salesAnyTicBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:redo(uint256,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 20";
    assert salesAnyTopAfter != salesAnyTopBefore => f.selector == sig:kick(uint256,uint256,address,address).selector || f.selector == sig:redo(uint256,address).selector || f.selector == sig:take(uint256,uint256,uint256,address,bytes).selector || f.selector == sig:yank(uint256).selector, "Assert 21";
    assert stoppedAfter != stoppedBefore => f.selector == sig:file(bytes32,uint256).selector, "Assert 22";
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
rule file_uint256(bytes32 what, uint256 data) {
    env e;

    mathint bufBefore = buf();
    mathint tailBefore = tail();
    mathint cuspBefore = cusp();
    mathint chipBefore = chip();
    mathint tipBefore = tip();
    mathint stoppedBefore = stopped();

    file(e, what, data);

    mathint bufAfter = buf();
    mathint tailAfter = tail();
    mathint cuspAfter = cusp();
    mathint chipAfter = chip();
    mathint tipAfter = tip();
    mathint stoppedAfter = stopped();

    assert what == to_bytes32(0x6275660000000000000000000000000000000000000000000000000000000000) => bufAfter == to_mathint(data), "Assert 1";
    assert what != to_bytes32(0x6275660000000000000000000000000000000000000000000000000000000000) => bufAfter == bufBefore, "Assert 2";
    assert what == to_bytes32(0x7461696c00000000000000000000000000000000000000000000000000000000) => tailAfter == to_mathint(data), "Assert 3";
    assert what != to_bytes32(0x7461696c00000000000000000000000000000000000000000000000000000000) => tailAfter == tailBefore, "Assert 4";
    assert what == to_bytes32(0x6375737000000000000000000000000000000000000000000000000000000000) => cuspAfter == to_mathint(data), "Assert 5";
    assert what != to_bytes32(0x6375737000000000000000000000000000000000000000000000000000000000) => cuspAfter == cuspBefore, "Assert 6";
    assert what == to_bytes32(0x6368697000000000000000000000000000000000000000000000000000000000) => chipAfter == data % (max_uint64 + 1), "Assert 7";
    assert what != to_bytes32(0x6368697000000000000000000000000000000000000000000000000000000000) => chipAfter == chipBefore, "Assert 8";
    assert what == to_bytes32(0x7469700000000000000000000000000000000000000000000000000000000000) => tipAfter == data % (max_uint192 + 1), "Assert 9";
    assert what != to_bytes32(0x7469700000000000000000000000000000000000000000000000000000000000) => tipAfter == tipBefore, "Assert 10";
    assert what == to_bytes32(0x73746f7070656400000000000000000000000000000000000000000000000000) => stoppedAfter == to_mathint(data), "Assert 11";
    assert what != to_bytes32(0x73746f7070656400000000000000000000000000000000000000000000000000) => stoppedAfter == stoppedBefore, "Assert 12";
}

// Verify revert rules on file
rule file_uint256_revert(bytes32 what, uint256 data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);
    mathint locked = lockedGhost();

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = locked != 0;
    bool revert4 = what != to_bytes32(0x6275660000000000000000000000000000000000000000000000000000000000) &&
                   what != to_bytes32(0x7461696c00000000000000000000000000000000000000000000000000000000) &&
                   what != to_bytes32(0x6375737000000000000000000000000000000000000000000000000000000000) &&
                   what != to_bytes32(0x6368697000000000000000000000000000000000000000000000000000000000) &&
                   what != to_bytes32(0x7469700000000000000000000000000000000000000000000000000000000000) &&
                   what != to_bytes32(0x73746f7070656400000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting file
rule file_address(bytes32 what, address data) {
    env e;

    address spotterBefore = spotter();
    address dogBefore = dog();
    address vowBefore = vow();
    address calcBefore = calc();

    file(e, what, data);

    address spotterAfter = spotter();
    address dogAfter = dog();
    address vowAfter = vow();
    address calcAfter = calc();

    assert what == to_bytes32(0x73706f7474657200000000000000000000000000000000000000000000000000) => spotterAfter == data, "Assert 1";
    assert what != to_bytes32(0x73706f7474657200000000000000000000000000000000000000000000000000) => spotterAfter == spotterBefore, "Assert 2";
    assert what == to_bytes32(0x646f670000000000000000000000000000000000000000000000000000000000) => dogAfter == data, "Assert 3";
    assert what != to_bytes32(0x646f670000000000000000000000000000000000000000000000000000000000) => dogAfter == dogBefore, "Assert 4";
    assert what == to_bytes32(0x766f770000000000000000000000000000000000000000000000000000000000) => vowAfter == data, "Assert 5";
    assert what != to_bytes32(0x766f770000000000000000000000000000000000000000000000000000000000) => vowAfter == vowBefore, "Assert 6";
    assert what == to_bytes32(0x63616c6300000000000000000000000000000000000000000000000000000000) => calcAfter == data, "Assert 7";
    assert what != to_bytes32(0x63616c6300000000000000000000000000000000000000000000000000000000) => calcAfter == calcBefore, "Assert 8";
}

// Verify revert rules on file
rule file_address_revert(bytes32 what, address data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);
    mathint locked = lockedGhost();

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = locked != 0;
    bool revert4 = what != to_bytes32(0x73706f7474657200000000000000000000000000000000000000000000000000) &&
                   what != to_bytes32(0x646f670000000000000000000000000000000000000000000000000000000000) &&
                   what != to_bytes32(0x766f770000000000000000000000000000000000000000000000000000000000) &&
                   what != to_bytes32(0x63616c6300000000000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting kick
rule kick(uint256 tab, uint256 lot, address usr, address kpr) {
    env e;

    mathint kicksBefore = kicks();
    mathint countBefore = count();
    mathint id = kicksBefore + 1;
    uint256 otherUint256;
    require to_mathint(otherUint256) != id;
    mathint salesOtherPosBefore; mathint salesOtherTabBefore; mathint salesOtherLotBefore; mathint salesOtherTotBefore; address salesOtherUsrBefore; mathint salesOtherTicBefore; mathint salesOtherTopBefore;
    salesOtherPosBefore, salesOtherTabBefore, salesOtherLotBefore, salesOtherTotBefore, salesOtherUsrBefore, salesOtherTicBefore, salesOtherTopBefore = sales(otherUint256);
    mathint vatDaiKprBefore = vat.dai(kpr);
    address vow = vow();
    mathint vatSinVowBefore = vat.sin(vow);
    bytes32 ilk = ilk();
    mathint engineUrnAuctionsUsrBefore = lockstakeEngine.urnAuctions(usr);

    mathint par = spotter.par();
    // Avoid division by zero
    require par > 0;
    mathint val; bool b;
    val, b = peekSummary();
    mathint feedPrice = val * 10^9 * RAY() / par;
    mathint buf = buf();
    mathint coin = tip() + tab * chip() / WAD();

    kick(e, tab, lot, usr, kpr);

    mathint kicksAfter = kicks();
    mathint countAfter = count();
    mathint activeCountAfter = active(require_uint256(countAfter - 1));
    mathint salesIdPosAfter; mathint salesIdTabAfter; mathint salesIdLotAfter; mathint salesIdTotAfter; address salesIdUsrAfter; mathint salesIdTicAfter; mathint salesIdTopAfter;
    salesIdPosAfter, salesIdTabAfter, salesIdLotAfter, salesIdTotAfter, salesIdUsrAfter, salesIdTicAfter, salesIdTopAfter = sales(require_uint256(id));
    mathint salesOtherPosAfter; mathint salesOtherTabAfter; mathint salesOtherLotAfter; mathint salesOtherTotAfter; address salesOtherUsrAfter; mathint salesOtherTicAfter; mathint salesOtherTopAfter;
    salesOtherPosAfter, salesOtherTabAfter, salesOtherLotAfter, salesOtherTotAfter, salesOtherUsrAfter, salesOtherTicAfter, salesOtherTopAfter = sales(otherUint256);
    mathint vatDaiKprAfter= vat.dai(kpr);
    mathint vatSinVowAfter= vat.sin(vow);
    mathint engineUrnAuctionsUsrAfter = lockstakeEngine.urnAuctions(usr);

    assert kicksAfter == kicksBefore + 1, "Assert 1";
    assert countAfter == countBefore + 1, "Assert 2";
    assert activeCountAfter == id, "Assert 3";
    assert salesIdPosAfter == countAfter - 1, "Assert 4";
    assert salesIdTabAfter == to_mathint(tab), "Assert 5";
    assert salesIdLotAfter == to_mathint(lot), "Assert 6";
    assert salesIdTotAfter == to_mathint(lot), "Assert 7";
    assert salesIdUsrAfter == usr, "Assert 8";
    assert salesIdTicAfter == e.block.timestamp % (max_uint96 + 1), "Assert 9";
    assert salesIdTopAfter == feedPrice * buf / RAY(), "Assert 10";
    assert salesOtherPosAfter == salesOtherPosBefore, "Assert 11";
    assert salesOtherTabAfter == salesOtherTabBefore, "Assert 12";
    assert salesOtherLotAfter == salesOtherLotBefore, "Assert 13";
    assert salesOtherTotAfter == salesOtherTotBefore, "Assert 14";
    assert salesOtherUsrAfter == salesOtherUsrBefore, "Assert 15";
    assert salesOtherTicAfter == salesOtherTicBefore, "Assert 16";
    assert salesOtherTopAfter == salesOtherTopBefore, "Assert 17";
    assert vatDaiKprAfter == vatDaiKprBefore + coin, "Assert 18";
    assert vatSinVowAfter == vatSinVowBefore + coin, "Assert 19";
    assert engineUrnAuctionsUsrAfter == engineUrnAuctionsUsrBefore + 1, "Assert 20";
}

// Verify revert rules on kick
rule kick_revert(uint256 tab, uint256 lot, address usr, address kpr) {
    env e;

    require usr == lockstakeUrn;
    address prevVoteDelegate = lockstakeEngine.urnVoteDelegates(usr);
    require prevVoteDelegate == addrZero() || prevVoteDelegate == voteDelegate;
    address prevFarm = lockstakeEngine.urnFarms(usr);
    require prevFarm == addrZero() || prevFarm == stakingRewards;

    mathint wardsSender = wards(e.msg.sender);
    mathint locked = lockedGhost();
    mathint stopped = stopped();
    mathint kicks = kicks();
    mathint count = count();
    mathint buf = buf();
    mathint par = spotter.par();
    bytes32 ilk = ilk();
    mathint vatUrnsIlkUsrInk; mathint a;
    vatUrnsIlkUsrInk, a = vat.urns(ilk, usr);
    // Avoid division by zero
    require par > 0;
    mathint val; bool has;
    val, has = peekSummary();
    mathint feedPrice = val * 10^9 * RAY() / par;
    mathint chip = chip();
    mathint coin = tip() + tab * chip / WAD();
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lockstakeEngine.wards(currentContract) == 1;
    // Happening in urn (usr) init
    require lsmkr.allowance(usr, lockstakeEngine) == max_uint256;
    // Tokens invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(prevFarm) + lsmkr.balanceOf(usr) + lsmkr.balanceOf(lockstakeEngine);
    require stakingRewards.totalSupply() >= stakingRewards.balanceOf(usr);
    // VoteDelegate assumptions
    require prevVoteDelegate == addrZero() || to_mathint(voteDelegate.stake(lockstakeEngine)) >= vatUrnsIlkUsrInk + lot;
    require prevVoteDelegate == addrZero() || mkr.balanceOf(voteDelegate) >= voteDelegate.stake(lockstakeEngine);
    // StakingRewards assumptions
    require prevFarm == addrZero() && lsmkr.balanceOf(usr) >= lot ||
            prevFarm != addrZero() && to_mathint(stakingRewards.balanceOf(usr)) >= vatUrnsIlkUsrInk + lot && to_mathint(lsmkr.balanceOf(prevFarm)) >= vatUrnsIlkUsrInk + lot;
    // Practical Vat assumptions
    require vat.sin(vow()) + coin <= max_uint256;
    require vat.dai(kpr) + coin <= max_uint256;
    require vat.vice() + coin <= max_uint256;
    require vat.debt() + coin <= max_uint256;
    // Practical assumption (vatUrnsIlkUsrInk + lot should be the same than the vatUrnsIlkUsrInk prev to the kick call)
    require vatUrnsIlkUsrInk + lot <= max_uint256;
    // LockstakeEngine assumption
    require lockstakeEngine.urnAuctions(usr) < max_uint256;
    require lockstakeEngine.ilk() == ilk;

    kick@withrevert(e, tab, lot, usr, kpr);

    bool revert1  = e.msg.value > 0;
    bool revert2  = wardsSender != 1;
    bool revert3  = locked != 0;
    bool revert4  = stopped >= 1;
    bool revert5  = tab == 0;
    bool revert6  = lot == 0;
    bool revert7  = to_mathint(lot) > max_int256();
    bool revert8  = usr == addrZero();
    bool revert9  = kicks == max_uint256;
    bool revert10 = count == max_uint256;
    bool revert11 = !has;
    bool revert12 = val * 10^9 * RAY() > max_uint256;
    bool revert13 = feedPrice * buf > max_uint256;
    bool revert14 = feedPrice * buf / RAY() == 0;
    bool revert15 = tab * chip > max_uint256;
    bool revert16 = coin > max_uint256;

    assert lastReverted <=> revert1  || revert2  || revert3  ||
                            revert4  || revert5  || revert6  ||
                            revert7  || revert8  || revert9  ||
                            revert10 || revert11 || revert12 ||
                            revert13 || revert14 || revert15 ||
                            revert16, "Revert rules failed";
}

// Verify correct storage changes for non reverting redo
rule redo(uint256 id, address kpr) {
    env e;

    uint256 otherUint256;
    require otherUint256 != id;

    mathint chost = chost();
    mathint a; address b;
    mathint salesIdTab; mathint salesIdLot; mathint salesIdTicBefore; mathint salesIdTopBefore;
    a, salesIdTab, salesIdLot, a, b, salesIdTicBefore, salesIdTopBefore = sales(id);
    mathint salesOtherTicBefore; mathint salesOtherTopBefore;
    a, a, a, a, b, salesOtherTicBefore, salesOtherTopBefore = sales(otherUint256);
    mathint vatDaiKprBefore = vat.dai(kpr);
    address vow = vow();
    mathint vatSinVowBefore = vat.sin(vow);

    mathint par = spotter.par();
    // Avoid division by zero
    require par > 0;
    mathint val; bool c;
    val, c = peekSummary();
    mathint feedPrice = val * 10^9 * RAY() / par;
    mathint buf = buf();
    mathint coin = tip() + salesIdTab * chip() / WAD();
    bool paysKpr = salesIdTab >= chost && salesIdLot * feedPrice >= chost;

    redo(e, id, kpr);

    mathint salesIdTicAfter; mathint salesIdTopAfter;
    a, a, a, a, b, salesIdTicAfter, salesIdTopAfter = sales(id);
    mathint salesOtherTicAfter; mathint salesOtherTopAfter;
    a, a, a, a, b, salesOtherTicAfter, salesOtherTopAfter = sales(otherUint256);
    mathint vatDaiKprAfter = vat.dai(kpr);
    mathint vatSinVowAfter = vat.sin(vow);

    assert salesIdTicAfter == e.block.timestamp % (max_uint96 + 1), "Assert 1";
    assert salesIdTopAfter == feedPrice * buf / RAY(), "Assert 2";
    assert salesOtherTicAfter == salesOtherTicBefore, "Assert 3";
    assert salesOtherTopAfter == salesOtherTopBefore, "Assert 4";
    assert paysKpr => vatDaiKprAfter == vatDaiKprBefore + coin, "Assert 5";
    assert !paysKpr => vatDaiKprAfter == vatDaiKprBefore, "Assert 6";
    assert paysKpr => vatSinVowAfter == vatSinVowBefore + coin, "Assert 7";
    assert !paysKpr => vatSinVowAfter == vatSinVowBefore, "Assert 8";
}

// Verify revert rules on redo
rule redo_revert(uint256 id, address kpr) {
    env e;

    mathint locked = lockedGhost();
    mathint stopped = stopped();
    mathint tail = tail();
    mathint cusp = cusp();
    mathint chost = chost();

    mathint a;
    mathint salesIdTab; mathint salesIdLot; address salesIdUsr; mathint salesIdTic; mathint salesIdTop;
    a, salesIdTab, salesIdLot, a, salesIdUsr, salesIdTic, salesIdTop = sales(id);

    require to_mathint(e.block.timestamp) >= salesIdTic;
    mathint price = calcPriceSummary();
    // Avoid division by zero
    require salesIdTop > 0;
    bool done = e.block.timestamp - salesIdTic > tail || price * RAY() / salesIdTop < cusp;

    mathint par = spotter.par();
    // Avoid division by zero
    require par > 0;
    mathint val; bool has;
    val, has = peekSummary();
    mathint feedPrice = val * 10^9 * RAY() / par;
    mathint buf = buf();
    mathint tip = tip();
    mathint chip = chip();
    mathint coin = tip + salesIdTab * chip() / WAD();
    bool paysKpr = salesIdTab >= chost && salesIdLot * feedPrice >= chost;

    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    // Practical Vat assumptions
    require vat.sin(vow()) + coin <= max_uint256;
    require vat.dai(kpr) + coin <= max_uint256;
    require vat.vice() + coin <= max_uint256;
    require vat.debt() + coin <= max_uint256;

    redo@withrevert(e, id, kpr);

    bool revert1  = e.msg.value > 0;
    bool revert2  = locked != 0;
    bool revert3  = stopped >= 2;
    bool revert4  = salesIdUsr == addrZero();
    bool revert5  = to_mathint(e.block.timestamp) < salesIdTic;
    bool revert6  = e.block.timestamp - salesIdTic <= tail && price * RAY() > max_uint256;
    bool revert7  = !done;
    bool revert8  = !has;
    bool revert9  = val * 10^9 * RAY() > max_uint256;
    bool revert10 = feedPrice * buf > max_uint256;
    bool revert11 = feedPrice * buf / RAY() == 0;
    bool revert12 = (tip > 0 || chip > 0) && salesIdTab >= chost && salesIdLot * feedPrice > max_uint256;
    bool revert13 = paysKpr && salesIdTab * chip > max_uint256;
    bool revert14 = paysKpr && coin > max_uint256;

    assert lastReverted <=> revert1  || revert2  || revert3  ||
                            revert4  || revert5  || revert6  ||
                            revert7  || revert8  || revert9  ||
                            revert10 || revert11 || revert12 ||
                            revert13 || revert14, "Revert rules failed";
}

// Verify correct storage changes for non reverting take
rule take(uint256 id, uint256 amt, uint256 max, address who, bytes data) {
    env e;

    bytes32 ilk = ilk();
    address vow = vow();

    mathint countBefore = count();
    uint256 otherUint256;
    require otherUint256 != id;

    mathint salesIdPosBefore; mathint salesIdTabBefore; mathint salesIdLotBefore; mathint salesIdTotBefore; address salesIdUsrBefore; mathint salesIdTicBefore; mathint salesIdTopBefore;
    salesIdPosBefore, salesIdTabBefore, salesIdLotBefore, salesIdTotBefore, salesIdUsrBefore, salesIdTicBefore, salesIdTopBefore = sales(id);
    require salesIdUsrBefore == lockstakeUrn;
    mathint salesOtherPosBefore; mathint salesOtherTabBefore; mathint salesOtherLotBefore; mathint salesOtherTotBefore; address salesOtherUsrBefore; mathint salesOtherTicBefore; mathint salesOtherTopBefore;
    salesOtherPosBefore, salesOtherTabBefore, salesOtherLotBefore, salesOtherTotBefore, salesOtherUsrBefore, salesOtherTicBefore, salesOtherTopBefore = sales(otherUint256);
    mathint vatGemIlkClipperBefore = vat.gem(ilk, currentContract);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(lockstakeEngine);
    mathint mkrBalanceOfWhoBefore = mkr.balanceOf(who);
    mathint vatDaiSenderBefore = vat.dai(e.msg.sender);
    mathint vatDaiVowBefore = vat.dai(vow);
    mathint dogDirtBefore = dog.Dirt();
    address a; mathint b;
    mathint dogIlkDirtBefore;
    a, b, b, dogIlkDirtBefore = dog.ilks(ilk);
    mathint vatUrnsIlkUsrInkBefore;
    vatUrnsIlkUsrInkBefore, b = vat.urns(ilk, salesIdUsrBefore);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUsrBefore = lsmkr.balanceOf(salesIdUsrBefore);
    mathint engineUrnAuctionsUsrBefore = lockstakeEngine.urnAuctions(salesIdUsrBefore);

    mathint price = calcPriceSummary();
    // Avoid division by zero
    require price > 0;
    // Token invariants
    require mkrTotalSupplyBefore >= mkrBalanceOfEngineBefore + mkrBalanceOfWhoBefore;
    require lsmkrTotalSupplyBefore >= lsmkrBalanceOfUsrBefore;
    // LockstakeEngine assumption
    require lockstakeEngine.ilk() == ilk;
    // Governance setting assumption
    require vow != e.msg.sender;

    mathint sliceAux = _min(salesIdLotBefore, amt);
    mathint oweAux = sliceAux * price;
    mathint chost = chost();
    mathint slice; mathint owe;
    if (oweAux > salesIdTabBefore) {
        owe = salesIdTabBefore;
        slice = owe / price;
    } else {
        if (oweAux < salesIdTabBefore && sliceAux < salesIdLotBefore) {
            if (salesIdTabBefore - oweAux < chost) {
                owe = salesIdTabBefore - chost;
                slice = owe / price;
            } else {
                owe = oweAux;
                slice = sliceAux;
            }
        } else {
            owe = oweAux;
            slice = sliceAux;
        }
    }
    mathint calcTabAfter = salesIdTabBefore - owe;
    mathint calcLotAfter = salesIdLotBefore - slice;
    bool isRemoved = calcLotAfter == 0 || calcTabAfter == 0;
    mathint fee = lockstakeEngine.fee();
    // Happening in Engine constructor
    require fee < WAD();
    mathint sold = calcLotAfter == 0 ? salesIdTotBefore : (calcTabAfter == 0 ? salesIdTotBefore - calcLotAfter : 0);
    mathint left = calcTabAfter == 0 ? calcLotAfter : 0;
    mathint burn = _min(sold * fee / (WAD() - fee), left);
    mathint refund = left - burn;

    take(e, id, amt, max, who, data);

    mathint kicksAfter = kicks();
    mathint countAfter = count();
    mathint activeCountAfter = active(require_uint256(countAfter - 1));
    mathint salesIdPosAfter; mathint salesIdTabAfter; mathint salesIdLotAfter; mathint salesIdTotAfter; address salesIdUsrAfter; mathint salesIdTicAfter; mathint salesIdTopAfter;
    salesIdPosAfter, salesIdTabAfter, salesIdLotAfter, salesIdTotAfter, salesIdUsrAfter, salesIdTicAfter, salesIdTopAfter = sales(id);
    mathint salesOtherPosAfter; mathint salesOtherTabAfter; mathint salesOtherLotAfter; mathint salesOtherTotAfter; address salesOtherUsrAfter; mathint salesOtherTicAfter; mathint salesOtherTopAfter;
    salesOtherPosAfter, salesOtherTabAfter, salesOtherLotAfter, salesOtherTotAfter, salesOtherUsrAfter, salesOtherTicAfter, salesOtherTopAfter = sales(otherUint256);
    mathint vatGemIlkClipperAfter = vat.gem(ilk, currentContract);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfEngineAfter = mkr.balanceOf(lockstakeEngine);
    mathint mkrBalanceOfWhoAfter = mkr.balanceOf(who);
    mathint vatDaiSenderAfter = vat.dai(e.msg.sender);
    mathint vatDaiVowAfter = vat.dai(vow);
    mathint dogDirtAfter = dog.Dirt();
    mathint dogIlkDirtAfter;
    a, b, b, dogIlkDirtAfter = dog.ilks(ilk);
    mathint vatUrnsIlkUsrInkAfter;
    vatUrnsIlkUsrInkAfter, b = vat.urns(ilk, salesIdUsrBefore);
    mathint lsmkrTotalSupplyAfter = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUsrAfter = lsmkr.balanceOf(salesIdUsrBefore);
    mathint engineUrnAuctionsUsrAfter = lockstakeEngine.urnAuctions(salesIdUsrBefore);

    assert countAfter == (isRemoved ? countBefore - 1 : countBefore), "Assert 1";
    assert salesIdPosAfter == (isRemoved ? 0 : salesIdPosBefore), "Assert 2";
    assert salesIdTabAfter == (isRemoved ? 0 : calcTabAfter), "Assert 3";
    assert salesIdLotAfter == (isRemoved ? 0 : calcLotAfter), "Assert 4";
    assert salesIdTotAfter == (isRemoved ? 0 : salesIdTotBefore), "Assert 5";
    assert salesIdUsrAfter == (isRemoved ? addrZero() : salesIdUsrBefore), "Assert 6";
    assert salesIdTicAfter == (isRemoved ? 0 : salesIdTicBefore), "Assert 7";
    assert salesIdTopAfter == (isRemoved ? 0 : salesIdTopBefore), "Assert 8";
    assert salesOtherPosAfter == (otherUint256 == active(assert_uint256(countBefore - 1)) && isRemoved ? salesIdPosBefore : salesOtherPosBefore), "Assert 9";
    assert salesOtherTabAfter == salesOtherTabBefore, "Assert 10";
    assert salesOtherLotAfter == salesOtherLotBefore, "Assert 11";
    assert salesOtherTotAfter == salesOtherTotBefore, "Assert 12";
    assert salesOtherUsrAfter == salesOtherUsrBefore, "Assert 13";
    assert salesOtherTicAfter == salesOtherTicBefore, "Assert 14";
    assert salesOtherTopAfter == salesOtherTopBefore, "Assert 15";
    assert vatGemIlkClipperAfter == vatGemIlkClipperBefore - (calcLotAfter > 0 && calcTabAfter == 0 ? salesIdLotBefore : slice), "Assert 16";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - burn, "Assert 17";
    assert who == lockstakeEngine => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - burn, "Assert 18";
    assert who != lockstakeEngine => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - slice - burn, "Assert 19";
    assert who != lockstakeEngine && who != salesIdUsrBefore => mkrBalanceOfWhoAfter == mkrBalanceOfWhoBefore + slice, "Assert 20";
    assert vatDaiSenderAfter == vatDaiSenderBefore - owe, "Assert 21";
    assert vatDaiVowAfter == vatDaiVowBefore + owe, "Assert 22";
    assert dogDirtAfter == dogDirtBefore - (calcLotAfter == 0 ? salesIdTabBefore : owe), "Assert 23";
    assert dogIlkDirtAfter == dogIlkDirtBefore - (calcLotAfter == 0 ? salesIdTabBefore : owe), "Assert 24";
    assert vatUrnsIlkUsrInkAfter == vatUrnsIlkUsrInkBefore + refund, "Assert 25";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore + refund, "Assert 26";
    assert lsmkrBalanceOfUsrAfter == lsmkrBalanceOfUsrBefore + refund, "Assert 27";
    assert engineUrnAuctionsUsrAfter == engineUrnAuctionsUsrBefore - (isRemoved ? 1 : 0), "Assert 28";
}

// Verify revert rules on take
rule take_revert(uint256 id, uint256 amt, uint256 max, address who, bytes data) {
    env e;

    require e.msg.sender != currentContract;

    bytes32 ilk = ilk();
    address vow = vow();
    mathint locked = lockedGhost();
    mathint stopped = stopped();
    mathint tail = tail();
    mathint cusp = cusp();
    mathint chost = chost();
    mathint count = count();
    mathint activeLast;
    if (count > 0) {
        activeLast = active(assert_uint256(count - 1));
    } else {
        activeLast = 0;
    }

    mathint salesIdPos; mathint salesIdTab; mathint salesIdLot; mathint salesIdTot; address salesIdUsr; mathint salesIdTic; mathint salesIdTop;
    salesIdPos, salesIdTab, salesIdLot, salesIdTot, salesIdUsr, salesIdTic, salesIdTop = sales(id);

    mathint vatGemIlkClipper = vat.gem(ilk, currentContract);
    mathint vatCanSenderClipper = vat.can(e.msg.sender, currentContract);
    mathint vatDaiSender = vat.dai(e.msg.sender);

    mathint vatIlksIlkArt; mathint vatIlksIlkRate; mathint vatIlksIlkSpot; mathint vatIlksIlkDust; mathint a;
    vatIlksIlkArt, vatIlksIlkRate, vatIlksIlkSpot, a, vatIlksIlkDust = vat.ilks(ilk);
    mathint vatUrnsIlkUsrInk; mathint vatUrnsIlkUsrArt;
    vatUrnsIlkUsrInk, vatUrnsIlkUsrArt = vat.urns(ilk, salesIdUsr);

    mathint dogDirt = dog.Dirt();
    address b; mathint dogIlkDirt;
    b, a, a, dogIlkDirt = dog.ilks(ilk);

    require to_mathint(e.block.timestamp) >= salesIdTic;
    mathint price = calcPriceSummary();
    // Avoid division by zero
    require salesIdTop > 0;
    bool done = e.block.timestamp - salesIdTic > tail || price * RAY() / salesIdTop < cusp;

    mathint sliceAux = _min(salesIdLot, amt);
    mathint oweAux = sliceAux * price;
    mathint slice; mathint owe;
    if (oweAux > salesIdTab) {
        owe = salesIdTab;
        slice = owe / price;
    } else {
        if (oweAux < salesIdTab && sliceAux < salesIdLot) {
            if (salesIdTab - oweAux < chost) {
                owe = salesIdTab - chost;
                slice = price > 0 ? owe / price : max_uint256; // Just a placeholder if price == 0
            } else {
                owe = oweAux;
                slice = sliceAux;
            }
        } else {
            owe = oweAux;
            slice = sliceAux;
        }
    }
    mathint calcTabAfter = salesIdTab - owe;
    mathint calcLotAfter = salesIdLot - slice;
    mathint digAmt = calcLotAfter == 0 ? salesIdTab : owe;
    bool isRemoved = calcLotAfter == 0 || calcTabAfter == 0;
    mathint fee = lockstakeEngine.fee();

    // Happening in kick
    require salesIdLot <= max_int256();
    require salesIdTot >= salesIdLot;
    // Happening in Engine constructor
    require fee < WAD();
    require lsmkr.wards(lockstakeEngine) == 1;
    mathint sold = calcLotAfter == 0 ? salesIdTot : (calcTabAfter == 0 ? salesIdTot - calcLotAfter : 0);
    mathint left = calcTabAfter == 0 ? calcLotAfter : 0;
    mathint burn = _min(sold * fee / (WAD() - fee), left);
    mathint refund = left - burn;
    // Happening in urn init
    require vat.can(salesIdUsr, lockstakeEngine) == 1;
    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(lockstakeEngine) + mkr.balanceOf(who);
    require lsmkr.totalSupply() >= mkr.balanceOf(salesIdUsr);
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require vat.wards(lockstakeEngine) == 1;
    require dog.wards(currentContract) == 1;
    require lockstakeEngine.wards(currentContract) == 1;
    // LockstakeEngine assumtions
    require lockstakeEngine.ilk() == ilk;
    require to_mathint(mkr.balanceOf(lockstakeEngine)) >= slice + burn;
    require lockstakeEngine.urnAuctions(salesIdUsr) > 0;
    require sold * fee <= max_uint256;
    require refund <= max_int256();
    require vat.gem(ilk, salesIdUsr) + refund <= max_uint256;
    require salesIdUsr != addrZero() && salesIdUsr != lsmkr;
    require lsmkr.totalSupply() + refund <= max_uint256;
    // Dog assumptions
    require dogDirt >= digAmt;
    require dogIlkDirt >= digAmt;
    // Practical Vat assumptions
    require vat.live() == 1;
    require vat.dai(vow) + owe <= max_uint256;
    require vatIlksIlkRate >= RAY() && vatIlksIlkRate <= max_int256();
    require vatUrnsIlkUsrInk + refund <= max_uint256;
    require (vatUrnsIlkUsrInk + refund) * vatIlksIlkSpot <= max_uint256;
    require vatIlksIlkRate * vatIlksIlkArt <= max_uint256;
    require vatIlksIlkArt >= vatUrnsIlkUsrArt;
    require vatUrnsIlkUsrArt == 0 || vatIlksIlkRate * vatUrnsIlkUsrArt >= vatIlksIlkDust;

    take@withrevert(e, id, amt, max, who, data);

    bool revert1  = e.msg.value > 0;
    bool revert2  = locked != 0;
    bool revert3  = stopped >= 3;
    bool revert4  = salesIdUsr == addrZero();
    bool revert5  = price * RAY() > max_uint256;
    bool revert6  = done;
    bool revert7  = to_mathint(max) < price;
    bool revert8  = sliceAux * price > max_uint256;
    bool revert9  = oweAux < salesIdTab && sliceAux < salesIdLot && salesIdTab - oweAux < chost && salesIdTab <= chost;
    bool revert10 = oweAux < salesIdTab && sliceAux < salesIdLot && salesIdTab - oweAux < chost && price == 0;
    bool revert11 = vatGemIlkClipper < slice;
    bool revert12 = data.length > 0 && (who == badGuy || who == redoGuy || who == kickGuy || who == fileUintGuy || who == fileAddrGuy || who == yankGuy);
    bool revert13 = vatCanSenderClipper != 1;
    bool revert14 = vatDaiSender < owe;
    bool revert15 = (calcLotAfter == 0 || calcTabAfter == 0) && count == 0;
    bool revert16 = (calcLotAfter == 0 || calcTabAfter == 0) && to_mathint(id) != activeLast && salesIdPos > count - 1;
    bool revert17 = calcLotAfter > 0 && calcTabAfter == 0 && vatGemIlkClipper < salesIdLot;

    assert lastReverted <=> revert1  || revert2  || revert3  ||
                            revert4  || revert5  || revert6  ||
                            revert7  || revert8  || revert9  ||
                            revert10 || revert11 || revert12 ||
                            revert13 || revert14 || revert15 ||
                            revert16 || revert17, "Revert rules failed";
}
