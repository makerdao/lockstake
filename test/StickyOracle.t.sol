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

contract StickyOracleTest is Test {

    PipLike public medianizer;
    StickyOracle public oracle;
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

        oracle = new StickyOracle(PIP_MKR);
        oracle.kiss(address(this));
        medianizer.kiss(address(oracle));
        medianizer.kiss(address(this));

        vm.stopPrank();

        initialMedianizerPrice = uint256(medianizer.read());
        assertGt(initialMedianizerPrice, 0);
    }

    function testPoke() public {
    }
}
