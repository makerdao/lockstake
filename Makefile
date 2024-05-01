PATH := ~/.solc-select/artifacts/solc-0.8.21:$(PATH)
certora-urn :; PATH=${PATH} certoraRun certora/LockstakeUrn.conf$(if $(rule), --rule $(rule),) --disable_auto_cache_key_gen
