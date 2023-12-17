# Saggitarius Lockstake Engine

A technical description of the components of the Saggitarius LockStake Engine (SLE).


## 1. LockstakeEngine

## 2. NGT wrapper

## 3. LockStake Clipper

## 4. Keepers Support

## 5. Splitter

The Splitter contract is in charge of distributing the Surplus Buffer funds on each `vow.flap` to the Smart Burn Engine (SBE) and the SLE farm. The total amount sent each time is `vow.bump`.

To accomplish this, it exposes a `kick` operation to be triggered periodically. Its logic withdraws DAI from the `vow` and splits it in two parts. The first part (`burn`) is sent to the underlying `flapper` contract to be processed by the SBE. The second part (`WAD - burn`) is distributed as reward to a `farm` contract. Note that`burn == 1 WAD` indicates funneling 100% of the DAI to the SBE without sending any rewards to the farm.

When sending DAI to the farm, the splitter also calls `farm.notifyRewardAmount` to update the farm contract on the new rewards distribution. This resets the farming distribution period to the governance configured duration and sets the rewards rate according to the sent reward amount and rewards leftovers from the previous distribution (in case there are any).

The Splitter relies on the SBE for rate-limiting, so each distribution will only succeed if the call to `flapper.kick` does not revert. In other words, the `splitter.kick` cadence is determined by `flapper.hop`.

**Configurable Parameters:**
* `flapper` - The underlying burner strategy (e.g. the address of `FlapperUniV2SwapOnly`).
* `burn` - The percentage of the `vow.bump` to be moved to the underlying `flapper`. For example, a value of 0.70 \* `WAD` corresponds to a funneling 70% of the DAI to the burn engine.

Up to date for: https://github.com/makerdao/dss-flappers/commit/6f73645f020ed9bf82733b1de595537c137d719b


## 6. StakingRewards

