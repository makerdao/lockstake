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
}

interface PipLike {
    function read() external view returns (uint256);
    function kiss(address) external;
}

interface JugLike {
    function init(bytes32) external;
    function file(bytes32, bytes32, uint256) external;
    function rely(address) external;
}

interface SpotterLike {
    function par() external view returns (uint256);
    function file(bytes32, bytes32, address) external;
    function file(bytes32, bytes32, uint256) external;
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
        spotter.file(ILK, "mat", 3 * RAY); // 300% coll ratio
        vat.file(ILK, "line", 10_000_000 * RAD);
        autoLine.setIlk(ILK, 100_000_000 * RAD, 10_000_000 * RAD, 8 hours);
        pip.kiss(address(this));
        vm.stopPrank();

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
        autoMaxLine.file("duty",         1000000001547125957863212448); // 5%
        autoMaxLine.file("windDownDuty", 1000000004431822129783699001); // 15%
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
        (uint256 amountDai, uint256 amountMkr, uint256 liquidity) = RouterLike(UNIV2_ROUTER).addLiquidity(
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

    function testConstructor() public {
        // TODO: implement
    }

    function testAuth() public {
        checkAuth(address(autoMaxLine), "LockstakeAutoMaxLine");
    }

    function testFileUint() public {
        checkFileUint(address(autoMaxLine), "LockstakeAutoMaxLine", ["duty", "windDownDuty", "lpFactor"]);
    }

    function testExec() public {
        autoMaxLine.exec();
    }

    // TODO: more tests
}