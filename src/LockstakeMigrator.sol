// SPDX-FileCopyrightText: © 2025 Dai Foundation <www.daifoundation.org>
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
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function file(bytes32, bytes32, uint256) external;
    function hope(address) external;
}

interface LockstakeEngineLike {
    function vat() external view returns (VatLike);
    function ilk() external view returns (bytes32);
    function mkr() external view returns (TokenLike);
    function sky() external view returns (TokenLike);
    function usdsJoin() external view returns (UsdsJoinLike);
    function ownerUrns(address, uint256) external view returns (address);
    function isUrnAuth(address, uint256, address) external view returns (bool);
    function lock(address, uint256, uint256, uint16) external;
    function freeNoFee(address, uint256, address, uint256) external;
    function draw(address, uint256, address, uint256) external;
    function wipeAll(address, uint256) external;
}

interface UsdsJoinLike {
    function usds() external view returns (TokenLike);
    function join(address, uint256) external;
    function exit(address, uint256) external;
}

interface TokenLike {
    function approve(address, uint256) external;
}

interface MkrSkyLike {
    function rate() external view returns (uint256);
    function mkrToSky(address, uint256) external;
}

interface FlashLike {
    function vatDaiFlashLoan(address, uint256, bytes calldata) external;
}

contract LockstakeMigrator {
    // --- immutables ---

    LockstakeEngineLike immutable public oldEngine;
    LockstakeEngineLike immutable public newEngine;
    MkrSkyLike          immutable public mkrSky;
    FlashLike           immutable public flash;
    VatLike             immutable public vat;
    UsdsJoinLike        immutable public usdsJoin;
    bytes32             immutable public oldIlk;
    bytes32             immutable public newIlk;
    uint256             immutable public mkrSkyRate;

    // --- constants ---

    uint256 private constant RAY = 10**27;
    uint256 private constant RAD = 10**45;

    // --- math ---

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // Note: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    // --- events ---

    event Migrate(address indexed oldOwner, uint256 indexed oldIndex, address indexed newOwner, uint256 indexed newIndex, uint256 ink, uint256 debt) anonymous;

    // --- constructor ---

    constructor(address oldEngine_, address newEngine_, address mkrSky_, address flash_) {
        oldEngine = LockstakeEngineLike(oldEngine_);
        newEngine = LockstakeEngineLike(newEngine_);
        mkrSky = MkrSkyLike(mkrSky_);
        flash = FlashLike(flash_);
        vat = oldEngine.vat();
        usdsJoin = oldEngine.usdsJoin();
        oldIlk = oldEngine.ilk();
        newIlk = newEngine.ilk();
        mkrSkyRate = mkrSky.rate();

        TokenLike usds = usdsJoin.usds();
        oldEngine.mkr().approve(mkrSky_, type(uint256).max);
        oldEngine.sky().approve(newEngine_, type(uint256).max);
        usds.approve(oldEngine_, type(uint256).max);
        usds.approve(address(usdsJoin), type(uint256).max);
        vat.hope(address(usdsJoin));
    }

    function migrate(address oldOwner, uint256 oldIndex, address newOwner, uint256 newIndex, uint16 ref) external {
        require(oldEngine.isUrnAuth(oldOwner, oldIndex, msg.sender), "LockstakeMigrator/sender-not-authed-old-urn");
        require(newEngine.isUrnAuth(newOwner, newIndex, msg.sender), "LockstakeMigrator/sender-not-authed-new-urn");

        address oldUrn = oldEngine.ownerUrns(oldOwner, oldIndex);
        (uint256 ink, uint256 art) = vat.urns(oldIlk, oldUrn);
        uint256 debt;
        if (art == 0) {
            oldEngine.freeNoFee(oldOwner, oldIndex, address(this), ink);
            mkrSky.mkrToSky(address(this), ink);
            newEngine.lock(newOwner, newIndex, ink * mkrSkyRate, ref);
        } else {
            // Just a sanity check at migrate execution time. It is still needed to assume
            // governance won't ever give debt ceiling allowance for the old collateral
            (, uint256 oldIlkRate,, uint256 oldIlkLine,) = vat.ilks(oldIlk);
            require(oldIlkLine == 0, "LockstakeMigrator/old-ilk-line-not-zero");
            debt = _divup(art * oldIlkRate, RAY) * RAY;
            flash.vatDaiFlashLoan(address(this), debt, abi.encode(oldOwner, oldIndex, newOwner, newIndex, ink, ref));
        }

        emit Migrate(oldOwner, oldIndex, newOwner, newIndex, ink, debt);
    }

    function onVatDaiFlashLoan(address initiator, uint256 radAmt, uint256, bytes calldata data) external returns (bytes32) {
        require(msg.sender == address(flash) && initiator == address(this), "LockstakeMigrator/wrong-origin");

        uint256 wadAmt = radAmt / RAY;
        (address oldOwner, uint256 oldIndex, address newOwner, uint256 newIndex, uint256 ink, uint16 ref) = abi.decode(data, (address, uint256, address, uint256, uint256, uint16));
        usdsJoin.exit(address(this), wadAmt);
        oldEngine.wipeAll(oldOwner, oldIndex);
        oldEngine.freeNoFee(oldOwner, oldIndex, address(this), ink);
        mkrSky.mkrToSky(address(this), ink);
        newEngine.lock(newOwner, newIndex, ink * mkrSkyRate, ref);
        vat.file(newIlk, "line", 55_000_000 * RAD); // Should be enough for migrating current positions even if everything is taken and then some fees are accrued on top
        newEngine.draw(newOwner, newIndex, address(this), wadAmt);
        vat.file(newIlk, "line", 0);
        usdsJoin.join(address(flash), wadAmt);

        return keccak256("VatDaiFlashBorrower.onVatDaiFlashLoan");
    }
}
