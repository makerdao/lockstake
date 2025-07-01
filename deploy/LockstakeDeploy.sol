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

import { ScriptTools } from "dss-test/ScriptTools.sol";
import { MCD, DssInstance } from "dss-test/MCD.sol";
import { LockstakeInstance } from "./LockstakeInstance.sol";
import { LockstakeSky } from "src/LockstakeSky.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { LockstakeMigrator } from "src/LockstakeMigrator.sol";

// Deploy a Lockstake instance
library LockstakeDeploy {

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function deployLockstake(
        address deployer,
        address owner,
        address voteDelegateFactory, // new address won't be in chainlog at deploy time
        bytes32 ilk,
        uint256 fee,
        bytes4  calcSig,
        address mkrSky // new address won't be in chainlog at deploy time
    ) internal returns (LockstakeInstance memory lockstakeInstance) {
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        lockstakeInstance.lssky   = address(new LockstakeSky());
        lockstakeInstance.engine  = address(new LockstakeEngine(
                                                    voteDelegateFactory,
                                                    dss.chainlog.getAddress("USDS_JOIN"),
                                                    ilk,
                                                    dss.chainlog.getAddress("SKY"),
                                                    lockstakeInstance.lssky,
                                                    fee
                                            ));
        lockstakeInstance.clipper = address(new LockstakeClipper(
                                                    address(dss.vat),
                                                    address(dss.spotter),
                                                    address(dss.dog),
                                                    lockstakeInstance.engine
                                            ));
        (bool ok, bytes memory returnV) = dss.chainlog.getAddress("CALC_FAB").call(abi.encodeWithSelector(calcSig, owner));
        require(ok);
        lockstakeInstance.clipperCalc = abi.decode(returnV, (address));
        lockstakeInstance.migrator = address(new LockstakeMigrator(
                                                    dss.chainlog.getAddress("LOCKSTAKE_ENGINE"),
                                                    lockstakeInstance.engine,
                                                    mkrSky,
                                                    dss.chainlog.getAddress("MCD_FLASH")
                                            ));

        ScriptTools.switchOwner(lockstakeInstance.lssky, deployer, owner);
        ScriptTools.switchOwner(lockstakeInstance.engine, deployer, owner);
        ScriptTools.switchOwner(lockstakeInstance.clipper, deployer, owner);
    }

    function deployClipper(
        address deployer,
        address owner
    ) internal returns (address clipper) {
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        clipper = address(new LockstakeClipper(
                            address(dss.vat),
                            address(dss.spotter),
                            address(dss.dog),
                            dss.chainlog.getAddress("LOCKSTAKE_ENGINE")
                        ));

        ScriptTools.switchOwner(clipper, deployer, owner);
    }
}
