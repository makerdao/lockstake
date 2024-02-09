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
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
}

interface AutoLineLike {
    function ilks(bytes32) external view returns(uint256, uint256, uint48, uint48, uint48);
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
    address constant UNIV2_DAI_USDC_PAIR = 0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5;
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

        // Set price and protocol owned liquidity in Uniswap
        uint256 initialPrice = 727;
        changeMedianizerPrice(initialPrice * WAD);
        changeUniV2Price(pip.read(), mkr, UNIV2_DAI_MKR_PAIR);

        deal(UNIV2_DAI_MKR_PAIR, pauseProxy, 0);
        deal(dai, pauseProxy, 40_000_000 * WAD);
        deal(mkr, pauseProxy, 40_000_000 * WAD / initialPrice);

        vm.startPrank(pauseProxy);
        GemLike(dai).approve(UNIV2_ROUTER, 40_000_000 * WAD);
        GemLike(mkr).approve(UNIV2_ROUTER, 40_000_000 * WAD / initialPrice);
        RouterLike(UNIV2_ROUTER).addLiquidity(
            dai,
            mkr,
            40_000_000 * WAD,
            40_000_000 * WAD / initialPrice,
            0,
            0,
            pauseProxy,
            block.timestamp
        );
        vm.stopPrank();

        // Set surplus buffer funds
        stdstore.target(address(vat)).sig("dai(address)").with_key(vow).depth(0).checked_write(50_000_000 * RAD);
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
            address(vat),
            address(jug),
            address(spotter),
            address(autoLine),
            ILK,
            dai,
            UNIV2_DAI_USDC_PAIR,
            vow,
            address(pip),
            pauseProxy
        );

        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        LockstakeAutoMaxLine a = new LockstakeAutoMaxLine(
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
        assertEq(address(a.vat()),      address(vat));
        assertEq(address(a.jug()),      address(jug));
        assertEq(address(a.spotter()),  address(spotter));
        assertEq(address(a.autoLine()), address(autoLine));
        assertEq(a.ilk(),               ILK);
        assertEq(address(a.dai()),      dai);
        assertEq(address(a.pair()),     UNIV2_DAI_MKR_PAIR);
        assertEq(address(a.vow()),      vow);
        assertEq(address(a.pip()),      address(pip));
        assertEq(address(a.lpOwner()),  pauseProxy);

        assertEq(a.daiFirst(),  true);
        assertEq(a.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(autoMaxLine), "LockstakeAutoMaxLine");
    }

    function testFileUint() public {
        checkFileUint(address(autoMaxLine), "LockstakeAutoMaxLine", ["duty", "windDownDuty", "lpFactor"]);
    }

    function testAutoLineNotEnabled() public {
        vm.prank(pauseProxy); autoLine.remIlk(ILK);
        vm.expectRevert("LockstakeAutoMaxLine/auto-line-not-enabled");
        autoMaxLine.exec();

        vm.prank(pauseProxy); autoLine.setIlk(ILK, 200_000_000 * RAD, 0, 8 hours);
        vm.expectRevert("LockstakeAutoMaxLine/auto-line-not-enabled");
        autoMaxLine.exec();

        vm.prank(pauseProxy); autoLine.setIlk(ILK, 200_000_000 * RAD, 10_000_000 * RAD, 0);
        vm.expectRevert("LockstakeAutoMaxLine/auto-line-not-enabled");
        autoMaxLine.exec();
    }

    function testMissingDuty() public {
        vm.prank(pauseProxy); autoMaxLine.file("duty", 0);
        vm.expectRevert("LockstakeAutoMaxLine/missing-duties");
        autoMaxLine.exec();
    }

    function testMissingWindDownDuty() public {
        vm.prank(pauseProxy); autoMaxLine.file("windDownDuty", 0);
        vm.expectRevert("LockstakeAutoMaxLine/missing-duties");
        autoMaxLine.exec();
    }

    function checkExec(uint256 debtToCreate, uint256 expectedNewMaxLine, uint256 expectedNewDuty) internal {
        vat.frob(ILK, address(this), address(0), address(0), 0, int256(debtToCreate)); // assuming rate == RAY (jug never dripped)

        uint256 snapshot = vm.snapshot();
        (uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty) = autoMaxLine.exec();
        vm.revertTo(snapshot);

        (, uint256 gapBefore, uint48 ttlBefore, uint48 lastBefore, uint48 lastIncBefore) = autoLine.ilks(ILK);
        vm.expectEmit(true, true, true, true);
        emit Exec(oldMaxLine, newMaxLine, debt, oldDuty, newDuty);
        autoMaxLine.exec();

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
        (uint256 dutyAfter,)= jug.ilks(ILK);
        assertEq(dutyAfter, newDuty);
    }

    function testExecDebtLessThanNewMaxLine() public {
        checkExec(70_000_000 * WAD, 82_000_000 * RAD, RATE_5_PERCENT); // 70m < max(50m - 0m + 0.4 * 80m, 1 wei)
    }

    function testExecDebtMoreThanNewMaxLine() public {
        checkExec(90_000_000 * WAD, 82_000_000 * RAD, RATE_15_PERCENT); // 90m > max(50m - 0m + 0.4 * 80m, 1 wei)
    }

    function testExecMinusLargerThanPlus() public {
        stdstore.target(address(vat)).sig("sin(address)").with_key(vow).depth(0).checked_write(90_000_000 * RAD);
        checkExec(15_000_000 * WAD, 1 wei, RATE_15_PERCENT); // 15m > max(50m - 90m + 0.4 * 80m, 1 wei)
    }

    function calculateNaiveMaxLine() public view returns (uint256) {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, dai, mkr);
        uint256 currentDaiForMkr = reserveDai * WAD / reserveMkr;
        uint256 reservesInDai = reserveDai + reserveMkr * currentDaiForMkr / WAD;
        uint256 protocolReseveInDai = GemLike(UNIV2_DAI_MKR_PAIR).balanceOf(pauseProxy) * reservesInDai / GemLike(UNIV2_DAI_MKR_PAIR).totalSupply();
        return (protocolReseveInDai * autoMaxLine.lpFactor() / WAD) * RAY;
    }

    function testManipulation() public {
        // Set surplus buffer to 0 for simplicity
        stdstore.target(address(vat)).sig("dai(address)").with_key(vow).depth(0).checked_write(uint256(0));
        stdstore.target(address(vat)).sig("sin(address)").with_key(vow).depth(0).checked_write(uint256(0));

        // first show that similar to naive pricing
        (, uint256 newMaxLineBefore,,,) = autoMaxLine.exec();
        uint256 naiveMaxLineBefore = calculateNaiveMaxLine();
        assertEqApprox(newMaxLineBefore, naiveMaxLineBefore, RAD / 1000);

        // Buy 4B DAI worth of MKR to inflate the MKR value
        deal(dai, address(this), 4_000_000_000 * WAD);
        GemLike(dai).approve(UNIV2_ROUTER, 4_000_000_000 * WAD);
        address[] memory path = new address[](2);
        path[0] = dai;
        path[1] = mkr;
        RouterLike(UNIV2_ROUTER).swapExactTokensForTokens(4_000_000_000 * WAD, 0, path, address(this), block.timestamp);

        (, uint256 newMaxLineAfter,,,) = autoMaxLine.exec();
        uint256 naiveMaxLineAfter = calculateNaiveMaxLine();

        assertGt(naiveMaxLineAfter, naiveMaxLineBefore * 40);
        assertEqApprox(newMaxLineAfter, naiveMaxLineBefore, 50_000 * RAD); // TODO: investigate why this is not closer
    }
}