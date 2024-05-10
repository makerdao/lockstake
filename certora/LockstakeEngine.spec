// LockstakeEngine.spec

using MulticallExecutor as multicallExecutor;
using LockstakeUrn as lockstakeUrn;
using Vat as vat;
using MkrMock as mkr;
using LockstakeMkr as lsmkr;
using VoteDelegateMock as voteDelegate;
using VoteDelegate2Mock as voteDelegate2;
using VoteDelegateFactoryMock as voteDelegateFactory;
using StakingRewardsMock as farm;
using StakingRewards2Mock as farm2;
using MkrNgtMock as mkrNgt;
using NgtMock as ngt;

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
    function mkrNgt() external returns (address) envfree;
    function ngt() external returns (address) envfree;
    function mkrNgtRate() external returns (uint256) envfree;
    function urnImplementation() external returns (address) envfree;
    // custom getters
    function getUrn(address,uint256) external returns (address) envfree;
    //
    function lockstakeUrn.engine() external returns (address) envfree;
    function vat.live() external returns (uint256) envfree;
    function vat.ilks(bytes32) external returns (uint256,uint256,uint256,uint256,uint256) envfree;
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
    function farm.balanceOf(address) external returns (uint256) envfree;
    function farm.totalSupply() external returns (uint256) envfree;
    function farm2.balanceOf(address) external returns (uint256) envfree;
    function farm2.totalSupply() external returns (uint256) envfree;
    function mkrNgt.rate() external returns (uint256) envfree;
    //
    function voteDelegate.stake(address) external returns (uint256) envfree;
    function voteDelegate2.stake(address) external returns (uint256) envfree;
    function voteDelegateFactory.created(address) external returns (uint256) envfree;
    function _.init() external => DISPATCHER(true);
    function _.lock(uint256) external => DISPATCHER(true);
    function _.free(uint256) external => DISPATCHER(true);
    function _.stake(address,uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => DISPATCHER(true);
    function _.stake(uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
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

definition max_int256() returns mathint = 2^255 - 1;
definition WAD() returns mathint = 10^18;
definition RAY() returns mathint = 10^27;

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) filtered { f -> f.selector != sig:multicall(bytes[]).selector  } {
    env e;

    address anyAddr;
    address anyAddr2;

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

    assert wardsAfter != wardsBefore => f.selector == sig:rely(address).selector || f.selector == sig:deny(address).selector, "wards[x] changed in an unexpected function";
    assert farmsAfter != farmsBefore => f.selector == sig:addFarm(address).selector || f.selector == sig:delFarm(address).selector, "farms[x] changed in an unexpected function";
    assert usrAmtsAfter != usrAmtsBefore => f.selector == sig:open(uint256).selector, "usrAmts[x] changed in an unexpected function";
    assert urnOwnersAfter != urnOwnersBefore => f.selector == sig:open(uint256).selector, "urnOwners[x] changed in an unexpected function";
    assert urnCanAfter != urnCanBefore => f.selector == sig:hope(address,address).selector || f.selector == sig:nope(address,address).selector, "urnCan[x][y] changed in an unexpected function";
    assert urnVoteDelegatesAfter != urnVoteDelegatesBefore => f.selector == sig:selectVoteDelegate(address,address).selector || f.selector == sig:onKick(address,uint256).selector, "urnVoteDelegates[x] changed in an unexpected function";
    assert urnFarmsAfter != urnFarmsBefore => f.selector == sig:selectFarm(address,address,uint16).selector || f.selector == sig:onKick(address,uint256).selector, "urnFarms[x] changed in an unexpected function";
    assert urnAuctionsAfter != urnAuctionsBefore => f.selector == sig:onKick(address,uint256).selector || f.selector == sig:onRemove(address,uint256,uint256).selector, "urnAuctions[x] changed in an unexpected function";
    assert jugAfter != jugBefore => f.selector == sig:file(bytes32,address).selector, "jug changed in an unexpected function";
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

    assert wardsUsrAfter == 1, "rely did not set the wards";
    assert wardsOtherAfter == wardsOtherBefore, "rely did not keep unchanged the rest of wards[x]";
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

    assert wardsUsrAfter == 0, "deny did not set the wards";
    assert wardsOtherAfter == wardsOtherBefore, "deny did not keep unchanged the rest of wards[x]";
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

    assert jugAfter == data, "file did not set jug";
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
rule addFarm(address farm_) {
    env e;

    address other;
    require other != farm_;

    LockstakeEngine.FarmStatus farmsOtherBefore = farms(other);

    addFarm(e, farm_);

    LockstakeEngine.FarmStatus farmsFarmAfter = farms(farm_);
    LockstakeEngine.FarmStatus farmsOtherAfter = farms(other);

    assert farmsFarmAfter == LockstakeEngine.FarmStatus.ACTIVE, "addFarm did not set the farms[farm_] as ACTIVE";
    assert farmsOtherAfter == farmsOtherBefore, "addFarm did not keep unchanged the rest of farms[x]";
}

// Verify revert rules on addFarm
rule addFarm_revert(address farm_) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    addFarm@withrevert(e, farm_);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting delFarm
rule delFarm(address farm_) {
    env e;

    address other;
    require other != farm_;

    LockstakeEngine.FarmStatus farmsOtherBefore = farms(other);

    delFarm(e, farm_);

    LockstakeEngine.FarmStatus farmsFarmAfter = farms(farm_);
    LockstakeEngine.FarmStatus farmsOtherAfter = farms(other);

    assert farmsFarmAfter == LockstakeEngine.FarmStatus.DELETED, "delFarm did not set the farms[farm_] as DELETED";
    assert farmsOtherAfter == farmsOtherBefore, "delFarm did not keep unchanged the rest of farms[x]";
}

// Verify revert rules on delFarm
rule delFarm_revert(address farm_) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    delFarm@withrevert(e, farm_);

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
    assert usrAmtsSenderAfter == usrAmtsSenderBefore + 1, "open did not increase usrAmts[sender] by 1";
    assert usrAmtsOtherAfter == usrAmtsOtherBefore, "open did not keep unchanged for the rest of usrAmts[x]";
    assert urnOwnersUrnAfter == e.msg.sender, "open did not set urnOwners[urn] as the sender";
    assert vatCanUrnEngineAfter == 1, "open did not set vat.can[urn][engine] as 1";
    assert lsmkrAllowanceUrnEngine == max_uint256, "open did not set lsmkr.allowance[urn][engine] as max_uint256";
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

    assert urnCanUrnUsrAfter == 1, "hope did not set the urnCan[urn][usr] as 1";
    assert urnCanOtherAfter == urnCanOtherBefore, "hope did not keep unchanged the rest of urnCan[x][y]";
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

    assert urnCanUrnUsrAfter == 0, "nope did not set the urnCan[urn][usr] as 0";
    assert urnCanOtherAfter == urnCanOtherBefore, "nope did not keep unchanged the rest of urnCan[x][y]";
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

    address zero = 0x0000000000000000000000000000000000000000;

    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address prevVoteDelegate = urnVoteDelegates(urn);
    require prevVoteDelegate == zero || prevVoteDelegate == voteDelegate2;

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

    assert urnVoteDelegatesUrnAfter == voteDelegate_, "selectVoteDelegate did not set urnVoteDelegates[urn] as voteDelegate_";
    assert urnVoteDelegatesOtherAfter == urnVoteDelegatesOtherBefore, "selectVoteDelegate did not keep unchanged the rest of urnVoteDelegates[x]";
    assert prevVoteDelegate == zero => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore, "selectVoteDelegate did not keep unchanged mkr.balanceOf(address(0))";
    assert prevVoteDelegate != zero => mkrBalanceOfPrevVoteDelegateAfter == mkrBalanceOfPrevVoteDelegateBefore - ink, "selectVoteDelegate did not decrease mkr.balanceOf(prevVoteDelegate) by ink";
    assert voteDelegate_ == zero => mkrBalanceOfNewVoteDelegateAfter == mkrBalanceOfNewVoteDelegateBefore, "selectVoteDelegate did not keep unchanged mkr.balanceOf(address(0)) 2";
    assert voteDelegate_ != zero => mkrBalanceOfNewVoteDelegateAfter == mkrBalanceOfNewVoteDelegateBefore + ink, "selectVoteDelegate did not increase mkr.balanceOf(newVoteDelegate) by ink";
    assert prevVoteDelegate == zero && voteDelegate_ == zero || prevVoteDelegate != zero && voteDelegate_ != zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "selectVoteDelegate did not keep unchanged mkr.balanceOf(engine)";
    assert prevVoteDelegate == zero && voteDelegate_ != zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - ink, "selectVoteDelegate did not decrease mkr.balanceOf(engine) by ink";
    assert prevVoteDelegate != zero && voteDelegate_ == zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + ink, "selectVoteDelegate did not increase mkr.balanceOf(engine) by ink";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "selectVoteDelegate did not keep unchanged the rest of mkr.balanceOf(x)";
}

// Verify revert rules on selectVoteDelegate
rule selectVoteDelegate_revert(address urn, address voteDelegate_) {
    env e;

    address zero = 0x0000000000000000000000000000000000000000;

    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address prevVoteDelegate = urnVoteDelegates(urn);
    require prevVoteDelegate == zero || prevVoteDelegate == voteDelegate2;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);
    mathint urnAuctions = urnAuctions(urn);
    mathint voteDelegateFactoryCreatedVoteDelegate = voteDelegateFactory.created(voteDelegate_);
    bytes32 ilk = ilk();
    mathint a; mathint rate; mathint spot; mathint b; mathint c;
    a, rate, spot, b, c = vat.ilks(ilk);
    mathint ink; mathint art;
    ink, art = vat.urns(ilk, urn);
    // Vat assumptions
    require ink * spot <= max_uint256;
    require art * rate <= max_uint256;

    require prevVoteDelegate == zero && to_mathint(mkr.balanceOf(currentContract)) >= ink || prevVoteDelegate != zero && to_mathint(mkr.balanceOf(prevVoteDelegate)) >= ink && to_mathint(voteDelegate2.stake(currentContract)) >= ink; // TODO: this might be interesting to be proved
    require voteDelegate.stake(currentContract) + ink <= max_uint256;
    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(prevVoteDelegate) + mkr.balanceOf(voteDelegate_) + mkr.balanceOf(currentContract);

    selectVoteDelegate@withrevert(e, urn, voteDelegate_);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = urnAuctions > 0;
    bool revert4 = voteDelegate_ != zero && voteDelegateFactoryCreatedVoteDelegate != 1;
    bool revert5 = voteDelegate_ == prevVoteDelegate;
    bool revert6 = art > 0 && voteDelegate_ != zero && ink * spot < art * rate;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
}

