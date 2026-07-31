# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Stage 1: build gost-engine against the distribution OpenSSL.
#
# Debian trixie ships OpenSSL 3.5.x, which satisfies the "3.4+" requirement.
# gost-engine has no Debian package for OpenSSL 3.x, so it is built from source
# and dropped into the OpenSSL engines directory reported by `openssl version -e`.
# ---------------------------------------------------------------------------
FROM debian:trixie-slim AS builder

ARG GOST_ENGINE_REPO=https://github.com/gost-engine/engine.git
ARG GOST_ENGINE_REF=master

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        git \
        libssl-dev \
        openssl \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "${GOST_ENGINE_REF}" --recurse-submodules \
        "${GOST_ENGINE_REPO}" engine

RUN cmake -S engine -B build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j "$(nproc)"

# The engine directory is arch-dependent (x86_64 vs aarch64), so ask OpenSSL.
RUN set -eu; \
    enginesdir="$(openssl version -e | sed -e 's/^ENGINESDIR: *"//' -e 's/"$//')"; \
    mkdir -p "/staging${enginesdir}"; \
    cp build/bin/gost.so "/staging${enginesdir}/gost.so"

# ---------------------------------------------------------------------------
# Stage 2: runtime. Only OpenSSL, make and the engine.
# ---------------------------------------------------------------------------
FROM debian:trixie-slim

LABEL org.opencontainers.image.title="gost-pfx-divider" \
      org.opencontainers.image.description="Splits GOST R PKCS#12 (PFX) containers into a private key and a certificate" \
      org.opencontainers.image.authors="Aleksei Kudelin" \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        make \
        openssl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /staging/usr /usr

COPY openssl.cnf /opt/gost-pfx-divider/openssl.cnf
COPY Makefile /opt/gost-pfx-divider/Makefile
COPY entrypoint.sh /opt/gost-pfx-divider/entrypoint.sh
RUN chmod 0755 /opt/gost-pfx-divider/entrypoint.sh

# The engines directory is arch-dependent, so the real path is stamped into the
# config at build time instead of being hard-coded for one architecture.
RUN set -eu; \
    enginesdir="$(openssl version -e | sed -e 's/^ENGINESDIR: *"//' -e 's/"$//')"; \
    sed -i "s|@ENGINESDIR@|${enginesdir}|" /opt/gost-pfx-divider/openssl.cnf; \
    test -f "${enginesdir}/gost.so"

# Every openssl invocation in this image loads the GOST engine and the legacy
# provider through this config. See openssl.cnf for the rationale.
ENV OPENSSL_CONF=/opt/gost-pfx-divider/openssl.cnf

# Fail the build instead of shipping an image where the engine does not load.
RUN openssl engine gost -c | grep -q 'md_gost12_256' \
    && openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out /dev/null

WORKDIR /work
ENTRYPOINT ["/opt/gost-pfx-divider/entrypoint.sh"]
CMD ["help"]
