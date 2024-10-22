// SPDX-License-Identifier: AGPL-3.0-or-later

// taken from: ./LockstakeClipper.t.sol

pragma solidity ^0.8.21;

import { LockstakeClipper } from "src/LockstakeClipper.sol";

contract BadGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(address sender, uint256 owe, uint256 slice, bytes calldata data)
        external {
        sender; owe; slice; data;
        clip.take({ // attempt reentrancy
            id: 1,
            amt: 25 ether,
            max: 5 ether * 10E27,
            who: address(this),
            data: ""
        });
    }
}

contract RedoGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        owe; slice; data;
        clip.redo(1, sender);
    }
}

contract KickGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        sender; owe; slice; data;
        clip.kick(1, 1, address(0), address(0));
    }
}

contract FileUintGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        sender; owe; slice; data;
        clip.file("stopped", 1);
    }
}

contract FileAddrGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        sender; owe; slice; data;
        clip.file("vow", address(123));
    }
}

contract YankGuy {
    LockstakeClipper clip;

    constructor(LockstakeClipper clip_) {
        clip = clip_;
    }

    function clipperCall(
        address sender, uint256 owe, uint256 slice, bytes calldata data
    ) external {
        sender; owe; slice; data;
        clip.yank(1);
    }
}
