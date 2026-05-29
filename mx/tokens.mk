# Test-token workflows.
#
# These targets create Stellar classic assets and deploy their Stellar Asset
# Contracts (SACs). Use 7-decimal amounts for SO4.market math:
#   1 TWBTC = 10000000

CODE ?= TWBTC
ISSUER ?= $(CODE)-issuer
TO ?= $(SOURCE)
AMOUNT ?= 1000000000

.PHONY: token-issuer token-deploy token-id token-trust token-mint token-balance token-bootstrap tokens

token-issuer: preflight
	@if ! stellar keys address "$(ISSUER)" >/dev/null 2>&1; then \
		stellar keys generate --global "$(ISSUER)" --network "$(NETWORK)"; \
	fi
	@if [ "$(NETWORK)" = "testnet" ]; then stellar keys fund "$(ISSUER)" --network "$(NETWORK)" >/dev/null; fi
	@stellar keys address "$(ISSUER)"

token-deploy: preflight token-issuer
	@mkdir -p "$(DEPLOY_DIR)"
	issuer_addr="$$(stellar keys address "$(ISSUER)")"
	asset="$(CODE):$$issuer_addr"
	contract_id="$$(stellar contract asset deploy --source "$(SOURCE)" --network "$(NETWORK)" --asset "$$asset")"
	printf '%s_ASSET=%s\n' "$(CODE)" "$$asset" >> "$(TOKEN_ENV)"
	printf '%s=%s\n' "$(CODE)" "$$contract_id" >> "$(TOKEN_ENV)"
	printf '%s\n' "$$contract_id"

token-id: preflight token-issuer
	issuer_addr="$$(stellar keys address "$(ISSUER)")"
	stellar contract id asset --network "$(NETWORK)" --asset "$(CODE):$$issuer_addr"

token-trust: preflight token-issuer
	issuer_addr="$$(stellar keys address "$(ISSUER)")"
	if [ "$(NETWORK)" = "testnet" ]; then stellar keys fund "$(TO)" --network "$(NETWORK)" >/dev/null || true; fi
	stellar tx new change-trust --source "$(TO)" --network "$(NETWORK)" --line "$(CODE):$$issuer_addr"

token-mint: preflight token-issuer
	issuer_addr="$$(stellar keys address "$(ISSUER)")"
	contract_id="$$(stellar contract id asset --network "$(NETWORK)" --asset "$(CODE):$$issuer_addr")"
	stellar contract invoke \
		--id "$$contract_id" \
		--source "$(ISSUER)" \
		--network "$(NETWORK)" \
		-- mint --to "$(TO)" --amount "$(AMOUNT)"

token-balance: preflight token-issuer
	issuer_addr="$$(stellar keys address "$(ISSUER)")"
	contract_id="$$(stellar contract id asset --network "$(NETWORK)" --asset "$(CODE):$$issuer_addr")"
	stellar contract invoke \
		--id "$$contract_id" \
		--source "$(SOURCE)" \
		--network "$(NETWORK)" \
		-- balance --id "$(TO)"

token-bootstrap: token-deploy token-trust token-mint token-balance

# Bootstrap all market tokens for a standard testnet deployment.
# Creates TWBTC and TUSDC, mints an initial amount to SOURCE.
#
# Usage:
#   make market-tokens NETWORK=testnet SOURCE=alice
#   make market-tokens LONG_CODE=TWBTC SHORT_CODE=TUSDC NETWORK=testnet SOURCE=alice

LONG_CODE  ?= TWBTC
SHORT_CODE ?= TUSDC
SEED_LONG  ?= 1000000000
SEED_SHORT ?= 1000000000

.PHONY: market-tokens

market-tokens: preflight
	$(MAKE) token-bootstrap CODE="$(LONG_CODE)"  TO="$(SOURCE)" AMOUNT="$(SEED_LONG)"  NETWORK="$(NETWORK)" SOURCE="$(SOURCE)"
	$(MAKE) token-bootstrap CODE="$(SHORT_CODE)" TO="$(SOURCE)" AMOUNT="$(SEED_SHORT)" NETWORK="$(NETWORK)" SOURCE="$(SOURCE)"
	@printf 'Market tokens ready. Run:\n'
	@printf '  make deploy-all NETWORK=$(NETWORK) SOURCE=$(SOURCE)\n'
	@printf '  make bootstrap  NETWORK=$(NETWORK) SOURCE=$(SOURCE) LONG_CODE=$(LONG_CODE) SHORT_CODE=$(SHORT_CODE)\n'

tokens:
	@test -f "$(TOKEN_ENV)" || { printf 'Missing %s. Run make token-bootstrap first.\n' "$(TOKEN_ENV)"; exit 1; }
	@sed -n '1,220p' "$(TOKEN_ENV)"
