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

import "dss-test/DssTest.sol";

import { LockstakeAutoMaxLine } from "src/LockstakeAutoMaxLine.sol";
import { UniswapV2Library } from "test/helpers/UniswapV2Library.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface VatLike {
    function init(bytes32) external;
    function file(bytes32, bytes32, uint256) external;
    function slip(bytes32, address, int256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
}

interface PipLike {
    function read() external view returns (uint256);
    function kiss(address) external;
}

interface JugLike {
    function init(bytes32) external;
    function file(bytes32, bytes32, uint256) external;
    function rely(address) external;
    function ilks(bytes32) external view returns (uint256, uint256);
}

interface SpotterLike {
    function par() external view returns (uint256);
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
    function poke(bytes32) external;
}

interface PairLike {
    function sync() external;
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
}

interface AutoLineLike {
    function setIlk(bytes32, uint256, uint256, uint256) external;
    function rely(address) external;
    function ilks(bytes32) external view returns(uint256, uint256, uint48, uint48, uint48);
}

interface RouterLike {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

contract LockstakeAutoMaxLineTest is DssTest {
    using stdStorage for StdStorage;

    address              dai;
    address              mkr;
    address              pauseProxy;
    address              vow;
    SpotterLike          spotter;
    JugLike              jug;
    AutoLineLike         autoLine;
    VatLike              vat;
    PipLike              pip;
    LockstakeAutoMaxLine autoMaxLine;
    
    bytes32 constant ILK                 = "ILK";
    address constant LOG                 = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address constant UNIV2_FACTORY       = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNIV2_DAI_MKR_PAIR  = 0x517F9dD285e75b599234F7221227339478d0FcC8;
    address constant UNIV2_ROUTER        = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 constant RATE_5_PERCENT      = 1000000001547125957863212448;
    uint256 constant RATE_15_PERCENT     = 1000000004431822129783699001;

    event Exec(uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dai           = ChainlogLike(LOG).getAddress("MCD_DAI");
        mkr           = ChainlogLike(LOG).getAddress("MCD_GOV");
        pauseProxy    = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        vow           = ChainlogLike(LOG).getAddress("MCD_VOW");
        spotter       = SpotterLike(ChainlogLike(LOG).getAddress("MCD_SPOT"));
        jug           = JugLike(ChainlogLike(LOG).getAddress("MCD_JUG"));
        autoLine      = AutoLineLike(ChainlogLike(LOG).getAddress("MCD_IAM_AUTO_LINE"));
        vat           = VatLike(ChainlogLike(LOG).getAddress("MCD_VAT"));
        pip           = PipLike(ChainlogLike(LOG).getAddress("PIP_MKR"));

        vm.startPrank(pauseProxy);
        vat.init(ILK);
        jug.init(ILK);
        jug.file(ILK, "duty", 1001 * RAY / 1000);
        spotter.file(ILK, "pip", address(pip));
        spotter.file(ILK, "mat", 1 * RAY); // 100% coll ratio
        vat.file(ILK, "line", 100_000_000 * RAD);
        autoLine.setIlk(ILK, 200_000_000 * RAD, 10_000_000 * RAD, 8 hours);
        pip.kiss(address(spotter));
        spotter.poke(ILK);
        pip.kiss(address(this));
        vat.slip(ILK, address(this), type(int256).max);
        vm.stopPrank();

        vat.frob(ILK, address(this), address(this), address(0), int256(500_000_000 * WAD), 0);

        autoMaxLine = new LockstakeAutoMaxLine(
            address(vat),
            address(jug),
            address(spotter),
            address(autoLine),
            ILK,
            dai,
            UNIV2_DAI_MKR_PAIR,
            vow,
            address(pip),
            pauseProxy
        );
        autoMaxLine.rely(pauseProxy);
        autoMaxLine.deny(address(this));

        vm.startPrank(pauseProxy);
        jug.rely(address(autoMaxLine));
        pip.kiss(address(autoMaxLine));
        autoLine.rely(address(autoMaxLine));
        autoMaxLine.file("duty",         RATE_5_PERCENT);
        autoMaxLine.file("windDownDuty", RATE_15_PERCENT);
        autoMaxLine.file("lpFactor", 40 * WAD / 100);
        vm.stopPrank();

        // Set protocol owned liquidity in Uniswap
        uint256 initialPrice = 727;
        changeMedianizerPrice(initialPrice * WAD);
        changeUniV2Price(pip.read(), mkr, UNIV2_DAI_MKR_PAIR);

        deal(UNIV2_DAI_MKR_PAIR, pauseProxy, 0);
        deal(dai, pauseProxy, 20_000_000 * WAD);
        deal(mkr, pauseProxy, 20_000_000 * WAD / initialPrice);

        vm.startPrank(pauseProxy);
        GemLike(dai).approve(UNIV2_ROUTER, 20_000_000 * WAD);
        GemLike(mkr).approve(UNIV2_ROUTER, 20_000_000 * WAD / initialPrice);
        (uint256 depositedDai, uint256 depositedMkr, uint256 liquidity) = RouterLike(UNIV2_ROUTER).addLiquidity(
            dai,
            mkr,
            20_000_000 * WAD,
            20_000_000 * WAD / initialPrice,
            0,
            0,
            pauseProxy,
            block.timestamp
        );
        vm.stopPrank();

        // Set surplus buffer funds
        stdstore.target(address(vat)).sig("dai(address)").with_key(vow).depth(0).checked_write(70_000_000 * RAD);
        stdstore.target(address(vat)).sig("sin(address)").with_key(vow).depth(0).checked_write(uint256(0));

    }

    function changeUniV2Price(uint256 daiForGem, address gem, address pair) internal {
        (uint256 reserveDai, uint256 reserveGem) = UniswapV2Library.getReserves(UNIV2_FACTORY, dai, gem);
        uint256 currentDaiForGem = reserveDai * WAD / reserveGem;

        if (currentDaiForGem > daiForGem) {
            deal(gem, pair, reserveDai * WAD / daiForGem);
        } else {
            deal(dai, pair, reserveGem * daiForGem / WAD);
        }
        PairLike(pair).sync();
    }

    function changeMedianizerPrice(uint256 daiForGem) internal {
        vm.store(address(pip), bytes32(uint256(1)), bytes32(block.timestamp << 128 | daiForGem));
    }

    function assertEqApprox(uint256 a, uint256 b, uint256 tolerance) internal {
        assertLt(a, b + tolerance);
        assertGt(a, b - tolerance);
    }


    function testConstructor() public {
        // TODO: implement
    }

    function testAuth() public {
        checkAuth(address(autoMaxLine), "LockstakeAutoMaxLine");
    }

    function testFileUint() public {
        checkFileUint(address(autoMaxLine), "LockstakeAutoMaxLine", ["duty", "windDownDuty", "lpFactor"]);
    }

    // TODO: test auto-line-not-enabled
    // TODO: test ilk-not-enabled"

    function checkExec(uint256 debtToCreate, uint256 expectedNewDuty) internal {
        vat.frob(ILK, address(this), address(0), address(0), 0, int256(debtToCreate)); // assuming rate == RAY (jug never dripped)

        uint256 snapshot = vm.snapshot();
        (uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty) = autoMaxLine.exec();
        vm.revertTo(snapshot);

        (, uint256 gapBefore, uint48 ttlBefore, uint48 lastBefore, uint48 lastIncBefore) = autoLine.ilks(ILK);
        (uint256 dutyBefore,)= jug.ilks(ILK);

        vm.expectEmit(true, true, true, true);
        emit Exec(oldMaxLine, newMaxLine, debt, oldDuty, newDuty);
        autoMaxLine.exec();

        // check return values and event values
        assertEq(oldMaxLine, 200_000_000 * RAD);
        assertEqApprox(newMaxLine, 86_000_000 * RAD, RAD / 1000); // 70m + 0.4 * 40m
        assertEq(debt, debtToCreate * RAY);
        assertEq(oldDuty, 1001 * RAY / 1000);
        assertEq(newDuty, expectedNewDuty);

        // check modifications
        (uint256 maxLineAfter, uint256 gapAfter, uint48 ttlAfter, uint48 lastAfter, uint48 lastIncAfter) = autoLine.ilks(ILK);
        assertEq(maxLineAfter, newMaxLine);
        assertEq(gapAfter,     gapBefore);
        assertEq(ttlAfter,     ttlBefore);
        assertEq(lastAfter,    lastBefore);
        assertEq(lastIncAfter, lastIncBefore);
        (uint256 dutyAfter,)= jug.ilks(ILK);
        assertEq(dutyAfter, newDuty);
    }

    function testExecDebtLessThanNewMaxLine() public {
        checkExec(75_000_000 * WAD, RATE_5_PERCENT);
    }

    function testExecDebtMoreThanNewMaxLine() public {
        checkExec(90_000_000 * WAD, RATE_15_PERCENT);
    }

    // TODO: test seek not affected by trading
}