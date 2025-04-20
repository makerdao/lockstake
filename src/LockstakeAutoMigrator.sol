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

interface LockstakeMigratorLike {
    function migrate(address owner, uint256 index, address newOwner, uint256 newIndex, bytes16 ref) external;
}

contract LockstakeAutoMigrator {

    mapping (address => uint256) public wards;
    bool public done;

    LockstakeMigratorLike immutable public migrator;

    event Rely(address indexed usr);
    event Deny(address indexed usr);

    modifier auth {
        require(wards[msg.sender] == 1, "LockstakeEngine/not-authorized");
        _;
    }

    constructor(address migrator_) {
        migrator = LockstakeMigratorLike(migrator_);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    // Note - since ref is passed as 0 here, for a different ref the farm will need to be chosen after the migration
    function autoMigrate(address[] calldata owners, uint256[] calldata indexes) external auth {
        require(!done, "LockstakeAutoMigrator/already-done");
        require(owners.length == indexes.length, "LockstakeAutoMigrator/length-mismatch");

        for (uint256 i = 0; i < owners.length; i++) {
            try migrator.migrate(owners[i], indexes[i], owners[i], indexes[i], bytes16(0)) {} catch {}
        }
        done = true;
    }
}
