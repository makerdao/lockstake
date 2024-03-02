// https://vaas-stg.certora.com/output/20941/06d5489e909f49f38ed2d4fe4c051e4f?anonymousKey=4e49e54a557731c1bf3983a57d7b1c595e44881d

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
    function engine() external returns address envfree;
}

/* Property: only the contract's owner, i.e. [engine], does not revert, when calling [withdraw] */
rule onlyOwnerNotRevert() {
    env e;
    address farm; uint256 wad;
    withdraw@withrevert(e, farm, wad);
    satisfy !lastReverted; // check we do not always revert
    assert !lastReverted => e.msg.sender == engine();
}