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
    constructor(address _pip) StickyOracle (_pip) {}

    function getAccumulatorVal(uint256 day) external view returns (uint256) {
        return accumulators[day].val;
    }

    function getAccumulatorTs(uint256 day) external view returns (uint32) {
        return accumulators[day].ts;
    }

    function getPokePrice() external view returns (uint256) {
        return pokePrice;
    }

    function getPokeDay() external view returns (uint256) {
        return pokeDay;
    }

    function getCap() external view returns (uint128) {
        return cap;
    }

    function calcCap() external view returns (uint128) {
        return _calcCap();
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

    event Init(uint256 days_, uint128 pokePrice_);
    event Poke(uint256 indexed day, uint128 cap, uint128 pokePrice_);

    function setMedianizerPrice(uint256 newPrice) internal {
        vm.store(address(medianizer), bytes32(uint256(1)), bytes32(block.timestamp << 128 | newPrice));
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        PAUSE_PROXY = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        PIP_MKR = ChainlogLike(LOG).getAddress("PIP_MKR");

        medianizer = PipLike(PIP_MKR);

        vm.startPrank(PAUSE_PROXY); 

        oracle = new StickyOracleHarness(PIP_MKR);
        oracle.kiss(address(this));
        medianizer.kiss(address(oracle));
        medianizer.kiss(address(this));

        oracle.file("hi", 1);
        oracle.file("lo", 3);
        oracle.file("slope", RAY * 105 / 100);

        vm.stopPrank();

        initialMedianizerPrice = 1000 * 10**18;
        setMedianizerPrice(initialMedianizerPrice);
        assertEq(medianizer.read(), initialMedianizerPrice);
    }

    function testInit() public {
        vm.expectRevert("StickyOracle/cap-not-set");
        oracle.read();

        vm.expectEmit(true, true, true, true);
        emit Init(3, uint128(initialMedianizerPrice));
        vm.prank(PAUSE_PROXY); oracle.init(3);

        assertEq(oracle.read(), medianizer.read());
        assertEq(oracle.getCap(), medianizer.read());

        assertEq(oracle.getAccumulatorVal(block.timestamp / 1 days - 3), 0);
        assertEq(oracle.getAccumulatorVal(block.timestamp / 1 days - 2), initialMedianizerPrice * 1 days);
        assertEq(oracle.getAccumulatorVal(block.timestamp / 1 days - 1), initialMedianizerPrice * 2 days);
        assertEq(oracle.getAccumulatorVal(block.timestamp / 1 days    ), initialMedianizerPrice * 3 days);

        assertEq(oracle.getAccumulatorTs(block.timestamp / 1 days - 3), block.timestamp - 3 days);
        assertEq(oracle.getAccumulatorTs(block.timestamp / 1 days - 2), block.timestamp - 2 days);
        assertEq(oracle.getAccumulatorTs(block.timestamp / 1 days - 1), block.timestamp - 1 days);
        assertEq(oracle.getAccumulatorTs(block.timestamp / 1 days    ), block.timestamp);

        assertEq(oracle.getPokePrice(), initialMedianizerPrice);
        assertEq(oracle.getPokeDay(), block.timestamp / 1 days);
    }

    function testPoke() public {
        vm.prank(PAUSE_PROXY); oracle.init(3);
        assertEq(oracle.read(), medianizer.read());

        setMedianizerPrice(initialMedianizerPrice * 110 / 100);

        vm.expectRevert("StickyOracle/already-poked-today");
        oracle.poke();

        vm.warp(block.timestamp + 1 days);
        vm.expectEmit(true, true, true, true);
        emit Poke(block.timestamp / 1 days, uint128(initialMedianizerPrice * 105 / 100), uint128(initialMedianizerPrice * 105 / 100));
        oracle.poke(); // before: [100,100,100]
        assertEq(oracle.getCap(), initialMedianizerPrice * 105 / 100); // (100 + 100) / 2 * 1.05 = 105
        assertEq(oracle.read(), initialMedianizerPrice * 105 / 100);

        vm.warp(block.timestamp + 1 days);
        oracle.poke(); // before: // [100,100,105]
        assertEq(oracle.getCap(), initialMedianizerPrice * 105 / 100 ); // (100 + 100) / 2 * 1.05 = 105
        assertEq(oracle.read(), initialMedianizerPrice * 105 / 100);

        vm.warp(block.timestamp + 1 days);
        oracle.poke(); // before: [100,105,105]
        assertEq(oracle.getCap(), initialMedianizerPrice * 107625 / 100000); // (100 + 105) /2 * 1.05 = 107.625
        assertEq(oracle.read(), initialMedianizerPrice * 107625 / 100000);

        vm.warp(block.timestamp + 1 days);
        oracle.poke(); // before: [105,105,107.625]
        assertEq(oracle.getCap(), initialMedianizerPrice * 11025 / 10000); // (105 + 105) / 2 * 1.05 = 110.25
        assertEq(oracle.read(), initialMedianizerPrice * 110 / 100);   // blocked by current price of 110

        vm.warp(block.timestamp + 2 days); // missing a poke
        oracle.poke(); // before: [107.625,110,Miss]
        assertEq(oracle.getCap(), initialMedianizerPrice * 11025 / 10000); // cannot calc twap, cap will stay the same
        assertEq(oracle.read(), initialMedianizerPrice * 110 / 100); // still blocked by current price of 110

        setMedianizerPrice(initialMedianizerPrice * 111 / 100); // price goes up a bit

        vm.warp(block.timestamp + 1 days);
        oracle.poke(); // before: [110,Miss,110]
        assertEq(oracle.getCap(), initialMedianizerPrice * 1155 / 1000); // (110 * 2) / 2 * 1.05 = 115.5
        assertEq(oracle.read(), initialMedianizerPrice * 111 / 100); // blocked by current price of 111

        vm.warp(block.timestamp + 1 days);
        oracle.poke(); // before: [Miss,110,111];
        assertEq(oracle.getCap(), initialMedianizerPrice * 1155 / 1000); // cannot calc twap, cap will stay the same
        assertEq(oracle.read(), initialMedianizerPrice * 111 / 100); // still blocked by current price of 111

        vm.warp(block.timestamp + 1 days);
        oracle.poke(); // before: [110,111,111];
        assertEq(oracle.getCap(), initialMedianizerPrice * 116025 / 100000); // (110 + 111)/2 * 1.05 = 116.025
        assertEq(oracle.read(), initialMedianizerPrice * 111 / 100); // still blocked by current price of 111
    }
}
