// SPDX-FileCopyrightText: © 2021 Dai Foundation <www.daifoundation.org>
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

interface VatLike {
    function suck(address, address, uint256) external;
    function move(address, address, uint256) external;
    function flux(bytes32, address, address, uint256) external;
    function slip(bytes32, address, int256) external;
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface PipLike {
    function peek() external returns (bytes32, bool);
}

interface SpotterLike {
    function par() external returns (uint256);
    function ilks(bytes32) external returns (PipLike, uint256);
}

interface DogLike {
    function chop(bytes32) external returns (uint256);
    function digs(bytes32, uint256) external;
}

interface ClipperCallee {
    function clipperCall(address, uint256, uint256, bytes calldata) external;
}

interface AbacusLike {
    function price(uint256, uint256) external view returns (uint256);
}

interface CutteeLike {
    function cut(uint256) external;
    function drip() external;
}

interface LockstakeEngineLike {
    function ilk() external view returns (bytes32);
    function onKick(address, uint256) external;
    function onTake(address, address, uint256) external;
    function onRemove(address, uint256, uint256) external;
}

// Clipper for use with the Lockstake Engine
contract LockstakeClipper {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth {
        require(wards[msg.sender] == 1, "LockstakeClipper/not-authorized");
        _;
    }

    // --- Data ---
    bytes32             immutable public ilk;    // Collateral type of this LockstakeClipper
    VatLike             immutable public vat;    // Core CDP Engine
    LockstakeEngineLike immutable public engine; // Lockstake Engine

    DogLike     public dog;      // Liquidation module
    address     public vow;      // Recipient of dai raised in auctions
    SpotterLike public spotter;  // Collateral price module
    AbacusLike  public calc;     // Current price calculator
    address     public cuttee;   // Contract for accounting bad debt (if not set, callback won't be executed)

    uint256 public buf;    // Multiplicative factor to increase starting price                  [ray]
    uint256 public tail;   // Time elapsed before auction reset                                 [seconds]
    uint256 public cusp;   // Percentage drop before auction reset                              [ray]
    uint64  public chip;   // Percentage of tab to suck from vow to incentivize keepers         [wad]
    uint192 public tip;    // Flat fee to suck from vow to incentivize keepers                  [rad]
    uint256 public chost;  // Cache the ilk dust times the ilk chop to prevent excessive SLOADs [rad]

    uint256   public kicks;   // Total auctions
    uint256[] public active;  // Array of active auction ids
    uint256   public Due;     // Total due amount from active auctions

    struct Sale {
        uint256 pos;  // Index in active array
        uint256 tab;  // Usds to raise      [rad]
        uint256 due;  // Usds debt          [rad]
        uint256 lot;  // collateral to sell [wad]
        uint256 tot;  // static registry of total collateral to sell [wad]
        address usr;  // Liquidated CDP
        uint96  tic;  // Auction start time
        uint256 top;  // Starting price     [ray]
    }
    mapping(uint256 => Sale) public sales;

    uint256 internal locked;

    // Levels for circuit breaker
    // 0: no breaker
    // 1: no new kick()
    // 2: no new kick() or redo()
    // 3: no new kick(), redo(), or take()
    uint256 public stopped = 0;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);

    event Kick(
        uint256 indexed id,
        uint256 top,
        uint256 tab,
        uint256 lot,
        address indexed usr,
        address indexed kpr,
        uint256 coin
    );
    event Take(
        uint256 indexed id,
        uint256 max,
        uint256 price,
        uint256 owe,
        uint256 tab,
        uint256 lot,
        address indexed usr
    );
    event Redo(
        uint256 indexed id,
        uint256 top,
        uint256 tab,
        uint256 lot,
        address indexed usr,
        address indexed kpr,
        uint256 coin
    );

    event Yank(uint256 id);

