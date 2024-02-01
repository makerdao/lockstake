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

interface VatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface JugLike {
    function ilks(bytes32) external view returns (uint256, uint256);
    function drip(bytes32) external returns (uint256);
    function file(bytes32, bytes32, uint256) external;
}

interface AutoLineLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint48, uint48, uint48);
    function setIlk(bytes32, uint256, uint256, uint256) view external;
}

contract LockstakeAutoMaxLine {

    mapping(address => uint256) public wards;
    JugLike                     public jug;
    AutoLineLike                public autoLine;
    uint256                     public duty;         // [ray]
    uint256                     public windDownDuty; // [ray]

    VatLike public immutable vat;
    bytes32 public immutable ilk;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, address data);
    event File(bytes32 indexed what, uint256 data);
    event Exec(uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty);

    constructor(address vat_, bytes32 ilk_) {
        vat = VatLike(vat_);
        ilk = ilk_;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    modifier auth {
        require(wards[msg.sender] == 1, "LockstakeAutoMaxLine/not-authorized");
        _;
    }

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function file(bytes32 what, address data) external auth {
        if      (what == "jug")           jug = JugLike(data);
        else if (what == "autoLine") autoLine = AutoLineLike(data);
        else revert("LockstakeAutoMaxLine/file-unrecognized-param");
        emit File(what, data);
    }

    function file(bytes32 what, uint256 data) external auth {
        if      (what == "duty")                  duty = data;
        else if (what == "windDownDuty") windDownDuty = data;
        else revert("LockstakeAutoMaxLine/file-unrecognized-param");
        emit File(what, data);
    }

    function exec() external returns (uint256 oldMaxLine, uint256 newMaxLine, uint256 debt, uint256 oldDuty, uint256 newDuty) {
        uint256 gap;
        uint48 ttl;
        (oldMaxLine, gap, ttl,,) = autoLine.ilks(ilk);
        require(oldMaxLine !=0 && gap != 0 && ttl != 0, "LockstakeAutoMaxLine/auto-line-not-enabled");

        newMaxLine = 0; // TODO: calculate
        if (newMaxLine != oldMaxLine) {
            autoLine.setIlk(ilk, newMaxLine, uint256(gap), uint256(ttl));
        }

        uint256 duty_         = duty;
        uint256 windDownDuty_ = windDownDuty;
        require(duty_ !=0 && windDownDuty_ != 0, "LockstakeAutoMaxLine/ilk-not-enabled");

        (uint256 Art, uint256 rate,,,) = vat.ilks(ilk);
        debt = Art * rate;

        (oldDuty,)= jug.ilks(ilk);
        newDuty = (debt > newMaxLine) ? windDownDuty_ : duty_;
        if (newDuty != oldDuty) {
            jug.drip(ilk);
            jug.file(ilk, "duty", newDuty);
        }

        emit Exec(oldMaxLine, newMaxLine, debt, oldDuty, newDuty);
        return (oldMaxLine, newMaxLine, debt, oldDuty, newDuty);
    }
}

