// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

interface GemLike {
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function mint(address, uint256) external;
}

contract StakingRewardsMock {
    GemLike public immutable rewardsToken;
    GemLike public immutable stakingToken;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public rewards;

    constructor(
        address _rewardsToken,
        address _stakingToken
    ) {
        rewardsToken = GemLike(_rewardsToken);
        stakingToken = GemLike(_stakingToken);
    }

    function stake(uint256 amount, uint16) external {
        require(amount > 0, "Cannot stake 0");
        totalSupply = totalSupply + amount;
        balanceOf[msg.sender] = balanceOf[msg.sender] + amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Cannot withdraw 0");
        totalSupply = totalSupply - amount;
        balanceOf[msg.sender] = balanceOf[msg.sender] - amount;
        stakingToken.transfer(msg.sender, amount);
    }

    function setReward(address usr, uint256 amount) public {
        rewardsToken.mint(address(this), amount);
        rewards[usr] += amount;
    }

    function getReward() public {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }
}