// Verify correct storage changes for non reverting selectFarm
rule selectFarm(address urn, address farm_, uint16 ref) {
    env e;

    require urn == lockstakeUrn;

    address zero = 0x0000000000000000000000000000000000000000;

    require farm_ == zero || farm_ == farm;
    address prevFarm = urnFarms(urn);
    require prevFarm == zero || prevFarm == farm2;

    address other;
    require other != urn;
    address other2;
    require other2 != farm_ && other2 != prevFarm && other2 != urn;

    bytes32 ilk = ilk();
    mathint ink; mathint a;
    ink, a = vat.urns(ilk, urn);

    address urnFarmsOtherBefore = urnFarms(other);
    mathint lsmkrBalanceOfPrevFarmBefore = lsmkr.balanceOf(prevFarm);
    mathint lsmkrBalanceOfNewFarmBefore = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);
    // Tokens invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkrBalanceOfPrevFarmBefore + lsmkrBalanceOfNewFarmBefore + lsmkrBalanceOfUrnBefore + lsmkrBalanceOfOtherBefore;

    selectFarm(e, urn, farm_, ref);

    address urnFarmsUrnAfter = urnFarms(urn);
    address urnFarmsOtherAfter = urnFarms(other);
    mathint lsmkrBalanceOfPrevFarmAfter = lsmkr.balanceOf(prevFarm);
    mathint lsmkrBalanceOfNewFarmAfter = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert urnFarmsUrnAfter == farm_, "selectFarm did not set urnFarms[urn] as farm_";
    assert urnFarmsOtherAfter == urnFarmsOtherBefore, "selectFarm did not keep unchanged the rest of urnFarms[x]";
    assert prevFarm == zero => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore, "selectFarm did not keep unchanged lsmkr.balanceOf(address(0))";
    assert prevFarm != zero => lsmkrBalanceOfPrevFarmAfter == lsmkrBalanceOfPrevFarmBefore - ink, "selectFarm did not decrease lsmkr.balanceOf(prevFarm) by ink";
    assert farm_ == zero => lsmkrBalanceOfNewFarmAfter == lsmkrBalanceOfNewFarmBefore, "selectFarm did not keep unchanged lsmkr.balanceOf(address(0)) 2";
    assert farm_ != zero => lsmkrBalanceOfNewFarmAfter == lsmkrBalanceOfNewFarmBefore + ink, "selectFarm did not increase lsmkr.balanceOf(new Farm) by ink";
    assert prevFarm == zero && farm_ == zero || prevFarm != zero && farm_ != zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "selectFarm did not keep unchanged lsmkr.balanceOf(urn)";
    assert prevFarm == zero && farm_ != zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - ink, "selectFarm did not decrease lsmkr.balanceOf(urn) by ink";
    assert prevFarm != zero && farm_ == zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + ink, "selectFarm did not increase lsmkr.balanceOf(urn) by ink";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "selectFarm did not keep unchanged the rest of lsmkr.balanceOf(x)";
}

