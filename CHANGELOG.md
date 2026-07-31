# Changelog

Все заметные изменения проекта документируются в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
проект придерживается [семантического версионирования](https://semver.org/lang/ru/).

---

*All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/).*

## [Unreleased]

## [1.0.0] — 2026-07-31

Первый выпуск. / First release.

### Added

- Разделение PFX-контейнера по ГОСТ на `private.key` и `public.cer` в
  Docker-контейнере, без установки чего-либо в хост-систему.
  / Splitting of GOST PFX containers into `private.key` and `public.cer` inside
  a Docker container, with nothing installed on the host.
- Образ на базе Debian trixie: OpenSSL 3.5 и gost-engine, собранный из
  исходников, с одновременно включёнными engine `gost` и legacy provider —
  комбинация, необходимая для контейнеров КриптоПРО CSP.
  / A Debian trixie image with OpenSSL 3.5 and gost-engine built from source,
  enabling the `gost` engine and the legacy provider at the same time — the
  combination CryptoPro CSP containers require.
- Внешний `Makefile`: цели `build`, `rebuild`, `split`, `private`, `public`,
  `info`, `selftest`, `shell`, `clean`, `clean-image`, `help`.
  / Outer `Makefile` with those targets.
- Внутренний `docker/Makefile`: цели `info`, `private`, `public`, `split`,
  `selftest`, `help`.
  / Inner `docker/Makefile` with those targets.
- Приём пароля из переменной окружения `PFX_PASSWORD` или интерактивным
  запросом с отключённым эхом; пароль передаётся в контейнер через stdin.
  / Password taken from `PFX_PASSWORD` or asked for interactively with echo
  off; passed to the container over stdin.
- Результаты в `results/<имя pfx>/`, вне git-индекса, с правами 600 на ключ и
  с UID/GID вызывающего пользователя.
  / Results in `results/<pfx name>/`, kept out of the git index, key mode 600,
  files owned by the calling user.
- `make selftest`: генерация ГОСТ-контейнера внутри образа и его разделение —
  проверка работоспособности engine.
  / `make selftest`: generates a GOST container inside the image and splits it,
  verifying the engine.
- README на русском и английском языках, лицензия MIT.
  / README in Russian and English, MIT licence.

[Unreleased]: https://github.com/alexkudelin/gost-pfx-divider/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/alexkudelin/gost-pfx-divider/releases/tag/v1.0.0
