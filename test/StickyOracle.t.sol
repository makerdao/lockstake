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
        vm.expectRevert("StickyOracle/not-init");
        oracle.read();

        vm.prank(PAUSE_PROXY); oracle.init(3);
        assertEq(oracle.read(), medianizer.read());
        assertEq(oracle.getVal(), medianizer.read());
        assertEq(oracle.age(), block.timestamp);
        assertEq(oracle.getAccumulator(block.timestamp / 1 days - 4), 0);
        assertEq(oracle.getAccumulator(block.timestamp / 1 days - 3), initialMedianizerPrice * 1 days);
        assertEq(oracle.getAccumulator(block.timestamp / 1 days - 2), initialMedianizerPrice * 2 days);
        assertEq(oracle.getAccumulator(block.timestamp / 1 days - 1), initialMedianizerPrice * 3 days);
        assertEq(oracle.getAccumulator(block.timestamp / 1 days    ), initialMedianizerPrice * 4 days);
    }

    function testFix() external {
        vm.prank(PAUSE_PROXY); oracle.init(3);
        assertEq(oracle.read(), medianizer.read());

        vm.expectRevert("StickyOracle/nothing-to-fix");
        oracle.fix(block.timestamp / 1 days - 1);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert("StickyOracle/too-soon");
        oracle.fix(block.timestamp / 1 days);

        vm.warp(block.timestamp + 1 days);
        assertEq(oracle.getAccumulator(block.timestamp / 1 days - 1), 0);

        oracle.fix(block.timestamp / 1 days - 1);

        uint256 acc1 = oracle.getAccumulator(block.timestamp / 1 days - 2);
        uint256 acc2 = oracle.getAccumulator(block.timestamp / 1 days - 3);
        assertGt(oracle.getAccumulator(block.timestamp / 1 days - 1), 0);
        assertEq(oracle.getAccumulator(block.timestamp / 1 days - 1), acc1 + (acc1 - acc2));
    }

    function testPoke() public {
        vm.prank(PAUSE_PROXY); oracle.init(3);
        assertEq(oracle.read(), medianizer.read());

        uint256 medianizerPrice1 = initialMedianizerPrice * 110 / 100;
        setMedianizerPrice(medianizerPrice1);
        vm.warp((block.timestamp / 1 days) * 1 days + 1 days + 8 hours); // warping to 8am on the next day
        uint256 prevVal = oracle.getVal();

        oracle.poke(); // first poke of the day

        uint256 oraclePrice1 = 105 * initialMedianizerPrice / 100;
        assertEq(oracle.getCap(), oraclePrice1);
        assertEq(oracle.getVal(), oraclePrice1);
        assertEq(oracle.age(), block.timestamp);
        assertEq(oracle.read(), oraclePrice1);
        uint256 bef = prevVal * 8 hours;
        uint256 aft = oraclePrice1 * 16 hours;
        assertEq(oracle.getAccumulator(block.timestamp / 1 days), oracle.getAccumulator(block.timestamp / 1 days - 1) + bef + aft);

        uint256 prevAcc = oracle.getAccumulator(block.timestamp / 1 days);
        vm.warp(block.timestamp + 8 hours); // warping to 4pm on the same day
        uint256 medianizerPrice2 = initialMedianizerPrice * 104 / 100;
        setMedianizerPrice(medianizerPrice2);

        oracle.poke(); // second poke of the day

        uint256 oraclePrice2 = 104 * initialMedianizerPrice / 100;
        assertEq(oracle.getCap(), 105 * initialMedianizerPrice / 100);
        assertEq(oracle.getVal(), oraclePrice2);
        assertEq(oracle.age(), block.timestamp);
        assertEq(oracle.read(), oraclePrice2);
        assertEq(oracle.getAccumulator(block.timestamp / 1 days), prevAcc + 8 hours * oraclePrice2 - 8 hours * oraclePrice1);
    }
}
