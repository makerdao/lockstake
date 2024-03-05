// https://vaas-stg.certora.com/output/20941/61ae8ae6f52c4ec08b24246e2662d996?anonymousKey=14596e43a091c8678b03616ef66222729c4cd8ea

methods {
    function _.getReward(address,address) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => DISPATCHER(true);
    function _.stake(address,uint256,uint16) external => DISPATCHER(true);
    function _.init() external => DISPATCHER(true);
    function _.free(uint256) external => DISPATCHER(true);
    function _.lock(uint256) external => DISPATCHER(true);
    function _.stake(address,uint16) external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.getReward() external => DISPATCHER(true);
    function _.rewardsToken() external => DISPATCHER(true);
    function _.take(uint256,uint256,uint256,address,bytes) external => DISPATCHER(true); 
    function _.clipperCall(address, uint256, uint256, bytes) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.stake(uint256,uint16) external => DISPATCHER(true);
    function _.ilk() external => DISPATCHER(true);
    function _.Ash() external => DISPATCHER(true);
    function _.kiss(uint) external => DISPATCHER(true);
}

ghost bool isUrnOwnersStored;

hook Sstore urnOwners[KEY address urn] address owner {
  isUrnOwnersStored = true;
}

ghost bool isUrnCanStored;

hook Sstore urnCan[KEY address urn][KEY address candidate] uint256 isAuthorized {
  isUrnCanStored = true;
}

/* Property: one can store into [urnOwners]/[urnCan] only via the [open], [hope]/[nope]
functions (respectively) */
rule updateGhostByCall(method f) filtered {
    // resolving the delegate calls within the Multicall contract is a work in progress
    f -> f.selector != sig:multicall(bytes[]).selector
  } {
    env e; calldataarg args;
    require !isUrnOwnersStored && !isUrnCanStored;
    f(e, args);
    assert isUrnOwnersStored => f.selector == sig:open(uint256).selector;
    assert isUrnCanStored => f.selector == sig:hope(address,address).selector ||
      f.selector == sig:nope(address,address).selector;
}