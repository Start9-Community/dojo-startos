# Updating the upstream version

This package builds its image from source. It pulls three upstreams: Dojo itself as a git
submodule, and Tor and Soroban as pinned source builds inside the `Dockerfile`.

## Determining the upstream version

- **Dojo** ([Dojo-Open-Source-Project/samourai-dojo](https://github.com/Dojo-Open-Source-Project/samourai-dojo)) — the release the `samourai-dojo` submodule is checked out at, and the upstream half of the package version:

  ```sh
  gh release view -R Dojo-Open-Source-Project/samourai-dojo --json tagName -q .tagName
  ```

- **Soroban** ([Dojo-Open-Source-Project/soroban](https://github.com/Dojo-Open-Source-Project/soroban)) — pinned by `SOROBAN_VERSION` in the `Dockerfile`:

  ```sh
  gh release view -R Dojo-Open-Source-Project/soroban --json tagName -q .tagName
  ```

- **Tor** — pinned by `TOR_VERSION` in the `Dockerfile`, as a tag in the Tor Project's git. This
  build serves Soroban's onion service only; the StartOS `tor` dependency is a separate thing and
  is not pinned here.

  ```sh
  git ls-remote --tags --refs https://gitlab.torproject.org/tpo/core/tor.git 'tor-*' | tail -5
  ```

## Applying the bump

- **Dojo**: check the submodule out at the new tag, then set `version` in
  `startos/versions/current.ts` to `<new version>:0`.

  ```sh
  git -C samourai-dojo fetch --tags
  git -C samourai-dojo checkout v<new version>
  git add samourai-dojo
  ```

  Read `samourai-dojo/RELEASES.md` for the release notes to summarize. If the bump adds or
  renames a `docker/my-dojo/.env` variable that `config.env` maps, update `config.env` in the
  same change.

- **Soroban**: set `SOROBAN_VERSION` in the `Dockerfile` (no leading `v`; the download URL adds it).

- **Tor**: set `TOR_VERSION` in the `Dockerfile` to the full tag (e.g. `tor-0.4.9.6`).

A Soroban or Tor bump alone is a wrapper change: leave the upstream version and increment the
downstream revision in `startos/versions/current.ts`.
