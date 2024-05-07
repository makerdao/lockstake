// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import {StakingRewardsMock} from "../../test/mocks/StakingRewardsMock.sol";

contract StakingRewards2Mock is StakingRewardsMock {
    
    constructor(address rewardsToken, address stakingToken) StakingRewardsMock(rewardsToken, stakingToken) {
    }
}
