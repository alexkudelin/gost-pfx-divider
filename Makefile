# gost-pfx-divider — outer Makefile.
#
# This is the user-facing interface: it builds the image and runs the container
# with the right mounts, the right UID and the password on stdin. All OpenSSL
# knowledge lives in docker/Makefile, inside the container.
#
#   make build
#   make split PFX=path/to/container.pfx
#   PFX_PASSWORD=... make split PFX=path/to/container.pfx

SHELL := /bin/sh

IMAGE       ?= gost-pfx-divider
TAG         ?= 1.0.0
RESULTS_DIR ?= results
DOCKER      ?= docker

PFX     ?=
PFX_ABS := $(abspath $(PFX))
NAME    := $(basename $(notdir $(PFX)))
OUTDIR  := $(abspath $(RESULTS_DIR)/$(NAME))

UID := $(shell id -u)
GID := $(shell id -g)

.DEFAULT_GOAL := help
.PHONY: help build rebuild split private public info selftest shell clean clean-image ensure-image require-pfx

# --- user-facing targets --------------------------------------------------

help:
	@echo 'gost-pfx-divider $(TAG) — splits GOST PKCS#12 containers into a key and a certificate'
	@echo
	@echo 'Usage:'
	@echo '  make split PFX=path/to/container.pfx      extract both parts'
	@echo '  make private PFX=...                      extract the private key only'
	@echo '  make public PFX=...                       extract the certificate only'
	@echo '  make info PFX=...                         show what is inside the container'
	@echo
	@echo 'Maintenance:'
	@echo '  make build         build the image ($(IMAGE):$(TAG))'
	@echo '  make rebuild       rebuild it from scratch, without the layer cache'
	@echo '  make selftest      generate a GOST PFX inside the image and split it'
	@echo '  make shell         open a shell inside the image'
	@echo '  make clean         remove everything under $(RESULTS_DIR)/'
	@echo '  make clean-image   remove the Docker image'
	@echo
	@echo 'Password:'
	@echo '  export PFX_PASSWORD=...   taken from the environment, or'
	@echo '  (nothing)                 asked for interactively, with echo turned off'
	@echo
	@echo 'Results go to $(RESULTS_DIR)/<pfx name>/{private.key,public.cer}'

build:
	$(DOCKER) build -t '$(IMAGE):$(TAG)' -t '$(IMAGE):latest' docker

rebuild:
	$(DOCKER) build --no-cache --pull -t '$(IMAGE):$(TAG)' -t '$(IMAGE):latest' docker

split private public: ensure-image require-pfx
	@set -eu; \
	mkdir -p '$(OUTDIR)'; \
	$(get_password) \
	printf '%s' "$$password" | $(DOCKER) run --rm -i \
		--network none \
		-u '$(UID):$(GID)' \
		-v '$(PFX_ABS):/work/input.pfx:ro' \
		-v '$(OUTDIR):/work/out' \
		'$(IMAGE):$(TAG)' $@; \
	echo "==> results in $(RESULTS_DIR)/$(NAME)/"

info: ensure-image require-pfx
	@set -eu; \
	$(get_password) \
	printf '%s' "$$password" | $(DOCKER) run --rm -i \
		--network none \
		-u '$(UID):$(GID)' \
		-v '$(PFX_ABS):/work/input.pfx:ro' \
		'$(IMAGE):$(TAG)' info

selftest: ensure-image
	$(DOCKER) run --rm --network none '$(IMAGE):$(TAG)' selftest

shell: ensure-image
	$(DOCKER) run --rm -it --entrypoint /bin/sh '$(IMAGE):$(TAG)'

clean:
	@set -eu; \
	if [ -z "$$(ls -A '$(RESULTS_DIR)' 2>/dev/null | grep -v '^\.gitkeep$$' || true)" ]; then \
		echo 'nothing to clean'; exit 0; \
	fi; \
	echo 'about to delete extracted keys and certificates:'; \
	ls -1 '$(RESULTS_DIR)' | grep -v '^\.gitkeep$$' | sed 's|^|  $(RESULTS_DIR)/|'; \
	if [ -t 0 ]; then \
		printf 'proceed? [y/N] '; read -r answer; \
		case "$$answer" in y|Y|yes|YES) ;; *) echo 'aborted'; exit 0 ;; esac; \
	fi; \
	find '$(RESULTS_DIR)' -mindepth 1 ! -name .gitkeep -delete; \
	echo 'cleaned'

clean-image:
	-$(DOCKER) rmi '$(IMAGE):$(TAG)' '$(IMAGE):latest'

# --- helpers --------------------------------------------------------------

# Builds the image on first use so that `make split` works out of the box.
ensure-image:
	@$(DOCKER) image inspect '$(IMAGE):$(TAG)' >/dev/null 2>&1 || $(MAKE) --no-print-directory build

require-pfx:
	@test -n '$(PFX)' || { echo 'error: PFX is not set. Usage: make $(MAKECMDGOALS) PFX=path/to/container.pfx' >&2; exit 1; }
	@test -r '$(PFX_ABS)' || { echo 'error: cannot read $(PFX_ABS)' >&2; exit 1; }

# Puts the password into $password: from the environment if it is there,
# otherwise asked for on the terminal with echo turned off. It is then piped
# into the container on stdin — never as an argument and never as `docker -e`,
# both of which would expose it through `ps` and `docker inspect`.
define get_password
	password="$${PFX_PASSWORD:-}"; \
	if [ -z "$$password" ]; then \
		if [ ! -t 0 ]; then \
			echo 'error: PFX_PASSWORD is not set and there is no terminal to ask on' >&2; \
			exit 1; \
		fi; \
		trap 'stty echo 2>/dev/null || true' EXIT INT TERM; \
		printf 'Password for %s: ' '$(notdir $(PFX))' >&2; \
		stty -echo; read -r password; stty echo; printf '\n' >&2; \
	fi;
endef
