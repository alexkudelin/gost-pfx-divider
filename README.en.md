# gost-pfx-divider

[![selftest](https://github.com/alexkudelin/gost-pfx-divider/actions/workflows/selftest.yml/badge.svg)](https://github.com/alexkudelin/gost-pfx-divider/actions/workflows/selftest.yml)

Splits PFX (PKCS#12) containers holding keys and certificates issued with Russian GOST R algorithms into their private and public parts. Everything happens inside a Docker container — nothing is installed on the host.

*Читать по-русски: [README.md](README.md).*

```
make split PFX=ivanov.pfx
```

```
results/ivanov/
├── private.key   private key, PEM, no passphrase
└── public.cer    end-entity certificate, PEM
```

## The problem

A PFX issued by a Russian CA and exported from CryptoPro CSP does not open with a stock `openssl`:

```
$ openssl pkcs12 -in ivanov.pfx -nokeys -out public.cer
Error outputting keys and certificates
error:0308010C:digital envelope routines:inner_evp_generic_fetch:unsupported:
  Algorithm (RC2-40-CBC : 0), Properties ()
```

There are normally two reasons behind that message, and they bite at the same time:

1. **The contents are GOST.** The key and the certificate use GOST R 34.10-2012 and GOST R 34.11-2012, which stock OpenSSL does not implement. That needs [gost-engine](https://github.com/gost-engine/engine).
2. **The wrapper is ancient PBE.** On export, CryptoPro CSP still encrypts the certificate bag with `pbeWithSHA1And40BitRC2-CBC`, and OpenSSL 3.x moved RC2 into the *legacy provider*, which is off by default.

Hence the reputation of these files as unsplittable: enable one of the two and you get the same error somewhere else. Hence, too, the classic way to shoot yourself in the foot — build a patched OpenSSL and let it replace the system one. On most distributions everything from `apt` to `ssh` links against the system `libssl`, and that replacement breaks the base system for a long time.

## Why it is useful

**You split once, and from then on standard tooling works.**
This is the main point. PKCS#12 needs GOST-aware parsing *every time* the container is opened. After splitting you are left with two ordinary PEM files, and every application accepts those through its normal options — `ssl_certificate_key` in nginx, `--cert`/`--key` in curl, a path in a service config, a filename in a script. No patched OpenSSL on the production host, no gost-engine to carry around, no PKCS#12 parsing at runtime.

**The host stays clean.**
The GOST tooling lives inside the image and dies with the container. The system OpenSSL is never touched — no `LD_PRELOAD`, no edits to `/etc/ssl/openssl.cnf`, no `make install` into `/usr/local`.

**It ships as a box.**
Two make targets and no configuration: `make build`, `make split PFX=...`. You do not have to remember the `openssl pkcs12` flags or how an engine is enabled in the config file.

**It fits an air-gapped environment.**
Build the image once on a machine with internet access, move it over with `docker save`/`docker load`, and run it on a server that has no network. The split itself runs with `--network none`, so the container physically cannot send anything anywhere.

**The password does not leak into the process list.**
It is handed to the container over stdin rather than as a command line argument or a `docker run -e` variable: both of those are visible through `ps` and `docker inspect` to anyone with access to the host.

### Disclaimer

This is a simple solution found empirically. There is nothing novel in it: inside are the very same `openssl pkcs12` commands you could type by hand. The value is convenience, and the fact that the working combination of engine, provider and flags has already been figured out and written down.

One boundary is worth stating: splitting makes the files readable by any application, but it does not teach that application GOST cryptography. If what you need is a GOST TLS handshake, GOST support still has to exist on the client or server side. For everything else — feeding the key to a signing library, storing it in a secret manager, converting it, handing it to a service — the split PEM files are enough.

## Requirements

* Docker
* `make`

Nothing else. OpenSSL 3.5 and gost-engine are built inside the image.

## Quick start

```bash
git clone https://github.com/alexkudelin/gost-pfx-divider.git
cd gost-pfx-divider

make build                      # build the image (once, ~2 minutes)
make split PFX=~/certs/ivanov.pfx
```

The password is asked for interactively, with echo turned off:

```
Password for ivanov.pfx:
==> extracting private key
    /work/out/private.key  (Parameter set: id-GostR3410-2001-CryptoPro-A-ParamSet)
==> extracting certificate
    /work/out/public.cer  (subject=CN=Ivan Ivanov, O=Romashka LLC, C=RU)
==> done
==> results in results/ivanov/
```

Or non-interactively, through an environment variable, for scripts and CI:

```bash
export PFX_PASSWORD='...'
make split PFX=~/certs/ivanov.pfx
```

## Commands

The outer `Makefile` is the user interface:

| Command | What it does |
| --- | --- |
| `make split PFX=file.pfx` | extract both parts |
| `make private PFX=file.pfx` | private key only |
| `make public PFX=file.pfx` | certificate only |
| `make info PFX=file.pfx` | show the container structure and its algorithms, writing nothing |
| `make build` | build the image |
| `make rebuild` | rebuild without cache (picks up a fresh gost-engine) |
| `make selftest` | prove the engine works, on a generated GOST container |
| `make shell` | open a shell inside the image |
| `make clean` | delete everything under `results/` (asks first when run in a terminal) |
| `make clean-image` | delete the image |

`make build` is optional: if the image is missing, the first `make split` builds it.

Starting with `make info` is a good habit — it shows exactly how your container is encrypted:

```
$ make info PFX=~/certs/ivanov.pfx
MAC: sha1, Iteration 2048
PKCS7 Encrypted data: pbeWithSHA1And40BitRC2-CBC, Iteration 2048
Certificate bag
PKCS7 Data
Shrouded Keybag: pbeWithSHA1And40BitRC2-CBC, Iteration 2048
```

## Results

The PFX file name becomes a directory under `results/`, and both parts go in there:

```
results/<pfx name>/
├── private.key   PEM, no passphrase, mode 600
└── public.cer    PEM, mode 644
```

The whole `results/` directory is excluded from the git index, so private keys cannot slip into the repository by accident.

The files belong to you, not to root: the container runs with your UID and GID. The `friendlyName` and `localKeyID` bag attributes that CryptoPro puts in front of the PEM block — and that some parsers choke on — are stripped, leaving clean PEM.

`public.cer` holds the end-entity certificate only. A CA chain stored in the container is not extracted: applications need the owner certificate to present, and root certificates are usually in the trust store already.

### Using them

```nginx
ssl_certificate     /etc/ssl/ivanov/public.cer;
ssl_certificate_key /etc/ssl/ivanov/private.key;
```

```bash
curl --cert public.cer --key private.key https://service.example.ru/
```

In other words, exactly like any other key/certificate pair. That was the whole point.

## How it works

Two Makefiles, separated by the container boundary:

```
Makefile                 outer: the user interface
└── docker/
    ├── Dockerfile       Debian trixie + OpenSSL 3.5 + gost-engine from source
    ├── openssl.cnf      enables the gost engine and the legacy provider
    ├── entrypoint.sh    reads the password from stdin into the environment
    └── Makefile         inner: the actual openssl commands
```

**The outer Makefile** knows nothing about OpenSSL. It validates arguments, obtains the password, creates the output directory and starts the container: the PFX is mounted read-only at `/work/input.pfx`, the output directory at `/work/out`.

**The inner Makefile** knows nothing about Docker. It takes a file, a password in `$PFX_PASSWORD` and an output directory — and hides four `openssl pkcs12` invocations behind them. You can read it in a minute and see exactly what is done to your key; there is no magic in there.

The critical piece is `docker/openssl.cnf`, where the `gost` engine (GOST algorithms) and the legacy provider (that RC2) are enabled at the same time. That combination is precisely what is missing when "nothing works".

The private key passes through a temporary file inside the container rather than the mounted directory, and a `trap` removes it even on failure.

## Built on

This project is a wrapper around other people's work. Here it is:

* **[OpenSSL](https://github.com/openssl/openssl)** — [openssl.org](https://www.openssl.org/), Apache License 2.0. Version 3.5.x from Debian trixie is used; 3.4 or newer is required.
* **[gost-engine](https://github.com/gost-engine/engine)** — GOST R 34.10-2012, 34.11-2012, Magma and Kuznyechik for OpenSSL 3.x. OpenSSL / Apache 2.0 licence. Built from master when the image is built.
* **[Debian](https://www.debian.org/)** trixie-slim as the base image.

Thanks to their authors — all the actual cryptography here is theirs.

## Security notes

* `private.key` is written **without a passphrase** so it can be plugged straight into an application. That is a normal but sensitive file: it is created with mode 600, store it accordingly and never commit it.
* The PFX password travels over stdin and never appears in arguments, in the container environment, or in your shell history (when entered interactively).
* The container runs without network access (`--network none`) and without root privileges.
* The PFX is mounted read-only, so the source container cannot be damaged.
* Keys stay on your machine. This project sends nothing anywhere.

## Licence

MIT. See [LICENSE](LICENSE).

Author — Aleksei Kudelin.
