// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.21;

interface VatLike {
    function hope(address) external;
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
}

interface StakingRewardsLike {
    function rewardsToken() external view returns (GemLike);
    function stake(uint256, uint16) external;
    function withdraw(uint256) external;
    function getReward() external;
}

contract LockstakeUrn {
    // --- immutables ---

    address immutable public engine;
    GemLike immutable public lssky;
    VatLike immutable public vat;

    // --- modifiers ---

    modifier isEngine {
        require(msg.sender == engine, "LockstakeUrn/not-engine");
        _;
    }

    // --- constructor & init ---

    constructor(address vat_, address lssky_) {
        engine = msg.sender;
        vat = VatLike(vat_);
        lssky = GemLike(lssky_);
    }

    function init() external isEngine {
        vat.hope(msg.sender);
        lssky.approve(msg.sender, type(uint256).max);
    }

    // --- staking functions ---

    function stake(address farm, uint256 wad, uint16 ref) external isEngine {
        lssky.approve(farm, wad);
        StakingRewardsLike(farm).stake(wad, ref);
    }

    function withdraw(address farm, uint256 wad) external isEngine {
        StakingRewardsLike(farm).withdraw(wad);
    }

    function getReward(address farm, address to) external isEngine returns (uint256 amt) {
        StakingRewardsLike(farm).getReward();
        GemLike rewardsToken = StakingRewardsLike(farm).rewardsToken();
        amt = rewardsToken.balanceOf(address(this));
        rewardsToken.transfer(to, amt);
    }
}
