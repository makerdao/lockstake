// Basic spec checking the `multicall` function

using MulticallExecutor as multicallExecutor;
using MkrMock as mkr;

methods {
    function farms(address) external returns (LockstakeEngine.FarmStatus) envfree;
    function urnCan(address,address) external returns (uint256) envfree;
    function urnFarms(address) external returns (address) envfree;
    function mkr.allowance(address,address) external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function mkr.totalSupply() external returns (uint256) envfree;
    //
    // function _.init() external => DISPATCHER(true);
    // function _.lock(uint256) external => DISPATCHER(true);
    // function _.free(uint256) external => DISPATCHER(true);
    // function _.stake(address,uint256,uint16) external => DISPATCHER(true);
    // function _.withdraw(address,uint256) external => DISPATCHER(true);
    // function _.stake(uint256,uint16) external => DISPATCHER(true);
    // function _.withdraw(uint256) external => DISPATCHER(true);
    // function _.getReward(address,address) external => DISPATCHER(true);
    // function _.getReward() external => DISPATCHER(true);
    // function _.rewardsToken() external => DISPATCHER(true);
    // function _.balanceOf(address) external => DISPATCHER(true);
    // function _.transfer(address,uint256) external => DISPATCHER(true);
    // The Prover will attempt to dispatch to the following functions any unresolved
    // call, if the signature fits. Otherwise it will use the summary defined by the
    // `default` keyword.
    function _._ external => DISPATCH [
        // currentContract.open(uint256),
        currentContract.hope(address,address),
        currentContract.nope(address,address),
        // currentContract.selectVoteDelegate(address,address),
        currentContract.selectFarm(address,address,uint16),
        currentContract.lock(address,uint256,uint16),
        // currentContract.lockNgt(address,uint256,uint16),
        // currentContract.free(address,address,uint256),
        // currentContract.freeNgt(address,address,uint256),
        // currentContract.freeNoFee(address,address,uint256),
        // currentContract.draw(address,address,uint256),
        // currentContract.wipe(address,uint256),
        // currentContract.wipeAll(address),
        // currentContract.getReward(address,address,address)
    ] default HAVOC_ALL;
}

definition addrZero() returns address = 0x0000000000000000000000000000000000000000;

rule hopeAndHope(address urn1, address urn2, address usr) {
    env e;

    storage init = lastStorage;

    hope(e, urn1, usr);
    hope(e, urn2, usr);

    storage twoCalls = lastStorage;

    multicallExecutor.hopeAndHope(e, urn1, urn2, usr) at init;

    assert twoCalls == lastStorage;
}

rule hopeAndNope(address urn, address usr) {
    env e;

    multicallExecutor.hopeAndNope(e, urn, usr);

    mathint urnCanUrnAfter = urnCan(urn, usr);

    assert urnCanUrnAfter == 0;
}


rule selectFarmAndLock(uint256 index, address urn, address farm, uint16 ref, uint256 wad) {
    env e;

    mathint mkrBalanceOfExecutorBefore = mkr.balanceOf(multicallExecutor);
    mathint mkrAllowanceExecutorEngineBefore = mkr.allowance(multicallExecutor, currentContract);

    // Token invariants
    require to_mathint(mkr.totalSupply()) >= mkrBalanceOfExecutorBefore + mkrAllowanceExecutorEngineBefore;

    multicallExecutor.selectFarmAndLock(e, urn, farm, ref, wad);

    mathint mkrBalanceOfExecutorAfter = mkr.balanceOf(multicallExecutor);
    mathint mkrAllowanceExecutorEngineAfter = mkr.allowance(multicallExecutor, currentContract);
    address urnFarmsUrnAfter = urnFarms(urn);

    assert mkrBalanceOfExecutorAfter == mkrBalanceOfExecutorBefore - wad, "Assert 1";
    assert mkrAllowanceExecutorEngineBefore < max_uint256 => mkrAllowanceExecutorEngineAfter == mkrAllowanceExecutorEngineBefore - wad, "Assert 2";
    assert mkrAllowanceExecutorEngineBefore == max_uint256 => mkrAllowanceExecutorEngineAfter == mkrAllowanceExecutorEngineBefore, "Assert 3";
    assert urnFarmsUrnAfter == farm, "Assert 4";

    assert farm == addrZero() || farms(farm) == LockstakeEngine.FarmStatus.ACTIVE, "farm is active";
}
