# Saggitarius LockStake Engine

## 1. LockStake Engine

## 2. NGT wrapper

## 3. LockStake Clipper

## 4. Keepers Support

## 5. Splitter

The Splitter contract is in charge of distributing the Surplus Buffer funds on each `vow.flap` to the Smart Burn Engine (SBE) and the Lockstake Engine (LSE) farm. The total amount sent each time is `vow.bump`.

Governance should configure the `burn` variable which states what proportion of the `vow.bump` to send to the SBE, while the remaining amount is sent for farming (`burn == 1 WAD` indicates 100% burn).

When sending NST to the farm, the splitter also calls `notifyRewardAmount` to update the farm contract on the new rewards distribution.

The Splitter relies on the SBE for rate-limitting, so each distribution will only succeed if the call to `flapper.kick` does not revert.

Up to date for: https://github.com/makerdao/dss-flappers/commit/6f73645f020ed9bf82733b1de595537c137d719b


## 6. StakingRewards

The LSE uses a Maker modified [version](https://github.com/telome/endgame-toolkit/blob/2d3aa2af6d736ad312f818ba826bf85c5db4d17c/README.md#farms) of the Synthetix Staking Reward as the farm for distributing NST to stakers.

For compatibility with the SBE, the assumption is that the duration of each farming distribution (`farm.duration`) is similar to the flapper's cooldown period (`flap.hop`). This in practice divides the overall farming reward distribution to a set of smaller non overlapping distributions.

The StakingRewards contract `setDuration` function was modified to enable governance to change the farming disribution duration even if the previous distribution was not done. This now supports changing it simultaneously with the SBE cooldown period (through a governance spell).

Up to date for: https://github.com/telome/endgame-toolkit/commit/2d3aa2af6d736ad312f818ba826bf85c5db4d17c

## 7. Flappers
### 7.a. FlapperUniV2
### 7.b. FlapperUniV2SwapOnly

## 8. Sticky Oracle
### 8. StickyOracle 
### 8. Cron Job

## 9. Debt Ceiling Instant Access Module

## 10. Stability Rate Setter

## 11. Deployment Scripts

## 12. Formal Verification
    
### TODO:
- ES disclaimer
- LSE or SLSE or SLE? :)



