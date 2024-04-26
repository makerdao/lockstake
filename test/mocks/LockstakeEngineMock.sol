// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

interface VatLike {
    function slip(bytes32, address, int256) external;
}

contract LockstakeEngineMock {
    VatLike immutable public vat;
    bytes32 immutable public ilk;

    constructor(address vat_, bytes32 ilk_) {
        vat = VatLike(vat_);
        ilk = ilk_;
    }

    function onKick(address, uint256) external {
    }

    function onTake(address, address who, uint256 wad) external {
        VatLike(vat).slip(ilk, who, int256(wad));
    }

    function onRemove(address urn, uint256, uint256 left) external {
        VatLike(vat).slip(ilk, urn, int256(left));
    }
}
