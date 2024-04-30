// A spec checking the `multicall` function

using LockstakeEngine as _Engine;
using MuticallTest as _MuticallTest;
using LockstakeUrn as _LockstakeUrn;
using StkMock as _stkMkr;
using MkrMock as _mkrMock;
using DelegateFactoryMock as _DelegateFactory;
using DelegateMock as _DelegateMock;
using GemMockRewards as _GemMockRewards;

methods {
    // `LockstakeEngine`
    function urnFarms(address) external returns (address) envfree;
    function farms(address) external returns (LockstakeEngine.FarmStatus) envfree;

    // `LockstakeUrn`
    function _.stake(address,uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => DISPATCHER(true);
    function _.getReward(address,address) external => DISPATCHER(true);
    function _.init() external => DISPATCHER(true); // Prevent havoc due to `init`

    // `StkMock`
    function StkMock.balanceOf(address) external returns (uint256) envfree;

    // `MkrMock`
    function MkrMock.balanceOf(address) external returns (uint256) envfree;
    function MkrMock.allowance(address,address) external returns (uint256) envfree;
    // Summarize `transfer` to prevent overflow
    function MkrMock.transfer(
        address to, uint256 value
    ) external returns (bool) with (env e) => transferSummary(to, value, e);

    // `DelegateMock`
    function _.lock(uint256) external => DISPATCHER(true);
    function _.free(uint256) external => DISPATCHER(true);

    // `StakingRewardsMock`
    function _.rewardsToken() external => DISPATCHER(true);
    function _.stake(uint256,uint16) external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.getReward() external => DISPATCHER(true);

    // `rewardsToken` - using dispatcher to avoid unresolved calls causing havoc
    function _.transfer(address,uint256) external => DISPATCHER(true);

    // The Prover will attempt to dispatch to the following functions any unresolved
    // call, if the signature fits. Otherwise it will use the summary defined by the
    // `default` keyword.
    // NOTE: The more functions added, the longer the verification time will be.
    function _._ external => DISPATCH [
        _Engine.selectFarm(address,address,uint16),
        _Engine.lock(address,uint256,uint16),
        _Engine.hope(address,address),
        _Engine.nope(address,address),
        _Engine.rely(address),
        _Engine.deny(address),
        _Engine.open(uint256)
    ] default HAVOC_ALL;
}


/// @title Select and lock integrity
rule selectLockIntegrity(
        uint256 index,
        address farm,
        uint16 ref,
        uint256 wad
        ) {
    // NOTE: `_MuticallTest` is the contract calling the `multicall` function
    uint256 mkrBefore = _mkrMock.balanceOf(_MuticallTest);
    uint256 allowanceBefore = _mkrMock.allowance(_MuticallTest, currentContract);

    env e;
    _MuticallTest.standardMulticall(e, _LockstakeUrn, farm, ref, wad);

    uint256 mkrAfter = _mkrMock.balanceOf(_MuticallTest);
    uint256 allowanceAfter = _mkrMock.allowance(_MuticallTest, currentContract);

    assert (
        mkrBefore - mkrAfter == to_mathint(wad), "locking reduces users amount by wad"
    );
    assert (
        (
            allowanceBefore < max_uint256 =>
            allowanceBefore - allowanceAfter == to_mathint(wad)
        ) && (
            allowanceBefore == max_uint256 => allowanceBefore == allowanceAfter
        ),
        "allowance correctly changed by locking"
    );
    assert urnFarms(_LockstakeUrn) == farm, "farm was selected";

    // This assertion fails - the counter example uses `address(0)` as `farm`
    assert farms(farm) == LockstakeEngine.FarmStatus.ACTIVE, "farm is active";
}


/// @title Prevent transfer from overflowing
function transferSummary(address to, uint256 value, env e) returns bool {
    // NOTE: use this require only if you are certain of it.
    require _mkrMock.balanceOf(to) + value <= max_uint256;
    return _mkrMock.transfer(e, to, value);
}


/// @title Only the user can reduce their own balance
rule onlyUserCanChangeOwnBalance(method f, address user) {

    require user != _DelegateMock;
    require user != _Engine;
    require user != _GemMockRewards;
    uint256 balanceBefore = _mkrMock.balanceOf(user);

    env e;
    calldataarg args;
    f(e, args);
    
    uint256 balanceAfter = _mkrMock.balanceOf(user);
    
    assert (
        balanceBefore > balanceAfter => e.msg.sender == user,
        "only the user can change their own balance"
    );
}
