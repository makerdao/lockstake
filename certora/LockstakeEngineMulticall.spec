// Basic spec checking the `multicall` function

using MulticallExecutor as multicallExecutor;
using SkyMock as sky;
using LockstakeUrn as lockstakeUrn;

methods {
    function farms(address) external returns (LockstakeEngine.FarmStatus) envfree;
    function ownerUrns(address,uint256) external returns (address) envfree;
    function urnCan(address,address) external returns (uint256) envfree;
    function urnFarms(address) external returns (address) envfree;
    function sky.allowance(address,address) external returns (uint256) envfree;
    function sky.balanceOf(address) external returns (uint256) envfree;
    function sky.totalSupply() external returns (uint256) envfree;
    //
    function _.lock(address, uint256, uint256, uint16) external => DISPATCHER(true);
    function _.lock(uint256) external => DISPATCHER(true);
    function _.stake(address,uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => DISPATCHER(true);
    function _.stake(uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.mint(address,uint256) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
    // The Prover will attempt to dispatch to the following functions any unresolved
    // call, if the signature fits. Otherwise it will use the summary defined by the
    // `default` keyword.
    unresolved external in _._ => DISPATCH [
        // currentContract.open(uint256),
        currentContract.hope(address,uint256,address),
        currentContract.nope(address,uint256,address),
        // currentContract.selectVoteDelegate(address,uint256,address),
        currentContract.selectFarm(address,uint256,address,uint16),
        currentContract.lock(address,uint256,uint256,uint16),
        // currentContract.lockSky(address,uint256,uint256,uint16),
        // currentContract.free(address,uint256,address,uint256),
        // currentContract.freeSky(address,uint256,address,uint256),
        // currentContract.freeNoFee(address,uint256,address,uint256),
        // currentContract.draw(address,uint256,address,uint256),
        // currentContract.wipe(address,uint256,uint256),
        // currentContract.wipeAll(address,uint256),
        // currentContract.getReward(address,uint256,address,address)
    ] default HAVOC_ALL;
}

rule hopeAndHope(address owner1, uint256 index1, address owner2, uint256 index2, address usr) {
    env e;

    storage init = lastStorage;

    hope(e, owner1, index1, usr);
    hope(e, owner2, index2, usr);

    storage twoCalls = lastStorage;

    multicallExecutor.hopeAndHope(e, owner1, index1, owner2, index2, usr) at init;

    assert twoCalls == lastStorage;
}

rule hopeAndNope(address owner, uint256 index, address usr) {
    env e;

    multicallExecutor.hopeAndNope(e, owner, index, usr);

    mathint urnCanUrnAfter = urnCan(ownerUrns(owner, index), usr);

    assert urnCanUrnAfter == 0;
}


rule selectFarmAndLock(address owner, uint256 index, address farm, uint16 ref, uint256 wad) {
    env e;

    mathint skyBalanceOfExecutorBefore = sky.balanceOf(multicallExecutor);
    mathint skyAllowanceExecutorEngineBefore = sky.allowance(multicallExecutor, currentContract);

    // Token invariants
    require to_mathint(sky.totalSupply()) >= skyBalanceOfExecutorBefore + skyAllowanceExecutorEngineBefore;

    multicallExecutor.selectFarmAndLock(e, owner, index, farm, ref, wad);

    mathint skyBalanceOfExecutorAfter = sky.balanceOf(multicallExecutor);
    mathint skyAllowanceExecutorEngineAfter = sky.allowance(multicallExecutor, currentContract);
    address urn = ownerUrns(owner, index);
    require lockstakeUrn == urn;
    address urnFarmsUrnAfter = urnFarms(urn);

    assert skyBalanceOfExecutorAfter == skyBalanceOfExecutorBefore - wad, "Assert 1";
    assert skyAllowanceExecutorEngineBefore < max_uint256 => skyAllowanceExecutorEngineAfter == skyAllowanceExecutorEngineBefore - wad, "Assert 2";
    assert skyAllowanceExecutorEngineBefore == max_uint256 => skyAllowanceExecutorEngineAfter == skyAllowanceExecutorEngineBefore, "Assert 3";
    assert urnFarmsUrnAfter == farm, "Assert 4";

    assert farm == 0 || farms(farm) == LockstakeEngine.FarmStatus.ACTIVE, "farm is active";
}
