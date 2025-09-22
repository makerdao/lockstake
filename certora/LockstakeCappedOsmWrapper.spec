// LockstakeCappedOsmWrapper.spec

using OsmMock as osm;

methods {
    // storage variables
    function wards(address) external returns (uint256) envfree;
    function bud(address) external returns (uint256) envfree;
    function cap() external returns (uint256) envfree;
    // getters
    function stopped() external returns (uint256) envfree;
    function src() external returns (address) envfree;
    function hop() external returns (uint16) envfree;
    function zzz() external returns (uint64) envfree;
    function pass() external returns (bool) envfree;
    //
    function osm.stopped() external returns (uint256) envfree;
    function osm.src() external returns (address) envfree;
    function osm.hop() external returns (uint16) envfree;
    function osm.zzz() external returns (uint64) envfree;
    function osm.pass() external returns (bool) envfree;
    function osm.peek() external returns (bytes32, bool) envfree;
    function osm.peep() external returns (bytes32, bool) envfree;
    function osm.read() external returns (bytes32) envfree;
    function osm.curVal() external returns (uint256) envfree;
    function osm.curHas() external returns (bool) envfree;
    function osm.nxtVal() external returns (uint256) envfree;
    function osm.nxtNxtVal() external returns (uint256) envfree;
}

definition _min(mathint x, mathint y) returns mathint = x < y ? x : y;

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) {
    env e;

    address anyAddr;

    mathint wardsBefore = wards(anyAddr);
    mathint budBefore = bud(anyAddr);
    mathint capBefore = cap();

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);
    mathint budAfter = bud(anyAddr);
    mathint capAfter = cap();

    assert wardsAfter != wardsBefore => f.selector == sig:rely(address).selector || f.selector == sig:deny(address).selector, "Assert 1";
    assert budAfter != budBefore => f.selector == sig:kiss(address).selector || f.selector == sig:diss(address).selector, "Assert 2";
    assert capAfter != capBefore => f.selector == sig:file(bytes32,uint256).selector, "Assert 3";
}

// Verify correct stopped getter result
rule stopped() {
    mathint osmStopped = osm.stopped();
    mathint stopped = stopped();

    assert stopped == osmStopped, "Assert 1";
}

// Verify correct src getter result
rule src() {
    address osmSrc = osm.src();
    address src = src();

    assert src == osmSrc, "Assert 1";
}

// Verify correct hop getter result
rule hop() {
    mathint osmHop = osm.hop();
    mathint hop = hop();

    assert hop == osmHop, "Assert 1";
}

// Verify correct zzz getter result
rule zzz() {
    mathint osmZzz = osm.zzz();
    mathint zzz = zzz();

    assert zzz == osmZzz, "Assert 1";
}

// Verify correct pass getter result
rule pass() {
    bool osmPass = osm.pass();
    bool pass = pass();

    assert pass == osmPass, "Assert 1";
}

// Verify correct storage changes for non reverting poke
rule poke() {
    env e;

    mathint curValBefore = osm.curVal();
    mathint nxtValBefore = osm.nxtVal();
    mathint nxtNxtVal = osm.nxtNxtVal();

    poke(e);

    mathint curValAfter = osm.curVal();
    mathint nxtValAfter = osm.nxtVal();

    assert curValAfter == nxtValBefore, "Assert 1";
    assert nxtValAfter == nxtNxtVal, "Assert 2";
}

// Verify correct storage changes for non reverting rely
rule rely(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    rely(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 1, "Assert 1";
    assert wardsOtherAfter == wardsOtherBefore, "Assert 2";
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting deny
rule deny(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    deny(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 0, "Assert 1";
    assert wardsOtherAfter == wardsOtherBefore, "Assert 2";
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting kiss
rule kiss(address usr) {
    env e;

    address other;
    require other != usr;

    mathint budOtherBefore = bud(other);

    kiss(e, usr);

    mathint budUsrAfter = bud(usr);
    mathint budOtherAfter = bud(other);

    assert budUsrAfter == 1, "Assert 1";
    assert budOtherAfter == budOtherBefore, "Assert 2";
}

// Verify revert rules on kiss
rule kiss_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    kiss@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting diss
rule diss(address usr) {
    env e;

    address other;
    require other != usr;

    mathint budOtherBefore = bud(other);

    diss(e, usr);

    mathint budUsrAfter = bud(usr);
    mathint budOtherAfter = bud(other);

    assert budUsrAfter == 0, "Assert 1";
    assert budOtherAfter == budOtherBefore, "Assert 2";
}

// Verify revert rules on diss
rule diss_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    diss@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting file
rule file(bytes32 what, uint256 data) {
    env e;

    file(e, what, data);

    uint256 capAfter = cap();

    assert capAfter == data, "Assert 1";
}

// Verify revert rules on file
rule file_revert(bytes32 what, uint256 data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = what != to_bytes32(0x6361700000000000000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct peek getter result
rule peek() {
    env e;

    mathint cap = cap();

    bytes32 osmVal; bool osmOk;
    osmVal, osmOk = osm.peek();

    bytes32 val; bool ok;
    val, ok = peek(e);

    assert to_mathint(assert_uint256(val)) == _min(to_mathint(assert_uint256(osmVal)), cap), "Assert 1";
    assert ok  == osmOk, "Assert 2";
}

// Verify revert rules on peek
rule peek_revert() {
    env e;

    mathint budSender = bud(e.msg.sender);

    peek@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = budSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct peep getter result
rule peep() {
    env e;

    mathint cap = cap();

    bytes32 osmVal; bool osmOk;
    osmVal, osmOk = osm.peep();

    bytes32 val; bool ok;
    val, ok = peep(e);

    assert to_mathint(assert_uint256(val)) == _min(to_mathint(assert_uint256(osmVal)), cap), "Assert 1";
    assert ok  == osmOk, "Assert 2";
}

// Verify revert rules on peep
rule peep_revert() {
    env e;

    mathint budSender = bud(e.msg.sender);

    peep@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = budSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct read getter result
rule read() {
    env e;

    mathint cap = cap();

    bytes32 osmVal = osm.read();

    bytes32 val = read(e);

    assert to_mathint(assert_uint256(val)) == _min(to_mathint(assert_uint256(osmVal)), cap), "Assert 1";
}

// Verify revert rules on read
rule read_revert() {
    env e;

    mathint budSender = bud(e.msg.sender);
    bool osmHas = osm.curHas();

    read@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = budSender != 1;
    bool revert3 = !osmHas;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}
