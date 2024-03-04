// https://vaas-stg.certora.com/output/20941/f85d86a50414439e8b74b3fcd02b901e?anonymousKey=84778d323dfef74d79e15c21b7c0772d079ed6c8 for LockstateEngine
// https://vaas-stg.certora.com/output/20941/b5f39d29a2e94131b64e7d9c169ddc06?anonymousKey=9b1d9699d8f2cd5c81eb1e78c45c31b69ab372af for LockstateClipper
// https://vaas-stg.certora.com/output/20941/2bae243e702b409784174ce2cb21c2f3?anonymousKey=cf3bf0b50c72561fafd1887bb23c0ef3aac5a48b for LockstateUrn

use builtin rule sanity;

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