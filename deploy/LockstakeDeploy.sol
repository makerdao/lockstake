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

import { ScriptTools } from "dss-test/ScriptTools.sol";
import { MCD, DssInstance } from "dss-test/MCD.sol";
import { LockstakeInstance } from "./LockstakeInstance.sol";
import { LockstakeEngine } from "src/LockstakeEngine.sol";
import { LockstakeClipper } from "src/LockstakeClipper.sol";
import { LockstakeAutoMaxLine } from "src/LockstakeAutoMaxLine.sol";

// Deploy a Lockstake instance
library LockstakeDeploy {

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function deployLockstake(
        address deployer,
        address owner,
        address delegateFactory,
        address nstJoin,
        bytes32 ilk,
        address stkMkr,
        uint256 fee,
        address mkrNgt,
        bytes4  calcSig
    ) internal returns (LockstakeInstance memory lockstakeInstance) {
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        lockstakeInstance.engine  = address(new LockstakeEngine(delegateFactory, nstJoin, ilk, stkMkr, fee, mkrNgt));
        lockstakeInstance.clipper = address(new LockstakeClipper(address(dss.vat), address(dss.spotter), address(dss.dog), lockstakeInstance.engine));
        (bool ok, bytes memory returnV) = dss.chainlog.getAddress("CALC_FAB").call(abi.encodeWithSelector(calcSig, owner));
        require(ok);
        lockstakeInstance.clipperCalc = abi.decode(returnV, (address));

        ScriptTools.switchOwner(lockstakeInstance.engine, deployer, owner);
        ScriptTools.switchOwner(lockstakeInstance.clipper, deployer, owner);
    }

    function deployAutoMaxLine(
        address deployer,
        address owner,
        bytes32 ilk,
        address dai,
        address pair,
        address pip
    ) internal returns (address autoMaxLine) {
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        autoMaxLine = address(new LockstakeAutoMaxLine(
            address(dss.vat),
            address(dss.jug),
            address(dss.spotter),
            dss.chainlog.getAddress("MCD_IAM_AUTO_LINE"),
            ilk,
            dai,
            pair,
            pip,
            dss.chainlog.getAddress("MCD_PAUSE_PROXY")
        ));

        ScriptTools.switchOwner(autoMaxLine, deployer, owner);
    }
}