    // --- Init ---
    constructor(address vat_, address spotter_, address dog_, address engine_) {
        vat       = VatLike(vat_);
        spotter   = SpotterLike(spotter_);
        dog       = DogLike(dog_);
        engine    = LockstakeEngineLike(engine_);
        ilk       = engine.ilk();
        buf       = RAY;
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Synchronization ---
    modifier lock {
        require(locked == 0, "LockstakeClipper/system-locked");
        locked = 1;
        _;
        locked = 0;
    }

    modifier isStopped(uint256 level) {
        require(stopped < level, "LockstakeClipper/stopped-incorrect");
        _;
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth lock {
        if      (what == "buf")         buf = data;
        else if (what == "tail")       tail = data;           // Time elapsed before auction reset
        else if (what == "cusp")       cusp = data;           // Percentage drop before auction reset
        else if (what == "chip")       chip = uint64(data);   // Percentage of tab to incentivize (max: 2^64 - 1 => 18.xxx WAD = 18xx%)
        else if (what == "tip")         tip = uint192(data);  // Flat fee to incentivize keepers (max: 2^192 - 1 => 6.277T RAD)
        else if (what == "stopped") stopped = data;           // Set breaker (0, 1, 2, or 3)
        else revert("LockstakeClipper/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 what, address data) external auth lock {
        if (what == "spotter") spotter = SpotterLike(data);
        else if (what == "dog")       dog = DogLike(data);
        else if (what == "vow")       vow = data;
        else if (what == "calc")     calc = AbacusLike(data);
        else if (what == "cuttee") cuttee = data;
        else revert("LockstakeClipper/file-unrecognized-param");
        emit File(what, data);
    }

    // --- Math ---
    uint256 constant BLN = 10 **  9;
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }
    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y / WAD;
    }
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y / RAY;
    }
    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * RAY / y;
    }

    // --- Auction ---

    // get the price directly from the pip
    // Could get this from rmul(Vat.ilks(ilk).spot, Spotter.mat()) instead, but
    // if mat has changed since the last poke, the resulting value will be
    // incorrect.
    function getFeedPrice() internal returns (uint256 feedPrice) {
        (PipLike pip, ) = spotter.ilks(ilk);
        (bytes32 val, bool has) = pip.peek();
        require(has, "LockstakeClipper/invalid-price");
        feedPrice = rdiv(uint256(val) * BLN, spotter.par());
    }

    // start an auction
    // note: trusts the caller to transfer collateral to the contract
    // The starting price `top` is obtained as follows:
    //
    //     top = val * buf / par
    //
    // Where `val` is the collateral's unitary value in USD, `buf` is a
    // multiplicative factor to increase the starting price, and `par` is a
    // reference per DAI.
    function kick(
        uint256 tab,  // Debt                   [rad]
        uint256 lot,  // Collateral             [wad]
        address usr,  // Address that will receive any leftover collateral; additionally assumed here to be the liquidated Vault.
        address kpr   // Address that will receive incentives
    ) external auth lock isStopped(1) returns (uint256 id) {
        // Input validation
        require(tab  >                         0, "LockstakeClipper/zero-tab");
        require(lot  >                         0, "LockstakeClipper/zero-lot");
        require(lot <= uint256(type(int256).max), "LockstakeClipper/over-maxint-lot"); // This is ensured by the dog but we still prefer to be explicit
        require(usr !=                address(0), "LockstakeClipper/zero-usr");
        unchecked { id = ++kicks; }
        require(id   >                         0, "LockstakeClipper/overflow");

        active.push(id);

        sales[id].pos = active.length - 1;

        sales[id].tab = tab;
        Due += sales[id].due = tab * WAD / dog.chop(ilk); // Under approximation is not a problem for this
        sales[id].lot = lot;
        sales[id].tot = lot;
        sales[id].usr = usr;
        sales[id].tic = uint96(block.timestamp);

        uint256 top;
        top = rmul(getFeedPrice(), buf);
        require(top > 0, "LockstakeClipper/zero-top-price");
        sales[id].top = top;

        // incentive to kick auction
        uint256 _tip  = tip;
        uint256 _chip = chip;
        uint256 coin;
        if (_tip > 0 || _chip > 0) {
            coin = _tip + wmul(tab, _chip);
            vat.suck(vow, kpr, coin);
        }

        // Trigger engine liquidation call-back
        engine.onKick(usr, lot);
        // Trigger cuttee accounting (will update line accordingly)
        if (cuttee != address(0)) { CutteeLike(cuttee).drip(); }

        emit Kick(id, top, tab, lot, usr, kpr, coin);
    }

    // Reset an auction
    // See `kick` above for an explanation of the computation of `top`.
    function redo(
        uint256 id,  // id of the auction to reset
        address kpr  // Address that will receive incentives
    ) external lock isStopped(2) {
        // Read auction data
        address usr = sales[id].usr;
        uint96  tic = sales[id].tic;
        uint256 top = sales[id].top;

        require(usr != address(0), "LockstakeClipper/not-running-auction");

        // Check that auction needs reset
        // and compute current price [ray]
        (bool done,) = status(tic, top);
        require(done, "LockstakeClipper/cannot-reset");

        uint256 tab   = sales[id].tab;
        uint256 lot   = sales[id].lot;
        sales[id].tic = uint96(block.timestamp);

        uint256 feedPrice = getFeedPrice();
        top = rmul(feedPrice, buf);
        require(top > 0, "LockstakeClipper/zero-top-price");
        sales[id].top = top;

        // incentive to redo auction
        uint256 _tip  = tip;
        uint256 _chip = chip;
        uint256 coin;
        if (_tip > 0 || _chip > 0) {
            uint256 _chost = chost;
            if (tab >= _chost && lot * feedPrice >= _chost) {
                coin = _tip + wmul(tab, _chip);
                vat.suck(vow, kpr, coin);
            }
        }

        emit Redo(id, top, tab, lot, usr, kpr, coin);
    }

    // Buy up to `amt` of collateral from the auction indexed by `id`.
    // 
    // Auctions will not collect more DAI than their assigned DAI target,`tab`;
    // thus, if `amt` would cost more DAI than `tab` at the current price, the
    // amount of collateral purchased will instead be just enough to collect `tab` DAI.
    //
    // To avoid partial purchases resulting in very small leftover auctions that will
    // never be cleared, any partial purchase must leave at least `LockstakeClipper.chost`
    // remaining DAI target. `chost` is an asynchronously updated value equal to
    // (Vat.dust * Dog.chop(ilk) / WAD) where the values are understood to be determined
    // by whatever they were when LockstakeClipper.upchost() was last called. Purchase amounts
    // will be minimally decreased when necessary to respect this limit; i.e., if the
    // specified `amt` would leave `tab < chost` but `tab > 0`, the amount actually
    // purchased will be such that `tab == chost`.
    //
    // If `tab <= chost`, partial purchases are no longer possible; that is, the remaining
    // collateral can only be purchased entirely, or not at all.
    function take(
        uint256 id,           // Auction id
        uint256 amt,          // Upper limit on amount of collateral to buy  [wad]
        uint256 max,          // Maximum acceptable price (DAI / collateral) [ray]
        address who,          // Receiver of collateral and external call address
        bytes calldata data   // Data to pass in external call; if length 0, no call is done
    ) external lock isStopped(3) {

        Sale memory sale;
        sale.usr = sales[id].usr;
        sale.tic = sales[id].tic;

        require(sale.usr != address(0), "LockstakeClipper/not-running-auction");

        uint256 price;
        {
            bool done;
            (done, price) = status(sale.tic, sales[id].top);

            // Check that auction doesn't need reset
            require(!done, "LockstakeClipper/needs-reset");
        }

        // Ensure price is acceptable to buyer
        require(max >= price, "LockstakeClipper/too-expensive");

        sale.lot = sales[id].lot;
        sale.tab = sales[id].tab;
        uint256 owe;

        {
            // Purchase as much as possible, up to amt
            uint256 slice = min(sale.lot, amt);  // slice <= sale.lot

            // DAI needed to buy a slice of this sale
            owe = slice * price;

            // Don't collect more than tab of DAI
            if (owe > sale.tab) {
                // Total debt will be paid
                owe = sale.tab;                  // owe' <= owe
                // Adjust slice
                slice = owe / price;             // slice' = owe' / price <= owe / price == slice <= lot
            } else if (owe < sale.tab && slice < sale.lot) {
                // If slice == lot => auction completed => dust doesn't matter
                uint256 _chost = chost;
                if (sale.tab - owe < _chost) {   // safe as owe < tab
                    // If tab <= chost, buyers have to take the entire lot.
                    require(sale.tab > _chost, "LockstakeClipper/no-partial-purchase");
                    // Adjust amount to pay
                    owe = sale.tab - _chost;     // owe' <= owe
                    // Adjust slice
                    slice = owe / price;         // slice' = owe' / price < owe / price == slice < lot
                }
            }

            // Calculate remaining tab after operation
            sale.tab = sale.tab - owe;  // safe since owe <= tab
            // Calculate remaining lot after operation
            sale.lot = sale.lot - slice;

            // Send collateral to who
            vat.slip(ilk, address(this), -int256(slice));
            engine.onTake(sale.usr, who, slice);

            // Do external call (if data is defined) but to be
            // extremely careful we don't allow to do it to the four
            // contracts which the LockstakeClipper needs to be authorized
            DogLike dog_ = dog;
            if (
                data.length > 0 &&
                who != address(vat) &&
                who != address(dog_) &&
                who != address(engine) &&
                (who != cuttee || cuttee == address(0)) // Keep consistency executing with address(0) to revert
            ) {
                ClipperCallee(who).clipperCall(msg.sender, owe, slice, data);
            }

            // Get DAI from caller
            vat.move(msg.sender, vow, owe);

            // Removes Dai out for liquidation from accumulator
            dog_.digs(ilk, sale.lot == 0 ? sale.tab + owe : owe);
        }

        if (sale.lot == 0) {
            engine.onRemove(sale.usr, sales[id].tot, 0);
            uint256 due = sales[id].due;
            Due -= due;
            if (due > owe && cuttee != address(0)) {
                CutteeLike(cuttee).cut(due - owe);
            }
            _remove(id);
        } else if (sale.tab == 0) {
            vat.slip(ilk, address(this), -int256(sale.lot));
            engine.onRemove(sale.usr, sales[id].tot - sale.lot, sale.lot);
            Due -= sales[id].due;
            _remove(id);
        } else {
            sales[id].tab = sale.tab;
            sales[id].lot = sale.lot;
            uint256 sub = min(sales[id].due, owe);
            sales[id].due -= sub;
            Due -= sub;
        }

        // Note: In any case but the cut scenario, the line won't be updated accordingly, leaving a lower number than it should be (Due decrement is not accounted for).
        // This can be updated with a permissionless call to cuttee.drip and not penalize every take with the extra gas cost.

        emit Take(id, max, price, owe, sale.tab, sale.lot, sale.usr);
    }

    function _remove(uint256 id) internal {
        uint256 _move    = active[active.length - 1];
        if (id != _move) {
            uint256 _index   = sales[id].pos;
            active[_index]   = _move;
            sales[_move].pos = _index;
        }
        active.pop();
        delete sales[id];
    }

    // The number of active auctions
    function count() external view returns (uint256) {
        return active.length;
    }

    // Return the entire array of active auctions
    function list() external view returns (uint256[] memory) {
        return active;
    }

    // Externally returns boolean for if an auction needs a redo and also the current price
    function getStatus(uint256 id) external view returns (bool needsRedo, uint256 price, uint256 lot, uint256 tab) {
        // Read auction data
        address usr = sales[id].usr;
        uint96  tic = sales[id].tic;

        bool done;
        (done, price) = status(tic, sales[id].top);

        needsRedo = usr != address(0) && done;
        lot = sales[id].lot;
        tab = sales[id].tab;
    }

    // Internally returns boolean for if an auction needs a redo
    function status(uint96 tic, uint256 top) internal view returns (bool done, uint256 price) {
        price = calc.price(top, block.timestamp - tic);
        done  = (block.timestamp - tic > tail || rdiv(price, top) < cusp);
    }

    // Public function to update the cached dust*chop value.
    function upchost() external {
        (,,,, uint256 _dust) = VatLike(vat).ilks(ilk);
        chost = wmul(_dust, dog.chop(ilk));
    }

    // Cancel an auction during End.cage or via other governance action.
    // It is up to governance to define if cuttee.cut(sales[id].due) and cuttee.drip() needs to be called whenever yank is executed
    function yank(uint256 id) external auth lock {
        require(sales[id].usr != address(0), "LockstakeClipper/not-running-auction");
        dog.digs(ilk, sales[id].tab);
        uint256 lot = sales[id].lot;
        vat.flux(ilk, address(this), msg.sender, lot);
        engine.onRemove(sales[id].usr, 0, 0);
        Due -= sales[id].due;
        _remove(id);
        emit Yank(id);
    }
}
