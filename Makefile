SHELL := /bin/bash

OS_NAME=$(shell hostnamectl | grep "Operating System" | sed -n s/.*System\://p | xargs)

DOCKERCMP=docker-compose
ifeq ("$(OS_NAME)", "Ubuntu 22.04.1 LTS")
	DOCKERCMP=docker compose
endif

# The version of the code.  Needed if you want to embed this in the
# code itself.
GIT_VERSION:=$(shell git describe --abbrev=6 --dirty --always --tags)

# check for dependencies to build the application (docker,
# docker-compose, etc)
EXECUTABLES = sudo nohup git docker docker-compose pytest-3
ifeq ("$(OS_NAME)", "Ubuntu 22.04.01 LTS")
	EXECUTABLES = sudo nohup git docker pytest-3
endif
K := $(foreach exec,$(EXECUTABLES),\
        $(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))

# Verbose flag used similarly to the Linux kernel kbuild system.  By
# default, the makefile is mostly silent/terse. to run, type: make
# V=n, where n can be any positive non-zero integer. by default, V=0
V=0
ifeq ($(V),0)
  Q = @
else
  Q = 
endif

# Include the .config file. This should be the single configuration
# file for the project:
-include .config

.PHONY: all
all: build ## Default rule: compile the main application
	@echo "make all rule"

.PHONY: host-setup
host-setup: ## Setup your build environment
	@echo "make host-setup rule"
	$(Q)git submodule update --init --recursive

.PHONY: build
build:	host-setup .config .env pgadmin/servers.json node-red/flows_cred.json node-red/flows.json ## Builds the application
	$(Q)$(DOCKERCMP) build

.PHONY: start
start:	host-setup mounted_volumes build ## Starts the application
	$(Q)nohup $(DOCKERCMP) up -d &
	@echo "Application Started - VERSION $(GIT_VERSION)"
	@echo "  Node-Red Workspace:                                  http://${HOST_IP}:${NODE_RED_PORT}/"
	@echo "  World Map:                                           http://${HOST_IP}:${NODE_RED_PORT}/worldmap/"
	@echo "  PgAdmin4                                             http://${HOST_IP}:${PGADMIN_PORT}/ user: $(PGADMIN_DEFAULT_EMAIL) password: $(PGADMIN_DEFAULT_PASSWORD)"

.PHONY: stop
stop: ## Stops the application
	$(Q) $(DOCKERCMP) down

.PHONY: clean
clean: stop ## Cleans the project
	-$(Q)rm -f *~ nohup.out
	-$(Q)$(DOCKERCMP) down --rmi local --remove-orphans
	-$(Q)for image in network-survey-server_test-runner ; do docker images | grep -q $${image} && docker rmi -f $${image} || /bin/true ; done
	-$(Q)for network in network-survey-server_frontend network-survey-server_frontend ; do docker network ls | grep -q $${network} && docker network rm $${network} || /bin/true ; done
	-$(Q)sudo rm -rf ./mounted_volumes
	-$(Q)rm -f substitutions.sed
	-$(Q)rm -f .env node-red/flows_cred.json node-red/flows.json pgadmin/servers.json

.PHONY: dist-clean
dist-clean: clean ## Really cleans the project (USE CAUTION!)
	$(Q)sudo git clean -xdff

# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '\#\#'
.PHONY: help
help:           ## Show this help
	$(Q)awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make <TARGET>\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  %-15s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

mounted_volumes:
	$(Q)./utils/setup_mounted_volumes.sh

# Create a script that converts variables in the form @VARIABLENAME@ to the VALUE
substitutions.sed: .config
	$(Q)sed -e 's/#.*//' -e '/^$$/d' -e 's/\([^=]*\)=\(.*\)/s;@\1@;\2;g/g' $< >$@

# Generate the pgadmin server file:
pgadmin/servers.json: pgadmin/servers.json.in substitutions.sed
	$(Q)sed -f substitutions.sed $< >$@

# Generate the docker environment file:
.env: .env.in substitutions.sed
	$(Q)sed -f substitutions.sed $< >$@

node-red/flows_cred.json: node-red/flows_cred.json.in substitutions.sed
	$(Q)sed -f substitutions.sed $< >$@

node-red/flows.json: node-red/flows.json.in substitutions.sed
	$(Q)sed -f substitutions.sed $< >$@

# overwrite the .config file from the 
.PHONY: defconfig
defconfig: ## Use the default config file (localhost)
	$(Q)cp .defconfig .config

# TODO: create `menuconfig` rule to create a config file using kconfig
.config:
	$(Q)cp .defconfig .config

