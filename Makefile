PATH := ~/.solc-select/artifacts/solc-0.5.12:~/.solc-select/artifacts/solc-0.6.12:~/.solc-select/artifacts/solc-0.8.21:$(PATH)
certora-urn                :; PATH=${PATH} certoraRun certora/LockstakeUrn.conf$(if $(rule), --rule $(rule),)
certora-lsmkr              :; PATH=${PATH} certoraRun certora/LockstakeMkr.conf$(if $(rule), --rule $(rule),)
certora-engine             :; PATH=${PATH} certoraRun certora/LockstakeEngine.conf$(if $(rule), --rule $(rule),) --exclude_rule wipe_revert
certora-engine-wipe-revert :; PATH=${PATH} certoraRun certora/LockstakeEngine.conf --rule wipe_revert --prover_args "-rewriteMSizeAllocations true -depth 0"
certora-engine-multicall   :; PATH=${PATH} certoraRun certora/LockstakeEngineMulticall.conf$(if $(rule), --rule $(rule),)
certora-clipper            :; PATH=${PATH} certoraRun certora/LockstakeClipper.conf$(if $(rule), --rule $(rule),)