// Verify revert rules on selectFarm
rule selectFarm_revert(address urn, address farm_, uint16 ref) {
    env e;

    require urn == lockstakeUrn;

    address zero = 0x0000000000000000000000000000000000000000;

    require farm_ == zero || farm_ == farm;
    address prevFarm = urnFarms(urn);
    require prevFarm == zero || prevFarm == farm2;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);
    mathint urnAuctions = urnAuctions(urn);
    LockstakeEngine.FarmStatus farmsFarm = farms(farm_);
    bytes32 ilk = ilk();
    mathint ink; mathint a;
    ink, a = vat.urns(ilk, urn);

    // TODO: this might be nice to prove in some sort
    require prevFarm == zero && to_mathint(lsmkr.balanceOf(urn)) >= ink || prevFarm != zero && to_mathint(lsmkr.balanceOf(prevFarm)) >= ink && to_mathint(farm2.balanceOf(urn)) >= ink;
    // Token invariants
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(prevFarm) + lsmkr.balanceOf(farm_) + lsmkr.balanceOf(urn);
    require farm2.totalSupply() >= farm2.balanceOf(urn);
    require farm.totalSupply() >= farm.balanceOf(urn);
    // Assumption
    require farm.totalSupply() + ink <= max_uint256;

    selectFarm@withrevert(e, urn, farm_, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = urnAuctions > 0;
    bool revert4 = farm_ != zero && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert5 = farm_ == prevFarm;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting lock
rule lock(address urn, uint256 wad, uint16 ref) {
    env e;

    require urn == lockstakeUrn;

    address zero = 0x0000000000000000000000000000000000000000;

    address voteDelegate_ = urnVoteDelegates(urn);
    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;
    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address farm_ = urnFarms(urn);
    require farm_ == zero || farm_ == farm;

    address other;
    require other != e.msg.sender && other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm_;

    bytes32 ilk = ilk();
    mathint inkBefore; mathint a;
    inkBefore, a = vat.urns(ilk, urn);
    mathint mkrBalanceOfSenderBefore = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfEngineBefore = mkr.balanceOf(currentContract);
    mathint mkrBalanceOfVoteDelegateBefore = mkr.balanceOf(voteDelegate_);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other);
    mathint lsmkrTotalSupplyBefore = lsmkr.totalSupply();
    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm_);
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
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore + wad, "lock did not increase ink by wad";
    assert mkrBalanceOfSenderAfter == mkrBalanceOfSenderBefore - wad, "lock did not decrease mkr.balanceOf(sender) by wad";
    assert voteDelegate_ == zero => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "lock did not keep unchanged mkr.balanceOf(address(0))";
    assert voteDelegate_ != zero => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore + wad, "lock did not increase mkr.balanceOf(voteDelegate) by wad";
    assert voteDelegate_ == zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + wad, "lock did not increase mkr.balanceOf(engine) by wad";
    assert voteDelegate_ != zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "lock did not keep unchanged mkr.balanceOf(engine)";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "lock did not keep unchanged the rest of mkr.balanceOf(x)";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore + wad, "lock did not increase lsmkr.totalSupply() by wad";
    assert farm_ == zero => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "lock did not keep unchanged lsmkr.balanceOf(address(0))";
    assert farm_ != zero => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore + wad, "lock did not increase lsmkr.balanceOf(farm) by wad";
    assert farm_ == zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + wad, "lock did not increase lsmkr.balanceOf(urn) by wad";
    assert farm_ != zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "lock did not keep unchanged lsmkr.balanceOf(urn)";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "lock did not keep unchanged the rest of lsmkr.balanceOf(x)";
}

