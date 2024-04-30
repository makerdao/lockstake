// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import {StakingRewardsMock} from "../../../test/mocks/StakingRewardsMock.sol";

contract Farm1 is StakingRewardsMock {
    
    constructor(
        address _rewardsToken,
        address _stakingToken
    ) StakingRewardsMock(_rewardsToken, _stakingToken) {
    }
}
