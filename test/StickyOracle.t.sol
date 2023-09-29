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
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import { StickyOracle } from "src/StickyOracle.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface PipLike {
    function read() external view returns (uint256);
    function kiss(address) external;
}

contract StickyOracleHarness is StickyOracle {
    constructor(address _pip, uint256 _grit) StickyOracle (_pip, _grit) {}
    function getAccumulator(uint256 day) external view returns (uint256) {
        return accumulators[day];
    }
    function getVal() external view returns (uint128) {
        return val;
    }
    function getCap() external view returns (uint128) {
        return _getCap();
    }
}

contract StickyOracleTest is Test {

    PipLike public medianizer;
    StickyOracleHarness public oracle;
    uint256 public initialMedianizerPrice;

    uint256 constant RAY = 10 ** 27;
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address PAUSE_PROXY;
    address PIP_MKR;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        PAUSE_PROXY = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        PIP_MKR = ChainlogLike(LOG).getAddress("PIP_MKR");

        medianizer = PipLike(PIP_MKR);

        vm.startPrank(PAUSE_PROXY); 

        oracle = new StickyOracleHarness(PIP_MKR, 5);
        oracle.kiss(address(this));
        medianizer.kiss(address(oracle));
        medianizer.kiss(address(this));

        oracle.file("hi", 1);
        oracle.file("lo", 3);
        oracle.file("slope", RAY * 105/100);

        vm.stopPrank();

        initialMedianizerPrice = 1000;
        vm.store(address(medianizer), bytes32(uint256(1)), bytes32(block.timestamp << 128 | initialMedianizerPrice));
        assertEq(oracle.read(), initialMedianizerPrice);
    }

    function setMedianizerPrice(uint256 newPrice) internal {
        vm.store(address(medianizer), bytes32(uint256(1)), bytes32(block.timestamp << 128 | newPrice));
    }

    function testPoke() public {
        uint256 price0 = initialMedianizerPrice;
        assertEq(oracle.getCap(), type(uint128).max);
        assertEq(oracle.read(), price0);
        assertEq(oracle.getVal(), 0);
        assertEq(oracle.age(), 0);
        uint256 day0 = block.timestamp / 1 days;
        assertEq(oracle.getAccumulator(day0), 0);

        oracle.poke();

        assertEq(oracle.getCap(), type(uint128).max);
        assertEq(oracle.read(), price0);
        assertEq(oracle.getVal(), price0);
        assertEq(oracle.age(), block.timestamp);
        uint256 acc0 = price0 * 1 days;
        assertEq(oracle.getAccumulator(day0), acc0);

        uint256 price1 = price0 * 110 / 100;
        setMedianizerPrice(price1);
        vm.warp(block.timestamp + 1 days);
        oracle.poke();

        assertEq(oracle.getCap(), type(uint128).max);
        assertEq(oracle.read(), price1);
        assertEq(oracle.getVal(), price1);
        assertEq(oracle.age(), block.timestamp);
        uint256 acc1 = acc0 + price0 * (block.timestamp - (day0 + 1) * 1 days) + price1 * ((day0 + 2) * 1 days - block.timestamp);
        assertEq(oracle.getAccumulator(day0 + 1), acc1);

        uint256 price2 = price0 * 120 / 100;
        setMedianizerPrice(price2);
        vm.warp(block.timestamp + 1 days);
        oracle.poke();

        assertEq(oracle.getCap(), type(uint128).max);
        assertEq(oracle.read(), price2);
        assertEq(oracle.getVal(), price2);
        assertEq(oracle.age(), block.timestamp);
        uint256 acc2 = acc1 + price1 * (block.timestamp - (day0 + 2) * 1 days) + price2 * ((day0 + 3) * 1 days - block.timestamp);
        assertEq(oracle.getAccumulator(day0 + 2), acc2);

        uint256 price3 = initialMedianizerPrice * 130 / 100;
        setMedianizerPrice(price3);
        vm.warp(block.timestamp + 1 days);
        oracle.poke();

        uint256 cap = (acc2 - acc0) *  105 / 100 / (2 days);
        assertEq(oracle.getCap(), cap);
        assertLt(cap, price3);
        assertEq(oracle.read(), cap);
        assertEq(oracle.getVal(), cap);
        assertEq(oracle.age(), block.timestamp);
        uint256 acc3 = acc2 + price2 * (block.timestamp - (day0 + 3) * 1 days) + cap * ((day0 + 4) * 1 days - block.timestamp);
        assertEq(oracle.getAccumulator(day0 + 3), acc3);
    }
}
