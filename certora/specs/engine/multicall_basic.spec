// Basic spec checking the `multicall` function

using LockstakeEngine as _Engine;
using MuticallTest as _MuticallTest;

methods {
    function MuticallTest.makeMulticallHope(
        address, address, address
    ) external envfree;

    // The Prover will attempt to dispatch to the following functions any unresolved
    // call, if the signature fits. Otherwise it will use the summary defined by the
    // `default` keyword.
    function _._ external => DISPATCH [
        _Engine.hope(address,address),
        _Engine.nope(address,address)
    ] default HAVOC_ALL;
}


/// @title Basic reachability check
rule reachability(method f) {
    env e;
    calldataarg args;
    f(e, args);
    satisfy true;
}


/// @title Two calls to `hope` (with the same `usr`) are the same as running them via `multicall`
rule testMulticallTwiceHope(address urn1, address urn2, address usr) {

    env e;
    storage init = lastStorage;

    hope(e, urn1, usr);
    hope(e, urn2, usr);

    storage twoCalls = lastStorage;

    // Uses the initial storage
    _MuticallTest.makeMulticallHope(urn1, urn2, usr) at init;

    assert twoCalls == lastStorage;
}


/// @title Example of two `hope` calls directly and using `multicall`
rule testMulticallTwiceHopeExample(address urn1, address urn2, address usr) {

    env e;
    storage init = lastStorage;

    hope(e, urn1, usr);
    hope(e, urn2, usr);

    storage twoCalls = lastStorage;

    _MuticallTest.makeMulticallHope(urn1, urn2, usr) at init;

    satisfy twoCalls == lastStorage;
}


/// @title Test calling `hope` followed by `nope` using `multicall`
rule hopeNopeTest(address urn, address usr) {

    env e;
    _MuticallTest.hopeThenNope(e, urn, usr);

    assert currentContract.urnCan[urn][usr] == 0;
}
