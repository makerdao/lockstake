// LockstakeMigrator.spec

using LockstakeEngine as newEngine;
using LockstakeEngineV1Mock as oldEngine;
using Vat as vat;
using MkrSkyMock as mkrSky;

methods {
    function flash() external returns (address) envfree;
    function oldIlk() external returns (bytes32) envfree;
    function newIlk() external returns (bytes32) envfree;
    function mkrSkyRate() external returns (uint256) envfree;
    //
    function oldEngine.ownerUrns(address,uint256) external returns (address) envfree;
    function oldEngine.ilk() external returns (bytes32) envfree;
    function oldEngine.isUrnAuth(address,uint256,address) external returns (bool) envfree;
    function newEngine.ownerUrns(address,uint256) external returns (address) envfree;
    function newEngine.ilk() external returns (bytes32) envfree;
    function newEngine.isUrnAuth(address,uint256,address) external returns (bool) envfree;
    function mkrSky.rate() external returns (uint256) envfree;
    function vat.ilks(bytes32) external returns (uint256,uint256,uint256,uint256,uint256) envfree;
    function vat.urns(bytes32,address) external returns (uint256,uint256) envfree;
    //
    function _.drip(bytes32 ilk) external => dripSummary(ilk) expect uint256;
    function _.hope(address) external => DISPATCHER(true);
    function _.approve(address,uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => CONSTANT;
    function _.lock(uint256) external => CONSTANT;
    function _.free(uint256) external => CONSTANT;
    function _.stake(address,uint256,uint16) external => CONSTANT;
    function _.mint(address,uint256) external => CONSTANT;
    function _.burn(address,uint256) external => CONSTANT;
}

definition RAY() returns mathint = 10^27;
definition RAD() returns mathint = 10^45;
definition _divup(mathint x, mathint y) returns mathint = x != 0 ? ((x - 1) / y) + 1 : 0;

persistent ghost address vow;
persistent ghost mathint duty;
persistent ghost mathint timeDiff;
function dripSummary(bytes32 ilk) returns uint256 {
    env e;
    require duty >= RAY();
    uint256 prev; uint256 a;
    a, prev, a, a, a = vat.ilks(ilk);
    uint256 rate = timeDiff == 0 ? prev : require_uint256(duty * timeDiff * prev / RAY());
    timeDiff = 0;
    vat.fold(e, ilk, vow, require_int256(rate - prev));
    return rate;
}

rule migrate(address oldOwner, uint256 oldIndex, address newOwner, uint256 newIndex, uint16 ref) {
    env e;

    bytes32 oldIlk = oldIlk();
    bytes32 newIlk = newIlk();
    mathint mkrSkyRate = mkrSkyRate();
    address oldUrn = oldEngine.ownerUrns(oldOwner, oldIndex);
    address newUrn = newEngine.ownerUrns(newOwner, newIndex);

    // Assumption from constructor
    require oldIlk == oldEngine.ilk();
    require newIlk == newEngine.ilk();
    require mkrSkyRate == mkrSky.rate();
    // Assumption from initialization
    require oldIlk != newIlk;

    mathint vatUrnsOldIlkUrnInkBefore;
    mathint vatUrnsOldIlkUrnArtBefore;
    vatUrnsOldIlkUrnInkBefore, vatUrnsOldIlkUrnArtBefore = vat.urns(oldIlk, oldUrn);
    mathint vatUrnsNewIlkUrnInkBefore;
    mathint vatUrnsNewIlkUrnArtBefore;
    vatUrnsNewIlkUrnInkBefore, vatUrnsNewIlkUrnArtBefore = vat.urns(newIlk, newUrn);

    bool isUrnAuthOldUrn = oldEngine.isUrnAuth(oldOwner, oldIndex, e.msg.sender);
    bool isUrnAuthNewUrn = newEngine.isUrnAuth(newOwner, newIndex, e.msg.sender);

    migrate(e, oldOwner, oldIndex, newOwner, newIndex, ref);

    mathint vatUrnsOldIlkUrnInkAfter;
    mathint vatUrnsOldIlkUrnArtAfter;
    vatUrnsOldIlkUrnInkAfter, vatUrnsOldIlkUrnArtAfter = vat.urns(oldIlk, oldUrn);
    mathint vatUrnsNewIlkUrnInkAfter;
    mathint vatUrnsNewIlkUrnArtAfter;
    vatUrnsNewIlkUrnInkAfter, vatUrnsNewIlkUrnArtAfter = vat.urns(newIlk, newUrn);

    mathint a;
    mathint vatIlksOldIlkRateAfter;
    a, vatIlksOldIlkRateAfter, a, a, a = vat.ilks(oldIlk);
    mathint vatIlksNewIlkArtAfter; mathint vatIlksNewIlkRateAfter; mathint vatIlksNewIlkLineAfter;
    vatIlksNewIlkArtAfter, vatIlksNewIlkRateAfter, a, vatIlksNewIlkLineAfter, a = vat.ilks(newIlk);
    mathint debt = _divup(vatUrnsOldIlkUrnArtBefore * vatIlksOldIlkRateAfter, RAY()) * RAY();

    assert vatUrnsOldIlkUrnInkAfter == 0, "Assert 1";
    assert vatUrnsOldIlkUrnArtAfter == 0, "Assert 2";
    assert vatUrnsNewIlkUrnInkAfter == vatUrnsNewIlkUrnInkBefore + vatUrnsOldIlkUrnInkBefore * mkrSkyRate, "Assert 3";
    assert vatUrnsNewIlkUrnArtAfter == vatUrnsNewIlkUrnArtBefore + _divup(debt, vatIlksNewIlkRateAfter), "Assert 4";
    assert isUrnAuthOldUrn, "Assert 5";
    assert isUrnAuthNewUrn, "Assert 6";
    assert vatUrnsOldIlkUrnArtBefore > 0 => vatIlksNewIlkLineAfter == 0, "Assert 7";
    assert vatUrnsOldIlkUrnArtBefore > 0 => vatIlksNewIlkArtAfter * vatIlksNewIlkRateAfter <= 55000000 * RAD(), "Assert 8";
}

// Verify revert rules on onVatDaiFlashLoan
rule onVatDaiFlashLoan_revert(address initiator, uint256 radAmt, uint256 random, bytes data) {
    env e;

    address flash = flash();

    onVatDaiFlashLoan@withrevert(e, initiator, radAmt, random, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.msg.sender != flash || initiator != currentContract;

    assert revert1 || revert2 => lastReverted, "Revert rules failed";
}
