// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import { GemMock } from "test/mocks/GemMock.sol";

interface VatLike {
    function move(address, address, uint256) external;
}

contract UsdsJoinMock {
    VatLike public vat;
    GemMock public usds;

    constructor(address vat_, address usds_) {
        vat  = VatLike(vat_);
        usds = GemMock(usds_);
    }

    function join(address usr, uint256 wad) external {
        vat.move(address(this), usr, wad * 10**27);
        usds.burn(msg.sender, wad);
    }

    function exit(address usr, uint256 wad) external {
        vat.move(msg.sender, address(this), wad * 10**27);
        usds.mint(usr, wad);
    }
}
