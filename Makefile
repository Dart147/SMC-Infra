.PHONY: help core-up core-down core-restart logs check network-init

## Show help message
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' Makefile | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[0;32m%-15s\033[0m %s\n", $$1, $$2}'

core-up: ## Start Traefik (creates smc-traefik network if missing)
	@./scripts/core-manager.sh start

core-down: ## Stop Traefik
	@./scripts/core-manager.sh stop

core-restart: ## Restart Traefik
	@./scripts/core-manager.sh stop && ./scripts/core-manager.sh start

logs: ## Tail Traefik logs
	@./scripts/core-manager.sh logs

check: ## Check if Traefik container is running
	@./scripts/core-manager.sh check

network-init: ## Create the shared smc-traefik network if not exists
	@./scripts/core-manager.sh network-init
