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

pragma solidity ^0.8.21;

import { LockstakeUrn } from "src/LockstakeUrn.sol";
import { Multicall } from "src/Multicall.sol";

interface VoteDelegateFactoryLike {
    function created(address) external returns (uint256);
}

interface VoteDelegateLike {
    function lock(uint256) external;
    function free(uint256) external;
}

interface VatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function hope(address) external;
    function slip(bytes32, address, int256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
    function grab(bytes32, address, address, address, int256, int256) external;
}

interface UsdsJoinLike {
    function vat() external view returns (VatLike);
    function usds() external view returns (GemLike);
    function join(address, uint256) external;
    function exit(address, uint256) external;
}

interface GemLike {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}

interface JugLike {
    function drip(bytes32) external returns (uint256);
}

contract LockstakeEngine is Multicall {
    // --- storage variables ---

    mapping(address usr   => uint256 allowed)                         public wards;
    mapping(address farm  => FarmStatus)                              public farms;
    mapping(address owner => uint256 count)                           public ownerUrnsCount;
    mapping(address owner => mapping(uint256 index => address urn))   public ownerUrns;
    mapping(address urn   => address owner)                           public urnOwners;
    mapping(address urn   => mapping(address usr => uint256 allowed)) public urnCan;
    mapping(address urn   => address voteDelegate)                    public urnVoteDelegates;
    mapping(address urn   => address farm)                            public urnFarms;
    mapping(address urn   => uint256 auctionsCount)                   public urnAuctions;
    JugLike                                                           public jug;

    // --- constants and enums ---

    uint256 constant WAD = 10**18;
    uint256 constant RAY = 10**27;

    enum FarmStatus { UNSUPPORTED, ACTIVE, DELETED }

    // --- immutables ---

    VoteDelegateFactoryLike immutable public voteDelegateFactory;
    VatLike                 immutable public vat;
    UsdsJoinLike            immutable public usdsJoin;
    GemLike                 immutable public usds;
    bytes32                 immutable public ilk;
    GemLike                 immutable public sky;
    GemLike                 immutable public lssky;
    address                 immutable public urnImplementation;
    uint256                 immutable public fee;

    // --- events ---   

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, address data);
    event AddFarm(address farm);
    event DelFarm(address farm);
    event Open(address indexed owner, uint256 indexed index, address urn);
    event Hope(address indexed owner, uint256 indexed index, address indexed usr);
    event Nope(address indexed owner, uint256 indexed index, address indexed usr);
    event SelectVoteDelegate(address indexed owner, uint256 indexed index, address indexed voteDelegate);
    event SelectFarm(address indexed owner, uint256 indexed index, address indexed farm, uint16 ref);
    event Lock(address indexed owner, uint256 indexed index, uint256 wad, uint16 ref);
    event Free(address indexed owner, uint256 indexed index, address to, uint256 wad, uint256 freed);
    event FreeNoFee(address indexed owner, uint256 indexed index, address to, uint256 wad);
    event Draw(address indexed owner, uint256 indexed index, address to, uint256 wad);
    event Wipe(address indexed owner, uint256 indexed index, uint256 wad);
    event GetReward(address indexed owner, uint256 indexed index, address indexed farm, address to, uint256 amt);
    event OnKick(address indexed urn, uint256 wad);
    event OnTake(address indexed urn, address indexed who, uint256 wad);
    event OnRemove(address indexed urn, uint256 sold, uint256 burn, uint256 refund);

    // --- modifiers ---

    modifier auth {
        require(wards[msg.sender] == 1, "LockstakeEngine/not-authorized");
        _;
    }

    // --- constructor ---

    constructor(address voteDelegateFactory_, address usdsJoin_, bytes32 ilk_, address sky_, address lssky_, uint256 fee_) {
        voteDelegateFactory = VoteDelegateFactoryLike(voteDelegateFactory_);
        usdsJoin = UsdsJoinLike(usdsJoin_);
        vat = usdsJoin.vat();
        usds = usdsJoin.usds();
        ilk = ilk_;
        sky = GemLike(sky_);
        lssky = GemLike(lssky_);
        fee = fee_;
        urnImplementation = address(new LockstakeUrn(address(vat), lssky_));
        vat.hope(usdsJoin_);
        usds.approve(usdsJoin_, type(uint256).max);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- internals ---

    function _min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // Note: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function _urnAuth(address owner, address urn, address usr) internal view returns (bool ok) {
        ok = owner == usr || urnCan[urn][usr] == 1;
    }

    function _getUrn(address owner, uint256 index) internal view returns (address urn) {
        urn = ownerUrns[owner][index];
        require(urn != address(0), "LockstakeEngine/invalid-urn");
    }

    function _getAuthedUrn(address owner, uint256 index) internal view returns (address urn) {
        urn = _getUrn(owner, index);
        require(_urnAuth(owner, urn, msg.sender), "LockstakeEngine/urn-not-authorized");
    }

    // See the reference implementation in https://eips.ethereum.org/EIPS/eip-1167
    function _initCode() internal view returns (bytes memory code) {
        code = new bytes(0x37);
        bytes20 impl = bytes20(urnImplementation);
        assembly {
            mstore(add(code,     0x20),        0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(code, add(0x20, 0x14)), impl)
            mstore(add(code, add(0x20, 0x28)), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
        }
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
        farms[farm] = FarmStatus.ACTIVE;
        emit AddFarm(farm);
    }

    function delFarm(address farm) external auth {
        farms[farm] = FarmStatus.DELETED;
        emit DelFarm(farm);
    }

    // --- getters ---

    function isUrnAuth(address owner, uint256 index, address usr) external view returns (bool ok) {
        ok = _urnAuth(owner, _getUrn(owner, index), usr);
    }

    // --- urn management functions ---

    function open(uint256 index) external returns (address urn) {
        require(index == ownerUrnsCount[msg.sender]++, "LockstakeEngine/wrong-urn-index");
        bytes memory initCode = _initCode();
        assembly { urn := create(0, add(initCode, 0x20), 0x37) }
        LockstakeUrn(urn).init(); // would revert if create had failed
        ownerUrns[msg.sender][index] = urn;
        urnOwners[urn] = msg.sender;
        emit Open(msg.sender, index, urn);
    }

    function hope(address owner, uint256 index, address usr) external {
        address urn = _getAuthedUrn(owner, index);
        urnCan[urn][usr] = 1;
        emit Hope(owner, index, usr);
    }

    function nope(address owner, uint256 index, address usr) external {
        address urn = _getAuthedUrn(owner, index);
        urnCan[urn][usr] = 0;
        emit Nope(owner, index, usr);
    }

    // --- delegation/staking functions ---

    function selectVoteDelegate(address owner, uint256 index, address voteDelegate) external {
        address urn = _getAuthedUrn(owner, index);
        require(urnAuctions[urn] == 0, "LockstakeEngine/urn-in-auction");
        require(voteDelegate == address(0) || voteDelegateFactory.created(voteDelegate) == 1, "LockstakeEngine/not-valid-vote-delegate");
        address prevVoteDelegate = urnVoteDelegates[urn];
        require(prevVoteDelegate != voteDelegate, "LockstakeEngine/same-vote-delegate");
        (uint256 ink, uint256 art) = vat.urns(ilk, urn);
        if (art > 0 && voteDelegate != address(0)) {
            (,, uint256 spot,,) = vat.ilks(ilk);
            require(ink * spot >= art * jug.drip(ilk), "LockstakeEngine/urn-unsafe");
        }
        _selectVoteDelegate(urn, ink, prevVoteDelegate, voteDelegate);
        emit SelectVoteDelegate(owner, index, voteDelegate);
    }

    function _selectVoteDelegate(address urn, uint256 wad, address prevVoteDelegate, address voteDelegate) internal {
        if (wad > 0) {
            if (prevVoteDelegate != address(0)) {
                VoteDelegateLike(prevVoteDelegate).free(wad);
            }
            if (voteDelegate != address(0)) {
                sky.approve(voteDelegate, wad);
                VoteDelegateLike(voteDelegate).lock(wad);
            }
        }
        urnVoteDelegates[urn] = voteDelegate;
    }

    function selectFarm(address owner, uint256 index, address farm, uint16 ref) external {
        address urn = _getAuthedUrn(owner, index);
        require(urnAuctions[urn] == 0, "LockstakeEngine/urn-in-auction");
        require(farm == address(0) || farms[farm] == FarmStatus.ACTIVE, "LockstakeEngine/farm-unsupported-or-deleted");
        address prevFarm = urnFarms[urn];
        require(prevFarm != farm, "LockstakeEngine/same-farm");
        (uint256 ink,) = vat.urns(ilk, urn);
        _selectFarm(urn, ink, prevFarm, farm, ref);
        emit SelectFarm(owner, index, farm, ref);
    }

    function _selectFarm(address urn, uint256 wad, address prevFarm, address farm, uint16 ref) internal {
        if (wad > 0) {
            if (prevFarm != address(0)) {
                LockstakeUrn(urn).withdraw(prevFarm, wad);
            }
            if (farm != address(0)) {
                LockstakeUrn(urn).stake(farm, wad, ref);
            }
        }
        urnFarms[urn] = farm;
    }

    function lock(address owner, uint256 index, uint256 wad, uint16 ref) external {
        address urn = _getUrn(owner, index);
        sky.transferFrom(msg.sender, address(this), wad);
        require(wad <= uint256(type(int256).max), "LockstakeEngine/overflow");
        address voteDelegate = urnVoteDelegates[urn];
        if (voteDelegate != address(0)) {
            sky.approve(voteDelegate, wad);
            VoteDelegateLike(voteDelegate).lock(wad);
        }
        vat.slip(ilk, urn, int256(wad));
        vat.frob(ilk, urn, urn, address(0), int256(wad), 0);
        lssky.mint(urn, wad);
        address urnFarm = urnFarms[urn];
        if (urnFarm != address(0)) {
            require(farms[urnFarm] == FarmStatus.ACTIVE, "LockstakeEngine/farm-deleted");
            LockstakeUrn(urn).stake(urnFarm, wad, ref);
        }
        emit Lock(owner, index, wad, ref);
    }

    function free(address owner, uint256 index, address to, uint256 wad) external returns (uint256 freed) {
        address urn = _getAuthedUrn(owner, index);
        freed = _free(urn, wad, fee);
        sky.transfer(to, freed);
        emit Free(owner, index, to, wad, freed);
    }

    function freeNoFee(address owner, uint256 index, address to, uint256 wad) external auth {
        address urn = _getAuthedUrn(owner, index);
        _free(urn, wad, 0);
        sky.transfer(to, wad);
        emit FreeNoFee(owner, index, to, wad);
    }

    function _free(address urn, uint256 wad, uint256 fee_) internal returns (uint256 freed) {
        require(wad <= uint256(type(int256).max), "LockstakeEngine/overflow");
        address urnFarm = urnFarms[urn];
        if (urnFarm != address(0)) {
            LockstakeUrn(urn).withdraw(urnFarm, wad);
        }
        lssky.burn(urn, wad);
        vat.frob(ilk, urn, urn, address(0), -int256(wad), 0);
        vat.slip(ilk, urn, -int256(wad));
        address voteDelegate = urnVoteDelegates[urn];
        if (voteDelegate != address(0)) {
            VoteDelegateLike(voteDelegate).free(wad);
        }
        uint256 burn = wad * fee_ / WAD;
        if (burn > 0) {
            sky.burn(address(this), burn);
        }
        unchecked { freed = wad - burn; } // burn <= wad always
    }

    // --- loan functions ---

    function draw(address owner, uint256 index, address to, uint256 wad) external {
        address urn = _getAuthedUrn(owner, index);
        uint256 rate = jug.drip(ilk);
        uint256 dart = _divup(wad * RAY, rate);
        require(dart <= uint256(type(int256).max), "LockstakeEngine/overflow");
        vat.frob(ilk, urn, address(0), address(this), 0, int256(dart));
        usdsJoin.exit(to, wad);
        emit Draw(owner, index, to, wad);
    }

    function wipe(address owner, uint256 index, uint256 wad) external {
        address urn = _getUrn(owner, index);
        usds.transferFrom(msg.sender, address(this), wad);
        usdsJoin.join(address(this), wad);
        (, uint256 rate,,,) = vat.ilks(ilk);
        uint256 dart = wad * RAY / rate;
        require(dart <= uint256(type(int256).max), "LockstakeEngine/overflow");
        vat.frob(ilk, urn, address(0), address(this), 0, -int256(dart));
        emit Wipe(owner, index, wad);
    }

    function wipeAll(address owner, uint256 index) external returns (uint256 wad) {
        address urn = _getUrn(owner, index);
        (, uint256 art) = vat.urns(ilk, urn);
        require(art <= uint256(type(int256).max), "LockstakeEngine/overflow");
        (, uint256 rate,,,) = vat.ilks(ilk);
        wad = _divup(art * rate, RAY);
        usds.transferFrom(msg.sender, address(this), wad);
        usdsJoin.join(address(this), wad);
        vat.frob(ilk, urn, address(0), address(this), 0, -int256(art));
        emit Wipe(owner, index, wad);
    }

    // --- staking rewards function ---

    function getReward(address owner, uint256 index, address farm, address to) external returns (uint256 amt) {
        address urn = _getAuthedUrn(owner, index);
        require(farms[farm] > FarmStatus.UNSUPPORTED, "LockstakeEngine/farm-unsupported");
        amt = LockstakeUrn(urn).getReward(farm, to);
        emit GetReward(owner, index, farm, to, amt);
    }

    // --- liquidation callback functions ---

    function onKick(address urn, uint256 wad) external auth {
        // Urn confiscation happens in Dog contract where ilk vat.gem is sent to the LockstakeClipper
        (uint256 ink,) = vat.urns(ilk, urn);
        uint256 inkBeforeKick = ink + wad;
        _selectVoteDelegate(urn, inkBeforeKick, urnVoteDelegates[urn], address(0));
        _selectFarm(urn, inkBeforeKick, urnFarms[urn], address(0), 0);
        lssky.burn(urn, wad);
        urnAuctions[urn]++;
        emit OnKick(urn, wad);
    }

    function onTake(address urn, address who, uint256 wad) external auth {
        sky.transfer(who, wad); // Free SKY to the auction buyer
        emit OnTake(urn, who, wad);
    }

    function onRemove(address urn, uint256 sold, uint256 left) external auth {
        uint256 burn;
        uint256 refund;
        if (left > 0) {
            uint256 fee_ = fee;
            burn = _min(sold * fee_ / (WAD - fee_), left);
            sky.burn(address(this), burn);
            unchecked { refund = left - burn; }
            if (refund > 0) {
                // The following is ensured by the dog and clip but we still prefer to be explicit
                require(refund <= uint256(type(int256).max), "LockstakeEngine/overflow");
                vat.slip(ilk, urn, int256(refund));
                vat.grab(ilk, urn, urn, address(0), int256(refund), 0);
                lssky.mint(urn, refund);
            }
        }
        urnAuctions[urn]--;
        emit OnRemove(urn, sold, burn, refund);
    }
}
