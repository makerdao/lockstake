// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.21;

interface VatLike {
    function heal(uint256) external;
    function suck(address, address, uint256) external;
}

interface IVatDaiFlashBorrower {
    function onVatDaiFlashLoan(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

contract FlashMock {
    VatLike public vat;

    bytes32 public constant CALLBACK_SUCCESS_VAT_DAI = keccak256("VatDaiFlashBorrower.onVatDaiFlashLoan");

    uint256 constant RAY = 10 ** 27;

    function vatDaiFlashLoan(
        IVatDaiFlashBorrower receiver,          // address of conformant IVatDaiFlashBorrower
        uint256 amount,                         // amount to flash loan [rad]
        bytes calldata data                     // arbitrary data to pass to the receiver
    ) external returns (bool) {
        vat.suck(address(this), address(receiver), amount);

        require(
            receiver.onVatDaiFlashLoan(msg.sender, amount, 0, data) == CALLBACK_SUCCESS_VAT_DAI,
            "FlashMock/callback-failed"
        );

        vat.heal(amount);

        return true;
    }
}
