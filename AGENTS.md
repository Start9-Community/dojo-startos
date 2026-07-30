# AGENTS.md

This is a StartOS service-package repository — it builds a `.s9pk` for StartOS.

Develop it inside a StartOS packaging workspace created by `start-cli s9pk init-workspace`,
which provides the packaging guide and agent context one level up. If you're reading this in a
bare clone with no workspace, the full guide is at <https://docs.start9.com/packaging>.

**Start every task at the recipe index** — `../start-technologies/projects/start-sdk/docs/src/recipes.md`
(or <https://docs.start9.com/packaging/recipes.html>). It maps an intent ("prompt the user to create
admin credentials", "expose a web UI") to the constructs, the reference pages, and a named production
package to copy. Find the recipe before you read this package's neighbours: a package you reach by
grepping may be non-conformant, and the recipe outranks it.

Work this package's `TODO.md` from top to bottom. Keep `README.md` (architecture, for developers and LLMs) and `instructions.md` (end-user docs) in sync with your changes.

## This repo

- **Package id is `dojo`.** It wraps the `samourai-dojo` git submodule — check it out (`git submodule update --init`) before building; the Dockerfile builds from it, plus Tor and Soroban from source, so a cold image build is slow.
- **Four daemons share one subcontainer** (`dojo-sub`): MariaDB, Soroban, the Dojo API under pm2, and nginx. They talk to each other over `127.0.0.1`, so they must keep sharing a single `SubContainer` instance — splitting them breaks every internal connection.
- **`main.ts` is the only place that resolves addresses.** Bitcoin's RPC and ZeroMQ, the indexer's Electrum port and Tor's SOCKS proxy are read with `sdk.host.getBridgeAddress` and passed to the daemons as `S9_*` environment variables. Never reintroduce `<pkg>.startos` DNS names or hardcoded dependency ports — they are deprecated and the ports are assigned dynamically.
- **The entrypoint and health scripts live in `assets/`**, mounted read-only at `/assets` by `main.ts` and invoked as `['bash', '/assets/<script>']` — not baked into the image, because the Dockerfile compiles Tor and Soroban from source and a script edit should not pay for that. Keep new scripts there; the only script still copied in is upstream's `soroban-restart.sh`, which comes from the submodule.
- **`assets/config.env` maps `S9_*` onto the names Dojo reads**, and the ordering is load-bearing: it sources upstream's own `docker/my-dojo/.env` first for Dojo's defaults, then applies everything StartOS resolved. Setting an upstream name (`NODE_API_KEY`, `BITCOIND_IP`, …) directly from `main.ts` would be clobbered by that source.
- **The three secrets are minted once** by `init/seedSecrets.ts` and persisted in `store.json`. Do not give them generated defaults in the file model — a `.catch()` default is evaluated per process and never written back, so every restart would hand out a new API key and change the user's pairing code.
- **Health scripts use a three-way exit protocol**: `0` healthy, `60` still starting, anything else still loading. `runCheckScript` in `main.ts` maps it; `sdk.healthCheck.runHealthScript` cannot express it.
- **`bc` is not in the image.** Compute percentages with bash arithmetic.

## Inspecting a running install

To run a command inside the service's container (read its generated config, grep app logs), use `start-cli package attach dojo -n dojo-sub -- <cmd>`. Select the subcontainer by **name** with `-n` (the name passed to `SubContainer.of` in `main.ts` — here `dojo-sub`) or by image with `-i`. Note: `-s/--subcontainer` matches the internal **Guid**, not the name, so passing a name to `-s` fails with "no matching subcontainers".
