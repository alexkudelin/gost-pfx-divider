# Inner Makefile — runs inside the container.
#
# This is where the actual OpenSSL work happens. Nothing here knows about
# Docker: it takes a PFX file, a password in $PFX_PASSWORD, and writes the
# split parts into $(OUT).

SHELL := /bin/sh

PFX     ?= /work/input.pfx
OUT     ?= /work/out
OPENSSL ?= openssl

KEY  := $(OUT)/private.key
CERT := $(OUT)/public.cer

PASSIN := -passin env:PFX_PASSWORD

.PHONY: help info private public split selftest

help:
	@echo 'gost-pfx-divider — inner targets (run inside the container)'
	@echo
	@echo '  info      show the PKCS#12 structure and the algorithms it uses'
	@echo '  private   extract the private key    -> $(KEY)'
	@echo '  public    extract the certificate    -> $(CERT)'
	@echo '  split     extract both (shortcut)'
	@echo '  selftest  build a throwaway GOST PFX and split it, to prove the engine works'
	@echo
	@echo 'Input:  $(PFX)'
	@echo 'Output: $(OUT)'
	@echo 'Password is taken from the PFX_PASSWORD environment variable.'
	@echo
	@$(OPENSSL) version
	@echo "gost engine: $$($(OPENSSL) engine gost -c >/dev/null 2>&1 && echo available || echo MISSING)"

# --- inspection -----------------------------------------------------------

info: | check-input
	@echo '==> PKCS#12 structure of $(PFX)'
	@$(OPENSSL) pkcs12 -in '$(PFX)' -info -nokeys -noout $(PASSIN)

# --- extraction -----------------------------------------------------------

# Both extractions run the raw bag through `openssl pkey` / `openssl x509`.
# That drops the friendlyName / localKeyID bag attributes CryptoPro puts in
# front of the PEM block, which some parsers choke on, and leaves a plain
# textbook PEM file behind.

private: | check-input check-output
	@echo '==> extracting private key'
	@set -eu; \
	umask 077; \
	tmp="$$(mktemp)"; \
	trap 'rm -f "$$tmp"' EXIT INT TERM; \
	$(OPENSSL) pkcs12 -in '$(PFX)' -nocerts -noenc $(PASSIN) -out "$$tmp"; \
	$(OPENSSL) pkey -in "$$tmp" -out '$(KEY)'; \
	chmod 600 '$(KEY)'; \
	paramset="$$($(OPENSSL) pkey -in '$(KEY)' -noout -text_pub 2>/dev/null | grep -m1 'Parameter set:' || true)"; \
	echo "    $(KEY)$${paramset:+  ($$paramset)}"

public: | check-input check-output
	@echo '==> extracting certificate'
	@set -eu; \
	tmp="$$(mktemp)"; \
	trap 'rm -f "$$tmp"' EXIT INT TERM; \
	$(OPENSSL) pkcs12 -in '$(PFX)' -clcerts -nokeys $(PASSIN) -out "$$tmp"; \
	$(OPENSSL) x509 -in "$$tmp" -out '$(CERT)'; \
	chmod 644 '$(CERT)'; \
	echo "    $(CERT)  ($$($(OPENSSL) x509 -in '$(CERT)' -noout -subject))"

split: private public
	@echo '==> done'

# --- guards ---------------------------------------------------------------

.PHONY: check-input check-output
check-input:
	@test -r '$(PFX)' || { echo "error: cannot read $(PFX)" >&2; exit 1; }

check-output:
	@test -d '$(OUT)' || { echo "error: $(OUT) is not a directory" >&2; exit 1; }
	@test -w '$(OUT)' || { echo "error: $(OUT) is not writable" >&2; exit 1; }

# --- self test ------------------------------------------------------------

# Generates a GOST R 34.10-2012 key, a self-signed certificate, packs them into
# a PFX and splits it again. This exercises the engine and the whole pipeline
# end to end without needing a real certificate. It does NOT reproduce the
# exact algorithm mix CryptoPro CSP uses on export — only a real container can
# do that.
selftest:
	@set -eu; \
	tmp="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmp"' EXIT; \
	export PFX_PASSWORD=selftest; \
	echo '==> generating a GOST R 34.10-2012 (256 bit) key'; \
	$(OPENSSL) genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out "$$tmp/key.pem"; \
	echo '==> issuing a self-signed certificate'; \
	$(OPENSSL) req -new -x509 -key "$$tmp/key.pem" -out "$$tmp/cert.pem" -days 1 \
		-subj '/CN=gost-pfx-divider selftest'; \
	echo '==> packing them into a PFX'; \
	$(OPENSSL) pkcs12 -export -inkey "$$tmp/key.pem" -in "$$tmp/cert.pem" \
		-out "$$tmp/selftest.pfx" -passout env:PFX_PASSWORD; \
	echo '==> splitting it back'; \
	$(MAKE) --no-print-directory -f '$(firstword $(MAKEFILE_LIST))' split \
		PFX="$$tmp/selftest.pfx" OUT="$$tmp"; \
	$(OPENSSL) pkey -in "$$tmp/private.key" -noout; \
	$(OPENSSL) x509 -in "$$tmp/public.cer" -noout; \
	echo '==> selftest passed'