The SLE uses a Maker modified [version](https://github.com/telome/endgame-toolkit/blob/2d3aa2af6d736ad312f818ba826bf85c5db4d17c/README.md#farms) of the Synthetix Staking Reward as the farm for distributing NST to stakers.

For compatibility with the SBE, the assumption is that the duration of each farming distribution (`farm.duration`) is similar to the flapper's cooldown period (`flap.hop`). This in practice divides the overall farming reward distribution to a set of smaller non overlapping distributions. It also allows for periods where there is no distribution at all.

The StakingRewards contract `setDuration` function was modified to enable governance to change the farming distribution duration even if the previous distribution was not done. This now supports changing it simultaneously with the SBE cooldown period (through a governance spell).

**Configurable Parameters:**
* `rewardsDistribution` - The address which is allowed to start a rewards distribution. Will be set to the splitter.
* `rewardsDuration` - The amount of seconds each distribution should take.

Up to date for: https://github.com/telome/endgame-toolkit/commit/2d3aa2af6d736ad312f818ba826bf85c5db4d17c

## 7. Flappers
### 7.a. FlapperUniV2

Exposes a `kick` operation to be triggered periodically. Its logic withdraws DAI from the `vow` and buys `gem` tokens on Uniswap v2. The acquired tokens, along with a proportional amount of DAI (saved from the initial withdrawal) are deposited back into the liquidity pool. Finally, the minted LP tokens are sent to a predefined `receiver` address.

Note that as opposed to the first version of FlapperUniV2, the SLE aligned version was changed so that the `lot` parameter it receives on `kick` indicates the total amount the flapper should consume (and not just the amount to sell).

The calculations of how much DAI to sell out of `lot` so that the exact proportion of deposit amount remains afterwards can be seen in the code [comments](https://github.com/makerdao/dss-flappers/blob/78f2ec664ba5ad6de45195ff6fdd68771145a56a/src/FlapperUniV2.sol#L150).

**Configurable Parameters:**
* `hop` - Minimum seconds interval between kicks.
* `pip` - A reference price oracle, used for bounding the exchange rate of the swap.
* `want` - Relative multiplier of the reference price to insist on in the swap. For example, a value of 0.98 * `WAD` allows for a 2% worse price than the reference.

Up to date for: https://github.com/makerdao/dss-flappers/commit/78f2ec664ba5ad6de45195ff6fdd68771145a56a

### 7.b. FlapperUniV2SwapOnly

Exposes a `kick` operation to be triggered periodically. Its logic withdraws DAI from the `vow` and buys `gem` tokens on Uniswap v2. The acquired tokens are sent to a predefined `receiver` address.

**Configurable Parameters:**
* `hop` - Minimum seconds interval between kicks.
* `pip` - A reference price oracle, used for bounding the exchange rate of the swap.
* `want` - Relative multiplier of the reference price to insist on in the swap. For example, a value of 0.98 * `WAD` allows for a 2% worse price than the reference.

Up to date for: https://github.com/makerdao/dss-flappers/commit/78f2ec664ba5ad6de45195ff6fdd68771145a56a

## 8. Sticky Oracle
### 8.a StickyOracle 

The MKR oracle for the SLE vaults has sticky upwards price movement. It works by operating both on a market price measured from the MKR underlying oracle, and a Sticky Price. The Sticky Price is what is actually used for calculating Liquidation Ratio and Soft Liquidation Ratio.

Whenever the real price is below the Sticky Price, the Sticky Price instantly adjusts down to be equal to the real price.

When the real price is above the Sticky Price, the Sticky Price adjusts upwards at a throttled rate (for example, a rate of at most 5% per month).

To achieve this behaviour the Sticky oracle always returns the minimum of the underlying oracle (`pip.read()`) and a `cap` storage variable.

The `cap` is calculated daily upon permissionless `poke` operations. To calculate it, a TWAP window of a configurable amount of days is used. The TWAP itself is calculated from the daily samples of `cap`. Every time a new `cap` is calculated it cannot grow more than the product of the TWAP calculation and a `slope` parameter (configured to only allow the desired growth rate).

In case a `poke` operation was not done on the current day, or in case a previous sample is missing for the TWAP calculation, the existing `cap` will be used.

An `init` function is provided for governance to artificially set the `cap` samples of a certain amount of days in the past. This can enhance the current `cap` calculation, as previous samples will not be missing.

**Configurable Parameters:**

`buds` - Whitelisted oracle readers.
`slope` - Maximum allowable price growth factor from center of TWAP window to now (in `RAY` such that `slope = (1 + {max growth rate}) * RAY`).
`lo` - How many days ago should the TWAP window start (exclusive), should be more than `hi`.
`hi` - How many days ago should the TWAP window end (inclusive), should be less than `lo` and more than 0.

Up to date for: https://github.com/makerdao/lockstake/commit/1ed6d987b3ed4bdfa378f3f35f18a01a064a2a43

### 8.b Cron Keeper Job

For performing `poke` on the Sticky Oracle a simple keeper job contract will be added. Since the `poke` will revert if it was already performed on that certain day, the job can return a     workable status whenever it does not revert.

Implementation - **TODO**

## 9. Debt Ceiling Instant Access Module
### 9.a DC-IAM-SETTER

The Debt Ceiling of SLE vaults is determined based on the surplus and reserves owned by the Maker Protocol. The total value of the debt ceiling is adjusted automatically through an algorithm.

For the first version (before the SubDaos launch) this contract permissionlessly sets the max debt ceiling of the autoline to:
`100% * the Surplus Buffer + 80% * protocol DAI deposited in Uniswap`

Note that the above amount of uniswap held DAI is equivalent to 40% of Elixir value.

The Surplus Buffer amount of DAI can be fetched easily (`vat.dai(vow) - vat.sin(vow)`). However, the Uniswap owned DAI calculation needs to be resistent to manipulation. For that we can use the [fair token prices](https://github.com/Uniswap/v2-periphery/blob/0335e8f7e1bd1e8d8329fd300aea2ef2f36dd19f/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L116) (which requires reading the MKR oracle).

Implementation - **TODO**

### 9.b Cron Keeper Job

For triggering the DC-IAM-SETTER a keeper job contract will be added. It should hold sensitivity thresholds, similarly to how the current autoline job [does](https://github.com/makerdao/dss-cron/blob/ae1300023b5db04851b1e8f926e5b7a59ffd18b0/src/AutoLineJob.sol#L47).

Implementation - **TODO**

## 10. Stability Rate Setter
### 10.a STABILITY-RATE-SETTER

Under normal circumstances the Stability Fee of the SLE vaults is equal to the Base Rate. However, when the max debt ceiling is exceeded there needs to be a mechanism for incentivizing wind down.

To achieve this, the STABILITY-RATE-SETTER will increase the stability fee when such a situation takes place, and will allow returning to the base rate once the max debt ceiling has again been reach.

Implementation - **TODO**

### 10.b Cron Keeper Job

For triggering the STABILITY-RATE-SETTER a keeper job contract will be added. It should hold sensitivity thresholds, similarly to how the current autoline job [does](https://github.com/makerdao/dss-cron/blob/ae1300023b5db04851b1e8f926e5b7a59ffd18b0/src/AutoLineJob.sol#L47).

Implementation - **TODO**

## 11. Deployment Scripts

Implementation - **TODO**

## 12. Formal Verification

Implementation - **TODO**
    
## General Notes
* In many of the modules, such as the splitter and the flappers, NGT can replace DAI. This will usually require a deployment of the contract with NstJoin as a replacement of the DaiJoin address.
* The SLE assumes that the ESM threshold is set large enough prior to its deployment, so Emergency Shutdown can never be called.