// Verify revert rules on lock
rule lock_revert(address urn, uint256 wad, uint16 ref) {
    env e;

    require urn == lockstakeUrn;

    address zero = 0x0000000000000000000000000000000000000000;

    address voteDelegate_ = urnVoteDelegates(urn);
    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;
    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address farm_ = urnFarms(urn);
    require farm_ == zero || farm_ == farm;

    address urnOwnersUrn = urnOwners(urn);

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

    // Happening in urn constructor
    require vat.can(urn, currentContract) == 1;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // User balance and approval
    require mkr.balanceOf(e.msg.sender) >= wad && mkr.allowance(e.msg.sender, currentContract) >= wad;
    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm_);
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require farm.totalSupply() == farm.balanceOf(urn);
    require lsmkr.balanceOf(farm_) == farm.totalSupply();
    require lsmkr.totalSupply() + wad <= to_mathint(mkr.totalSupply());
    // Vat assumptions
    require vat.live() == 1;
    require rate >= RAY() && rate <= max_int256();
    require (ink + wad) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // TODO: these might be nice to prove in some sort
    require vat.gem(ilk, urn) == 0;
    require lsmkr.balanceOf(urn) == 0 || farm.balanceOf(urn) == 0;
    require ink == lsmkr.balanceOf(urn) + farm.balanceOf(urn);

    LockstakeEngine.FarmStatus farmsFarm = farms(farm_);

    lock@withrevert(e, urn, wad, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn == zero;
    bool revert3 = to_mathint(wad) > max_int256();
    bool revert4 = farm_ != zero && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert5 = farm_ != zero && wad == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting lockNgt
rule lockNgt(address urn, uint256 ngtWad, uint16 ref) {
    env e;

    // Happening in constructor
    mathint mkrNgtRate = mkrNgtRate();
    require mkrNgtRate == to_mathint(mkrNgt.rate());

    require urn == lockstakeUrn;

    address zero = 0x0000000000000000000000000000000000000000;

    address voteDelegate_ = urnVoteDelegates(urn);
    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;
    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address farm_ = urnFarms(urn);
    require farm_ == zero || farm_ == farm;

    address other;
    require other != e.msg.sender && other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm_;

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
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

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
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore + ngtWad/mkrNgtRate, "lockNgt did not increase ink by ngtWad/mkrNgtRate";
    assert ngtTotalSupplyAfter == ngtTotalSupplyBefore - ngtWad, "lockNgt did not decrease ngt.totalSupply() by ngtWad";
    assert ngtBalanceOfSenderAfter == ngtBalanceOfSenderBefore - ngtWad, "lockNgt did not decrease ngt.balanceOf(sender) by ngtWad";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore + ngtWad/mkrNgtRate, "lockNgt did not increase mkr.totalSupply() by ngtWad/mkrNgtRate";
    assert voteDelegate_ == zero => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "lockNgt did not keep unchanged mkr.balanceOf(address(0))";
    assert voteDelegate_ != zero => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore + ngtWad/mkrNgtRate, "lockNgt did not increase mkr.balanceOf(voteDelegate) by ngtWad/mkrNgtRate";
    assert voteDelegate_ == zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore + ngtWad/mkrNgtRate, "lockNgt did not increase mkr.balanceOf(engine) by ngtWad/mkrNgtRate";
    assert voteDelegate_ != zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "lockNgt did not keep unchanged mkr.balanceOf(engine)";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "lockNgt did not keep unchanged the rest of mkr.balanceOf(x)";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore + ngtWad/mkrNgtRate, "lockNgt did not increase lsmkr.totalSupply() by ngtWad/mkrNgtRate";
    assert farm_ == zero => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "lockNgt did not keep unchanged lsmkr.balanceOf(address(0))";
    assert farm_ != zero => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore + ngtWad/mkrNgtRate, "lockNgt did not increase lsmkr.balanceOf(farm) by ngtWad/mkrNgtRate";
    assert farm_ == zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + ngtWad/mkrNgtRate, "lockNgt did not increase lsmkr.balanceOf(urn) by ngtWad/mkrNgtRate";
    assert farm_ != zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "lockNgt did not keep unchanged lsmkr.balanceOf(urn)";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "lockNgt did not keep unchanged the rest of lsmkr.balanceOf(x)";
}

// Verify revert rules on lockNgt
rule lockNgt_revert(address urn, uint256 ngtWad, uint16 ref) {
    env e;

    mathint mkrNgtRate = mkrNgtRate();
    require mkrNgtRate == to_mathint(mkrNgt.rate());
    // Avoid division by zero
    require mkrNgtRate > 0;

    require urn == lockstakeUrn;

    address zero = 0x0000000000000000000000000000000000000000;

    address voteDelegate_ = urnVoteDelegates(urn);
    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;
    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address farm_ = urnFarms(urn);
    require farm_ == zero || farm_ == farm;

    address urnOwnersUrn = urnOwners(urn);

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

    // Happening in urn constructor
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
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm_);
    // Assumption
    require to_mathint(mkr.totalSupply()) <= max_uint256 - ngtWad/mkrNgtRate;
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require farm.totalSupply() == farm.balanceOf(urn);
    require lsmkr.balanceOf(farm_) == farm.totalSupply();
    require lsmkr.totalSupply() + ngtWad/mkrNgtRate <= to_mathint(mkr.totalSupply());
    // Vat assumptions
    require vat.live() == 1;
    require rate >= RAY() && rate <= max_int256();
    require (ink + ngtWad/mkrNgtRate) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // TODO: these might be nice to prove in some sort
    require vat.gem(ilk, urn) == 0;
    require lsmkr.balanceOf(urn) == 0 || farm.balanceOf(urn) == 0;
    require ink == lsmkr.balanceOf(urn) + farm.balanceOf(urn);

    LockstakeEngine.FarmStatus farmsFarm = farms(farm_);

    lockNgt@withrevert(e, urn, ngtWad, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn == zero;
    bool revert3 = ngtWad/mkrNgtRate > max_int256();
    bool revert4 = farm_ != zero && farmsFarm != LockstakeEngine.FarmStatus.ACTIVE;
    bool revert5 = farm_ != zero && ngtWad/mkrNgtRate == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";
}

// Verify correct storage changes for non reverting free
rule free(address urn, address to, uint256 wad) {
    env e;

    require urn == lockstakeUrn;

    mathint fee = fee();
    require fee < WAD();

    address zero = 0x0000000000000000000000000000000000000000;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address farm_ = urnFarms(urn);
    require farm_ == zero || farm_ == farm;

    address other;
    require other != to && other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm_;

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
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

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
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore - wad, "free did not decrease ink by wad";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - wad * fee / WAD(), "free did not decrease mkr.totalSupply() by wad*fee/WAD";
    assert to != currentContract && to != voteDelegate_   ||
           to == currentContract && voteDelegate_ != zero ||
           to == voteDelegate_ && voteDelegate_ == zero => mkrBalanceOfToAfter == mkrBalanceOfToBefore + (wad - wad * fee / WAD()), "free did not increase mkr.balanceOf(to) by wad-wad*fee/WAD";
    assert to == currentContract && voteDelegate_ == zero ||
           to == voteDelegate_ && voteDelegate_ != zero => mkrBalanceOfToAfter == mkrBalanceOfToBefore - wad * fee / WAD(), "free did not decrease mkr.balanceOf(to) by wad*fee/WAD";
    assert to != voteDelegate_ && voteDelegate_ == zero => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "free did not keep unchanged mkr.balanceOf(address(0))";
    assert to != voteDelegate_ && voteDelegate_ != zero => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore - wad, "free did not decrease mkr.balanceOf(voteDelegate) by wad";
    assert to != currentContract && voteDelegate_ == zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - wad, "free did not decrease mkr.balanceOf(engine) by wad";
    assert to != currentContract && voteDelegate_ != zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "free did not keep unchanged mkr.balanceOf(engine)";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "free did not keep unchanged the rest of mkr.balanceOf(x)";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore - wad, "free did not decrease lsmkr.totalSupply() by wad";
    assert farm_ == zero => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "free did not keep unchanged lsmkr.balanceOf(address(0))";
    assert farm_ != zero => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore - wad, "free did not decrease lsmkr.balanceOf(farm) by wad";
    assert farm_ == zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - wad, "free did not decrease lsmkr.balanceOf(urn) by wad";
    assert farm_ != zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "free did not keep unchanged lsmkr.balanceOf(urn)";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "free did not keep unchanged the rest of lsmkr.balanceOf(x)";
}

// Verify revert rules on free
rule free_revert(address urn, address to, uint256 wad) {
    env e;

    require urn == lockstakeUrn;

    mathint fee = fee();
    require fee < WAD();

    address zero = 0x0000000000000000000000000000000000000000;

    address voteDelegate_ = urnVoteDelegates(urn);
    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;
    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address farm_ = urnFarms(urn);
    require farm_ == zero || farm_ == farm;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

    // Happening in urn constructor
    require vat.can(urn, currentContract) == 1;
    require lsmkr.allowance(urn, currentContract) == max_uint256;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // Tokens invariants
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm_);
    // TODO: this might be nice to prove in some sort
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require voteDelegate_ != zero => to_mathint(voteDelegate.stake(currentContract)) == ink;
    require voteDelegate_ == zero => to_mathint(mkr.balanceOf(currentContract)) >= ink;
    require farm.totalSupply() == farm.balanceOf(urn);
    require lsmkr.balanceOf(farm_) == farm.totalSupply();
    // Vat assumptions
    require vat.live() == 1;
    require rate >= RAY() && rate <= max_int256();
    require (ink - wad) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // TODO: these might be nice to prove in some sort
    require vat.gem(ilk, urn) == 0;
    require lsmkr.balanceOf(urn) == 0 || farm.balanceOf(urn) == 0;
    require lsmkr.balanceOf(urn) > 0 => farm_ == zero;
    require farm.balanceOf(urn)  > 0 => farm_ != zero;
    require ink == lsmkr.balanceOf(urn) + farm.balanceOf(urn);

    LockstakeEngine.FarmStatus farmsFarm = farms(farm_);

    free@withrevert(e, urn, to, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = to_mathint(wad) > max_int256();
    bool revert4 = ink < to_mathint(wad) || wad > 0 && (ink - wad) * spot < art * rate;
    bool revert5 = farm_ != 0 && wad == 0;
    bool revert6 = wad * fee > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
}

// Verify correct storage changes for non reverting freeNgt
rule freeNgt(address urn, address to, uint256 ngtWad) {
    env e;

    // Happening in constructor
    mathint mkrNgtRate = mkrNgtRate();
    require mkrNgtRate == to_mathint(mkrNgt.rate());
    mathint fee = fee();
    require fee < WAD();

    require urn == lockstakeUrn;

    address zero = 0x0000000000000000000000000000000000000000;

    address voteDelegate_ = urnVoteDelegates(urn);
    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address farm_ = urnFarms(urn);
    require farm_ == zero || farm_ == farm;

    address other;
    require other != currentContract && other != voteDelegate_;
    address other2;
    require other2 != urn && other2 != farm_;
    address other3;
    require other3 != to;

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
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfOtherBefore = lsmkr.balanceOf(other2);

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
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm_);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(urn);
    mathint lsmkrBalanceOfOtherAfter = lsmkr.balanceOf(other2);

    assert inkAfter == inkBefore - ngtWad/mkrNgtRate, "freeNgt did not decrease ink by ngtWad/mkrNgtRate";
    assert ngtTotalSupplyAfter == ngtTotalSupplyBefore + (ngtWad/mkrNgtRate - ngtWad/mkrNgtRate * fee / WAD()) * mkrNgtRate, "freeNgt did not increase ngt.totalSupply() by (ngtWad/mkrNgtRate - ngtWad/mkrNgtRate * fee / WAD()) * mkrNgtRate";
    assert ngtBalanceOfToAfter == ngtBalanceOfToBefore + (ngtWad/mkrNgtRate - ngtWad/mkrNgtRate * fee / WAD()) * mkrNgtRate, "freeNgt did not increase ngt.balanceOf(to) by (ngtWad/mkrNgtRate - ngtWad/mkrNgtRate * fee / WAD()) * mkrNgtRate";
    assert ngtBalanceOfOtherAfter == ngtBalanceOfOtherBefore, "freeNgt did not keep unchanged the rest of ngt.balanceOf(x)";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - ngtWad/mkrNgtRate, "freeNgt did not mkr.totalSupply() by ngtWad/mkrNgtRate";
    assert to != voteDelegate_ && voteDelegate_ == zero => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore, "freeNgt did not keep unchanged mkr.balanceOf(address(0))";
    assert to != voteDelegate_ && voteDelegate_ != zero => mkrBalanceOfVoteDelegateAfter == mkrBalanceOfVoteDelegateBefore - ngtWad/mkrNgtRate, "freeNgt did not decrease mkr.balanceOf(voteDelegate) by ngtWad/mkrNgtRate";
    assert to != currentContract && voteDelegate_ == zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore - ngtWad/mkrNgtRate, "freeNgt did not decrease mkr.balanceOf(engine) by ngtWad/mkrNgtRate";
    assert to != currentContract && voteDelegate_ != zero => mkrBalanceOfEngineAfter == mkrBalanceOfEngineBefore, "freeNgt did not keep unchanged mkr.balanceOf(engine)";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "freeNgt did not keep unchanged the rest of mkr.balanceOf(x)";
    assert lsmkrTotalSupplyAfter == lsmkrTotalSupplyBefore - ngtWad/mkrNgtRate, "freeNgt did not decrease lsmkr.totalSupply() by ngtWad/mkrNgtRate";
    assert farm_ == zero => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore, "freeNgt did not keep unchanged lsmkr.balanceOf(address(0))";
    assert farm_ != zero => lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore - ngtWad/mkrNgtRate, "freeNgt did not decrease lsmkr.balanceOf(farm) by ngtWad/mkrNgtRate";
    assert farm_ == zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - ngtWad/mkrNgtRate, "freeNgt did not decrease lsmkr.balanceOf(urn) by ngtWad/mkrNgtRate";
    assert farm_ != zero => lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore, "freeNgt did not keep unchanged lsmkr.balanceOf(urn)";
    assert lsmkrBalanceOfOtherAfter == lsmkrBalanceOfOtherBefore, "freeNgt did not keep unchanged the rest of lsmkr.balanceOf(x)";
}

