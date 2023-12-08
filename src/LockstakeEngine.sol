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

contract LockstakeEngine {
    // --- storage variables ---

    mapping(address => uint256)                     public wards;        // usr => 1 == access
    mapping(address => uint256)                     public farms;        // farm => 1 == whitelisted
    mapping(address => uint256)                     public usrAmts;      // usr => urns amount
    mapping(address => address)                     public urnOwners;    // urn => owner
    mapping(address => mapping(address => uint256)) public urnCan;       // urn => usr => allowed (1 = yes, 0 = no)
    mapping(address => address)                     public urnDelegates; // urn => current associated delegate
    mapping(address => address)                     public selectedFarm; // urn => current selected farm
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
    GemLike             immutable public gov;
    GemLike             immutable public stkGov;
    uint256             immutable public fee;

    // --- events ---   

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, address data);
    event AddFarm(address farm);
    event DelFarm(address farm);
    event Open(address indexed owner, address urn);
    event Hope(address indexed urn, address indexed usr);
    event Nope(address indexed urn, address indexed usr);
    event Delegate(address indexed urn, address indexed delegate);
    event Lock(address indexed urn, uint256 wad);
    event Free(address indexed urn, uint256 wad, uint256 burn);
    event Draw(address indexed urn, uint256 wad);
    event Wipe(address indexed urn, uint256 wad);
    event SelectFarm(address indexed urn, address farm);
    event Stake(address indexed urn, address indexed farm, uint256 wad, uint16 ref);
    event Withdraw(address indexed urn, address indexed farm, uint256 amt);
    event GetReward(address indexed urn, address indexed farm);
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

    constructor(address delegateFactory_, address nstJoin_, bytes32 ilk_, address stkGov_, uint256 fee_) {
        delegateFactory = DelegateFactoryLike(delegateFactory_);
        nstJoin = NstJoinLike(nstJoin_);
        vat = nstJoin.vat();
        nst = nstJoin.nst();
        ilk = ilk_;
        gov = delegateFactory.gov();
        stkGov = GemLike(stkGov_);
        fee = fee_;
        nst.approve(nstJoin_, type(uint256).max);
        vat.hope(nstJoin_);
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
        bytes32 codeHash = keccak256(abi.encodePacked(type(LockstakeUrn).creationCode, abi.encode(vat, stkGov)));
        urn = address(uint160(uint256(
            keccak256(
                abi.encodePacked(bytes1(0xff), address(this), salt, codeHash)
            )
        )));
    }

    function isUrnAuth(address urn, address usr) external view returns (bool ok) {
        ok = _urnAuth(urn, usr);
    }


    // --- urn/delegation functions ---

    function open() external returns (address urn) {
        uint256 salt = uint256(keccak256(abi.encode(msg.sender, usrAmts[msg.sender]++)));
        bytes memory code = abi.encodePacked(type(LockstakeUrn).creationCode, abi.encode(vat, stkGov));
        assembly {
            urn := create2(0, add(code, 0x20), mload(code), salt)
        }
        require(urn != address(0), "LockstakeEngine/urn-creation-failed");
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

    function lock(address urn, uint256 wad) external urnAuth(urn) {
        require(wad <= uint256(type(int256).max), "LockstakeEngine/wad-overflow");
        gov.transferFrom(msg.sender, address(this), wad);
        address delegate_ = urnDelegates[urn];
        if (delegate_ != address(0)) {
            gov.approve(address(delegate_), wad);
            DelegateLike(delegate_).lock(wad);
        }
        // TODO: define if we want an internal registry to register how much is locked per user,
        // the vat.slip and stkGov balance act already as a registry so probably not needed an extra one
        vat.slip(ilk, urn, int256(wad));
        vat.frob(ilk, urn, urn, address(0), int256(wad), 0);
        stkGov.mint(urn, wad);
        emit Lock(urn, wad);
    }

    function free(address urn, uint256 wad) external urnAuth(urn) {
        require(wad <= uint256(type(int256).max), "LockstakeEngine/wad-overflow");
        vat.frob(ilk, urn, urn, address(0), -int256(wad), 0);
        vat.slip(ilk, urn, -int256(wad));
        stkGov.burn(urn, wad);
        address delegate_ = urnDelegates[urn];
        if (delegate_ != address(0)) {
            DelegateLike(delegate_).free(wad);
        }
        uint256 burn = wad * fee / WAD;
        gov.burn(address(this), burn);
        gov.transfer(msg.sender, wad - burn);
        emit Free(urn, wad, burn);
    }

    function delegate(address urn, address delegate_) external urnAuth(urn) {
        require(delegate_ == address(0) || delegateFactory.isDelegate(delegate_) == 1, "LockstakeEngine/not-valid-delegate");
        address prevDelegate = urnDelegates[urn];
        require(prevDelegate != delegate_, "LockstakeEngine/same-delegate");
        (uint256 wad,) = vat.urns(ilk, urn);
        if (wad > 0) {
            if (prevDelegate != address(0)) {
                DelegateLike(prevDelegate).free(wad);
            }
            if (delegate_ != address(0)) {
                gov.approve(address(delegate_), wad);
                DelegateLike(delegate_).lock(wad);
            }
        }
        urnDelegates[urn] = delegate_;
        emit Delegate(urn, delegate_);
    }

    // --- loan functions ---

    function draw(address urn, uint256 wad) external urnAuth(urn) {
        uint256 rate = jug.drip(ilk);
        uint256 dart = _divup(wad * RAY, rate);
        require(dart <= uint256(type(int256).max), "LockstakeEngine/overflow");
        vat.frob(ilk, urn, address(0), address(this), 0, int256(dart));
        nstJoin.exit(msg.sender, wad);
        emit Draw(urn, wad);
    }

    function wipe(address urn, uint256 wad) external urnAuth(urn) {
        nst.transferFrom(msg.sender, address(this), wad);
        nstJoin.join(address(this), wad);
        uint256 rate = jug.drip(ilk);
        uint256 dart = wad * RAY / rate;
        require(dart <= uint256(type(int256).max), "LockstakeEngine/overflow");
        vat.frob(ilk, urn, address(0), address(this), 0, -int256(dart));
        emit Wipe(urn, wad);
    }

    // --- staking functions ---

    function selectFarm(address urn, address farm) external urnAuth(urn) {
        require(farms[farm] == 1, "LockstakeEngine/non-existing-farm");
        address selectedFarmUrn = selectedFarm[urn];
        require(selectedFarmUrn == address(0) || GemLike(selectedFarmUrn).balanceOf(address(urn)) == 0, "LockstakeEngine/withdraw-first");
        selectedFarm[urn] = farm;
        emit SelectFarm(urn, farm);
    }

    function stake(address urn, uint256 wad, uint16 ref) external urnAuth(urn) {
        address selectedFarmUrn = selectedFarm[urn];
        require(selectedFarmUrn != address(0), "LockstakeEngine/missing-selected-farm");
        LockstakeUrn(urn).stake(selectedFarmUrn, wad, ref);
        emit Stake(urn, selectedFarmUrn, wad, ref);
    }

    function withdraw(address urn, uint256 amt) external urnAuth(urn) {
        address selectedFarmUrn = selectedFarm[urn];
        require(selectedFarmUrn != address(0), "LockstakeEngine/missing-selected-farm");
        LockstakeUrn(urn).withdraw(selectedFarmUrn, amt);
        emit Withdraw(urn, selectedFarmUrn, amt);
    }

    function getReward(address urn, address farm) external urnAuth(urn) {
        LockstakeUrn(urn).getReward(farm, msg.sender);
        emit GetReward(urn, farm);
    }

    // --- liquidation callback functions ---

    function onKick(address urn, uint256 wad) external auth {
        address selectedFarmUrn = selectedFarm[urn];
        if (selectedFarmUrn != address(0)){
            uint256 freed = GemLike(stkGov).balanceOf(address(urn));
            if (wad > freed) {
                LockstakeUrn(urn).withdraw(selectedFarmUrn, wad - freed);
            }
        }
        stkGov.burn(urn, wad); // Burn the whole liquidated amount of staking token
        address delegate_ = urnDelegates[urn];
        if (delegate_ != address(0)) {
            DelegateLike(delegate_).free(wad); // Undelegate liquidated amount and retain NGT
        }
        // Urn confiscation happens in Dog contract where ilk vat.gem is sent to the LockstakeClipper
        emit OnKick(urn, wad);
    }

    function onTake(address urn, address who, uint256 wad) external auth {
        gov.transfer(who, wad); // Free GOV to the auction buyer
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
        gov.burn(address(this), burn); // Burn GOV
        if (left > 0) {
            address delegate_ = urnDelegates[urn];
            if (delegate_ != address(0)) {
                gov.approve(address(delegate_), left);
                DelegateLike(delegate_).lock(left);
            }
            vat.slip(ilk, urn, int256(left));
            vat.frob(ilk, urn, urn, address(0), int256(left), 0);
            stkGov.mint(urn, left);
        }
        emit OnTakeLeftovers(urn, tot, left, burn);
    }

    function onYank(address urn, uint256 wad) external auth {
        gov.burn(address(this), wad);
        emit OnYank(urn, wad);
    }
}
