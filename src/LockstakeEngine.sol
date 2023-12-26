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

pragma solidity ^0.8.16;

import { LockstakeUrn } from "src/LockstakeUrn.sol";
import { Multicall } from "src/Multicall.sol";

interface DelegateFactoryLike {
    function gov() external view returns (GemLike);
    function isDelegate(address) external returns (uint256);
}

interface DelegateLike {
    function lock(uint256) external;
    function free(uint256) external;
}

interface VatLike {
    function urns(bytes32, address) external view returns (uint256, uint256);
    function hope(address) external;
    function slip(bytes32, address, int256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
}

interface NstJoinLike {
    function vat() external view returns (VatLike);
    function nst() external view returns (GemLike);
    function join(address, uint256) external;
    function exit(address, uint256) external;
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}

interface JugLike {
    function drip(bytes32) external returns (uint256);
}

interface MkrNgtLike {
    function rate() external view returns (uint256);
    function ngt() external view returns (address);
    function ngtToMkr(address, uint256) external;
    function mkrToNgt(address, uint256) external;
}

contract LockstakeEngine is Multicall {
    // --- storage variables ---

    mapping(address => uint256)                     public wards;        // usr => 1 == access
    mapping(address => uint256)                     public farms;        // farm => 1 == whitelisted
    mapping(address => uint256)                     public usrAmts;      // usr => urns amount
    mapping(address => address)                     public urnOwners;    // urn => owner
    mapping(address => mapping(address => uint256)) public urnCan;       // urn => usr => allowed (1 = yes, 0 = no)
    mapping(address => address)                     public urnDelegates; // urn => current associated delegate
    mapping(address => address)                     public urnFarms;     // urn => current selected farm
    JugLike                                         public jug;

    // --- constants ---

    uint256 constant WAD = 10**18;
    uint256 constant RAY = 10**27;

    // --- immutables ---

    DelegateFactoryLike immutable public delegateFactory;
    VatLike             immutable public vat;
    NstJoinLike         immutable public nstJoin;
    GemLike             immutable public nst;
    bytes32             immutable public ilk;
    GemLike             immutable public mkr;
    GemLike             immutable public stkMkr;
    uint256             immutable public fee;
    MkrNgtLike          immutable public mkrNgt;
    GemLike             immutable public ngt;
    uint256             immutable public mkrNgtRate;

    // --- events ---   

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, address data);
    event AddFarm(address farm);
    event DelFarm(address farm);
    event Open(address indexed owner, address urn);
    event Hope(address indexed urn, address indexed usr);
    event Nope(address indexed urn, address indexed usr);
    event SelectDelegate(address indexed urn, address indexed delegate);
    event SelectFarm(address indexed urn, address farm, uint16 ref);
    event Lock(address indexed urn, uint256 wad, uint16 ref);
    event LockNgt(address indexed urn, uint256 ngtWad, uint16 ref);
    event Free(address indexed urn, address indexed to, uint256 wad, uint256 burn);
    event FreeNgt(address indexed urn, address indexed to, uint256 ngtWad, uint256 burn);
    event Draw(address indexed urn, uint256 wad);
    event Wipe(address indexed urn, uint256 wad);
    event Stake(address indexed urn, address indexed farm, uint256 wad, uint16 ref);
    event Withdraw(address indexed urn, address indexed farm, uint256 wad);
    event GetReward(address indexed urn, address indexed farm, address indexed to, uint256 amt);
    event OnKick(address indexed urn, uint256 wad);
    event OnTake(address indexed urn, address indexed who, uint256 wad);
    event OnTakeLeftovers(address indexed urn, uint256 tot, uint256 left, uint256 burn);
    event OnYank(address indexed urn, uint256 wad);

    // --- modifiers ---

    modifier auth {
        require(wards[msg.sender] == 1, "LockstakeEngine/not-authorized");
        _;
    }

    modifier urnAuth(address urn) {
        require(_urnAuth(urn, msg.sender), "LockstakeEngine/urn-not-authorized");
        _;
    }

    // --- constructor ---

