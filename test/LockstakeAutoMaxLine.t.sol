// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
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
import { LockstakeDeploy } from "deploy/LockstakeDeploy.sol";
import { LockstakeInit, AutoMaxLineConfig } from "deploy/LockstakeInit.sol";
import { UniswapV2Library } from "test/helpers/UniswapV2Library.sol";
import { PipMock } from "test/mocks/PipMock.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface VatLike {
    function init(bytes32) external;
    function file(bytes32, bytes32, uint256) external;
    function slip(bytes32, address, int256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
}

interface SpotterLike {
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
    function poke(bytes32) external;
}

interface PairLike {
    function sync() external;
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external;
}

interface AutoLineLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint48, uint48, uint48);
    function rely(address) external;
    function setIlk(bytes32, uint256, uint256, uint256) external;
    function remIlk(bytes32) external;
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

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface OsmLike {
    function src() external returns (address);
}

contract LockstakeAutoMaxLineTest is DssTest {
    DssInstance          dss;
    address              mkr;
    address              link;
    address              pauseProxy;
    AutoLineLike         autoLine;
    address             pipEth;
    address             pipMkr;
    address             pipLink;
    LockstakeAutoMaxLine autoMaxLine;
    LockstakeAutoMaxLine linkAutoMaxLine;
    
    bytes32 constant ILK                 = "ILK";
    address constant LOG                 = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address constant UNIV2_FACTORY       = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNIV2_DAI_MKR_PAIR  = 0x517F9dD285e75b599234F7221227339478d0FcC8;
    address constant UNIV2_LINK_DAI_PAIR = 0x6D4fd456eDecA58Cf53A8b586cd50754547DBDB2;
    address constant UNIV2_DAI_USDC_PAIR = 0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5;
    address constant UNIV2_ROUTER        = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 constant RATE_5_PERCENT      = 1000000001547125957863212448;
    uint256 constant RATE_15_PERCENT     = 1000000004431822129783699001;

    event Exec(uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dss = MCD.loadFromChainlog(LOG);

        mkr           = dss.chainlog.getAddress("MCD_GOV");
        link          = dss.chainlog.getAddress("LINK");
        pauseProxy    = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        autoLine      = AutoLineLike(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE"));
        pipEth        = dss.chainlog.getAddress("PIP_ETH");
        pipMkr        = dss.chainlog.getAddress("PIP_MKR");
        pipLink       = OsmLike(dss.chainlog.getAddress("PIP_LINK")).src(); // Compatibility with MKR pip

        vm.startPrank(pauseProxy);
        dss.vat.init(ILK);
        dss.jug.init(ILK);
        dss.jug.file(ILK, "duty", 1001 * RAY / 1000);
        dss.spotter.file(ILK, "pip", address(pipEth)); // Using ETH for simplicity, can be anything
        dss.spotter.file(ILK, "mat", 1 * RAY); // 100% coll ratio
        dss.vat.file(ILK, "line", 100_000_000 * RAD);
        autoLine.setIlk(ILK, 200_000_000 * RAD, 10_000_000 * RAD, 8 hours);
        dss.spotter.poke(ILK);
        dss.vat.slip(ILK, address(this), type(int256).max);
        vm.stopPrank();

        dss.vat.frob(ILK, address(this), address(this), address(0), int256(500_000_000 * WAD), 0);

        autoMaxLine     = setupAutoMaxLine(mkr,   UNIV2_DAI_MKR_PAIR,  pipMkr, 727);
        linkAutoMaxLine = setupAutoMaxLine(link, UNIV2_LINK_DAI_PAIR, pipLink, 727);
    }

    function setupAutoMaxLine(address gem, address pair, address pip, uint256 price)
        internal
        returns (LockstakeAutoMaxLine autoMaxLine_)
    {
        autoMaxLine_ = LockstakeAutoMaxLine(LockstakeDeploy.deployAutoMaxLine(
            address(this),
            pauseProxy,
            ILK,
            address(dss.dai),
            pair,
            address(pip)
        ));

        AutoMaxLineConfig memory cfg = AutoMaxLineConfig({
            ilk          : ILK,
            nst          : address(dss.dai),
            pair         : pair,
            pip          : address(pip),
            duty         : RATE_5_PERCENT,
            windDownDuty : RATE_15_PERCENT,
            lpFactor     : 40 * RAY / 100
        });

        vm.startPrank(pauseProxy);
        LockstakeInit.initAutoMaxLine(dss, address(autoMaxLine_), cfg);
        vm.stopPrank();

        // Set price and protocol owned liquidity in Uniswap
        changeMedianizerPrice(address(pip), price * WAD);
        changeUniV2Price(price * WAD, gem, pair);

        deal(pair, pauseProxy, 0);
        deal(address(dss.dai),  pauseProxy, 40_000_000 * WAD);
        deal(gem,  pauseProxy, 40_000_000 * WAD / price);

        vm.startPrank(pauseProxy);
        GemLike(address(dss.dai)).approve(UNIV2_ROUTER, 40_000_000 * WAD);
        GemLike(gem).approve(UNIV2_ROUTER, 40_000_000 * WAD / price);
        RouterLike(UNIV2_ROUTER).addLiquidity(
            address(dss.dai),
            gem,
            40_000_000 * WAD,
            40_000_000 * WAD / price,
            0,
            0,
            pauseProxy,
            block.timestamp
        );
        vm.stopPrank();
    }

    function changeUniV2Price(uint256 daiForGem, address gem, address pair) internal {
        (uint256 reserveDai, uint256 reserveGem) = UniswapV2Library.getReserves(UNIV2_FACTORY, address(dss.dai), gem);
        uint256 currentDaiForGem = reserveDai * WAD / reserveGem;

        if (currentDaiForGem > daiForGem) {
            deal(gem, pair, reserveDai * WAD / daiForGem);
        } else {
            deal(address(dss.dai), pair, reserveGem * daiForGem / WAD);
        }
        PairLike(pair).sync();
    }

    function changeMedianizerPrice(address pip, uint256 daiForGem) internal {
        vm.store(pip, bytes32(uint256(1)), bytes32(block.timestamp << 128 | daiForGem));
    }

    function assertEqApprox(uint256 _a, uint256 _b, uint256 _tolerance) internal {
        uint256 a = _a;
        uint256 b = _b;
        if (a < b) {
            uint256 tmp = a;
            a = b;
            b = tmp;
        }
        if (a - b > _tolerance) {
            emit log_bytes32("Error: Wrong `uint256' value");
            emit log_named_uint("  Expected", _b);
            emit log_named_uint("    Actual", _a);
            fail();
        }
    }

    function testConstructor() public {
        vm.expectRevert("LockstakeAutoMaxLine/gem-decimals-not-18");
        new LockstakeAutoMaxLine(
            address(dss.vat),
            address(dss.jug),
            address(dss.spotter),
            address(autoLine),
            ILK,
            address(dss.dai),
            UNIV2_DAI_USDC_PAIR,
            address(pipMkr),
            pauseProxy
        );

        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        LockstakeAutoMaxLine a = new LockstakeAutoMaxLine(
            address(dss.vat),
            address(dss.jug),
            address(dss.spotter),
            address(autoLine),
            ILK,
            address(dss.dai),
            UNIV2_DAI_MKR_PAIR,
            address(pipMkr),
            pauseProxy
        );
        assertEq(address(a.vat()),       address(dss.vat));
        assertEq(address(a.jug()),       address(dss.jug));
        assertEq(address(a.spotter()),   address(dss.spotter));
        assertEq(address(a.autoLine()),  address(autoLine));
        assertEq(a.ilk(),                ILK);
        assertEq(a.nst(),                address(dss.dai));
        assertEq(address(a.pair()),      UNIV2_DAI_MKR_PAIR);
        assertEq(address(a.pip()),       address(pipMkr));
        assertEq(a.lpOwner(),            pauseProxy);
        assertEq(a.nstFirst(),           true);
        assertEq(a.wards(address(this)), 1);

        // check also when nst is second
        LockstakeAutoMaxLine b = new LockstakeAutoMaxLine(
            address(dss.vat),
            address(dss.jug),
            address(dss.spotter),
            address(autoLine),
            ILK,
            address(dss.dai),
            UNIV2_LINK_DAI_PAIR,
            address(pipLink),
            pauseProxy
        );
        assertEq(address(b.vat()),       address(dss.vat));
        assertEq(address(b.jug()),       address(dss.jug));
        assertEq(address(b.spotter()),   address(dss.spotter));
        assertEq(address(b.autoLine()),  address(autoLine));
        assertEq(b.ilk(),                ILK);
        assertEq(a.nst(),                address(dss.dai));
        assertEq(address(b.pair()),      UNIV2_LINK_DAI_PAIR);
        assertEq(address(b.pip()),       address(pipLink));
        assertEq(a.lpOwner(),            pauseProxy);
        assertEq(b.nstFirst(),           false);
        assertEq(b.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(autoMaxLine), "LockstakeAutoMaxLine");
    }

    function testFileUint() public {
        checkFileUint(address(autoMaxLine), "LockstakeAutoMaxLine", ["duty", "windDownDuty", "lpFactor"]);
    }

    function testAutoLineNotEnabled() public {
        uint256 snapshot = vm.snapshot();

        vm.prank(pauseProxy); autoLine.remIlk(ILK);
        vm.expectRevert("LockstakeAutoMaxLine/auto-line-not-enabled");
        autoMaxLine.exec();

        vm.revertTo(snapshot);

        vm.prank(pauseProxy); autoLine.setIlk(ILK, 200_000_000 * RAD, 0, 8 hours);
        vm.expectRevert("LockstakeAutoMaxLine/auto-line-not-enabled");
        autoMaxLine.exec();

        vm.revertTo(snapshot);

        vm.prank(pauseProxy); autoLine.setIlk(ILK, 200_000_000 * RAD, 10_000_000 * RAD, 0);
        vm.expectRevert("LockstakeAutoMaxLine/auto-line-not-enabled");
        autoMaxLine.exec();
    }

    function testMissingDuty() public {
        uint256 snapshot = vm.snapshot();

        vm.prank(pauseProxy); autoMaxLine.file("duty", 0);
        vm.expectRevert("LockstakeAutoMaxLine/missing-duty");
        autoMaxLine.exec();

        vm.revertTo(snapshot);

        vm.prank(pauseProxy); autoMaxLine.file("windDownDuty", 0);
        vm.expectRevert("LockstakeAutoMaxLine/missing-duty");
        autoMaxLine.exec();
    }

    function testInvalidReserves() public {
        uint256 snapshot = vm.snapshot();

        deal(address(dss.dai), UNIV2_DAI_MKR_PAIR, 0);
        vm.expectRevert("LockstakeAutoMaxLine/invalid-reserves");
        autoMaxLine.exec();

        vm.revertTo(snapshot);

        deal(mkr, UNIV2_DAI_MKR_PAIR, 0);
        vm.expectRevert("LockstakeAutoMaxLine/invalid-reserves");
        autoMaxLine.exec();
    }

    function testInvalidOraclePrice() public {
        PipMock zeroPip = new PipMock();
        zeroPip.setPrice(0);

        LockstakeAutoMaxLine autoMaxLine_ = LockstakeAutoMaxLine(LockstakeDeploy.deployAutoMaxLine(
            address(this),
            pauseProxy,
            ILK,
            address(dss.dai),
            UNIV2_DAI_MKR_PAIR,
            address(zeroPip)
        ));

        vm.expectRevert("LockstakeAutoMaxLine/invalid-oracle-price");
        autoMaxLine_.exec();
    }

    function checkExec(LockstakeAutoMaxLine autoMaxLine_, uint256 debtToCreate, uint256 expectedNewMaxLine, uint256 expectedNewDuty) internal {
        dss.vat.frob(ILK, address(this), address(0), address(0), 0, int256(debtToCreate)); // assuming rate == RAY (jug never dripped)

        uint256 snapshot = vm.snapshot();
        (uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty) = autoMaxLine_.exec();
        vm.revertTo(snapshot);

        (, uint256 gapBefore, uint48 ttlBefore, uint48 lastBefore, uint48 lastIncBefore) = autoLine.ilks(ILK);
        vm.expectEmit(true, true, true, true);
        emit Exec(oldMaxLine, newMaxLine, debt, oldDuty, newDuty);
        autoMaxLine_.exec();

        // check return values and event values are as expected
        assertEq(oldMaxLine, 200_000_000 * RAD);
        assertEqApprox(newMaxLine, expectedNewMaxLine, RAD / 1000);
        assertEq(debt, debtToCreate * RAY);
        assertEq(oldDuty, 1001 * RAY / 1000);
        assertEq(newDuty, expectedNewDuty);

        // check storage modifications are as expected
        (uint256 maxLineAfter, uint256 gapAfter, uint48 ttlAfter, uint48 lastAfter, uint48 lastIncAfter) = autoLine.ilks(ILK);
        assertEq(maxLineAfter, newMaxLine);
        assertEq(gapAfter,     gapBefore);
        assertEq(ttlAfter,     ttlBefore);
        assertEq(lastAfter,    lastBefore);
        assertEq(lastIncAfter, lastIncBefore);
        (uint256 dutyAfter,) = dss.jug.ilks(ILK);
        assertEq(dutyAfter, newDuty);
    }

    function testExecDebtLessThanNewMaxLine() public {
        checkExec(autoMaxLine, 31_000_000 * WAD, 32_000_000 * RAD, RATE_5_PERCENT); // 31m < max(0.4 * 80m, 1 wei)
    }

    function testExecDebtLessThanNewMaxLineNstSecond() public {
        checkExec(linkAutoMaxLine, 31_000_000 * WAD, 32_000_000 * RAD, RATE_5_PERCENT); // 31m < max(0.4 * 80m, 1 wei)
    }

    function testExecDebtMoreThanNewMaxLine() public {
        checkExec(autoMaxLine, 33_000_000 * WAD, 32_000_000 * RAD, RATE_15_PERCENT); // 33m > max(0.4 * 80m, 1 wei)
    }

    function testExecDebtMoreThanNewMaxLineNstSecond() public {
        checkExec(linkAutoMaxLine, 33_000_000 * WAD, 32_000_000 * RAD, RATE_15_PERCENT); // 33m > max(0.4 * 80m, 1 wei)
    }

    function testExecNoLpFunds() public {
        deal(UNIV2_DAI_MKR_PAIR, pauseProxy, 0);
        checkExec(autoMaxLine, 1_000_000 * WAD, 1 wei, RATE_15_PERCENT); // 1m > max(0.4 * 0m, 1 wei)
    }

    function testExecNoLpFundsNstSecond() public {
        deal(UNIV2_LINK_DAI_PAIR, pauseProxy, 0);
        checkExec(linkAutoMaxLine, 1_000_000 * WAD, 1 wei, RATE_15_PERCENT); // 1m > max(0.4 * 0m, 1 wei)
    }

    function testExecToZeroAndBack() public {
        dss.vat.frob(ILK, address(this), address(0), address(0), 0, int256(31_000_000 * WAD)); // assuming rate == RAY (jug never dripped)

        uint256 initialLpFunds = GemLike(UNIV2_DAI_MKR_PAIR).balanceOf(pauseProxy);

        (, uint256 newMaxLine,,, uint256 newDuty) = autoMaxLine.exec(); // 31m < max(0.4 * 80m, 1 wei)
        assertEqApprox(newMaxLine, 32_000_000 * RAD, RAD / 1000);
        assertEq(newDuty, RATE_5_PERCENT);

        deal(UNIV2_DAI_MKR_PAIR, pauseProxy, 0); // 31m > max(0.4 * 0m, 1 wei)
        (, newMaxLine,,, newDuty) = autoMaxLine.exec();
        assertEq(newMaxLine, 1 wei);
        assertEq(newDuty, RATE_15_PERCENT);

        deal(UNIV2_DAI_MKR_PAIR, pauseProxy, initialLpFunds);
        (, newMaxLine,,, newDuty) = autoMaxLine.exec(); // 31m < max(0.4 * 80m, 1 wei)
        assertEqApprox(newMaxLine, 32_000_000 * RAD, RAD / 1000);
        assertEq(newDuty, RATE_5_PERCENT);
    }

    function calculateNaiveMaxLine() public view returns (uint256) {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, address(dss.dai), mkr);
        uint256 currentDaiForMkr = reserveDai * WAD / reserveMkr;
        uint256 reservesInDai = reserveDai + reserveMkr * currentDaiForMkr / WAD;
        uint256 protocolReseveInDai = GemLike(UNIV2_DAI_MKR_PAIR).balanceOf(pauseProxy) * reservesInDai / GemLike(UNIV2_DAI_MKR_PAIR).totalSupply();
        return protocolReseveInDai * autoMaxLine.lpFactor();
    }

    function checkManipulation(uint256 daiForManipulation, uint256 minNaiveRelativeGrowthPct, uint256 maxMaxLineDiff) internal {
        (, uint256 newMaxLineBefore,,,) = autoMaxLine.exec();
        uint256 naiveMaxLineBefore = calculateNaiveMaxLine();
        assertEqApprox(newMaxLineBefore, naiveMaxLineBefore, RAD / 1000); // Without manipulating naive pricing works

        // Buy MKR to inflate the MKR value
        deal(address(dss.dai), address(this), daiForManipulation);
        GemLike(address(dss.dai)).approve(UNIV2_ROUTER, daiForManipulation);
        address[] memory path = new address[](2);
        path[0] = address(dss.dai);
        path[1] = mkr;
        RouterLike(UNIV2_ROUTER).swapExactTokensForTokens(daiForManipulation, 0, path, address(this), block.timestamp);

        uint256 naiveMaxLineAfter = calculateNaiveMaxLine();
        assertGt(naiveMaxLineAfter, naiveMaxLineBefore * minNaiveRelativeGrowthPct / 100); // Naive pricing allows a huge max line manipulations

        (, uint256 newMaxLineAfter,,,) = autoMaxLine.exec();
        assertLt(newMaxLineAfter - newMaxLineBefore, maxMaxLineDiff); // With non-naive pricing the manipulation effect is very limited

        uint256 estimatedManipulationCost = daiForManipulation * RAY * 2 * 3 / 1000; // 0.3% fee for both directions
        assertGt(estimatedManipulationCost, (newMaxLineAfter - newMaxLineBefore) * 10); // Manipulation cost is at least 10x higher than the max line increase
    }

    function testManipulation10M() public {
        checkManipulation(10_000_000 * WAD, 101, 10_000 * RAD);
    }

    function testManipulation100M() public {
        checkManipulation(100_000_000 * WAD, 200, 30_000 * RAD);
    }

    function testManipulation2B() public {
        checkManipulation(2_000_000_000 * WAD, 2000, 50_000 * RAD);
    }

    function testManipulation4B() public {
        checkManipulation(4_000_000_000 * WAD, 4000, 50_000 * RAD);
    }
}
