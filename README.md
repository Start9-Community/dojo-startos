<p align="center">
  <img src="icon.png" alt="Dojo Logo" width="21%">
</p>

# Dojo on StartOS

> **Upstream docs:** <https://dojo-osp.org/>
>
> Everything not listed in this document should behave the same as upstream
> Dojo. If a feature, setting, or behavior is not mentioned here, the upstream
> documentation is accurate and fully applicable.

Dojo is the backend server for Ashigaru, Samourai Wallet and other light wallets. It tracks HD
account and BIP47 balances and transaction histories, serves unspent output lists to the wallet,
and broadcasts transactions through the user's own Bitcoin node. Upstream:
[Dojo-Open-Source-Project/samourai-dojo](https://github.com/Dojo-Open-Source-Project/samourai-dojo).

---

## Table of Contents

- [Image and Container Runtime](#image-and-container-runtime)
- [Volume and Data Layout](#volume-and-data-layout)
- [Installation and First-Run Flow](#installation-and-first-run-flow)
- [Configuration Management](#configuration-management)
- [Network Access and Interfaces](#network-access-and-interfaces)
- [Actions (StartOS UI)](#actions-startos-ui)
- [Backups and Restore](#backups-and-restore)
- [Health Checks](#health-checks)
- [Dependencies](#dependencies)
- [Limitations and Differences](#limitations-and-differences)
- [What Is Unchanged from Upstream](#what-is-unchanged-from-upstream)
- [Contributing](#contributing)
- [Quick Reference for AI Consumers](#quick-reference-for-ai-consumers)

---

## Image and Container Runtime

One image, built from the `Dockerfile` at the repository root for `x86_64` and `aarch64`. It has
three build stages beyond the runtime layer: Dojo's own `npm install` against the `samourai-dojo`
submodule, Tor from source (for Soroban's onion service), and Soroban from source.

Upstream ships Dojo as a docker-compose stack of separate containers — node, db, nginx, tor,
soroban, and an explorer. This package collapses that into one image and runs four StartOS daemons
inside a **single shared subcontainer**, because the upstream components address each other over
`127.0.0.1`:

| Daemon     | Command                            | What it runs                               |
| ---------- | ---------------------------------- | ------------------------------------------ |
| `mariadb`  | `/assets/db-entrypoint.sh`         | MariaDB, initialised and migrated on start |
| `soroban`  | `/assets/soroban-entrypoint.sh`    | The Soroban server, as the `soroban` user  |
| `backend`  | `/assets/backend-entrypoint.sh`    | Dojo's API, tracker and pushtx under pm2   |
| `frontend` | `/assets/frontend-entrypoint.sh`   | nginx, fronting all three                  |

Those entrypoints and the health scripts live in `assets/` and are mounted read-only at `/assets`
rather than copied into the image, so editing one does not rebuild the Tor and Soroban source
stages. Each sources `/assets/config.env`, the package's only translation layer between StartOS and
upstream (see [Configuration Management](#configuration-management)). Upstream's
`docker_entrypoint.sh` equivalent — a single script starting every process — is not used.

## Volume and Data Layout

| Volume | Mountpoint       | Contents                                                    |
| ------ | ---------------- | ----------------------------------------------------------- |
| `main` | `/data`          | `store.json` (package state), `backend.json` (pairing code) |
| `db`   | `/var/lib/mysql` | The MariaDB data directory                                  |

The selected Bitcoin node's `main` volume is also mounted read-only at `/mnt/bitcoin`, purely so
Dojo can read the RPC cookie. Its path within the volume differs between mainnet and testnet4 and
is imported from the Bitcoin package rather than hardcoded.

`store.json` holds everything the user configures plus the three generated secrets. Dojo's own
`keys/index.js` is generated from environment variables at container start and is not persisted.

## Installation and First-Run Flow

Upstream expects the operator to fill in a `.env` file before first launch. This package generates
the equivalent instead:

- **The API key, admin key and JWT secret are generated once on install** and written to
  `store.json`. They are not regenerated on restart, so the pairing code stays stable. The user can
  overwrite any of them with the **Configure Dojo** action.
- **Bitcoin and the indexer are configured through StartOS dependencies.** A critical task is
  raised against the selected Bitcoin node requiring pruning disabled and txindex and ZeroMQ
  enabled, prefilled so the user can accept it in one step.
- **The service will not start until a Tor address exists** on the Web UI interface. Dojo's pairing
  payload is its onion URL, so there is nothing useful to serve without one; the **Tor Address**
  health check states this and gates the `backend` daemon.

## Configuration Management

| StartOS-Managed                                                                                                                                              | Upstream-Managed                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| Bitcoin node selection, indexer selection, API/admin/JWT keys, BIP47 payment code, Soroban announce and PandoTx settings, and every network address Dojo dials | Everything else in Dojo's own configuration, and all runtime state in the maintenance tool |

`main.ts` resolves Bitcoin's RPC and ZeroMQ endpoints, the indexer's Electrum endpoint and Tor's
SOCKS proxy with `sdk.host.getBridgeAddress`, and passes them — along with the user's settings —
to every daemon as `S9_*` environment variables. `config.env` maps those onto the names Dojo
actually reads.

The ordering inside `config.env` is load-bearing: it sources upstream's `docker/my-dojo/.env`
first, for Dojo's own defaults, and applies the StartOS-resolved values after it. Setting an
upstream variable name directly from `main.ts` would be overwritten by that source.

The StartOS-managed environment variables are:

| Variable                                        | Resolved from                                    |
| ----------------------------------------------- | ------------------------------------------------ |
| `S9_BITCOIN_RPC_HOST` / `S9_BITCOIN_RPC_PORT`   | The Bitcoin node's `rpc` host over the bridge    |
| `S9_BITCOIN_ZMQ_BLOCK` / `S9_BITCOIN_ZMQ_TX`    | The Bitcoin node's `zmq` host over the bridge    |
| `S9_BITCOIN_COOKIE` / `S9_BITCOIN_NETWORK`      | The selected node's cookie path and chain        |
| `S9_INDEXER_HOST` / `S9_INDEXER_PORT`           | The indexer's Electrum host over the bridge      |
| `S9_TOR_SOCKS_HOST` / `S9_TOR_SOCKS_PORT`       | Tor's SOCKS binding over the bridge              |
| `S9_TOR_ADDRESS`                                | The onion address on the Web UI interface        |
| `S9_API_KEY` / `S9_ADMIN_KEY` / `S9_JWT_SECRET` | `store.json`, generated on install               |
| `S9_PAYMENT_CODE`                               | `store.json`, set by the user                    |
| `S9_SOROBAN_ANNOUNCE` / `S9_PANDOTX_*`          | `store.json`, set by the user                    |
| `S9_DATA_DIR`                                   | The `main` volume mountpoint                     |

## Network Access and Interfaces

| Interface | Port | Protocol | Purpose                                                        |
| --------- | ---- | -------- | -------------------------------------------------------------- |
| `ui`      | 9000 | HTTP     | The Dojo Maintenance Tool, and the API wallets pair to          |

nginx is the only listener bound to the interface. It proxies `/v2/` to the accounts API,
`/v2/pushtx/` and `/v2/tracker/` to their own upstream processes, `/admin/` to the maintenance
tool, and redirects `/` to `/admin/`. MariaDB, Soroban and the three Node processes stay on
loopback inside the container.

The interface's host id is `main` and its interface id is `ui`. Where it is reachable — LAN, a
`.local` name, an onion address, a custom domain — is the user's choice, made in StartOS.

## Actions (StartOS UI)

| Action                | Group         | Availability | Input                                                               | Output                        |
| --------------------- | ------------- | ------------ | ------------------------------------------------------------------- | ----------------------------- |
| **Select Bitcoin Node** | Configuration | Any status   | Bitcoin or Bitcoin (testnet4)                                       | —                             |
| **Select Indexer**      | Configuration | Any status   | Fulcrum or Electrs                                                  | —                             |
| **Configure Dojo**      | Configuration | Any status   | Payment code, API/admin/JWT keys, Soroban announce, PandoTx settings | —                             |
| **View Pairing Code**   | Credentials   | Only running | —                                                                   | Pairing code (QR) + admin key |

All four are `visibility: 'enabled'`. Selecting a node or indexer rewrites the declared dependency,
so StartOS prompts to install the newly selected one and drops the old requirement.

**View Pairing Code** reads `backend.json`, which the `backend` daemon writes at startup — hence
"only running". The payload it returns is the one the maintenance tool's own Pairing screen builds:
Dojo's `/support/pairing` response plus the API URL a browser would have filled in from its
location.

## Backups and Restore

The `db` volume is dumped with `mysqldump` rather than copied, because MariaDB writes its data
directory continuously while Dojo runs and an rsync of it would be torn. The backup therefore holds
a single `samourai-main-db.dump` in place of the data directory, alongside an rsync of the `main`
volume — so `store.json`, and with it the API key, admin key and JWT secret, survives a restore.

On restore, Dojo replays its own database migrations at startup and resumes tracking from the last
indexed block; it does not rescan from genesis.

The Tor address is not carried in this backup — it belongs to the interface's host and its key is
held by the Tor service — but on the same server it is re-attached to the restored interface, so
the pairing code stays valid. **Tor Address** reports failure for the short window before that
happens, and the `backend` daemon waits on it.

## Health Checks

| Check                     | Kind          | Method                                                          |
| ------------------------- | ------------- | --------------------------------------------------------------- |
| **Tor Address**           | Standalone    | An onion address is present on the Web UI interface              |
| **Bitcoin Client**        | Standalone    | Bitcoin's `getnetworkinfo` subversion is one Dojo supports        |
| **Database**              | `mariadb`     | `mysqladmin ping` (2 min grace)                                  |
| **Soroban**               | `soroban`     | `soroban-server` is running and listening                        |
| **Dojo API**              | `backend`     | Authenticated `GET /status` against the accounts API (2 min grace) |
| **Web UI**                | `frontend`    | Port 9000 is bound (2 min grace)                                 |
| **Transaction Broadcast** | Standalone    | Authenticated `GET /status` against the pushtx API               |
| **Sync Progress**         | Standalone    | Dojo's tracked height against Bitcoin's (12 min grace)           |

The shell health scripts report more than pass/fail through their exit code — `0` healthy, `60` not
up yet, `62` broken and needing the user, anything else up but not yet usable — so a service that is
catching up reports progress rather than failure, and one that cannot proceed says why. `Dojo API`
gates on `Tor Address`, `Bitcoin Client`, `Database` and `Soroban`; `Web UI` gates on `Dojo API`.

## Dependencies

| Dependency               | Required | Health checks required | Purpose                                                                    |
| ------------------------ | -------- | ---------------------- | -------------------------------------------------------------------------- |
| **Tor**                  | Yes      | `tor`                  | Publishes the onion wallets pair to, and carries Dojo's outbound traffic    |
| **Bitcoin**              | Optional | `bitcoind`             | Blockchain data over RPC, block and transaction events over ZeroMQ, and transaction broadcast. Its `main` volume is mounted read-only at `/mnt/bitcoin` for the RPC cookie |
| **Bitcoin (testnet4)**   | Optional | `bitcoind`             | The same, against testnet4                                                 |
| **Fulcrum**              | Optional | `primary`              | Address lookups and rescans                                                |
| **Electrs**              | Optional | `electrs`              | Address lookups and rescans                                                |

Exactly one Bitcoin flavor and one indexer are declared at a time, following the user's selection;
the version floors live in `startos/dependencies.ts`. Only the daemon-level health check is
required of the indexer, not its sync check — Dojo reports its own import progress, and waiting for
a first index would leave the service unavailable for hours.

Bitcoin (testnet4) is [`remcoros/bitcoind-testnet4-startos`](https://github.com/remcoros/bitcoind-testnet4-startos),
a community fork of the Start9 Bitcoin Core package. It is not published in a Start9 registry.

## Limitations and Differences

1. **A Tor address is required.** Dojo's pairing payload is its onion URL. Until the user adds a
   Tor address to the Web UI interface, the `backend` daemon does not start.
2. **The block explorer is mempool.space's public onion, not a local one.** Upstream's compose
   stack runs an explorer container alongside Dojo; this package ships none and advertises
   mempool.space's hidden service in the pairing payload instead. Transaction lookups the wallet
   makes through that link go to a third party over Tor.
3. **Switching between mainnet and testnet4 is not a migration.** The database is built for one
   chain. Changing the selection on a Dojo that has already tracked wallets leaves it pointed at a
   chain its data does not match.
4. **Bitcoin must be unpruned with txindex and ZeroMQ enabled.** Dojo reads raw transactions over
   RPC and subscribes to block events. The critical task raised on install sets this.
5. **Bitcoin Knots is not supported — by upstream policy, not by capability.**
   `lib/bitcoind-rpc/rpc-client.js` matches `getnetworkinfo`'s subversion against the literal
   string `Knots` and calls `process.exit(0)`; there is no version comparison and no feature probe.
   Left alone the accounts API crash-loops. The `bitcoind` dependency range therefore excludes both
   Knots flavors, and the **Bitcoin Client** health check states the reason and holds the `backend`
   daemon. Excluded by flavor rather than a version floor because the upstream rule has no version
   axis: every Knots build is refused, so a floor above whatever line Knots currently ships would
   stop excluding it the moment it caught up.
6. **Upstream's Knots peer-banning is not carried over.** my-dojo runs its own `bitcoind` and, when
   `BITCOIND_BAN_KNOTS` is on, runs `ban-knots.sh` against it every ten minutes — enumerating peers
   and `setban`-ing any whose subversion contains `Knots` until 2030. This package ships no Bitcoin
   node and never invokes that script, so it cannot and does not modify the peer list or ban list of
   the node it connects to.
7. **No bundled Bitcoin node or indexer.** Upstream can install its own; here both are StartOS
   dependencies, so Dojo shares the node and indexer the rest of the server already uses.
8. **Soroban's onion service is served by the Tor daemon built into this image**, not by the
   StartOS Tor service, which handles the Web UI interface instead.

## What Is Unchanged from Upstream

- The Dojo API, tracker and pushtx processes, and the pm2 configuration that supervises them.
- The database schema and Dojo's own migration scripts, which run on every start.
- The Dojo Maintenance Tool, including its pairing, transaction and API-key screens.
- The nginx routing map, taken from upstream with only the listening port changed.
- PandoTx and Soroban behavior, including announce, relay, retries and fallback semantics.
- BIP44/49/84 derivation, BIP47 payment codes, and Ricochet, Stonewall, StonewallX2 and Stowaway
  support.

## Contributing

See [AGENTS.md](AGENTS.md).

---

## Quick Reference for AI Consumers

```yaml
package_id: dojo
architectures: [x86_64, aarch64]
volumes:
  main: /data
  db: /var/lib/mysql
dependency_mounts:
  bitcoind_or_bitcoind-testnet_main: /mnt/bitcoin (read-only)
ports:
  ui: 9000
dependencies: [tor, bitcoind, bitcoind-testnet, fulcrum, electrs]
startos_managed_env_vars:
  - S9_DATA_DIR
  - S9_TOR_ADDRESS
  - S9_TOR_SOCKS_HOST
  - S9_TOR_SOCKS_PORT
  - S9_BITCOIN_NETWORK
  - S9_BITCOIN_RPC_HOST
  - S9_BITCOIN_RPC_PORT
  - S9_BITCOIN_ZMQ_BLOCK
  - S9_BITCOIN_ZMQ_TX
  - S9_BITCOIN_COOKIE
  - S9_INDEXER_TYPE
  - S9_INDEXER_HOST
  - S9_INDEXER_PORT
  - S9_API_KEY
  - S9_ADMIN_KEY
  - S9_JWT_SECRET
  - S9_PAYMENT_CODE
  - S9_SOROBAN_ANNOUNCE
  - S9_PANDOTX_PROCESS
  - S9_PANDOTX_PUSH
  - S9_PANDOTX_FALLBACK
  - S9_PANDOTX_RETRIES
actions:
  - select-bitcoin-node
  - select-indexer
  - configure-dojo
  - view-credentials
```
