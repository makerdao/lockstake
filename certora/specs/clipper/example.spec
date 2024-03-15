/* Example spec for `LockstakeClipper` */

methods {
    function kicks() external returns (uint256) envfree;
    function wards(address) external returns (uint256) envfree;
    
    /* We can summarize some complex math operations IF THEY ARE NOT RELEVANT
     * for the property being checked, and we want to reduce some run-time of the Prover.
     * Below we use the summaries JUST FOR DEMONSTRATION.
     */
    function rmul(uint256, uint256) internal returns (uint256) => CONSTANT;
    function rdiv(uint256 x, uint256 y) internal returns (uint256) => cvlRDiv(x, y);

    // `PipLike`
    // NOTE: If `PipLike.peek` was `view`, we could have used a `NONDET` summary.
    function _.peek() external => DISPATCHER(true);

    // `Abacus`
    // We could have used `DISPATCHER(true)`, which would have tried any of the contracts
    // included in the scene, i.e. `LinearDecrease`, `StairstepExponentialDecrease`
    // and `ExponentialDecrease`
    function _.price(uint256, uint256) external => NONDET;

    // `ClipperCallee`
    // NOTE: this might result in recursion, since we linked all the `ClipperCallee`
    // to the `LockstakeClipper`.
    function _.clipperCall(
        address, uint256, uint256, bytes
    ) external => DISPATCHER(true);
}

/// @title Division approximation from above
function cvlRDiv(uint x, uint y) returns uint256 {
    uint256 z;
    require z * y >= x * 10^27;
    return z;
}

/// @title `wards` values are either zero or one
invariant oneOrZero(address addr)
    wards(addr) == 0 || wards(addr) == 1;


/// @title Property: kicks is weakly monotonic increasing
rule kicksIncrease(method f) filtered { f -> !f.isView } {

    uint before = kicks();
    
    env e; calldataarg args;
    f(e, args);

    uint after = kicks();

    assert before <= after;
}