    constructor(address delegateFactory_, address nstJoin_, bytes32 ilk_, address stkMkr_, uint256 fee_, address mkrNgt_) {
        delegateFactory = DelegateFactoryLike(delegateFactory_);
        nstJoin = NstJoinLike(nstJoin_);
        vat = nstJoin.vat();
        nst = nstJoin.nst();
        ilk = ilk_;
        mkr = delegateFactory.gov();
        stkMkr = GemLike(stkMkr_);
        fee = fee_;
        nst.approve(nstJoin_, type(uint256).max);
        vat.hope(nstJoin_);
        mkrNgt = MkrNgtLike(mkrNgt_);
        ngt = GemLike(mkrNgt.ngt());
        ngt.approve(address(mkrNgt), type(uint256).max);
        mkr.approve(address(mkrNgt), type(uint256).max);
        mkrNgtRate = mkrNgt.rate();

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- internals ---

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function _urnAuth(address urn, address usr) internal view returns (bool ok) {
        ok = urnOwners[urn] == usr || urnCan[urn][usr] == 1;
    }

    // --- administration ---

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function file(bytes32 what, address data) external auth {
        if (what == "jug") {
            jug = JugLike(data);
        } else revert("LockstakeEngine/file-unrecognized-param");
        emit File(what, data);
    }

    function addFarm(address farm) external auth {
        farms[farm] = 1;
        emit AddFarm(farm);
    }

    function delFarm(address farm) external auth {
        farms[farm] = 0;
        emit DelFarm(farm);
    }

    // --- getters ---

    function getUrn(address owner, uint256 index) external view returns (address urn) {
        uint256 salt = uint256(keccak256(abi.encode(owner, index)));
        bytes32 codeHash = keccak256(abi.encodePacked(type(LockstakeUrn).creationCode, abi.encode(vat, stkMkr)));
        urn = address(uint160(uint256(
            keccak256(
                abi.encodePacked(bytes1(0xff), address(this), salt, codeHash)
            )
        )));
    }

    function isUrnAuth(address urn, address usr) external view returns (bool ok) {
        ok = _urnAuth(urn, usr);
    }

    // --- urn management functions ---

    function open(uint256 index) external returns (address urn) {
        require(index == usrAmts[msg.sender]++, "LockstakeEngine/wrong-urn-index");
        bytes32 salt = keccak256(abi.encode(msg.sender, index));
        urn = address(new LockstakeUrn{salt: salt}(address(vat), address(stkMkr)));
        urnOwners[urn] = msg.sender;
        emit Open(msg.sender, urn);
    }

    function hope(address urn, address usr) external urnAuth(urn) {
        urnCan[urn][usr] = 1;
        emit Hope(urn, usr);
    }

    function nope(address urn, address usr) external urnAuth(urn) {
        urnCan[urn][usr] = 0;
        emit Nope(urn, usr);
    }

    // --- delegation/staking functions ---

    function selectDelegate(address urn, address delegate) external urnAuth(urn) {
        require(delegate == address(0) || delegateFactory.isDelegate(delegate) == 1, "LockstakeEngine/not-valid-delegate");
        address prevDelegate = urnDelegates[urn];
        require(prevDelegate != delegate, "LockstakeEngine/same-delegate");
        (uint256 ink,) = vat.urns(ilk, urn);
        _selectDelegate(urn, ink, prevDelegate, delegate);
        emit SelectDelegate(urn, delegate);
    }

    function _selectDelegate(address urn, uint256 wad, address prevDelegate, address delegate) internal {
        if (wad > 0) {
            if (prevDelegate != address(0)) {
                DelegateLike(prevDelegate).free(wad);
            }
            if (delegate != address(0)) {
                mkr.approve(address(delegate), wad);
                DelegateLike(delegate).lock(wad);

                //mkr.approve(address(delegate), wad/2);  // TODO: remove
                //DelegateLike(delegate).lock(wad/2);
                //mkr.transfer(address(0), wad/2);
            }
        }
        urnDelegates[urn] = delegate;
    }

    function selectFarm(address urn, address farm, uint16 ref) external urnAuth(urn) {
        require(farm == address(0) || farms[farm] == 1, "LockstakeEngine/non-existing-farm");
        _selectFarm(urn, farm, ref);
        emit SelectFarm(urn, farm, ref);
    }

    function _selectFarm(address urn, address farm, uint16 ref) internal {
        address urnFarm = urnFarms[urn];
        if (urnFarm != address(0)) {
            uint256 balance = GemLike(urnFarm).balanceOf(address(urn));
            if (balance > 0) {
                LockstakeUrn(urn).withdraw(urnFarm, balance);
            }
        }
        if (farm != address(0)) {
//            stkMkr.burn(urn, 1); // TODO: remove
            uint256 balance = stkMkr.balanceOf(urn);
            if (balance > 0) {
                LockstakeUrn(urn).stake(farm, balance, ref);
            }
        }
        urnFarms[urn] = farm;
    }

    function lock(address urn, uint256 wad, uint16 ref) external urnAuth(urn) {
        mkr.transferFrom(msg.sender, address(this), wad);
        _lock(urn, wad, ref);
        emit Lock(urn, wad, ref);
    }

    function lockNgt(address urn, uint256 ngtWad, uint16 ref) external urnAuth(urn) {
        ngt.transferFrom(msg.sender, address(this), ngtWad);
        mkrNgt.ngtToMkr(address(this), ngtWad);
        _lock(urn, ngtWad / mkrNgtRate, ref);
        emit LockNgt(urn, ngtWad, ref);
    }

    function _lock(address urn, uint256 wad, uint16 ref) internal {
        require(wad <= uint256(type(int256).max), "LockstakeEngine/wad-overflow");
        address delegate = urnDelegates[urn];
        if (delegate != address(0)) {
            mkr.approve(address(delegate), wad);
            DelegateLike(delegate).lock(wad);
        }
        // TODO: define if we want an internal registry to register how much is locked per user,
        // the vat.slip and stkMkr balance act already as a registry so probably not needed an extra one
        vat.slip(ilk, urn, int256(wad));
        vat.frob(ilk, urn, urn, address(0), int256(wad), 0);
        stkMkr.mint(urn, wad);
        address urnFarm = urnFarms[urn];
        if (urnFarm != address(0)) {
            require(farms[urnFarm] == 1, "Lockstake/farm-not-whitelisted-anymore");
            LockstakeUrn(urn).stake(urnFarm, wad, ref);
        }
    }

    function free(address urn, address to, uint256 wad) external urnAuth(urn) {
        uint256 freed = _free(urn, wad);
        mkr.transfer(to, freed);
        emit Free(urn, to, wad, wad - freed);
    }

    function freeNgt(address urn, address to, uint256 ngtWad) external urnAuth(urn) {
        uint256 wad = ngtWad / mkrNgtRate;
        uint256 freed = _free(urn, wad);
        mkrNgt.mkrToNgt(to, freed);
        emit FreeNgt(urn, to, ngtWad, wad - freed);
    }

    function _free(address urn, uint256 wad) internal returns (uint256 freed) {
        require(wad <= uint256(type(int256).max), "LockstakeEngine/wad-overflow");
        address urnFarm = urnFarms[urn];
        if (urnFarm != address(0)) {
            LockstakeUrn(urn).withdraw(urnFarm, wad);
        }
        stkMkr.burn(urn, wad);
        vat.frob(ilk, urn, urn, address(0), -int256(wad), 0);
        vat.slip(ilk, urn, -int256(wad));
        address delegate = urnDelegates[urn];
        if (delegate != address(0)) {
            DelegateLike(delegate).free(wad);
        }
        uint256 burn = wad * fee / WAD;
        mkr.burn(address(this), burn);
        freed = wad - burn;
    }

    // --- loan functions ---

    function draw(address urn, uint256 wad) external urnAuth(urn) {
        uint256 rate = jug.drip(ilk);
        uint256 dart = _divup(wad * RAY, rate);
        require(dart <= uint256(type(int256).max), "LockstakeEngine/overflow");
        vat.frob(ilk, urn, address(0), address(this), 0, int256(dart));
        nstJoin.exit(msg.sender, wad);

        //mkr.burn(address(this), 1); // TODO: remove

        emit Draw(urn, wad);
    }

    function wipe(address urn, uint256 wad) external urnAuth(urn) {
        nst.transferFrom(msg.sender, address(this), wad);
        nstJoin.join(address(this), wad);
        uint256 rate = jug.drip(ilk);
        uint256 dart = wad * RAY / rate;
        require(dart <= uint256(type(int256).max), "LockstakeEngine/overflow");
        vat.frob(ilk, urn, address(0), address(this), 0, -int256(dart));

        // mkr.burn(address(this), 1); // TODO: remove
        emit Wipe(urn, wad);
    }

    // --- staking rewards function ---

    function getReward(address urn, address farm, address to) external urnAuth(urn) {
        uint256 amt = LockstakeUrn(urn).getReward(farm, to);
        emit GetReward(urn, farm, to, amt);
    }

    // --- liquidation callback functions ---

    function onKick(address urn, uint256 wad) external auth {
        (uint256 ink,) = vat.urns(ilk, urn);
        _selectDelegate(urn, ink + wad, urnDelegates[urn], address(0));
        _selectFarm(urn, address(0), 0);
        stkMkr.burn(urn, wad); // Burn the liquidated amount of staking token
        // Urn confiscation happens in Dog contract where ilk vat.gem is sent to the LockstakeClipper
        emit OnKick(urn, wad);
    }

    function onTake(address urn, address who, uint256 wad) external auth {
        mkr.transfer(who, wad); // Free MKR to the auction buyer
        emit OnTake(urn, who, wad);
    }

    function onTakeLeftovers(address urn, uint256 tot, uint256 left) external auth {
        uint256 burn = (tot - left) * fee / WAD;
        if (burn > left) {
            burn = left;
            left = 0;
        } else {
            unchecked { left = left - burn; }
        }
        mkr.burn(address(this), burn); // Burn MKR
        if (left > 0) {
            (uint256 ink,) = vat.urns(ilk, urn); // Get the ink value before adding the left to correctly undelegate
            vat.slip(ilk, urn, int256(left));
            vat.frob(ilk, urn, urn, address(0), int256(left), 0);
            stkMkr.mint(urn, left);
            _selectDelegate(urn, ink, urnDelegates[urn], address(0));
            _selectFarm(urn, address(0), 0);
        }
        emit OnTakeLeftovers(urn, tot, left, burn);
    }

    function onYank(address urn, uint256 wad) external auth {
        mkr.burn(address(this), wad);
        emit OnYank(urn, wad);
    }
}