// Verify revert rules on freeNgt
rule freeNgt_revert(address urn, address to, uint256 ngtWad) {
    env e;

    // Happening in constructor
    mathint mkrNgtRate = mkrNgtRate();
    require mkrNgtRate == to_mathint(mkrNgt.rate());
    mathint fee = fee();
    require fee < WAD();
    require mkr.allowance(currentContract, mkrNgt) == max_uint256;
    // Avoid division by zero
    require mkrNgtRate > 0;

    require urn == lockstakeUrn;

    address zero = 0x0000000000000000000000000000000000000000;

    address voteDelegate_ = urnVoteDelegates(urn);
    require e.msg.sender != voteDelegate_ && e.msg.sender != currentContract;
    require voteDelegate_ == zero || voteDelegate_ == voteDelegate;
    address farm_ = urnFarms(urn);
    require farm_ == zero || farm_ == farm;

    address urnOwnersUrn = urnOwners(urn);
    mathint urnCanUrnSender = urnCan(urn, e.msg.sender);

    bytes32 ilk = ilk();
    mathint ink; mathint art; mathint Art; mathint rate; mathint spot; mathint dust; mathint a;
    ink, art = vat.urns(ilk, urn);
    Art, rate, spot, a, dust = vat.ilks(ilk);

    // Happening in urn constructor
    require vat.can(urn, currentContract) == 1;
    require lsmkr.allowance(urn, currentContract) == max_uint256;
    // Happening in deploy scripts
    require vat.wards(currentContract) == 1;
    require lsmkr.wards(currentContract) == 1;
    // Tokens invariants
    require ngt.totalSupply() >= ngt.balanceOf(to);
    require to_mathint(mkr.totalSupply()) >= mkr.balanceOf(e.msg.sender) + mkr.balanceOf(currentContract) + mkr.balanceOf(voteDelegate_);
    require to_mathint(lsmkr.totalSupply()) >= lsmkr.balanceOf(urn) + lsmkr.balanceOf(farm_);
    // TODO: this might be nice to prove in some sort
    require ngt.totalSupply() + ngtWad <= max_uint256;
    require mkr.balanceOf(voteDelegate_) >= voteDelegate.stake(currentContract);
    require voteDelegate_ != zero => to_mathint(voteDelegate.stake(currentContract)) == ink;
    require voteDelegate_ == zero => to_mathint(mkr.balanceOf(currentContract)) >= ink;
    require farm.totalSupply() == farm.balanceOf(urn);
    require lsmkr.balanceOf(farm_) == farm.totalSupply();
    // Vat assumptions
    require vat.live() == 1;
    require rate >= RAY() && rate <= max_int256();
    require (ink - ngtWad/mkrNgtRate) * spot <= max_uint256;
    require rate * Art <= max_uint256;
    require Art >= art;
    require art == 0 || rate * art >= dust;
    // TODO: these might be nice to prove in some sort
    require vat.gem(ilk, urn) == 0;
    require lsmkr.balanceOf(urn) == 0 || farm.balanceOf(urn) == 0;
    require lsmkr.balanceOf(urn) > 0 => farm_ == zero;
    require farm.balanceOf(urn)  > 0 => farm_ != zero;
    require ink == lsmkr.balanceOf(urn) + farm.balanceOf(urn);

    LockstakeEngine.FarmStatus farmsFarm = farms(farm_);

    freeNgt@withrevert(e, urn, to, ngtWad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = urnOwnersUrn != e.msg.sender && urnCanUrnSender != 1;
    bool revert3 = to_mathint(ngtWad/mkrNgtRate) > max_int256();
    bool revert4 = ink < to_mathint(ngtWad/mkrNgtRate) || ngtWad/mkrNgtRate > 0 && (ink - ngtWad/mkrNgtRate) * spot < art * rate;
    bool revert5 = farm_ != 0 && ngtWad/mkrNgtRate == 0;
    bool revert6 = ngtWad/mkrNgtRate * fee > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6, "Revert rules failed";
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
