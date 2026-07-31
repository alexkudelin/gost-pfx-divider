#!/bin/sh
# Reads the PFX password from stdin (unless it is already in the environment)
# and hands control over to the inner Makefile.
#
# The password deliberately never travels as a command line argument or as a
# `docker run -e` variable: both are readable by anyone who can run `ps` or
# `docker inspect` while the container is alive.
set -eu

if [ -z "${PFX_PASSWORD:-}" ]; then
    # `read` returns non-zero when the input has no trailing newline, which is
    # the normal case here, so the failure is expected and ignored.
    IFS= read -r PFX_PASSWORD || true
    PFX_PASSWORD="${PFX_PASSWORD:-}"
fi
export PFX_PASSWORD

exec make --no-print-directory -f /opt/gost-pfx-divider/Makefile "$@"
