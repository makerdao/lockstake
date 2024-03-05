// https://vaas-stg.certora.com/output/20941/e887d30c21d94acbb75e0bbd6c712d60?anonymousKey=979896276276b19c54139d7d52e4db9fd1bc7a05 for LockstateEngine
// https://vaas-stg.certora.com/output/20941/524d77322ba54d31b96a85d9352a27d0?anonymousKey=b85a1e63ef8c2080ca2908425e3df2ee45f2d1b9 for LockstateClipper
// https://vaas-stg.certora.com/output/20941/c1e6db3c51374b51b427f70bd8e865e7?anonymousKey=eb049e6d25247fa32a08be5e7b7ac29a006fc211 for LockstateUrn

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