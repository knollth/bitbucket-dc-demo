# Bitbucket Data Center demo.
#
# Spin up a local, fully provisioned Bitbucket DC backed by PostgreSQL using a
# 3-hour Atlassian timebomb license. No setup wizard, no manual licensing.

SHELL := /usr/bin/env bash

COMPOSE := podman compose
ENV_FILE := .env

# Pull port and base URL from .env (falling back to defaults) for the banner.
PORT := $(shell [ -f $(ENV_FILE) ] && . ./$(ENV_FILE) 2>/dev/null; echo $${BITBUCKET_HTTP_PORT:-7990})
URL := $(shell [ -f $(ENV_FILE) ] && . ./$(ENV_FILE) 2>/dev/null; echo $${BITBUCKET_BASE_URL:-http://localhost:7990})

.DEFAULT_GOAL := help

.PHONY: help up down destroy seed logs status

help: ## Show this help.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-9s\033[0m %s\n", $$1, $$2}'

$(ENV_FILE):
	@cp .env.example $(ENV_FILE)
	@echo "Created $(ENV_FILE) from .env.example."

up: $(ENV_FILE) ## Start Bitbucket and PostgreSQL in the background.
	@$(COMPOSE) up --detach
	@echo
	@echo "Bitbucket is starting (first boot takes a few minutes)."
	@echo "  URL:      $(URL)"
	@echo "  Watch:    make logs"
	@echo "  Seed:     make seed   (creates the demo project and repo)"
	@echo
	@echo "The timebomb license expires ~3 hours after start."
	@echo "Run 'make destroy && make up' for a fresh instance."

down: ## Stop and remove the containers (keeps data volumes).
	@$(COMPOSE) down --remove-orphans

destroy: ## Stop everything and delete volumes and images.
	@./destroy.sh

seed: ## Wait for Bitbucket, then create the demo project and repo.
	@./seed.sh bootstrap

logs: ## Follow the Bitbucket container logs.
	@$(COMPOSE) logs --follow bitbucket

status: ## Show container status.
	@$(COMPOSE) ps
