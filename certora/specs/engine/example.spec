/* Example spec for `LockstakeEngine`
 * NOTE: this example does not use the custom wildcards summary
 */

methods {
    // `DelegateLike` - use dispatcher to avoid calls causing havoc to the ghosts
    function _.free(uint256) external => DISPATCHER(true);
    function _.lock(uint256) external => DISPATCHER(true);

    // `LockstakeUrn`
    function _.getReward(address, address) external => DISPATCHER(true);
    function _.stake(address, uint256, uint16) external => DISPATCHER(true);
    function _.withdraw(address, uint256) external => DISPATCHER(true);
    function _.init() external => DISPATCHER(true);
    
    // `GemMock``
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);

    // `StakingRewardsLike`
    function _.rewardsToken() external => DISPATCHER(true);
    function _.getReward() external => DISPATCHER(true);
    function _.stake(uint256, uint16) external => DISPATCHER(true);
    // function _.withdraw(uint256) external => DISPATCHER(true); summarized above
}

ghost bool isUrnOwnersStored;

hook Sstore urnOwners[KEY address urn] address owner {
  isUrnOwnersStored = true;
}

ghost bool isUrnCanStored;

hook Sstore urnCan[KEY address urn][KEY address candidate] uint256 isAuthorized {
  isUrnCanStored = true;
}


/// @title One can store into `urnOwners` and `urnCan` only using `open`, `hope` and `nope`
rule updateGhostByCall(method f) filtered {
    // Here we filter out `multicall` since we did not use custom wildcards summary
    f -> f.selector != sig:multicall(bytes[]).selector
} {
    require !isUrnOwnersStored && !isUrnCanStored;

    env e;
    calldataarg args;
    f(e, args);

    assert (
        isUrnOwnersStored => f.selector == sig:open(uint256).selector,
        "only open can change urnCan"
    );
    assert (
        isUrnCanStored => (
            f.selector == sig:hope(address,address).selector ||
            f.selector == sig:nope(address,address).selector
        ),
        "only hope and nope can change urnOwners"
    );
}
