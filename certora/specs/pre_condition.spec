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
    function _.peek() external => DISPATCHER(true);
    function _.kick(uint256,uint256,address,address) external => DISPATCHER(true);
    function _.ilk() external => DISPATCHER(true);
    function _.Ash() external => DISPATCHER(true);
    function _.kiss(uint) external => DISPATCHER(true);
}

ghost bool isUrnOwnersStored;

hook Sstore urnOwners[KEY address k1] address owner {
  isUrnOwnersStored = true;
}

ghost bool isUrnCanStored;

hook Sstore urnCan[KEY address k1][KEY address k2] uint256 authorized {
  isUrnCanStored = true;
}

rule updateGhostByCall(method f) {
    env e; calldataarg args;
    require !isUrnOwnersStored && !isUrnCanStored;
    f(e, args);
    satisfy true;
    assert isUrnOwnersStored => f.selector == sig:open(uint256).selector;
    assert isUrnCanStored => f.selector == sig:hope(address,address).selector || f.selector == sig:nope(address,address).selector;
}