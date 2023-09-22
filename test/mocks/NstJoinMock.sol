// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import { GemMock } from "test/mocks/GemMock.sol";

interface VatLike {
    function move(address, address, uint256) external;
}

contract NstJoinMock {
    VatLike public vat;
    GemMock public nst;

    constructor(address vat_, address nst_) {
        vat = VatLike(vat_);
        nst = GemMock(nst_);
    }

    function join(address usr, uint256 wad) external {
        vat.move(address(this), usr, wad * 10**27);
        nst.burn(msg.sender, wad);
    }

    function exit(address usr, uint256 wad) external {
        vat.move(msg.sender, address(this), wad * 10**27);
        nst.mint(usr, wad);
    }
}
