// LockstakeUrn.spec

using Vat as vat;
using LockstakeMkr as lsmkr;
using StakingRewardsMock as stakingRewards;
using RewardsMock as rewardsToken;

methods {
    function engine() external returns (address) envfree;
    function vat.can(address,address) external returns (uint256) envfree;
    function lsmkr.allowance(address,address) external returns (uint256) envfree;
    function lsmkr.balanceOf(address) external returns (uint256) envfree;
    function lsmkr.totalSupply() external returns (uint256) envfree;
    function stakingRewards.balanceOf(address) external returns (uint256) envfree;
    function stakingRewards.totalSupply() external returns (uint256) envfree;
    function stakingRewards.rewards(address) external returns (uint256) envfree;
    function _.stake(uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.getReward() external => DISPATCHER(true);
    function _.rewardsToken() external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function rewardsToken.balanceOf(address) external returns (uint256) envfree;
    function rewardsToken.totalSupply() external returns (uint256) envfree;
}

// Verify correct storage changes for non reverting init
rule init() {
    env e;

    address engine = engine();

    init(e);

    mathint vatCanUrnEngineAfter = vat.can(currentContract, engine);
    mathint lsmkrAllowanceUrnEngineAfter = lsmkr.allowance(currentContract, engine);

    assert vatCanUrnEngineAfter == 1, "Assert 1";
    assert lsmkrAllowanceUrnEngineAfter == max_uint256, "Assert 2";
}

// Verify revert rules on init
rule init_revert() {
    env e;

    address engine = engine();

    init@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = engine != e.msg.sender;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting stake
rule stake(address farm, uint256 wad, uint16 ref) {
    env e;

    require farm == stakingRewards;

    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(currentContract);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm);
    require to_mathint(lsmkr.totalSupply()) >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore;
    mathint farmBalanceOfUrnBefore = stakingRewards.balanceOf(currentContract);

    stake(e, farm, wad, ref);

    mathint lsmkrAllowanceUrnFarmAfter = lsmkr.allowance(currentContract, farm);
    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(currentContract);
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint farmBalanceOfUrnAfter = stakingRewards.balanceOf(currentContract);

    assert lsmkrAllowanceUrnFarmAfter == 0 || lsmkrAllowanceUrnFarmAfter == max_uint256, "Assert 1";
    assert lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore - wad, "Assert 2";
    assert lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore + wad, "Assert 3";
    assert farmBalanceOfUrnAfter == farmBalanceOfUrnBefore + wad, "Assert 4";
}

// Verify revert rules on stake
rule stake_revert(address farm, uint256 wad, uint16 ref) {
    env e;

    require farm == stakingRewards;

    require wad > 0;
    require lsmkr.balanceOf(currentContract) >= wad;
    require lsmkr.totalSupply() >= wad;
    require stakingRewards.balanceOf(currentContract) + wad <= max_uint256;
    require stakingRewards.totalSupply() + wad <= max_uint256;

    address engine = engine();

    stake@withrevert(e, farm, wad, ref);

    bool revert1 = e.msg.value > 0;
    bool revert2 = engine != e.msg.sender;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting withdraw
rule withdraw(address farm, uint256 wad) {
    env e;

    require farm == stakingRewards;

    mathint lsmkrBalanceOfUrnBefore = lsmkr.balanceOf(currentContract);
    mathint lsmkrBalanceOfFarmBefore = lsmkr.balanceOf(farm);
    require to_mathint(lsmkr.totalSupply()) >= lsmkrBalanceOfUrnBefore + lsmkrBalanceOfFarmBefore;
    mathint farmBalanceOfUrnBefore = stakingRewards.balanceOf(currentContract);

    withdraw(e, farm, wad);

    mathint lsmkrBalanceOfUrnAfter = lsmkr.balanceOf(currentContract);
    mathint lsmkrBalanceOfFarmAfter = lsmkr.balanceOf(farm);
    mathint farmBalanceOfUrnAfter = stakingRewards.balanceOf(currentContract);

    assert lsmkrBalanceOfUrnAfter == lsmkrBalanceOfUrnBefore + wad, "Assert 1";
    assert lsmkrBalanceOfFarmAfter == lsmkrBalanceOfFarmBefore - wad, "Assert 2";
    assert farmBalanceOfUrnAfter == farmBalanceOfUrnBefore - wad, "Assert 3";
}

// Verify revert rules on withdraw
rule withdraw_revert(address farm, uint256 wad) {
    env e;

    require farm == stakingRewards;

    require wad > 0;
    require lsmkr.balanceOf(farm) >= wad;
    require lsmkr.balanceOf(currentContract) + wad <= max_uint256;
    require lsmkr.totalSupply() + wad <= max_uint256;
    require stakingRewards.balanceOf(currentContract) >= wad;
    require stakingRewards.totalSupply() >= wad;

    address engine = engine();

    withdraw@withrevert(e, farm, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = engine != e.msg.sender;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting getReward
rule getReward(address farm, address to) {
    env e;

    require farm == stakingRewards;

    mathint rewardsTokenBalanceOfToBefore = rewardsToken.balanceOf(to);
    require rewardsTokenBalanceOfToBefore <= to_mathint(rewardsToken.totalSupply());
    require rewardsTokenBalanceOfToBefore + rewardsToken.balanceOf(currentContract) + rewardsToken.balanceOf(stakingRewards) <= to_mathint(rewardsToken.totalSupply());

    getReward(e, farm, to);

    mathint rewardsTokenBalanceOfToAfter = rewardsToken.balanceOf(to);

    assert rewardsTokenBalanceOfToAfter >= rewardsTokenBalanceOfToBefore, "Assert 1";
}

// Verify revert rules on getReward
rule getReward_revert(address farm, address to) {
    env e;

    require farm == stakingRewards;

    require rewardsToken.balanceOf(stakingRewards) >= stakingRewards.rewards(currentContract);

    address engine = engine();

    getReward@withrevert(e, farm, to);

    bool revert1 = e.msg.value > 0;
    bool revert2 = engine != e.msg.sender;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}
