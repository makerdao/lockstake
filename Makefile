PATH := ~/.solc-select/artifacts/solc-0.5.12:~/.solc-select/artifacts/solc-0.8.21:$(PATH)
certora-urn    :; PATH=${PATH} certoraRun certora/LockstakeUrn.conf$(if $(rule), --rule $(rule),) --disable_auto_cache_key_gen
certora-lsmkr  :; PATH=${PATH} certoraRun certora/LockstakeMkr.conf$(if $(rule), --rule $(rule),) --disable_auto_cache_key_gen
certora-engine :; PATH=${PATH} certoraRun certora/LockstakeEngine.conf$(if $(rule), --rule $(rule),) --disable_auto_cache_key_gen
