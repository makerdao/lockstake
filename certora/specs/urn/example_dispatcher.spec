/* Basic setup for `LockstakeUrn` with heavier use of dispatcher */

// This checks for reachability
use builtin rule sanity;

methods {
    function engine() external returns address envfree;

    // `rewardsToken` - used in `LockstakeUrn.getReward`
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);

    // `StakingRewardsLike`
    function _.rewardsToken() external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.getReward() external => DISPATCHER(true);
    function _.stake(uint256,uint16) external => DISPATCHER(true);

    // `StakingRewardsLike(farm).stakingToken`
    // We need this dispatcher since in `example_dispatcher.conf` we did not link
    // the `StakingRewardsLike.stakingToken` to a particular token.
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);

}

/// @title Only the contract's owner (`engine`) does not revert, when calling `withdraw`
rule onlyOwnerNotRevert() {
    env e;
    address farm; uint256 wad;
    withdraw@withrevert(e, farm, wad);
    satisfy !lastReverted; // check we do not always revert
    assert !lastReverted => e.msg.sender == engine();
}
