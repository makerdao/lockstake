// https://vaas-stg.certora.com/output/20941/2e795b9d31f64012bc650f08dff8661e?anonymousKey=25e64caed2fbcc46f4911ca86ac16f19fbb237a3

using LockstakeClipper as lockstakeClipper;

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

    /* When a function is not using the environment, it can be declared as envfree,
    to omit the call’s env argument */
    function kicks() external returns uint256 envfree;

    /* We can summarize some complex math operations if they are not relevant
    for the property being checked, and we want to reduce some run-time of the Prover.
    Below we use the summaries just for demonstration. */
    function rmul(uint256,uint256) internal returns (uint256) => CONSTANT;
    function rdiv(uint256 x, uint256 y) internal returns (uint256) => cvlRDiv(x, y);
}

function cvlRDiv(uint x, uint y) returns uint256 {
    return 3;
}

/* Invariant: [wards]'s values are always zero or one */
invariant oneOrZero(address addr)
    // using direct-storage access
    lockstakeClipper.wards[addr] == 0 || lockstakeClipper.wards[addr] == 1;

/* Property: [kicks] is monotonic increasing */
rule kicksIncrease(method f) filtered { f -> !f.isView } {

    uint before = kicks();
    
    env e; calldataarg args;
    f(e, args);

    uint after = kicks();

    assert before <= after;
}